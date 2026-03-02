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

    // Whether the dock is currently pinned (always visible).
    // Bound from the parent Dock.qml scope.
    property bool isPinned: false

    property bool suppressAnimation: false

    // Full thickness of the parent PanelWindow along its minor axis
    // (height for horizontal docks, width for vertical docks).
    // Required to correctly clamp the drag ghost within the panel bounds.
    property real panelThickness: 0

    // Emitted when the user clicks the pin/unpin button.
    signal togglePinRequested()

    // Padding around the icon grid, derived from the configured dock height.
    readonly property real dockPadding: (Config.options?.dock.height ?? 60) * 0.25

    // True when the dock is positioned on the left or right screen edge.
    readonly property bool isVertical: GlobalStates.dockIsVertical

    // Keeps the dock window visible while a popup or context menu is open.
    readonly property bool requestDockShow: previewPopup.visible || anyContextMenuOpen

    readonly property real maxWindowPreviewHeight: 200
    readonly property real maxWindowPreviewWidth:  300
    // Height reserved for the close/minimize controls inside the preview.
    readonly property real windowControlsHeight:   30

    // Flat list of { uniqueKey, appData } objects mirroring TaskbarApps.apps.
    property var  processedApps:      []
    // True while any DockAppButton context menu is open.
    property bool anyContextMenuOpen: false
    // Set to true during animated popup resize to suppress layout jitter.
    property bool popupIsResizing:    false

    // The DockAppButton currently under the cursor, or null.
    property Item lastHoveredButton
    // True while the cursor is over a button that has open windows.
    property bool buttonHovered: false

    // ── Drag state ────────────────────────────────────────────────

    // True while a drag gesture is in progress.
    property bool   dragActive:   false
    // appId of the icon being dragged.
    property string draggedAppId: ""
    // Index of the dragged item within processedApps (pinned zone only).
    property int    draggedIndex:    -1
    // Index of the current drop target within processedApps (pinned zone only).
    property int    dropTargetIndex: -1
    // True when the ghost is positioned outside the pinned zone,
    // indicating the app will be unpinned on release.
    property bool   willUnpin:    false

    // True if the dragged app was already pinned before the drag started.
    readonly property bool dragIsOriginallyPinned:
        Config.options.dock.pinnedApps.includes(draggedAppId)

    // Screen-space center point of the currently hovered button.
    // Used by DockPreviewPopup to anchor itself.
    readonly property point hoveredButtonCenter: {
        if (!lastHoveredButton) return Qt.point(0, 0)
        return lastHoveredButton.mapToItem(
            null,
            lastHoveredButton.width  / 2,
            lastHoveredButton.height / 2
        )
    }

    // ── App model ─────────────────────────────────────────────────

    // Rebuilds processedApps from TaskbarApps.apps.
    // Called on startup and whenever the app list changes.
    function updateModel() {
        processedApps = (TaskbarApps.apps ?? []).map(app => ({
            uniqueKey: app.appId,
            appData:   app
        }))
    }

    // Initiates a drag for the given appId.
    // Records the source index and positions the ghost over the source button.
    // The model is NOT rebuilt during drag — shifts are handled via transform.
    function startDrag(appId, sourceItem, index) {
        // Both pinned and unpinned apps can be dragged
        draggedAppId    = appId
        draggedIndex    = index
        dropTargetIndex = index
        willUnpin       = false
        dragActive      = true
        buttonHovered   = false
        previewPopup.show = false

        const pos = sourceItem.mapToItem(root, 0, 0)
        dragGhost.x = pos.x
        dragGhost.y = pos.y
    }

    // Updates ghost position and drop target on every mouse-move event.
    // No model mutation happens here — DockAppButton delegates read
    // draggedIndex/dropTargetIndex and apply a Translate transform themselves.
    function moveDragGhost(x, y) {
        const center = _clampGhostCenter(x, y)

        dragGhost.x = center.x - dragGhost.width  / 2
        dragGhost.y = center.y - dragGhost.height / 2

        willUnpin = _isOutsideDock(center) || _isPastSeparator(center)

        if (!willUnpin) {
            _updateDropTarget(center)
        } else {
            dropTargetIndex = draggedIndex
        }
    }

    // Finalises the drag: commits the new order to Config derived from
    // draggedIndex/dropTargetIndex, or removes the app if willUnpin is true.
    // Resets all drag state afterwards.
