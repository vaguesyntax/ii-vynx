pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.utils
import qs.services
import qs.modules.common.functions
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
    property color artDominantColor: colorQuantizer.colors[0] ?? "#31313131" // 31 means gooning in Turkish btw :)
    property bool downloaded: false
    property string displayedArtFilePath: ""

    readonly property string trackTitle: root.player.trackTitle || ""
    Component.onCompleted: Persistent.states.background.mediaMode.userScrollOffset = 0
    onTrackTitleChanged: Persistent.states.background.mediaMode.userScrollOffset = 0

    property bool canChangeColor: true
    property string geniusLyricsString: LyricsService.plainLyrics

    function updateArt() {
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer;
            root.displayedArtFilePath = "";
            return;
        }

        updateArt();
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.displayedArtFilePath = Qt.resolvedUrl(root.artFilePath);
                root.downloaded = true;
            }
        }
    }
    

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing

        // We have to delay the color change if the media changes too quickly...
        onColorsChanged: {
            if (!Config.options.background.mediaMode.changeShellColor) return;
            if (!root.canChangeColor) {
                console.log("[Media Mode] Color change delayed, pending color:", colorQuantizer.colors[0])
                switchColorDelayTimer.pendingColor = colorQuantizer.colors[0]
                switchColorDelayTimer.restart()
                return;
            }
            else {
                switchColorProc.colorString = colorQuantizer.colors[0] 
                Qt.callLater(() => {
                    switchColorProc.running = true
                    root.canChangeColor = false
                    switchColorDelayTimer.restart()
                })
            }
            

        }
    }

    Timer {
        id: switchColorDelayTimer
        interval: 2500
        property string pendingColor: ""
        onTriggered: {
            if (pendingColor == "") root.canChangeColor = true 
            else {
                console.log("[Media Mode] Delay timer triggered, pending color:", pendingColor)
                switchColorProc.colorString = pendingColor
                Qt.callLater(() => {
                    switchColorProc.running = true
                    root.canChangeColor = false
                    switchColorDelayTimer.restart()
                })
                pendingColor = ""
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

                FloatingArtBackground {
                    anchors.fill: parent

                    animationSpeedScale: Config.options.background.mediaMode.backgroundAnimation.speedScale / 10
                    artFilePath: root.displayedArtFilePath
                    overlayColor: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                    animationEnabled: Config.options.background.mediaMode.backgroundAnimation.enable
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    MediaModeCoverArt {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: -120
                            anchors.rightMargin: 120
                            anchors.topMargin: 40
                            anchors.bottomMargin: 40

                            // Genius lyrics
                            LyricsFlickable {
                                anchors.fill: parent
                                player: root.player
                            }

                            // Lrclib (synced) lyrics
                            LyricsSyllable {
                                anchors.fill: parent
                                anchors.rightMargin: 100
                            }

                            // Lrclib (synced) lyrics - alternative
                            /* LyricScroller {
                                id: lyricScroller
                                anchors.fill: parent
                                defaultLyricsSize: Appearance.font.pixelSize.hugeass * 1.5
                                textAlign: "left"
                                changeTextWeight: true
                            } */
                        }
                    }
                }
            }
        }
    }
}
