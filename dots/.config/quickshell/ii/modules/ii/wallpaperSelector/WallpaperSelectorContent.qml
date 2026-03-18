import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

MouseArea {
    id: wallpaperSelectorContent
    property int columns: 4
    property real previewCellAspectRatio: 4 / 3
    property bool useDarkMode: Appearance.m3colors.darkmode
    property bool favMode: false
    property bool browserMode: false

    property var moreOptionsModelData: null
    property string filterText: extraOptions.text

    property var apiImages: {
        let allImages = [];
        for (let i = 0; i < WallpaperBrowser.responses.length; i++) {
            let resp = WallpaperBrowser.responses[i];
            if (resp.images) {
                for (let j = 0; j < resp.images.length; j++) {
                    let img = resp.images[j];
                    allImages.push({
                        filePath: img.preview_url,
                        fileUrl: img.file_url,
                        fileName: "wallhaven-" + img.id || "image",
                        fileIsDir: false,
                        isApi: true,
                        imageData: img
                    });
                }
            }
        }
        return allImages;
    }

    function updateThumbnails() {
        const totalImageMargin = (Appearance.sizes.wallpaperSelectorItemMargins + Appearance.sizes.wallpaperSelectorItemPadding) * 2
        const thumbnailSizeName = Images.thumbnailSizeNameForDimensions(grid.cellWidth - totalImageMargin, grid.cellHeight - totalImageMargin)
        Wallpapers.generateThumbnail(thumbnailSizeName)
    }

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            // we need a better way instead of these 'mode' properties
            wallpaperSelectorContent.favMode = false;
            wallpaperSelectorContent.browserMode = false;
            wallpaperSelectorContent.updateThumbnails()
        }
    }

    Connections {
        target: Persistent.states.wallpaper
        function onFavouritesChanged() {
            if (wallpaperSelectorContent.favMode) {
                wallpaperSelectorContent.refreshFavourites();
            }
        }
    }

    ListModel {
        id: favouritesModel
    }

    function refreshFavourites() {
        favouritesModel.clear();
        const favs = Persistent.states.wallpaper.favourites;
        const query = filterText.toLowerCase();
        for (let i = 0; i < favs.length; i++) {
            const path = favs[i];
            const fileName = path.split('/').pop();
            if (query === "" || fileName.toLowerCase().includes(query)) {
                favouritesModel.append({
                    filePath: path,
                    fileName: fileName,
                    fileIsDir: false
                });
            }
        }
    }

    function handleFilePasting(event) {
        const currentClipboardEntry = Cliphist.entries[0]
        if (/^\d+\tfile:\/\/\S+/.test(currentClipboardEntry)) {
            const url = StringUtils.cleanCliphistEntry(currentClipboardEntry);
            Wallpapers.setDirectory(FileUtils.trimFileProtocol(decodeURIComponent(url)));
            event.accepted = true;
        } else {
            event.accepted = false; // No image, let text pasting proceed
        }
    }

    function selectWallpaperPath(filePath) {
        if (filePath && filePath.length > 0) {
            Wallpapers.select(filePath, wallpaperSelectorContent.useDarkMode);
            filterText = "";
            wallpaperSelectorContent.browserMode = false;
        }
    }

    function getWallhavenId(url) {
        if (!url) return null
        const urlStr = url.toString();
        const fileName = urlStr.split('/').pop();
        const fileNameWithoutExt = fileName.split('.')[0];
        const match = fileNameWithoutExt.match(/^wallhaven-([a-zA-Z0-9]{6})$/i);
        return match ? match[1] : null;
    }
    
    function searchForSimilarImages(id) {
        WallpaperBrowser.clearResponses();
        WallpaperBrowser.moreLikeThisPicture(id, 1);
        wallpaperSelectorContent.browserMode = true;
        wallpaperSelectorContent.favMode = false;
        filterText = "";
    }

    function toggleFavourite(path) {
        const favs = Array.from(Persistent.states.wallpaper.favourites);
        const index = favs.indexOf(path);
        if (index === -1) {
            favs.push(path);
        } else {
            favs.splice(index, 1);
        }
        Persistent.states.wallpaper.favourites = favs;
    }

    acceptedButtons: Qt.BackButton | Qt.ForwardButton
    onPressed: event => {
        if (event.button === Qt.BackButton) {
            Wallpapers.navigateBack();
        } else if (event.button === Qt.ForwardButton) {
            Wallpapers.navigateForward();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.wallpaperSelectorOpen = false;
            event.accepted = true;
        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) { // Intercept Ctrl+V to handle "paste to go to" in pickers
            wallpaperSelectorContent.handleFilePasting(event);
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            Wallpapers.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            Wallpapers.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            Wallpapers.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            grid.moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            grid.moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            grid.moveSelection(-grid.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            grid.moveSelection(grid.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            grid.activateCurrent();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (filterText.length > 0) {
                filterText = filterText.substring(0, filterText.length - 1);
            }
            filterField.forceActiveFocus();
            event.accepted = true;
        } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_L) {
            addressBar.focusBreadcrumb();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash) {
            filterField.forceActiveFocus();
            event.accepted = true;
        } else {
            if (event.text.length > 0) {
                filterText += event.text;
                filterField.cursorPosition = filterText.length;
                filterField.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    implicitHeight: mainLayout.implicitHeight
    implicitWidth: mainLayout.implicitWidth

    StyledRectangularShadow {
        target: wallpaperGridBackground
    }
    Rectangle {
        id: wallpaperGridBackground
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

        property int calculatedRows: Math.ceil(grid.count / grid.columns)

        implicitWidth: gridColumnLayout.implicitWidth
        implicitHeight: gridColumnLayout.implicitHeight

        RowLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: -4

            Rectangle {
                Layout.fillHeight: true
                Layout.margins: 4
                implicitWidth: quickDirColumnLayout.implicitWidth
                implicitHeight: quickDirColumnLayout.implicitHeight
                color: Appearance.colors.colLayer1
                radius: wallpaperGridBackground.radius - Layout.margins

                ColumnLayout {
                    id: quickDirColumnLayout
                    anchors.fill: parent
                    spacing: 0

                    StyledText {
                        Layout.margins: 12
                        font {
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.Medium
                        }
                        text: Translation.tr("Pick a wallpaper")
                    }
                    ListView {
                        // Quick dirs
                        Layout.fillHeight: true
                        Layout.margins: 4
                        implicitWidth: 140
                        clip: true
                        model: [
                            { icon: "home", name: "Home", path: Directories.home }, 
                            { icon: "docs", name: "Documents", path: Directories.documents }, 
                            { icon: "download", name: "Downloads", path: Directories.downloads }, 
                            { icon: "image", name: "Pictures", path: Directories.pictures }, 
                            { icon: "movie", name: "Videos", path: Directories.videos }, 
                            { icon: "public", name: "Browser", path: "BROWSER_MODE" }, 
                            { icon: "favorite", name: "Favourites", path: "FAVOURITES_MODE" }, 
                            { icon: "", name: "---", path: "INTENTIONALLY_INVALID_DIR" }, 
                            ...Config.options.wallpaperSelector.directories,
                            ...(Config.options.policies.weeb === 1 ? [{ icon: "favorite", name: "Homework", path: `${Directories.pictures}/homework` }] : []),
                        ]
                        delegate: RippleButton {
                            id: quickDirButton
                            required property var modelData
                            anchors {
                                left: parent.left
                                right: parent.right
                            }
                            onClicked: {
                                if (quickDirButton.modelData.path === "FAVOURITES_MODE") {
                                    wallpaperSelectorContent.favMode = true;
                                    wallpaperSelectorContent.browserMode = false;
                                    wallpaperSelectorContent.refreshFavourites();
                                } else if (quickDirButton.modelData.path === "BROWSER_MODE") {
                                    wallpaperSelectorContent.favMode = false;
                                    wallpaperSelectorContent.browserMode = true;
                                } else {
                                    wallpaperSelectorContent.favMode = false;
                                    wallpaperSelectorContent.browserMode = false;
                                    Wallpapers.setDirectory(quickDirButton.modelData.path)
                                }
                            }
                            enabled: modelData.icon.length > 0
                            toggled: {
                                if (modelData.path === "FAVOURITES_MODE") return wallpaperSelectorContent.favMode;
                                if (modelData.path === "BROWSER_MODE") return wallpaperSelectorContent.browserMode;
                                return !wallpaperSelectorContent.favMode && !wallpaperSelectorContent.browserMode && Wallpapers.directory === Qt.resolvedUrl(modelData.path);
                            }
                            colBackgroundToggled: Appearance.colors.colSecondaryContainer
                            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                            colRippleToggled: Appearance.colors.colSecondaryContainerActive
                            buttonRadius: Appearance.rounding.full
                            implicitHeight: 38

                            contentItem: RowLayout {
                                MaterialSymbol {
                                    color: quickDirButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    iconSize: Appearance.font.pixelSize.larger
                                    text: quickDirButton.modelData.icon
                                    fill: quickDirButton.toggled ? 1 : 0
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignLeft
                                    color: quickDirButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    text: quickDirButton.modelData.name
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                id: gridColumnLayout
                Layout.fillWidth: true
                Layout.fillHeight: true

                AddressBar {
                    id: addressBar
                    Layout.margins: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    directory: Wallpapers.effectiveDirectory
                    visible: !wallpaperSelectorContent.favMode && !wallpaperSelectorContent.browserMode
                    onNavigateToDirectory: path => {
                        Wallpapers.setDirectory(path.length == 0 ? "/" : path);
                    }
                    radius: wallpaperGridBackground.radius - Layout.margins
                }

                Rectangle {
                    visible: wallpaperSelectorContent.favMode || wallpaperSelectorContent.browserMode
                    Layout.margins: 4
                    Layout.fillWidth: true
                    implicitHeight: addressBar.implicitHeight
                    color: Appearance.colors.colLayer2
                    radius: wallpaperGridBackground.radius - Layout.margins

                    RowLayout {
                        spacing: 12
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        
                        MaterialSymbol {
                            text: wallpaperSelectorContent.browserMode ? "public" : "favorite"
                            color: Appearance.colors.colPrimary
                            iconSize: Appearance.font.pixelSize.larger
                        }
                        ConfigSelectionArray {
                            options: {
                                let items = [{ displayName: wallpaperSelectorContent.browserMode ? Translation.tr("Wallpaper Browser") : Translation.tr("Favourites"), isRoot: true }];
                                if (wallpaperSelectorContent.browserMode) {
                                    const tags = WallpaperBrowser.currentSearchTags;
                                    for (let i = 0; i < tags.length; i++) {
                                        items.push({ displayName: tags[i], value: tags[i] });
                                    }
                                }
                                return items;
                            }
                            onSelected: newValue => {
                                if (!newValue) return;
                                wallpaperSelectorContent.moreOptionsModelData = null
                                WallpaperBrowser.clearResponses();
                                WallpaperBrowser.makeRequest([newValue], 20, 1);
                            }
                        }
                    }
                    
                }

                Item {
                    id: gridDisplayRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledIndeterminateProgressBar {
                        id: indeterminateProgressBar
                        visible: (Wallpapers.thumbnailGenerationRunning && value == 0) || (wallpaperSelectorContent.browserMode && WallpaperBrowser.runningRequests > 0)
                        anchors {
                            bottom: parent.top
                            left: parent.left
                            right: parent.right
                            leftMargin: 4
                            rightMargin: 4
                        }
                    }

                    StyledProgressBar {
                        visible: Wallpapers.thumbnailGenerationRunning && value > 0
                        value: Wallpapers.thumbnailGenerationProgress
                        anchors.fill: indeterminateProgressBar
                    }

                    StyledText {
                        visible: (wallpaperSelectorContent.favMode && grid.model.count === 0) || (wallpaperSelectorContent.browserMode && grid.model.length === 0)
                        text: {
                            if (wallpaperSelectorContent.browserMode) {
                                return (WallpaperBrowser.runningRequests > 0) ? Translation.tr("Searching...") : Translation.tr("Search wallpapers with the search bar at the bottom.");
                            }
                            return Translation.tr("No favourites yet. Click the heart icon on any wallpaper to add it to favourites.");
                        }
                        anchors.centerIn: parent

                        font.family: Appearance.font.family.reading
                    }

                    GridView {
                        id: grid
                        visible: count > 0

                        readonly property int columns: wallpaperSelectorContent.columns
                        readonly property int rows: Math.max(1, Math.ceil(count / columns))
                        property int currentIndex: 0

                        anchors.fill: parent
                        cellWidth: width / wallpaperSelectorContent.columns
                        cellHeight: cellWidth / wallpaperSelectorContent.previewCellAspectRatio
                        interactive: true
                        clip: true
                        keyNavigationWraps: true
                        boundsBehavior: Flickable.StopAtBounds
                        bottomMargin: extraOptions.implicitHeight
                        ScrollBar.vertical: StyledScrollBar {}

                        Component.onCompleted: {
                            Qt.callLater(() => loadTimer.start())
                            wallpaperSelectorContent.updateThumbnails()
                        }

                        function moveSelection(delta) {
                            currentIndex = Math.max(0, Math.min(grid.model.count - 1, currentIndex + delta));
                            positionViewAtIndex(currentIndex, GridView.Contain);
                        }

                        function activateCurrent() {
                            const item = wallpaperSelectorContent.browserMode ? grid.model[currentIndex] : grid.model.get(currentIndex)
                            wallpaperSelectorContent.selectWallpaperPath(item.actualPath || item.filePath);
                        }

                        property int loadedCount: 0

                        Timer {
                            id: loadTimer
                            interval: 16
                            repeat: true
                            running: false
                            onTriggered: {
                                grid.loadedCount += 1
                                if (grid.loadedCount >= grid.count) loadTimer.stop()
                            }
                        }

                        model: wallpaperSelectorContent.browserMode ? wallpaperSelectorContent.apiImages : (wallpaperSelectorContent.favMode ? favouritesModel : Wallpapers.folderModel)
                        onModelChanged: currentIndex = 0
                        delegate: WallpaperDirectoryItem {
                            required property var modelData
                            required property int index
                            fileModelData: modelData
                            width: grid.cellWidth
                            height: grid.cellHeight
                            colBackground: (index === grid?.currentIndex || containsMouse) ? Appearance.colors.colPrimary : (fileModelData.filePath === Config.options.background.wallpaperPath) ? Appearance.colors.colSecondaryContainer : (fileModelData.filePath === wallpaperSelectorContent.moreOptionsModelData?.filePath) ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                            colText: (index === grid.currentIndex || containsMouse) ? Appearance.colors.colOnPrimary : (fileModelData.filePath === Config.options.background.wallpaperPath) ? Appearance.colors.colOnSecondaryContainer : (fileModelData.filePath === wallpaperSelectorContent.moreOptionsModelData?.filePath) ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                            shouldLoad: index < grid.loadedCount

                            onEntered: {
                                grid.currentIndex = index;
                            }
                            
                            onActivated: {
                                wallpaperSelectorContent.selectWallpaperPath(fileModelData.actualPath || fileModelData.filePath);
                            }

                            onSearchSimilarRequested: (path, id) => {
                                wallpaperSelectorContent.searchForSimilarImages(id)
                            }
                            onMoreOptionsRequested: (modelData) => {
                                //console.log("[Wallpaper Selector] More options requested:")
                                wallpaperSelectorContent.moreOptionsModelData = modelData
                            }
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: gridDisplayRegion.width
                                height: gridDisplayRegion.height
                                radius: wallpaperGridBackground.radius
                            }
                        }
                    }

                    ExtraOptionsToolbar {
                        id: extraOptions
                        colBackground: Appearance.m3colors.m3surfaceContainerLow
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 8
                        }
                    }

                    ImageOptionsToolbar {
                        z: 1
                        colBackground: Appearance.colors.colPrimary
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: 8
                            right: parent.right
                            rightMargin: 16
                        }
                    }

                    
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen && monitorIsFocused) {
                filterField.forceActiveFocus();
            }
        }
    }

    Connections {
        target: Wallpapers
        function onChanged() {
            GlobalStates.wallpaperSelectorOpen = false;
        }
    }
}