function endDrag() {
    if (!dragActive) return

    const wasAlreadyPinned = Config.options.dock.pinnedApps.includes(draggedAppId)

    if (willUnpin) {
        // Remove from pinned
        Config.options.dock.pinnedApps =
            Config.options.dock.pinnedApps.filter(id => id !== draggedAppId)

    } else if (!wasAlreadyPinned) {
        // Pin the app, inserted at dropTargetIndex position
        const newOrder = Config.options.dock.pinnedApps.slice()
        const insertAt = Math.min(dropTargetIndex, newOrder.length)
        newOrder.splice(insertAt, 0, draggedAppId)
        Config.options.dock.pinnedApps = newOrder

    } else if (draggedIndex !== dropTargetIndex) {
        // Reorder existing pinned app
        const fromAppId = processedApps[draggedIndex]?.appData?.appId ?? ""
        const toAppId   = processedApps[dropTargetIndex]?.appData?.appId ?? ""
        const newOrder  = Config.options.dock.pinnedApps.slice()
        const fromIdx   = newOrder.indexOf(fromAppId)
        const toIdx     = newOrder.indexOf(toAppId)
        if (fromIdx !== -1 && toIdx !== -1) {
            const moved = newOrder.splice(fromIdx, 1)[0]
            newOrder.splice(toIdx, 0, moved)
            Config.options.dock.pinnedApps = newOrder
        }
    }

    dragActive        = false
    draggedAppId      = ""
    draggedIndex      = -1
    dropTargetIndex   = -1
    willUnpin         = false
    buttonHovered     = false
    lastHoveredButton = null
}
    // Returns the ghost center point clamped within _clampBounds().
    function _clampGhostCenter(x, y) {
        const b = _clampBounds()
        return Qt.point(
            Math.max(b.x0, Math.min(x, b.x1)),
            Math.max(b.y0, Math.min(y, b.y1))
        )
    }

    // Computes the axis-aligned bounding box for the ghost center point,
    // expressed in root's local coordinate space.
    //
    // For horizontal docks (top / bottom):
    //   X — free along the dock length with a small overshoot allowance.
    //   Y — constrained so the ghost never visually exits the panel window.
    //       Since root is vertically centred inside the panel, the usable
    //       Y range extends ±offsetY beyond root's own bounds.
    //       halfH is subtracted/added so the ghost edges, not its centre,
    //       align with the panel edges.
    //
    // For vertical docks (left / right): same logic on the X axis.
    function _clampBounds() {
        const halfW     = dragGhost.width  / 2
        const halfH     = dragGhost.height / 2
        const overshoot = 20
        const pos       = GlobalStates.dockEffectivePosition

        if (pos === "bottom" || pos === "top") {
            const offsetY = (panelThickness - root.height) / 2
            return {
                x0: -overshoot,
                x1: root.width + overshoot,
                y0: -offsetY + halfH,
                y1:  offsetY + root.height - halfH
            }
        } else {
            const offsetX = (panelThickness - root.width) / 2
            return {
                x0: -offsetX + halfW,
                x1:  offsetX + root.width - halfW,
                y0: -overshoot,
                y1:  root.height + overshoot
            }
        }
    }

    // Returns true when the ghost center is more than `margin` px outside
    // the full panel bounds (including the space occupied by padding/gaps).
    // Triggers unpin when the user drags an icon well away from the dock.
    function _isOutsideDock(center) {
        const margin  = 40
        const offsetY = (panelThickness - root.height) / 2
        const offsetX = (panelThickness - root.width)  / 2

        return isVertical
            ? (center.x < -(offsetX + margin) || center.x > root.width  + offsetX + margin
            || center.y < -margin             || center.y > root.height + margin)
            : (center.x < -margin             || center.x > root.width  + margin
            || center.y < -(offsetY + margin) || center.y > root.height + offsetY + margin)
    }

    // Returns the position (in root-local coordinates) of the leading edge
    // of the SEPARATOR item, which marks the boundary between the pinned
    // and unpinned zones. Falls back to the full dock length when no
    // separator is found in the layout.
    function _pinnedZoneEnd() {
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            if (child.appToplevel?.appId !== "SEPARATOR") continue
            const p = child.mapToItem(root, 0, 0)
            return isVertical ? p.y : p.x
        }
        return Config.options.dock.pinnedApps.length > 0
            ? (isVertical ? root.height : root.width)
            : 60
    }

    // Returns true when the ghost has crossed into the unpinned zone,
    // i.e. past the separator along the dock's primary axis.
    function _isPastSeparator(center) {
        const end = _pinnedZoneEnd()
        return isVertical ? center.y > end : center.x > end
    }

    // Iterates layout children to find which pinned slot the ghost is over
    // and updates dropTargetIndex accordingly.
    // Uses a 30% inset dead zone to avoid flip-flopping at slot boundaries.
    function _updateDropTarget(center) {
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            const id    = child.appToplevel?.appId
            if (!id || id === "SEPARATOR") continue

            const pinnedApps = Config.options.dock.pinnedApps
            const idx = pinnedApps.indexOf(id)
            if (idx === -1) continue

            const p        = child.mapToItem(root, 0, 0)
            const insetX   = child.width  * 0.30
            const insetY   = child.height * 0.30

            if (center.x >= p.x + insetX && center.x <= p.x + child.width  - insetX &&
                center.y >= p.y + insetY && center.y <= p.y + child.height - insetY) {
                if (idx !== dropTargetIndex)
                    dropTargetIndex = idx
                return
            }
        }
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

    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // ── Drag ghost ────────────────────────────────────────────────

    DockDragGhost {
        id: dragGhost
        visible:      root.dragActive
        draggedAppId: root.draggedAppId
        willUnpin:    root.willUnpin
        z: 10
    }

    // ── Main layout ────────────────────────────────────────────────

    Flow {
        id: layout
        anchors.centerIn: parent

        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: dockPadding
        padding: dockPadding

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.7; to: 1
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Pin Button
        DockActionButton {
            symbolName: "keep"
            toggled:    root.isPinned
            isVertical: root.isVertical
            onClicked:  root.togglePinRequested()
        }

        // Separator 1
        Item {
            visible: root.processedApps.length > 0
            width:   root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            height:  root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83
            DockSeparator { anchors.fill: parent }
        }

        // Apps — model never changes during drag; shifts are visual-only via transform.
        Repeater {
            id: appsRepeater
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: root.processedApps
            }
            delegate: DockAppButton {
                required property var modelData
                required property int index
                appToplevel:  modelData.appData
                appListRoot:  root
                delegateIndex: index
            }
        }

        // Separator 2
        Item {
            visible: root.processedApps.length > 0
            width:   root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
            height:  root.isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83
            DockSeparator { anchors.fill: parent }
        }

        // Overview button
        DockActionButton {
            symbolName: "apps"
            isVertical: root.isVertical
            onClicked:  GlobalStates.overviewOpen = !GlobalStates.overviewOpen
        }
    }

    // ── Preview Popup  ───────────────────────────────────────────────

    DockPreviewPopup {
        id: previewPopup
        dockRoot:    root
        dockWindow:  root.QsWindow.window
        appTopLevel: root.lastHoveredButton?.appToplevel
    }
}