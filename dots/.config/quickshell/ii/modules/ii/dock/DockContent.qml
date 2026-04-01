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

import "./widgets"

Item {
    id: root

    signal togglePinRequested

    property var currentScreen: null
    property bool isPinned: false

    readonly property real dockPadding: 0
    readonly property bool isVertical: dock.isVertical
    readonly property real dotMargin: (Config.options?.dock.height ?? 60) * 0.2
    readonly property real sepThickness: Math.max(3, Math.round(Appearance.sizes.dockButtonSize * 0.06))
    readonly property real buttonSlotSize: Appearance.sizes.dockButtonSize + dotMargin * 2

    readonly property real visualWidth: isVertical ? Appearance.sizes.dockButtonSize + dotMargin * 2 : mainLayout.implicitWidth
    readonly property real visualHeight: isVertical ? mainLayout.implicitHeight : Appearance.sizes.dockButtonSize + dotMargin * 2

    readonly property bool ready: (isVertical ? visualHeight > 0 : visualWidth > 0) && !suppressSizeAnimation
    readonly property bool requestDockShow: previewPopupLoader.item?.visible || anyContextMenuOpen

    readonly property real maxWindowPreviewHeight: 200
    readonly property real maxWindowPreviewWidth: 300
    readonly property real windowControlsHeight: 30

    property bool anyContextMenuOpen: false
    property bool popupIsResizing: false
    property Item lastHoveredButton: null
    property bool buttonHovered: false
    property bool suppressHover: false
    property point hoveredButtonCenter: Qt.point(0, 0)
    property string externalDragIcon: ""
    property bool externalDragOver: false

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string rawTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || ""
    readonly property bool hasRealData: activePlayer !== null && rawTitle !== ""
    property bool showMusicPlayer: hasRealData

    onHasRealDataChanged: {
        if (hasRealData) {
            switchHoldTimer.stop();
            showMusicPlayer = true;
        } else
            switchHoldTimer.restart();
    }

    Timer {
        id: suppressHoverTimer
        interval: 250
        onTriggered: root.suppressHover = false
    }
    Timer {
        id: switchHoldTimer
        interval: 2000
        onTriggered: if (!root.hasRealData)
            root.showMusicPlayer = false
    }

    onLastHoveredButtonChanged: {
        if (root.lastHoveredButton)
            hoveredButtonCenter = root.lastHoveredButton.mapToItem(null, root.lastHoveredButton.width / 2, root.lastHoveredButton.height / 2);
    }

    property string dragState: "idle"
    property string draggedAppId: ""
    property string dragIntent: "none"
    property int draggedIndex: -1
    property int dropTargetIndex: -1

    property int fileDraggedIndex: -1
    property int fileDropIndex: -1
    property string fileDragIntent: "reorder"

    property bool suppressAnimation: false
    property bool fileSuppressAnim: false

    readonly property bool dragActive: dragState !== "idle"
    readonly property bool isAppDrag: dragState === "app"
    readonly property bool isFileDrag: dragState === "file"
    readonly property bool fileDragActive: dragState === "file"

    property alias dragGhostItem: dragGhost
    property alias fileDragGhostItem: dragGhost

    property var processedPinnedApps: []
    property var processedRunningApps: []
    property var processedFiles: []

    function updateModel() {
        const allApps = TaskbarApps.apps ?? [];
        const isolate = Config.options?.dock?.isolateMonitors ?? false;
        let pinned = [], running = [];

        allApps.forEach(app => {
            let toplevels = app.toplevels;
            if (isolate && root.currentScreen) {
                toplevels = toplevels.filter(tl => tl?.screens?.includes(root.currentScreen));
            }
            if (!app.pinned && toplevels.length === 0)
                return;
            const data = {
                appId: app.appId,
                pinned: app.pinned,
                toplevels
            };
            if (app.pinned)
                pinned.push({
                    uniqueKey: app.appId,
                    appData: data
                });
            else
                running.push({
                    uniqueKey: app.appId,
                    appData: data
                });
        });

        processedPinnedApps = pinned;
        processedRunningApps = running;
    }

    function updateFileModel() {
        processedFiles = (Config.options?.dock?.pinnedFiles ?? []).map(p => ({
                    uniqueKey: p,
                    path: p
                }));
    }

    function startDrag(appId, idx) {
        suppressAnimation = true;
        Qt.callLater(() => suppressAnimation = false);
        draggedIndex = dropTargetIndex = idx;
        draggedAppId = appId;
        dragIntent = TaskbarApps.isPinned(appId) ? "reorder" : "none";
        dragState = "app";
        buttonHovered = false;
        if (previewPopupLoader.item)
            previewPopupLoader.item.show = false;
    }

    function moveDrag() {
        const center = isVertical ? dragGhost.y + dragGhost.height / 2 : dragGhost.x + dragGhost.width / 2;
        const isPinned = TaskbarApps.isPinned(draggedAppId);
        if (center <= pinButtonCenter)
            dragIntent = isPinned ? "reorder" : "pin";
        else if (center >= unpinButtonCenter)
            dragIntent = "unpin";
        else
            dragIntent = isPinned ? "reorder" : "none";
    }

    function endDrag() {
        if (!isAppDrag)
            return;
        suppressAnimation = true;
        dragState = "idle";
        const appId = draggedAppId, intent = dragIntent, from = draggedIndex, to = dropTargetIndex;
        draggedAppId = "";
        draggedIndex = dropTargetIndex = -1;
        buttonHovered = false;
        lastHoveredButton = null;
        suppressHover = true;
        suppressHoverTimer.restart();

        if (intent === "pin" && !TaskbarApps.isPinned(appId))
            TaskbarApps.togglePin(appId);
        else if (intent === "unpin" && TaskbarApps.isPinned(appId))
            TaskbarApps.togglePin(appId);
        else if (intent === "reorder" && from !== to) {
            let pinned = Config.options.dock.pinnedApps.slice();
            let f = pinned.indexOf(appId);
            if (f !== -1) {
                pinned.splice(f, 1);
                pinned.splice(to, 0, appId);
                Config.options.dock.pinnedApps = pinned;
                updateModel();
            }
        }
        Qt.callLater(() => {
            updateModel();
            suppressAnimation = false;
        });
    }

    function startFileDrag(idx) {
        fileSuppressAnim = true;
        fileDraggedIndex = fileDropIndex = idx;
        dragState = "file";
        buttonHovered = false;
        if (previewPopupLoader.item)
            previewPopupLoader.item.show = false;
        Qt.callLater(() => fileSuppressAnim = false);
    }

    function moveFileDrag() {
        const center = isVertical ? dragGhost.y + dragGhost.height / 2 : dragGhost.x + dragGhost.width / 2;
        fileDragIntent = (center >= unpinButtonCenter) ? "unpin" : "reorder";
    }

    function endFileDrag() {
        if (!isFileDrag)
            return;
        fileSuppressAnim = true;
        dragState = "idle";
        const intent = fileDragIntent, from = fileDraggedIndex, to = fileDropIndex;
        fileDraggedIndex = fileDropIndex = -1;
        buttonHovered = false;

        if (intent === "unpin") {
            TaskbarApps.removePinnedFile(processedFiles[from]?.path ?? "");
        } else if (intent === "reorder" && from !== to) {
            TaskbarApps.reorderPinnedFile(processedFiles[from]?.path, processedFiles[to]?.path);
            updateFileModel();
        }
        Qt.callLater(() => {
            updateFileModel();
            fileSuppressAnim = false;
        });
    }

    function mimeIconFromPath(path) {
        const p = (path ?? "").toString().toLowerCase();
        if (/\.(png|jpe?g|webp|gif|svg|bmp|ico)$/.test(p))
            return "image";
        if (/\.(mp3|flac|ogg|wav|aac|m4a)$/.test(p))
            return "music_note";
        if (/\.(mp4|mkv|webm|avi|mov)$/.test(p))
            return "movie";
        if (p.endsWith(".pdf"))
            return "picture_as_pdf";
        if (/\.(txt|md|rst|log)$/.test(p))
            return "description";
        if (/\.(zip|tar|gz|zst|rar|7z)$/.test(p))
            return "folder_zip";
        const last = p.split("/").filter(s => s).pop() || "";
        return last.includes(".") ? "insert_drive_file" : "folder";
    }

    Connections {
        target: TaskbarApps
        function onAppsChanged() {
            if (isAppDrag)
                return;
            updateModel();
        }
    }
    Connections {
        target: Config.options?.dock ?? null
        function onIsolateMonitorsChanged() {
            updateModel();
        }
    }
    Connections {
        target: Config.options?.dock ?? null
        function onPinnedFilesChanged() {
            if (isFileDrag)
                return;
            updateFileModel();
        }
    }

    property bool suppressSizeAnimation: true

    Timer {
        id: suppressSizeAnimTimer
        interval: 150
        onTriggered: root.suppressSizeAnimation = false
    }

    Component.onCompleted: {
        updateModel();
        updateFileModel();
        suppressSizeAnimTimer.start();
    }

    readonly property real pinButtonCenter: isVertical ? pinButtonWrapper.y + pinButtonWrapper.height / 2 : pinButtonWrapper.x + pinButtonWrapper.width / 2
    readonly property real unpinButtonCenter: isVertical ? unpinButtonWrapper.y + unpinButtonWrapper.height / 2 : unpinButtonWrapper.x + unpinButtonWrapper.width / 2

    GridLayout {
        id: mainLayout
        anchors.fill: parent
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: 0

        Item {
            id: pinButtonWrapper
            Layout.preferredWidth: root.buttonSlotSize
            Layout.preferredHeight: root.buttonSlotSize
            Layout.alignment: Qt.AlignCenter
            DockActionButton {
                id: pinButton
                anchors.centerIn: parent
                symbolName: "keep"
                toggled: root.isPinned
                onClicked: root.togglePinRequested()
                dragActive: root.isAppDrag && !TaskbarApps.isPinned(root.draggedAppId)
                dragOver: root.dragActive && root.dragIntent === "pin" && !TaskbarApps.isPinned(root.draggedAppId)
                dragSymbol: "keep"
                fileDropIcon: root.externalDragIcon
                fileDropActive: root.externalDragOver
            }
        }

        SectionSeparator {
            show: root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0 || root.processedFiles.length > 0
        }

        Flickable {
            id: scrollArea
            Layout.fillWidth: !root.isVertical
            Layout.fillHeight: root.isVertical
            Layout.preferredWidth: Math.max(1, root.isVertical ? root.buttonSlotSize : middleContent.implicitWidth)
            Layout.preferredHeight: Math.max(1, root.isVertical ? middleContent.implicitHeight : root.buttonSlotSize)
            clip: true
            contentWidth: middleContent.width
            contentHeight: middleContent.height
            interactive: root.isVertical ? contentHeight > height : contentWidth > width
            flickableDirection: root.isVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick

            WheelHandler {
                onWheel: event => {
                    let d = (event.angleDelta.y !== 0) ? event.angleDelta.y : event.angleDelta.x;
                    if (root.isVertical)
                        scrollArea.contentY = Math.max(0, Math.min(scrollArea.contentHeight - scrollArea.height, scrollArea.contentY - d));
                    else
                        scrollArea.contentX = Math.max(0, Math.min(scrollArea.contentWidth - scrollArea.width, scrollArea.contentX - d));
                    event.accepted = true;
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

                DockListView {
                    id: pinnedListView
                    modelValues: root.processedPinnedApps
                    listLayoutDirection: root.isVertical ? Qt.LeftToRight : Qt.RightToLeft
                    listVerticalLayoutDirection: root.isVertical ? ListView.BottomToTop : ListView.TopToBottom
                    delegateComp: Component {
                        DockAppButton {
                            required property var modelData
                            required property int index
                            appToplevel: modelData.appData
                            dockContent: root
                            delegateIndex: index
                        }
                    }
                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-reorder"]
                        enabled: !root.externalDragOver
                        onPositionChanged: drag => {
                            if (!root.isAppDrag || !TaskbarApps.isPinned(root.draggedAppId))
                                return;
                            let pos = root.isVertical ? pinnedListView.height - drag.y : pinnedListView.width - drag.x;
                            root.dropTargetIndex = Math.max(0, Math.min(root.processedPinnedApps.length - 1, Math.floor(pos / root.buttonSlotSize)));
                        }
                    }
                }

                SectionSeparator {
                    show: root.processedPinnedApps.length > 0 && root.processedRunningApps.length > 0
                }

                DockListView {
                    modelValues: root.processedRunningApps
                    delegateComp: Component {
                        DockAppButton {
                            required property var modelData
                            required property int index
                            appToplevel: modelData.appData
                            dockContent: root
                            delegateIndex: index
                        }
                    }
                }

                SectionSeparator {
                    show: root.processedFiles.length > 0 && (root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0)
                }

                Item {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredWidth: root.isVertical ? root.buttonSlotSize : (root.processedFiles.length > 0 ? fileListView.contentWidth : 0)
                    Layout.preferredHeight: root.isVertical ? (root.processedFiles.length > 0 ? fileListView.contentHeight : 0) : root.buttonSlotSize
                    visible: root.processedFiles.length > 0
                    clip: true
                    Behavior on Layout.preferredWidth {
                        enabled: !root.suppressSizeAnimation && !root.isVertical
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }
                    Behavior on Layout.preferredHeight {
                        enabled: !root.suppressSizeAnimation && root.isVertical
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }

                    DockListView {
                        id: fileListView
                        modelValues: root.processedFiles
                        delegateComp: Component {
                            DockFileButton {
                                required property var modelData
                                required property int index
                                filePath: modelData.path
                                dockContent: root
                                delegateIndex: index
                            }
                        }
                        DropArea {
                            anchors.fill: parent
                            keys: ["dock-file-reorder"]
                            enabled: !root.externalDragOver
                            onPositionChanged: drag => {
                                if (!root.isFileDrag)
                                    return;
                                let pos = root.isVertical ? drag.y : drag.x;
                                root.fileDropIndex = Math.max(0, Math.min(root.processedFiles.length - 1, Math.floor(pos / root.buttonSlotSize)));
                            }
                        }
                    }
                }
            }
        }

        SectionSeparator {
            show: (Config.options?.dock?.enableMediaWidget ?? false) && root.showMusicPlayer
        }

        Item {
            id: mediaWidgetWrapper
            Layout.alignment: Qt.AlignCenter
            readonly property bool showWidget: (Config.options?.dock?.enableMediaWidget ?? false) && root.showMusicPlayer
            readonly property real innerW: mediaWidgetLoader.item?.implicitWidth ?? 0
            readonly property real innerH: mediaWidgetLoader.item?.implicitHeight ?? 0
            Layout.preferredWidth: root.isVertical ? root.buttonSlotSize : (showWidget ? innerW : 0)
            Layout.preferredHeight: root.isVertical ? (showWidget ? innerH : 0) : root.buttonSlotSize
            opacity: showWidget ? 1.0 : 0.0
            visible: showWidget || opacity > 0.01
            clip: true

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on Layout.preferredWidth {
                enabled: !root.isVertical
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on Layout.preferredHeight {
                enabled: root.isVertical
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            Loader {
                id: mediaWidgetLoader
                anchors.centerIn: parent
                active: mediaWidgetWrapper.visible
                sourceComponent: DockMediaWidget {
                    isVertical: root.isVertical
                }
            }
        }

        SectionSeparator {
            show: root.processedPinnedApps.length > 0 || root.processedRunningApps.length > 0 || root.processedFiles.length > 0
        }

        Item {
            id: unpinButtonWrapper
            Layout.preferredWidth: root.buttonSlotSize
            Layout.preferredHeight: root.buttonSlotSize
            Layout.alignment: Qt.AlignCenter
            DockActionButton {
                id: unpinButton
                anchors.centerIn: parent
                symbolName: "apps"
                activeShape: MaterialShape.Shape.SoftBurst
                onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                dragActive: (root.dragActive && TaskbarApps.isPinned(root.draggedAppId)) || root.isFileDrag
                dragOver: (root.dragActive && root.dragIntent === "unpin" && TaskbarApps.isPinned(root.draggedAppId)) || (root.isFileDrag && root.fileDragIntent === "unpin")
                dragSymbol: root.isFileDrag ? "do_not_disturb_on" : "keep_off"
            }
        }
    }

    DockDragGhost {
        id: dragGhost
        visible: root.dragActive
        draggedAppId: root.dragActive ? root.draggedAppId : ""
        willUnpin: root.dragIntent === "unpin" || root.fileDragIntent === "unpin"
        isFile: root.isFileDrag
        width: Appearance.sizes.dockButtonSize
        height: Appearance.sizes.dockButtonSize

        readonly property var draggedFileDelegate: (root.isFileDrag && root.fileDraggedIndex >= 0) ? fileListView.itemAtIndex(root.fileDraggedIndex) : null
        fileIsImage: draggedFileDelegate?.isImage ?? false
        filePath: draggedFileDelegate?.filePath ?? ""
        fileResolvedIcon: draggedFileDelegate?.resolvedXdgIcon ?? ""

        scale: {
            const intent = root.isFileDrag ? root.fileDragIntent : root.dragIntent;
            const isPinned = root.isFileDrag || TaskbarApps.isPinned(root.draggedAppId);
            if (intent === "unpin" && isPinned) return 0.7;
            if (intent === "pin" && !isPinned) return 0.7;
            return 1.0;
        }
        Behavior on scale {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Drag.active: root.dragActive || root.isFileDrag
        Drag.keys: root.isFileDrag ? ["dock-file-reorder"] : ["dock-reorder"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }

    Loader {
        id: previewPopupLoader
        active: Config.options.dock.enablePreview ?? true
        sourceComponent: DockPreviewPopup {
            dockRoot: root
            dockWindow: root.QsWindow.window
            appTopLevel: root.lastHoveredButton?.appToplevel
        }
    }
}