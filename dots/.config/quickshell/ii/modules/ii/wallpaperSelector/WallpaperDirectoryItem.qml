import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

MouseArea {
    id: root
    required property var fileModelData
    property bool isDirectory: fileModelData.fileIsDir

    property bool isVideo: {
        const path = fileModelData.fileName.toLowerCase();
        return path.endsWith('.mp4') || path.endsWith('.webm') || 
                path.endsWith('.mkv') || path.endsWith('.avi') || 
                path.endsWith('.mov') || path.endsWith('.m4v') ||
                path.endsWith('.ogv');
    }
    property bool useThumbnail: Images.isValidImageByName(fileModelData.fileName) || root.isVideo
    property bool showLoadingIndicator: false

    property alias colBackground: background.color
    property alias colText: wallpaperItemName.color
    property alias radius: background.radius
    property alias margins: background.anchors.margins
    property alias padding: wallpaperItemColumnLayout.anchors.margins
    margins: Appearance.sizes.wallpaperSelectorItemMargins
    padding: Appearance.sizes.wallpaperSelectorItemPadding

    signal activated()

    hoverEnabled: true
    onClicked: root.activated()

    function getWallhavenId(url) {
        const urlStr = url.toString()
        const fileName = urlStr.split('/').pop() 
        const fileNameWithoutExt = fileName.split('.')[0] 
        const match = fileNameWithoutExt.match(/^wallhaven-([a-zA-Z0-9]{6})$/i)
        return match ? match[1] : null
    }
    
    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: wallpaperItemColumnLayout
            anchors.fill: parent
            spacing: 4

            Item {
                id: wallpaperItemImageContainer
                Layout.fillHeight: true
                Layout.fillWidth: true

                Loader {
                    id: thumbnailShadowLoader
                    active: thumbnailImageLoader.active && thumbnailImageLoader.item.status === Image.Ready
                    anchors.fill: thumbnailImageLoader
                    sourceComponent: StyledRectangularShadow {
                        target: thumbnailImageLoader
                        anchors.fill: undefined
                        radius: Appearance.rounding.small
                    }
                }

                Loader {
                    id: thumbnailImageLoader
                    anchors.fill: parent
                    active: root.useThumbnail
                    sourceComponent: ThumbnailImage {
                        id: thumbnailImage
                        generateThumbnail: false
                        sourcePath: fileModelData.filePath

                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        sourceSize.width: wallpaperItemColumnLayout.width
                        sourceSize.height: wallpaperItemColumnLayout.height - wallpaperItemColumnLayout.spacing - wallpaperItemName.height

                        Connections {
                            target: Wallpapers
                            function onThumbnailGenerated(directory) {
                                if (thumbnailImage.status !== Image.Error) return;
                                if (FileUtils.parentDirectory(thumbnailImage.sourcePath) !== FileUtils.trimFileProtocol(directory)) return;
                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }
                            function onThumbnailGeneratedFile(filePath) {
                                if (thumbnailImage.status !== Image.Error) return;
                                if (Qt.resolvedUrl(thumbnailImage.sourcePath) !== Qt.resolvedUrl(filePath)) return;
                                thumbnailImage.source = "";
                                thumbnailImage.source = thumbnailImage.thumbnailPath;
                            }
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: wallpaperItemImageContainer.width
                                height: wallpaperItemImageContainer.height
                                radius: Appearance.rounding.small
                            }
                        }
                    }
                }

                Loader {
                    id: videoIconLoader
                    active: root.isVideo && root.useThumbnail
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 8
                    sourceComponent: MaterialSymbol {
                        text: "video_library"
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.large
                        fill: 1
                    }
                }

                Loader {
                    id: similarImageButtonLoader
                    active: root.getWallhavenId(fileModelData.fileName) && root.useThumbnail
                    
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8

                    asynchronous: true
                    sourceComponent: WallpaperActionButton {
                        id: button
                        buttonIcon: "image_search"
                        buttonFill: 1
                        tooltipText: Translation.tr("Search for similar images")

                        colBackground: root.containsMouse ? Appearance.colors.colSecondaryContainerHover : "transparent"

                        property int wallpaperTabIndex: {
                            let index = 0;
                            if (Config.options.policies.ai !== 0) index++;
                            if (Config.options.policies.translator !== 0) index++;
                            return Config.options.policies.wallpapers !== 0 ? index : -1;
                        }

                        onClicked: {
                            if (button.wallpaperTabIndex === -1) {
                                console.log("Wallpaper policies tab is disabled, cannot search for similar images. TODO: add an indicator to user");
                                return;
                            }
                            WallpaperBrowser.addSimilarImageMessage(Translation.tr("Searching for a similar image:"), fileModelData.filePath)
                            WallpaperBrowser.moreLikeThisPicture(root.getWallhavenId(fileModelData.fileName), 1);
                            Persistent.states.sidebar.policies.tab = button.wallpaperTabIndex;
                            
                            GlobalStates.policiesPanelOpen = true;
                            GlobalStates.wallpaperSelectorOpen = false;
                        }
                    }
                }

                FadeLoader {
                    id: favouriteButtonLoader
                    shown: !root.isDirectory && (root.containsMouse || isFavourite)

                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 8

                    property bool isFavourite: Persistent.states.wallpaper.favourites.includes(fileModelData.filePath)

                    sourceComponent: WallpaperActionButton {
                        buttonIcon: favouriteButtonLoader.isFavourite ? "favorite" : "favorite_border"
                        buttonFill: favouriteButtonLoader.isFavourite ? 1 : 0
                        tooltipText: Translation.tr("Toggle favourite")

                        onClicked: {
                            const favs = Array.from(Persistent.states.wallpaper.favourites);
                            const path = fileModelData.filePath;
                            const index = favs.indexOf(path);
                            if (index === -1) {
                                favs.push(path);
                            } else {
                                favs.splice(index, 1);
                            }
                            Persistent.states.wallpaper.favourites = favs;
                        }
                    }
                }

                Loader {
                    id: iconLoader
                    active: !root.useThumbnail
                    anchors.fill: parent
                    sourceComponent: DirectoryIcon {
                        fileModelData: root.fileModelData
                        sourceSize.width: wallpaperItemColumnLayout.width
                        sourceSize.height: wallpaperItemColumnLayout.height - wallpaperItemColumnLayout.spacing - wallpaperItemName.height
                    }
                }
            }

            StyledText {
                id: wallpaperItemName
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
                text: fileModelData.fileName
            }
        }
    }


    component WallpaperActionButton: RippleButton {
        id: button

        property alias buttonIcon: materialSymbol.text
        property alias buttonFill: materialSymbol.fill
        property alias tooltipText: tooltip.text

        implicitWidth: 30
        implicitHeight: 30

        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.colors.colSecondaryContainerActive

        MaterialSymbol {
            id: materialSymbol

            text: button.buttonIcon
            fill: button.buttonFill

            anchors.centerIn: parent
            color: Appearance.colors.colPrimary
            font.pixelSize: Appearance.font.pixelSize.large
        }

        StyledToolTip {
            id: tooltip
            text: button.tooltipText
        }
    }
}
