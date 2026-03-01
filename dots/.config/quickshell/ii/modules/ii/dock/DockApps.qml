import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property bool isPinned: false
    signal togglePinRequested()
    readonly property real dockPadding: (Config.options?.dock.height ?? 60) * 0.10

    readonly property bool isVertical:       GlobalStates.dockIsVertical
    readonly property bool requestDockShow:  previewPopup.visible || anyContextMenuOpen

    // ── Preview popup sizing ──────────────────────────────────────
    readonly property real maxWindowPreviewHeight: 200
    readonly property real maxWindowPreviewWidth:  300
    readonly property real windowControlsHeight:   30

    // ── Internal state ────────────────────────────────────────────
    property var  processedApps:      []
    property bool anyContextMenuOpen: false
    property bool popupIsResizing:    false

    // Hover
    property Item lastHoveredButton
    property bool buttonHovered: false

    // Drag
    property bool   dragActive:    false
    property string draggedAppId:  ""
    property var    liveOrder:     []
    property bool   willUnpin:     false

    readonly property bool dragIsOriginallyPinned: Config.options.dock.pinnedApps.indexOf(draggedAppId) !== -1

    // ── Helpers ───────────────────────────────────────────────────

    readonly property point hoveredButtonCenter: {
        if (!root.lastHoveredButton) return Qt.point(0, 0)
        return root.lastHoveredButton.mapToItem(
            null,
            root.lastHoveredButton.width  / 2,
            root.lastHoveredButton.height / 2
        )
    }

    // ── App model ─────────────────────────────────────────────────

    function updateModel() {
        root.processedApps = (TaskbarApps.apps ?? []).map(app => ({
            uniqueKey: app.appId,
            appData:   app
        }))
    }

    function buildDragModel() {
        const pinned = root.liveOrder
            .map(id => root.processedApps.find(a => a.appData.appId === id))
            .filter(Boolean)

        const separator = root.processedApps.find(a => a.appData.appId === "SEPARATOR")
            ?? { uniqueKey: "SEPARATOR_VIRTUAL", appData: { appId: "SEPARATOR", toplevels: [], pinned: false } }
        pinned.push(separator)

        const unpinned = root.processedApps.filter(a =>
            a.appData.appId !== "SEPARATOR" &&
            !root.liveOrder.includes(a.appData.appId) &&
            !a.appData.pinned
        )

        return [...pinned, ...unpinned]
    }

    // ── Drag logic ────────────────────────────────────────────────

    function startDrag(appId, sourceItem) {
        root.draggedAppId = appId
        root.liveOrder    = Config.options.dock.pinnedApps.slice()
        root.willUnpin    = false
        root.dragActive   = true
        root.buttonHovered = false
        previewPopup.show  = false

        const pos = sourceItem.mapToItem(root, 0, 0)
        dragGhost.x = pos.x
        dragGhost.y = pos.y
    }

    function moveDragGhost(x, y) {
        const clampedCenter = _clampGhostCenter(x, y)
        dragGhost.x = clampedCenter.x - dragGhost.width  / 2
        dragGhost.y = clampedCenter.y - dragGhost.height / 2

        root.willUnpin = _isOutsideDock(clampedCenter) || _isPastSeparator(clampedCenter)

        if (root.willUnpin) {
            _removeTransientFromOrder()
        } else {
            _ensureDraggedInOrder()
            _reorderByHover(clampedCenter)
        }
    }

    function endDrag() {
        if (root.willUnpin) {
            Config.options.dock.pinnedApps =
                Config.options.dock.pinnedApps.filter(id => id !== root.draggedAppId)
        } else if (root.liveOrder.length > 0) {
            Config.options.dock.pinnedApps = root.liveOrder
        }

        root.dragActive        = false
        root.draggedAppId      = ""
        root.liveOrder         = []
        root.willUnpin         = false
        root.buttonHovered     = false
        root.lastHoveredButton = null
    }

    // Private drag helpers (prefix _ by convention)

    function _clampGhostCenter(x, y) {
        const pos = _dockClampBounds()
        return Qt.point(
            Math.max(pos.minX, Math.min(x, pos.maxX)),
            Math.max(pos.minY, Math.min(y, pos.maxY))
        )
    }

    function _dockClampBounds() {
        switch (GlobalStates.dockEffectivePosition) {
            case "top":    return { minX: -20, maxX: root.width + 15, minY:  15, maxY: root.height - 10 }
            case "left":   return { minX:  15, maxX: root.width - 10, minY: -20, maxY: root.height + 15 }
            case "right":  return { minX:  10, maxX: root.width - 15, minY: -20, maxY: root.height + 15 }
            default:       return { minX: -20, maxX: root.width + 15, minY:  10, maxY: root.height - 15 } // bottom
        }
    }

    function _isOutsideDock(center) {
        const margin = 40
        return center.x < -margin || center.x > root.width  + margin
            || center.y < -margin || center.y > root.height + margin
    }

    function _pinnedZoneEnd() {
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            if (child.appToplevel?.appId === "SEPARATOR") {
                const p = child.mapToItem(root, 0, 0)
                return root.isVertical ? p.y : p.x
            }
        }
        return Config.options.dock.pinnedApps.length > 0
            ? (root.isVertical ? root.height : root.width)
            : 60
    }

    function _isPastSeparator(center) {
        const end = _pinnedZoneEnd()
        return root.isVertical ? center.y > end : center.x > end
    }

    function _ensureDraggedInOrder() {
        if (!root.liveOrder.includes(root.draggedAppId)) {
            root.liveOrder = [...root.liveOrder, root.draggedAppId]
        }
    }

    function _removeTransientFromOrder() {
        if (!Config.options.dock.pinnedApps.includes(root.draggedAppId)) {
            root.liveOrder = root.liveOrder.filter(id => id !== root.draggedAppId)
        }
    }

    function _reorderByHover(center) {
        const hoveredId = _findHoveredAppId(center)
        if (!hoveredId) return

        const withoutDragged = root.liveOrder.filter(id => id !== root.draggedAppId)
        const targetIdx      = withoutDragged.indexOf(hoveredId)
        if (targetIdx === -1) return

        const oldIdx   = root.liveOrder.indexOf(root.draggedAppId)
        const hoverIdx = root.liveOrder.indexOf(hoveredId)
        const insertAt = (oldIdx === -1 || oldIdx < hoverIdx) ? targetIdx + 1 : targetIdx

        withoutDragged.splice(insertAt, 0, root.draggedAppId)
        root.liveOrder = withoutDragged
    }

    function _findHoveredAppId(center) {
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            if (!child.appToplevel) continue
            const id = child.appToplevel.appId
            if (id === root.draggedAppId || id === "SEPARATOR") continue
            if (!root.liveOrder.includes(id)) continue

            const p = child.mapToItem(root, 0, 0)
            if (center.x >= p.x && center.x <= p.x + child.width &&
                center.y >= p.y && center.y <= p.y + child.height) {
                return id
            }
        }
        return ""
    }

    // ── Connections ───────────────────────────────────────────────

    Connections {
        target: TaskbarApps
        function onAppsChanged() { root.updateModel() }
    }

    Connections {
        target: GlobalStates
        function onDockEffectivePositionChanged() {
            if (root.lastHoveredButton) previewPopup.anchor.updateAnchor()
        }
    }

    Component.onCompleted: updateModel()

    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight


    // ── Drag ghost ────────────────────────────────────────────────
    DockDragGhost {
        id: dragGhost
        visible:       root.dragActive
        draggedAppId:  root.draggedAppId
        willUnpin:     root.willUnpin
        z: 10
    }

    // ── Main layout ───────────────────────────────────────────────
    GridLayout {
        id: layout
        anchors.centerIn: parent
        flow:         root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows:         root.isVertical ? -1 : 1
        columns:      root.isVertical ?  1 : -1
        columnSpacing: dockPadding
        rowSpacing:    dockPadding

        // Pin button
        DockPinButton {
            toggled:    root.isPinned
            isVertical: root.isVertical
            onClicked:  root.togglePinRequested()
        }

        // Separator — pinned / running apps
        Item {
            visible:    root.processedApps.length > 0
            Layout.preferredWidth:  root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            Layout.preferredHeight: root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83
            Layout.alignment: Qt.AlignCenter
            DockSeparator {
                anchors.fill: parent
                // anchors.topMargin:    root.isVertical ? 0 : 8
                // anchors.bottomMargin: root.isVertical ? 0 : 8
                // anchors.leftMargin:   root.isVertical ? 8 : 0
                // anchors.rightMargin:  root.isVertical ? 8 : 0
            }
        }

        // App buttons
        Repeater {
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: root.dragActive ? root.buildDragModel() : root.processedApps
            }
            delegate: DockAppButton {
                required property var modelData
                appToplevel:  modelData.appData
                appListRoot:  root
            }
        }

        // Second separator
        Item {
            visible:    root.processedApps.length > 0
            Layout.preferredWidth:  root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            Layout.preferredHeight: root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83

            DockSeparator {
                anchors.fill: parent
                // anchors.topMargin:    root.isVertical ? 0 : 8
                // anchors.bottomMargin: root.isVertical ? 0 : 8
                // anchors.leftMargin:   root.isVertical ? 8 : 0
                // anchors.rightMargin:  root.isVertical ? 8 : 0
            }
        }

        // Overview button
        DockButton {
            id: overviewButton
            Layout.preferredWidth:  overviewButton.buttonSize
            Layout.preferredHeight: overviewButton.buttonSize
            Layout.alignment: Qt.AlignCenter
            colBackground: "green"
            onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text:     "apps"
                iconSize: overviewButton.baseSize / 2
                color:    Appearance.colors.colOnLayer0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Preview popup ─────────────────────────────────────────────
    DockPreviewPopup {
        id: previewPopup
        dockRoot:    root
        dockWindow:  root.QsWindow.window
        appTopLevel: root.lastHoveredButton?.appToplevel
    }
}