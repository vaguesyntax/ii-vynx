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
    property real panelThickness: 0
    signal togglePinRequested()
    readonly property real dockPadding: (Config.options?.dock.height ?? 60) * 0.25
    readonly property bool isVertical: GlobalStates.dockIsVertical
    readonly property bool requestDockShow: previewPopup.visible || anyContextMenuOpen
    readonly property real maxWindowPreviewHeight: 200
    readonly property real maxWindowPreviewWidth: 300
    readonly property real windowControlsHeight: 30
    property var processedApps: []
    property bool anyContextMenuOpen: false
    property bool popupIsResizing: false
    property Item lastHoveredButton
    property bool buttonHovered: false

    // ── Drag state ────────────────────────────────────────────────
    property bool dragActive: false
    property string draggedAppId: ""
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool willUnpin: false
    property bool suppressAnimation: false
    property real dragDelta: 0                          // usato per riordino relativo pinnate
    readonly property bool dragIsOriginallyPinned: Config.options.dock.pinnedApps.includes(draggedAppId)
    readonly property point hoveredButtonCenter: {
        if (!lastHoveredButton) return Qt.point(0, 0)
        return lastHoveredButton.mapToItem(null, lastHoveredButton.width / 2, lastHoveredButton.height / 2)
    }

    // ── App model ─────────────────────────────────────────────────
    function updateModel() {
        processedApps = (TaskbarApps.apps ?? []).map(app => ({
            uniqueKey: app.appId,
            appData: app
        }))
    }

    // ── Drag logic ────────────────────────────────────────────────
    function startDrag(appId, delegateIdx) {
        draggedAppId = appId
        draggedIndex = delegateIdx
        dropTargetIndex = delegateIdx
        willUnpin = false
        dragActive = true
        buttonHovered = false
        previewPopup.show = false
        dragDelta = 0
    }

    function moveDrag(x, y) {
        const center = _clampPosition(x, y)
        willUnpin = _isOutsideDock(center) || _isPastSeparator(center)
        if (!willUnpin) {
            _updateDropTarget(center)
        } else {
            dropTargetIndex = draggedIndex
        }
    }

    function endDrag() {
        if (!dragActive) return

        root.suppressAnimation = true
        const wasAlreadyPinned = Config.options.dock.pinnedApps.includes(draggedAppId)
        const appIdToCommit = draggedAppId
        const didUnpin = willUnpin
        const fromIdx = draggedIndex
        const toIdx = dropTargetIndex

        dragActive = false
        draggedAppId = ""
        draggedIndex = -1
        dropTargetIndex = -1
        willUnpin = false
        buttonHovered = false
        lastHoveredButton = null
        dragDelta = 0

        if (didUnpin) {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appIdToCommit)
        } else if (!wasAlreadyPinned) {
            const newOrder = Config.options.dock.pinnedApps.slice()
            newOrder.splice(Math.min(toIdx, newOrder.length), 0, appIdToCommit)
            Config.options.dock.pinnedApps = newOrder
        } else if (fromIdx !== toIdx) {
            const fromAppId = processedApps[fromIdx]?.appData?.appId ?? ""
            const toAppId = processedApps[toIdx]?.appData?.appId ?? ""
            const newOrder = Config.options.dock.pinnedApps.slice()
            const f = newOrder.indexOf(fromAppId)
            const t = newOrder.indexOf(toAppId)
            if (f !== -1 && t !== -1) {
                const moved = newOrder.splice(f, 1)[0]
                newOrder.splice(t, 0, moved)
                Config.options.dock.pinnedApps = newOrder
            }
        }

        Qt.callLater(() => { root.suppressAnimation = false })
    }

    function _clampPosition(x, y) {
        const b = _clampBounds()
        return Qt.point(
            Math.max(b.x0, Math.min(x, b.x1)),
            Math.max(b.y0, Math.min(y, b.y1))
        )
    }

    function _clampBounds() {
        const overshoot = 20
        const pos = GlobalStates.dockEffectivePosition
        if (pos === "bottom" || pos === "top") {
            const offsetY = (panelThickness - root.height) / 2
            return { x0: -overshoot, x1: root.width + overshoot, y0: -offsetY, y1: offsetY + root.height }
        } else {
            const offsetX = (panelThickness - root.width) / 2
            return { x0: -offsetX, x1: offsetX + root.width, y0: -overshoot, y1: root.height + overshoot }
        }
    }

    function _isOutsideDock(center) {
        const margin = 40
        const offsetY = (panelThickness - root.height) / 2
        const offsetX = (panelThickness - root.width) / 2
        return isVertical
            ? (center.x < -(offsetX + margin) || center.x > root.width + offsetX + margin ||
               center.y < -margin || center.y > root.height + margin)
            : (center.x < -margin || center.x > root.width + margin ||
               center.y < -(offsetY + margin) || center.y > root.height + offsetY + margin)
    }

    function _pinnedZoneEnd() {
        for (let i = 0; i < appsRepeater.count; i++) {
            const child = appsRepeater.itemAt(i)
            if (!child) continue
            if (child.appToplevel?.appId !== "SEPARATOR") continue
            const p = child.mapToItem(root, 0, 0)
            return isVertical ? p.y : p.x
        }
        return Config.options.dock.pinnedApps.length > 0
            ? (isVertical ? root.height : root.width)
            : 60
    }

    function _isPastSeparator(center) {
        const end = _pinnedZoneEnd()
        return isVertical ? center.y > end : center.x > end
    }

    function _updateDropTarget(center) {
        if (dragIsOriginallyPinned) {
            const slotSize = (Config.options?.dock.height ?? 60) + dockPadding
            const slotOffset = Math.round(dragDelta / slotSize)
            let newTarget = draggedIndex + slotOffset
            newTarget = Math.max(0, Math.min(appsRepeater.count - 1, newTarget))
            if (newTarget !== dropTargetIndex)
                dropTargetIndex = newTarget
            return
        }

        const axisPos = isVertical ? center.y : center.x
        let target = 0
        for (let i = 0; i < appsRepeater.count; i++) {
            const child = appsRepeater.itemAt(i)
            if (!child) continue
            const id = child.appToplevel?.appId
            if (!id || id === draggedAppId || id === "SEPARATOR") continue
            if (!Config.options.dock.pinnedApps.includes(id)) continue

            const p = child.mapToItem(root, 0, 0)
            const childCenter = isVertical ? p.y + child.height / 2 : p.x + child.width / 2

            if (axisPos < childCenter) {
                target = i
                break
            }
            target = i + 1
        }
        if (target !== dropTargetIndex)
            dropTargetIndex = target
    }

    // ── Connections ───────────────────────────────────────────────
    Connections {
        target: TaskbarApps
        function onAppsChanged() {
            root.suppressAnimation = true
            root.draggedIndex = -1
            root.dropTargetIndex = -1
            root.updateModel()
            Qt.callLater(() => { root.suppressAnimation = false })
        }
    }

    Connections {
        target: GlobalStates
        function onDockEffectivePositionChanged() {
            if (root.lastHoveredButton) previewPopup.anchor.updateAnchor()
        }
    }

    Component.onCompleted: updateModel()

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // ── Main layout ────────────────────────────────────────────────
    Flow {
        id: layout
        anchors.centerIn: parent
        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: dockPadding
        padding: dockPadding

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.7; to: 1; duration: 150; easing.type: Easing.OutCubic }
        }

        DockActionButton {
            symbolName: "keep"
            toggled: root.isPinned
            isVertical: root.isVertical
            onClicked: root.togglePinRequested()
        }

        Item {
            visible: root.processedApps.length > 0
            width: root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            height: root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83
            DockSeparator { anchors.fill: parent }
        }

        Repeater {
            id: appsRepeater
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: root.processedApps
            }
            delegate: DockAppButton {
                required property var modelData
                required property int index
                appToplevel: modelData.appData
                appListRoot: root
                delegateIndex: index
            }
        }

        Item {
            visible: root.processedApps.length > 0
            width: root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            height: root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83
            DockSeparator { anchors.fill: parent }
        }

        DockActionButton {
            symbolName: "apps"
            isVertical: root.isVertical
            onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        }
    }

    DockPreviewPopup {
        id: previewPopup
        dockRoot: root
        dockWindow: root.QsWindow.window
        appTopLevel: root.lastHoveredButton?.appToplevel
    }
}