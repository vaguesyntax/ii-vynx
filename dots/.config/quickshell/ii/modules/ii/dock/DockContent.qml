import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell.Services.Mpris

Item {
    id: root

    // ── Signals ───────────────────────────────────────────────────────────
    signal togglePinRequested()

    // ── Screen ────────────────────────────────────────────────────────────
    property var currentScreen: null

    // ── Dock state ────────────────────────────────────────────────────────
    property bool isPinned: false

    readonly property real dockPadding: 0
    readonly property bool isVertical: dock.isVertical

    readonly property real dotMargin: (Config.options?.dock.height ?? 60) * 0.2

    // Separator thickness scales with buttonSize (~6% of button size, min 3px)
    readonly property real sepThickness: Math.max(3, Math.round(Appearance.sizes.dockButtonSize * 0.06))

    readonly property real visualWidth: isVertical
        ? Appearance.sizes.dockButtonSize + dotMargin * 2
        : mainLayout.implicitWidth
    readonly property real visualHeight: isVertical
        ? mainLayout.implicitHeight
        : Appearance.sizes.dockButtonSize + dotMargin * 2

    readonly property bool requestDockShow: previewPopupLoader.item?.visible || anyContextMenuOpen

    readonly property real maxWindowPreviewHeight: 200
    readonly property real maxWindowPreviewWidth: 300
    readonly property real windowControlsHeight: 30

    readonly property real pinButtonCenter: isVertical
        ? pinButtonWrapper.y + pinButtonWrapper.height / 2
        : pinButtonWrapper.x + pinButtonWrapper.width / 2

    readonly property real unpinButtonCenter: isVertical
        ? unpinButtonWrapper.y + unpinButtonWrapper.height / 2
        : unpinButtonWrapper.x + unpinButtonWrapper.width / 2

    // ── Hover / popup state ───────────────────────────────────────────────
    property bool anyContextMenuOpen: false
    property bool popupIsResizing: false
    property Item lastHoveredButton: null
    property bool buttonHovered: false
    property bool suppressHover: false

    Timer {
        id: suppressHoverTimer
        interval: 250
        onTriggered: root.suppressHover = false
    }

    property point hoveredButtonCenter: Qt.point(0, 0)

    onLastHoveredButtonChanged: {
        if (root.lastHoveredButton)
            hoveredButtonCenter = root.lastHoveredButton.mapToItem(
                null,
                root.lastHoveredButton.width / 2,
                root.lastHoveredButton.height / 2
            )
    }

    // ── External drag (files from file manager) ───────────────────────────
    property string externalDragIcon: ""
    property bool externalDragOver: false

    // ── Music player ──────────────────────────────────────────────────────
    readonly property var activePlayer: MprisController.activePlayer
    readonly property string rawTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || ""
    readonly property bool hasRealData: activePlayer !== null && rawTitle !== ""

    property bool showMusicPlayer: hasRealData

    onHasRealDataChanged: {
        if (hasRealData) {
            switchHoldTimer.stop()
            showMusicPlayer = true
        } else {
            switchHoldTimer.restart()
        }
    }

    // Keep the player visible for 2s after playback stops to avoid flickering
    Timer {
        id: switchHoldTimer
        interval: 2000
        repeat: false
        onTriggered: { if (!root.hasRealData) root.showMusicPlayer = false }
    }

    // ── App model ─────────────────────────────────────────────────────────
    property var processedPinnedApps: []
    property var processedRunningApps: []
    property bool _ignoringAppsChanged: false
    property bool suppressAnimation: false

    property bool dragActive: false
    property string draggedAppId: ""
    property string dragIntent: "none"
    property int draggedIndex: -1
    property int dropTargetIndex: -1

    property alias dragGhostItem: dragGhost

    function updateModel() {
        const allApps = TaskbarApps.apps ?? []
        const isolate = Config.options?.dock?.isolateMonitors ?? false

        let finalPinned = []
        let finalRunning = []

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i]

            // Filter toplevels by current screen when monitor isolation is enabled
            let validToplevels = app.toplevels
            if (isolate && root.currentScreen) {
                validToplevels = app.toplevels.filter(tl => {
                    return tl && tl.screens && tl.screens.includes(root.currentScreen)
                })
            }

            // Skip unpinned apps with no windows on this screen
            if (!app.pinned && validToplevels.length === 0) {
                continue
            }

            // Build a copy of the app data with filtered toplevels
            let appDataObj = {
                appId: app.appId,
                pinned: app.pinned,
                toplevels: validToplevels
            }

            if (app.pinned) {
                finalPinned.push({ uniqueKey: app.appId, appData: appDataObj })
            } else {
                finalRunning.push({ uniqueKey: app.appId, appData: appDataObj })
            }
        }

        root.processedPinnedApps = finalPinned
        root.processedRunningApps = finalRunning
    }

    function startDrag(appId, delegateIdx) {
        root.suppressAnimation = true
        Qt.callLater(() => { root.suppressAnimation = false })

        draggedIndex = delegateIdx
        dropTargetIndex = delegateIdx
        draggedAppId = appId
        dragIntent = TaskbarApps.isPinned(appId) ? "reorder" : "none"
        dragActive = true
        buttonHovered = false
        if (previewPopupLoader.item) previewPopupLoader.item.show = false
    }

    function moveDrag() {
        const ghostCenter = isVertical
            ? dragGhost.y + dragGhost.height / 2
            : dragGhost.x + dragGhost.width / 2

        const isDraggedPinned = TaskbarApps.isPinned(root.draggedAppId)
        if (ghostCenter <= root.pinButtonCenter) {
            dragIntent = isDraggedPinned ? "reorder" : "pin"
            return
        }
        if (ghostCenter >= root.unpinButtonCenter) {
            dragIntent = "unpin"
            return
        }
        dragIntent = isDraggedPinned ? "reorder" : "none"
    }

    function endDrag() {
        if (!dragActive) return

        root.suppressAnimation = true
        root._ignoringAppsChanged = true

        const appId = draggedAppId
        const intent = dragIntent
        const fromIdx = draggedIndex
        const toIdx = dropTargetIndex

        dragActive = false
        draggedAppId = ""
        dragIntent = "none"
        draggedIndex = -1
        dropTargetIndex = -1
        buttonHovered = false
        lastHoveredButton = null
        suppressHover = true
        suppressHoverTimer.restart()

        if (intent === "pin" && !TaskbarApps.isPinned(appId)) {
            const app = (TaskbarApps.apps ?? []).find(a => a.appId === appId)
            if (app) {
                // Optimistically add to pinned list before the model update arrives
                root.processedPinnedApps = root.processedPinnedApps.concat([{ uniqueKey: appId, appData: app }])
                root.processedRunningApps = root.processedRunningApps.filter(a => a.appData.appId !== appId)
            }
            TaskbarApps.togglePin(appId)
        } else if (intent === "unpin" && TaskbarApps.isPinned(appId)) {
            root.processedPinnedApps = root.processedPinnedApps.filter(a => a.appData.appId !== appId)
            TaskbarApps.togglePin(appId)
        } else if (intent === "reorder" && fromIdx !== toIdx) {
            const pinned = Config.options.dock.pinnedApps.slice()
            const f = pinned.indexOf(appId)
            if (f !== -1) {
                pinned.splice(f, 1)
                pinned.splice(toIdx, 0, appId)
                Config.options.dock.pinnedApps = pinned
                updateModel() // this is needed to avoid the hidden app reppearing for an instant
            }
        }

        Qt.callLater(() => {
            root.updateModel()
            root.suppressAnimation = false
            root._ignoringAppsChanged = false
        })
    }

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
        target: Config.options?.dock ?? null
        function onIsolateMonitorsChanged() {
            if (root._ignoringAppsChanged) return
            root.suppressAnimation = true
            root.updateModel()
            Qt.callLater(() => { root.suppressAnimation = false })
        }
    }

    // ── File model ────────────────────────────────────────────────────────
    property var processedFiles: []
    property bool _ignoringFilesChanged: false
    property bool fileSuppressAnim: false

    property bool fileDragActive: false
    property int fileDraggedIndex: -1
    property int fileDropIndex: -1
    property string fileDragIntent: "reorder"

    property alias fileDragGhostItem: dragGhost

    function updateFileModel() {
        root.processedFiles = (Config.options?.dock?.pinnedFiles ?? []).map(p => ({
            uniqueKey: p,
            path: p
        }))
    }

    function mimeIconFromPath(path) {
        const p = (path ?? "").toString().toLowerCase()
        if (/\.(png|jpe?g|webp|gif|svg|bmp|ico)$/.test(p)) return "image"
        if (/\.(mp3|flac|ogg|wav|aac|m4a)$/.test(p))       return "music_note"
        if (/\.(mp4|mkv|webm|avi|mov)$/.test(p))            return "movie"
        if (p.endsWith(".pdf"))                              return "picture_as_pdf"
        if (/\.(txt|md|rst|log)$/.test(p))                  return "description"
        if (/\.(zip|tar|gz|zst|rar|7z)$/.test(p))           return "folder_zip"
        const last = path.toString().split("/").filter(s => s).pop() ?? ""
        return last.includes(".") ? "insert_drive_file" : "folder"
    }

    function startFileDrag(index) {
        root.fileSuppressAnim = true
        fileDraggedIndex = index
        fileDropIndex = index
        fileDragIntent = "none"
        fileDragActive = true
        buttonHovered = false
        if (previewPopupLoader.item) previewPopupLoader.item.show = false
        Qt.callLater(() => { root.fileSuppressAnim = false })
    }

    function moveFileDrag() {
        const ghostCenter = isVertical
            ? dragGhost.y + dragGhost.height / 2
            : dragGhost.x + dragGhost.width / 2

        if (ghostCenter >= root.unpinButtonCenter) {
            fileDragIntent = "unpin"
            return
        }
        fileDragIntent = "reorder"
    }

    function endFileDrag() {
        if (!fileDragActive) return

        root.fileSuppressAnim = true
        root._ignoringFilesChanged = true

        const intent = fileDragIntent
        const fromIdx = fileDraggedIndex
        const toIdx = fileDropIndex

        fileDragActive = false
        fileDraggedIndex = -1
        fileDropIndex = -1
        fileDragIntent = "reorder"
        buttonHovered = false

        if (intent === "unpin") {
            const removePath = root.processedFiles[fromIdx]?.path ?? ""
            root.processedFiles = root.processedFiles.filter((_, i) => i !== fromIdx)
            TaskbarApps.removePinnedFile(removePath)
        } else if (intent === "reorder" && fromIdx !== toIdx) {
            const fromPath = root.processedFiles[fromIdx]?.path
            const toPath = root.processedFiles[toIdx]?.path
            if (fromPath && toPath) {
                TaskbarApps.reorderPinnedFile(fromPath, toPath)
                updateFileModel() // this is needed to avoid the hidden file/folder reppearing for an instant
            }
        }

        Qt.callLater(() => {
            root.updateFileModel()
            root.fileSuppressAnim = false
            root._ignoringFilesChanged = false
        })
    }

    Connections {
        target: Config.options?.dock ?? null
        function onPinnedFilesChanged() {
            if (root._ignoringFilesChanged) return
            root.fileSuppressAnim = true
            root.updateFileModel()
            Qt.callLater(() => { root.fileSuppressAnim = false })
        }
    }

    Component.onCompleted: {
        updateModel()
        updateFileModel()
    }

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    // ── Main layout ───────────────────────────────────────────────────────
    GridLayout {
        id: mainLayout
        anchors.fill: parent
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0

        // ── 1. Fixed leading section ──────────────────────────────────────
        Item {
            id: pinButtonWrapper
            Layout.preferredWidth: Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.preferredHeight: Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.alignment: Qt.AlignCenter

            DockActionButton {
                id: pinButton
                anchors.centerIn: parent
                symbolName: "keep"
                normalShape: MaterialShape.Shape.Pill
                activeShape: MaterialShape.Shape.Cookie9Sided
                toggled: root.isPinned
                isVertical: root.isVertical
                onClicked: root.togglePinRequested()
                dragActive: root.dragActive && !TaskbarApps.isPinned(root.draggedAppId)
                dragOver: root.dragActive && root.dragIntent === "pin" && !TaskbarApps.isPinned(root.draggedAppId)
                dragSymbol: "keep"
                fileDropIcon: root.externalDragIcon
                fileDropActive: root.externalDragOver
            }
        }

        // ── Pin separator ──
        Item {
            visible: root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0 || root.processedFiles.length > 0
            Layout.preferredWidth: root.isVertical ? Appearance.sizes.dockButtonSize + root.dotMargin * 1.9 : root.sepThickness
            Layout.preferredHeight: root.isVertical ? root.sepThickness : Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.alignment: Qt.AlignCenter

            DockSeparator { 
                anchors.fill: parent 
                isVertical: root.isVertical
                marginScale: 0.15 
            }
        }

        // ── 2. Scrollable middle section ──────────────────────────────────
        Flickable {
            id: scrollArea

            Layout.fillWidth: !root.isVertical
            Layout.fillHeight: root.isVertical

            // Math.max(1, ...) prevents zero-size crashes on Wayland
            Layout.preferredWidth: Math.max(1, root.isVertical
                ? (Appearance.sizes.dockButtonSize + root.dotMargin * 2)
                : middleContent.implicitWidth)
            Layout.preferredHeight: Math.max(1, root.isVertical
                ? middleContent.implicitHeight
                : (Appearance.sizes.dockButtonSize + root.dotMargin * 2))

            clip: true
            contentWidth: middleContent.width
            contentHeight: middleContent.height

            interactive: root.isVertical ? contentHeight > height : contentWidth > width
            flickableDirection: root.isVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    let delta = (event.angleDelta.y !== 0) ? event.angleDelta.y : event.angleDelta.x
                    if (root.isVertical) {
                        scrollArea.contentY = Math.max(0, Math.min(scrollArea.contentHeight - scrollArea.height, scrollArea.contentY - delta))
                    } else {
                        scrollArea.contentX = Math.max(0, Math.min(scrollArea.contentWidth - scrollArea.width, scrollArea.contentX - delta))
                    }
                    event.accepted = true
                }
            }

            GridLayout {
                id: middleContent
                width: implicitWidth
                height: implicitHeight
                flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rows: root.isVertical ? -1 : 1
                columns: root.isVertical ? 1 : -1
                rowSpacing: 0
                columnSpacing: 0

                // A. Pinned apps
                StyledListView {
                    id: pinnedListView
                    orientation: root.isVertical ? ListView.Vertical : ListView.Horizontal
                    layoutDirection: root.isVertical ? Qt.LeftToRight : Qt.RightToLeft
                    verticalLayoutDirection: root.isVertical ? ListView.BottomToTop : ListView.TopToBottom
                    spacing: 0

                    implicitWidth: root.isVertical
                        ? Appearance.sizes.dockButtonSize + root.dotMargin * 2
                        : Math.max(1, contentWidth)
                    implicitHeight: root.isVertical
                        ? Math.max(1, contentHeight)
                        : Appearance.sizes.dockButtonSize + root.dotMargin * 2

                    cacheBuffer: 99999
                    interactive: false
                    clip: true
                    animateAppearance: false
                    animateMovement: false
                    popin: false
                    removeOvershoot: 0
                    ScrollBar.vertical: null

                    Behavior on implicitWidth {
                        enabled: !root.dragActive
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(pinnedListView)
                    }
                    Behavior on implicitHeight {
                        enabled: !root.dragActive
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(pinnedListView)
                    }

                    add: null
                    addDisplaced: null
                    populate: null
                    remove: null
                    removeDisplaced: Transition {
                        enabled: !root.suppressAnimation && !root.dragActive
                        NumberAnimation {
                            properties: root.isVertical ? "y" : "x"
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    displaced: null
                    move: null
                    moveDisplaced: null

                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-reorder"]
                        enabled: !root.externalDragOver
                        onPositionChanged: (drag) => {
                            if (!root.dragActive) return
                            if (!TaskbarApps.isPinned(root.draggedAppId)) return

                            const step = Appearance.sizes.dockButtonSize + root.dotMargin * 2

                            // The list grows from the far edge, so measure distance from the opposite side
                            let pos
                            if (isVertical) {
                                pos = pinnedListView.height - drag.y
                            } else {
                                pos = pinnedListView.width - drag.x
                            }

                            root.dropTargetIndex = Math.max(0, Math.min(
                                root.processedPinnedApps.length - 1,
                                Math.floor(pos / step)
                            ))
                        }
                    }

                    model: ScriptModel {
                        objectProp: "uniqueKey"
                        values: root.processedPinnedApps
                    }

                    delegate: DockAppButton {
                        required property var modelData
                        required property int index
                        appToplevel: modelData.appData
                        dockContent: root
                        delegateIndex: index
                    }
                }

                // B. Pinned / running separator
                Item {
                    id: appSepWrapper
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical ? Appearance.sizes.dockButtonSize + root.dotMargin * 1.9 : root.sepThickness
                    Layout.preferredHeight: root.isVertical ? root.sepThickness : Appearance.sizes.dockButtonSize + root.dotMargin * 1.9
                    opacity: hasBothSections ? 1.0 : 0.0
                    visible: opacity > 0
                    readonly property bool hasBothSections: root.processedPinnedApps.length > 0 && root.processedRunningApps.length > 0

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(appSepWrapper)
                    }
                    Behavior on Layout.preferredWidth {
                        enabled: !root.isVertical
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(appSepWrapper)
                    }
                    Behavior on Layout.preferredHeight {
                        enabled: root.isVertical
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(appSepWrapper)
                    }

                    DockSeparator {
                        anchors.fill: parent
                        isVertical: root.isVertical
                        marginScale: 0.3
                    }
                }

                // C. Running apps
                StyledListView {
                    id: runningListView
                    orientation: root.isVertical ? ListView.Vertical : ListView.Horizontal
                    spacing: 0

                    implicitWidth: root.isVertical
                        ? Appearance.sizes.dockButtonSize + root.dotMargin * 2
                        : Math.max(1, contentWidth)
                    implicitHeight: root.isVertical
                        ? Math.max(1, contentHeight)
                        : Appearance.sizes.dockButtonSize + root.dotMargin * 2

                    cacheBuffer: 99999
                    interactive: false
                    clip: true
                    animateAppearance: false
                    animateMovement: false
                    popin: false
                    removeOvershoot: 0
                    ScrollBar.vertical: null

                    Behavior on implicitWidth {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(runningListView)
                    }
                    Behavior on implicitHeight {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(runningListView)
                    }

                    add: null
                    addDisplaced: null
                    populate: null
                    remove: null
                    removeDisplaced: Transition {
                        enabled: !root.suppressAnimation && !root.dragActive
                        NumberAnimation {
                            properties: root.isVertical ? "y" : "x"
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    displaced: null
                    move: null
                    moveDisplaced: null

                    model: ScriptModel {
                        objectProp: "uniqueKey"
                        values: root.processedRunningApps
                    }

                    delegate: DockAppButton {
                        required property var modelData
                        required property int index
                        appToplevel: modelData.appData
                        dockContent: root
                        delegateIndex: index
                    }
                }

                // D. File separator
                Item {
                    id: fileSepWrapper
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical
                        ? Appearance.sizes.dockButtonSize + root.dotMargin * 1.9
                        : (root.processedFiles.length > 0 ? root.sepThickness : 0)
                    Layout.preferredHeight: root.isVertical
                        ? (root.processedFiles.length > 0 ? root.sepThickness : 0)
                        : Appearance.sizes.dockButtonSize + root.dotMargin * 1.9
                    opacity: root.processedFiles.length > 0 ? 1.0 : 0.0
                    visible: opacity > 0 && (root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0)

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(fileSepWrapper)
                    }
                    Behavior on Layout.preferredWidth {
                        enabled: !root.isVertical
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(fileSepWrapper)
                    }
                    Behavior on Layout.preferredHeight {
                        enabled: root.isVertical
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(fileSepWrapper)
                    }

                    DockSeparator {
                        anchors.fill: parent
                        isVertical: root.isVertical
                        marginScale: 0.15
                    }
                }

                // E. File list (wrapped in a Loader for safe Wayland initialization)
                Item {
                    id: fileListWrapper
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical
                        ? Appearance.sizes.dockButtonSize + root.dotMargin * 2
                        : (root.processedFiles.length > 0 ? (fileListLoader.item?.implicitWidth ?? 0) : 0)
                    Layout.preferredHeight: root.isVertical
                        ? (root.processedFiles.length > 0 ? (fileListLoader.item?.implicitHeight ?? 0) : 0)
                        : Appearance.sizes.dockButtonSize + root.dotMargin * 2
                    opacity: root.processedFiles.length > 0 ? 1.0 : 0.0
                    visible: opacity > 0
                    clip: true

                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(fileListWrapper)
                    }
                    Behavior on Layout.preferredWidth {
                        enabled: !root.isVertical
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(fileListWrapper)
                    }
                    Behavior on Layout.preferredHeight {
                        enabled: root.isVertical
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(fileListWrapper)
                    }

                    Loader {
                        id: fileListLoader
                        anchors.centerIn: parent
                        active: fileListWrapper.visible

                        readonly property var listView: item?.listViewItem ?? null

                        sourceComponent: Component {
                            Item {
                                property alias listViewItem: fileListView

                                implicitWidth: fileListView.implicitWidth
                                implicitHeight: fileListView.implicitHeight

                                StyledListView {
                                    id: fileListView
                                    orientation: root.isVertical ? ListView.Vertical : ListView.Horizontal
                                    spacing: 0

                                    implicitWidth: root.isVertical
                                        ? Appearance.sizes.dockButtonSize + root.dotMargin * 2
                                        : Math.max(1, contentWidth)
                                    implicitHeight: root.isVertical
                                        ? Math.max(1, contentHeight)
                                        : Appearance.sizes.dockButtonSize + root.dotMargin * 2

                                    cacheBuffer: 99999
                                    interactive: false
                                    clip: false
                                    animateAppearance: false
                                    animateMovement: false
                                    popin: false
                                    removeOvershoot: 0
                                    ScrollBar.vertical: null

                                    Behavior on implicitWidth {
                                        enabled: !root.fileDragActive
                                        animation: Appearance.animation.elementMove.numberAnimation.createObject(fileListView)
                                    }
                                    Behavior on implicitHeight {
                                        enabled: !root.fileDragActive
                                        animation: Appearance.animation.elementMove.numberAnimation.createObject(fileListView)
                                    }

                                    DropArea {
                                        anchors.fill: parent
                                        keys: ["dock-file-reorder"]
                                        enabled: !root.externalDragOver
                                        onPositionChanged: (drag) => {
                                            if (!root.fileDragActive) return
                                            const step = Appearance.sizes.dockButtonSize + root.dotMargin * 2
                                            const pos = isVertical ? drag.y : drag.x
                                            root.fileDropIndex = Math.max(0, Math.min(
                                                root.processedFiles.length - 1,
                                                Math.floor(pos / step)
                                            ))
                                        }
                                    }

                                    model: ScriptModel {
                                        objectProp: "uniqueKey"
                                        values: root.processedFiles
                                    }

                                    delegate: DockFileButton {
                                        required property var modelData
                                        required property int index
                                        filePath: modelData.path
                                        dockContent: root
                                        delegateIndex: index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Fixed trailing section ─────────────────────────────────────

        // Music player separator
        Item {
            id: musicSepWrapper
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: root.isVertical
                ? Appearance.sizes.dockButtonSize + root.dotMargin * 1.9
                : (root.showMusicPlayer ? root.sepThickness : 0)
            Layout.preferredHeight: root.isVertical
                ? (root.showMusicPlayer ? root.sepThickness : 0)
                : Appearance.sizes.dockButtonSize + root.dotMargin * 1.9
            opacity: root.showMusicPlayer ? 1.0 : 0.0
            visible: (Config.options?.dock?.enableMediaWidget ?? false) && opacity > 0
            clip: true

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(musicSepWrapper)
            }
            Behavior on Layout.preferredWidth {
                enabled: !root.isVertical
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(musicSepWrapper)
            }
            Behavior on Layout.preferredHeight {
                enabled: root.isVertical
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(musicSepWrapper)
            }

            DockSeparator { 
                anchors.fill: parent 
                isVertical: root.isVertical
                marginScale: 0.15 // O il valore che preferisci per i bordi esterni
            }
        }

        // Music player widget
        Item {
            id: mediaWidgetWrapper
            Layout.alignment: Qt.AlignCenter

            readonly property real innerW: mediaWidgetLoader.item?.implicitWidth ?? 0
            readonly property real innerH: mediaWidgetLoader.item?.implicitHeight ?? 0

            readonly property bool showWidget: (Config.options?.dock?.enableMediaWidget ?? false) && root.showMusicPlayer

            Layout.preferredWidth: root.isVertical
                ? Appearance.sizes.dockButtonSize + root.dotMargin * 2
                : (showWidget ? innerW : 0)
            Layout.preferredHeight: root.isVertical
                ? (showWidget ? innerH : 0)
                : Appearance.sizes.dockButtonSize + root.dotMargin * 2

            opacity: showWidget ? 1.0 : 0.0

            // Keep the item alive during the fade-out to prevent an instant layout collapse
            visible: showWidget || opacity > 0.01
            clip: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }
            Behavior on Layout.preferredWidth {
                enabled: !root.isVertical
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }
            Behavior on Layout.preferredHeight {
                enabled: root.isVertical
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                }
            }

            Loader {
                id: mediaWidgetLoader
                anchors.centerIn: parent
                active: mediaWidgetWrapper.visible
                sourceComponent: DockMediaWidget { isVertical: root.isVertical }
            }
        }

        // ── Unpin separator ──
        Item {
            visible: root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0 || root.processedFiles.length > 0
            Layout.preferredWidth: root.isVertical ? Appearance.sizes.dockButtonSize + root.dotMargin * 1.9 : root.sepThickness
            Layout.preferredHeight: root.isVertical ? root.sepThickness : Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.alignment: Qt.AlignCenter

            DockSeparator { 
                anchors.fill: parent 
                isVertical: root.isVertical
                marginScale: 0.15 
            }
        }

        // Unpin button
        Item {
            id: unpinButtonWrapper
            Layout.preferredWidth: Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.preferredHeight: Appearance.sizes.dockButtonSize + root.dotMargin * 2
            Layout.alignment: Qt.AlignCenter

            DockActionButton {
                id: unpinButton
                anchors.centerIn: parent
                symbolName: "apps"
                normalShape: MaterialShape.Shape.Pill
                activeShape: MaterialShape.Shape.SoftBurst
                isVertical: root.isVertical
                onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                dragActive: (root.dragActive && TaskbarApps.isPinned(root.draggedAppId)) || root.fileDragActive
                dragOver: (root.dragActive && root.dragIntent === "unpin" && TaskbarApps.isPinned(root.draggedAppId)) || (root.fileDragActive && root.fileDragIntent === "unpin")
                dragSymbol: root.fileDragActive ? "do_not_disturb_on" : "keep_off"
            }
        }
    }

    // ── Drag ghost & preview popup ────────────────────────────────────────
    readonly property var draggedFileDelegate: {
        if (!root.fileDragActive || root.fileDraggedIndex < 0) return null
        return fileListLoader.item?.listViewItem?.itemAtIndex(root.fileDraggedIndex) ?? null
    }

    DockDragGhost {
        id: dragGhost
        visible: root.dragActive || root.fileDragActive
        draggedAppId: root.dragActive ? root.draggedAppId : ""
        willUnpin: root.dragIntent === "unpin" || root.fileDragIntent === "unpin"
        isFile: root.fileDragActive
        fileIsImage: root.draggedFileDelegate?.isImage ?? false
        filePath: root.draggedFileDelegate?.filePath ?? ""
        fileResolvedIcon: root.draggedFileDelegate?.resolvedXdgIcon ?? ""

        width: Appearance.sizes.dockButtonSize
        height: Appearance.sizes.dockButtonSize

        scale: {
            const intent = root.dragActive ? root.dragIntent : root.fileDragIntent
            const pinned = root.dragActive ? TaskbarApps.isPinned(root.draggedAppId) : true
            return (pinned && intent === "unpin") || (!pinned && intent === "pin") ? 0.7 : 1.0
        }
        Behavior on scale {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        Drag.active: root.dragActive || root.fileDragActive
        Drag.keys: root.fileDragActive ? ["dock-file-reorder"] : ["dock-reorder"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }

    Loader {
        id: previewPopupLoader
        active: Config.options.dock.enablePreview ?? true
        sourceComponent: Component {
            DockPreviewPopup {
                dockRoot: root
                dockWindow: root.QsWindow.window
                appTopLevel: root.lastHoveredButton?.appToplevel
            }
        }
    }
}
