pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // MediaMode instance
    id: root

    property MprisPlayer player: MprisController.activePlayer
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    onArtFilePathChanged: {
        loader.active = false;

        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer;
            return;
        }

        // Binding does not work in Process
        coverArtDownloader.targetFile = root.artUrl;
        coverArtDownloader.artFilePath = root.artFilePath;
        // Download
        root.downloaded = false;
        coverArtDownloader.running = true;
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true;
                recreateDelay.start();
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing

        onColorsChanged: {
            if (Persistent.states.mediaMode && root.artUrl && root.downloaded && colors.length > 0) {
                let colStr = colors[0].toString();
                if (colStr !== "") {
                    switchColorProc.colorString = colStr;
                    switchColorProc.running = true;
                }
            }
        }
    }

    Process {
        id: switchColorProc
        property string colorString: ""
        command: [`${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", switchColorProc.colorString]
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    Timer { // Recreate UI component delay
        id: recreateDelay
        interval: 10
        onTriggered: {
            loader.active = true;
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: true
        sourceComponent: Item {
            anchors.fill: parent

            Rectangle { // Background
                id: background
                anchors.fill: parent
                color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)

                Image {
                    id: blurredArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    sourceSize.width: background.width
                    sourceSize.height: background.height
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    asynchronous: true

                    layer.enabled: true
                    layer.effect: StyledBlurEffect {
                        source: blurredArt
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    Item {
                        Layout.fillHeight: true
                        implicitWidth: height

                        Rectangle { // Art background
                            id: artBackground
                            height: parent.height / 2
                            width: height
                            anchors.centerIn: parent
                            radius: Appearance.rounding.verysmall
                            color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: artBackground.width
                                    height: artBackground.height
                                    radius: artBackground.radius
                                }
                            }

                            StyledImage { // Art image
                                id: mediaArt
                                property int size: parent.height
                                anchors.fill: parent

                                source: root.displayedArtFilePath
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                antialiasing: true

                                width: size
                                height: size
                                sourceSize.width: size
                                sourceSize.height: size
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
