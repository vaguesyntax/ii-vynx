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
    property Item lastHoveredButton: null
    property bool buttonHovered: false

    property var unpinnedOrder: []
    property bool _ignoringAppsChanged: false

    property bool dragActive: false
    property string draggedAppId: ""
    property int draggedIndex: -1
    property int dropTargetIndex: -1
    property bool willUnpin: false
    property bool suppressAnimation: false
    readonly property bool dragIsOriginallyPinned: Config.options.dock.pinnedApps.includes(draggedAppId)

    readonly property int separatorIndex: {
        for (let i = 0; i < appsRepeater.count; i++) {
            const child = appsRepeater.itemAt(i)
            if (!child) continue
            if (child.appToplevel?.appId === "SEPARATOR") return i
        }
        return -1
    }

    readonly property point hoveredButtonCenter: {
        if (!lastHoveredButton) return Qt.point(0, 0)
        return lastHoveredButton.mapToItem(null, lastHoveredButton.width / 2, lastHoveredButton.height / 2)
    }

    // ── Model ─────────────────────────────────────────────────────

    function updateModel() {
        const raw = TaskbarApps.apps ?? []
        const pinnedItems = []
        const unpinnedItems = []
        let separatorItem = null

        for (const app of raw) {
            if (app.appId === "SEPARATOR") {
                separatorItem = app
            } else if (Config.options.dock.pinnedApps.includes(app.appId)) {
                pinnedItems.push(app)
            } else {
                unpinnedItems.push(app)
            }
        }

        const unpinnedMap = new Map()
        for (const app of unpinnedItems)
            unpinnedMap.set(app.appId, app)

        const sortedUnpinned = []
        for (const id of unpinnedOrder) {
            if (unpinnedMap.has(id)) {
                sortedUnpinned.push(unpinnedMap.get(id))
                unpinnedMap.delete(id)
            }
        }
        for (const app of unpinnedMap.values())
            sortedUnpinned.push(app)

        unpinnedOrder = sortedUnpinned.map(a => a.appId)

        const result = []
        for (const app of pinnedItems)
            result.push({ uniqueKey: app.appId, appData: app })
        if (separatorItem)
            result.push({ uniqueKey: "SEPARATOR", appData: separatorItem })
        for (const app of sortedUnpinned)
            result.push({ uniqueKey: app.appId, appData: app })

        processedApps = result
    }

    function _applyUnpinnedOrderToModel() {
        const raw = TaskbarApps.apps ?? []
        const pinnedItems = []
        const unpinnedItems = []
        let separatorItem = null

        for (const app of raw) {
            if (app.appId === "SEPARATOR") {
                separatorItem = app
            } else if (Config.options.dock.pinnedApps.includes(app.appId)) {
                pinnedItems.push(app)
            } else {
                unpinnedItems.push(app)
            }
        }

        const unpinnedMap = new Map()
        for (const app of unpinnedItems)
            unpinnedMap.set(app.appId, app)

        const sortedUnpinned = []
        for (const id of unpinnedOrder) {
            if (unpinnedMap.has(id)) {
                sortedUnpinned.push(unpinnedMap.get(id))
                unpinnedMap.delete(id)
            }
        }
        for (const app of unpinnedMap.values())
            sortedUnpinned.push(app)

        unpinnedOrder = sortedUnpinned.map(a => a.appId)

        const result = []
        for (const app of pinnedItems)
            result.push({ uniqueKey: app.appId, appData: app })
        if (separatorItem)
            result.push({ uniqueKey: "SEPARATOR", appData: separatorItem })
        for (const app of sortedUnpinned)
            result.push({ uniqueKey: app.appId, appData: app })

        processedApps = result
    }

    // ── Drag ──────────────────────────────────────────────────────

    function startDrag(appId, delegateIdx) {
        draggedAppId = appId
        draggedIndex = delegateIdx
        dropTargetIndex = delegateIdx
        willUnpin = false
        dragActive = true
        buttonHovered = false
        previewPopup.show = false
    }

    function moveDrag(x, y) {
        const center = Qt.point(x, y)
        willUnpin = _isOutsideDock(center)
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
        const sepIdx = separatorIndex

        dragActive = false
        draggedAppId = ""
        draggedIndex = -1
        dropTargetIndex = -1
        willUnpin = false
        buttonHovered = false
        lastHoveredButton = null

        const droppedInPinnedZone = sepIdx < 0 || toIdx <= sepIdx

        if (didUnpin) {
            _ignoringAppsChanged = true
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appIdToCommit)
            _applyUnpinnedOrderToModel()

        } else if (wasAlreadyPinned && !droppedInPinnedZone) {
            // Pinnata → zona unpinned
            _ignoringAppsChanged = true
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appIdToCommit)

            let insertAt = 0
            for (let i = 0; i < appsRepeater.count; i++) {
                const child = appsRepeater.itemAt(i)
                if (!child) continue
                const id = child.appToplevel?.appId
                if (!id || id === "SEPARATOR") continue
                if (i >= toIdx) break
                if (!Config.options.dock.pinnedApps.includes(id))
                    insertAt++
            }
            const newUnpinnedOrder = unpinnedOrder.filter(id => id !== appIdToCommit)
            newUnpinnedOrder.splice(insertAt, 0, appIdToCommit)
            unpinnedOrder = newUnpinnedOrder
            _applyUnpinnedOrderToModel()

        } else if (!wasAlreadyPinned && droppedInPinnedZone) {
            // Unpinned → zona pinnata
            _ignoringAppsChanged = true
            let insertAt = 0
            for (let i = 0; i < toIdx; i++) {
                const child = appsRepeater.itemAt(i)
                if (!child) continue
                const id = child.appToplevel?.appId
                if (id && id !== "SEPARATOR" && Config.options.dock.pinnedApps.includes(id))
                    insertAt++
            }
            const newOrder = Config.options.dock.pinnedApps.slice()
            newOrder.splice(insertAt, 0, appIdToCommit)
            Config.options.dock.pinnedApps = newOrder
            unpinnedOrder = unpinnedOrder.filter(id => id !== appIdToCommit)
            _applyUnpinnedOrderToModel()

        } else if (wasAlreadyPinned && droppedInPinnedZone && fromIdx !== toIdx) {
            // Riordino tra pinnate
            _ignoringAppsChanged = true
            const fromAppId = processedApps[fromIdx]?.appData?.appId ?? ""
            const toAppId   = processedApps[toIdx]?.appData?.appId ?? ""
            const newOrder  = Config.options.dock.pinnedApps.slice()
            const f = newOrder.indexOf(fromAppId)
            const t = newOrder.indexOf(toAppId)
            if (f !== -1 && t !== -1) {
                const moved = newOrder.splice(f, 1)[0]
                newOrder.splice(t, 0, moved)
                Config.options.dock.pinnedApps = newOrder
            }
            _applyUnpinnedOrderToModel()

        } else if (!wasAlreadyPinned && !droppedInPinnedZone && fromIdx !== toIdx) {
            // Riordino tra unpinnate
            const fromAppId = processedApps[fromIdx]?.appData?.appId ?? ""
            const toAppId   = processedApps[toIdx]?.appData?.appId ?? ""
            const newUnpinnedOrder = unpinnedOrder.slice()
            const f = newUnpinnedOrder.indexOf(fromAppId)
            let t = newUnpinnedOrder.indexOf(toAppId)
            if (f !== -1) {
                newUnpinnedOrder.splice(f, 1)
                t = newUnpinnedOrder.indexOf(toAppId)
                if (toIdx > fromIdx) {
                    const insertPos = t >= 0 ? t + 1 : newUnpinnedOrder.length
                    newUnpinnedOrder.splice(insertPos, 0, fromAppId)
                } else {
                    const insertPos = t >= 0 ? t : 0
                    newUnpinnedOrder.splice(insertPos, 0, fromAppId)
                }
                unpinnedOrder = newUnpinnedOrder
            }
            _applyUnpinnedOrderToModel()
        }

        Qt.callLater(() => {
            root.suppressAnimation = false
            root._ignoringAppsChanged = false
        })
    }

    function _isOutsideDock(center) {
        const margin = 80
        if (isVertical) {
            return center.x < -margin || center.x > root.width + margin
        } else {
            return center.y < -margin || center.y > root.height + margin
        }
    }

    function _updateDropTarget(center) {
        const axisPos = isVertical ? center.y : center.x

        const items = []
        for (let i = 0; i < appsRepeater.count; i++) {
            const child = appsRepeater.itemAt(i)
            if (!child) continue
            const id = child.appToplevel?.appId
            if (!id || id === "SEPARATOR") continue

            const cc = isVertical
                ? (child.y + child.height / 2)
                : (child.x + child.width  / 2)

            items.push({ index: i, center: cc })
        }

        if (items.length === 0) return

        items.sort((a, b) => a.center - b.center)

        let newDrop = items[items.length - 1].index + 1
        for (let i = 0; i < items.length; i++) {
            if (axisPos < items[i].center) {
                newDrop = items[i].index
                break
            }
        }

        const minDrop = items[0].index
        const maxDrop = items[items.length - 1].index + 1
        newDrop = Math.max(minDrop, Math.min(newDrop, maxDrop))

        if (newDrop !== dropTargetIndex)
            dropTargetIndex = newDrop
    }

    // ── Connections ───────────────────────────────────────────────

    Connections {
        target: TaskbarApps
        function onAppsChanged() {
            if (root._ignoringAppsChanged) return
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

    // ── Layout ────────────────────────────────────────────────────

    Flow {
        id: layout
        anchors.centerIn: parent
        flow: root.isVertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: dockPadding
        padding: dockPadding

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale";   from: 0.7; to: 1; duration: 150; easing.type: Easing.OutCubic }
        }

        DockActionButton {
            symbolName: "keep"
            toggled: root.isPinned
            isVertical: root.isVertical
            onClicked: root.togglePinRequested()
        }

        Item {
            visible: root.processedApps.length > 0
            width:  root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
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
                appToplevel:   modelData.appData
                appListRoot:   root
                delegateIndex: index
            }
        }

        Item {
            visible: root.processedApps.length > 0
            width:  root.isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1
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
        dockRoot:    root
        dockWindow:  root.QsWindow.window
        appTopLevel: root.lastHoveredButton?.appToplevel
    }
}