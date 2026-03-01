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
            // console.log("[Media Mode] Colors changed: ", colorQuantizer.colors)
            if (!Config.options.background.mediaMode.changeShellColor) return;
            // console.log("[Media Mode] Requesting to change shell color")
            LyricsService.changeShellColor(colorQuantizer.colors[0])
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
                color: ColorUtils.applyAlpha(Appearance.colors.colLayer0, 1)

                FloatingArtBackground {
                    anchors.fill: parent

                    animationSpeedScale: Config.options.background.mediaMode.backgroundAnimation.speedScale / 10
                    artFilePath: root.displayedArtFilePath
                    overlayColor: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.3)
                    animationEnabled: Config.options.background.mediaMode.backgroundAnimation.enable

                    workspaceNorm: {
                        const chunkSize = Config?.options.bar.workspaces.shown ?? 10
                        const lower = Math.floor(bgRoot.firstWorkspaceId / chunkSize) * chunkSize
                        const upper = Math.ceil(bgRoot.lastWorkspaceId / chunkSize) * chunkSize
                        const range = upper - lower
                        const id = bgRoot.monitor.activeWorkspace?.id ?? 1
                        return range > 0 ? (id - lower) / range : 0.5
                    }

                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    MediaModeCoverArt {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        showLoadingIndicator: !root.downloaded
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            id: lyricsItem
                            anchors.fill: parent
                            anchors.leftMargin: -120
                            anchors.rightMargin: 120
                            anchors.topMargin: 40
                            anchors.bottomMargin: 40

                            readonly property bool hasSyncedLines: LyricsService.syncedLines.length > 0
                            readonly property bool geniusEnabled: Config.options.lyricsService.enableGenius
                            readonly property bool lrclibEnabled: Config.options.lyricsService.enableLrclib

                            Component.onCompleted: {
                                if (!geniusEnabled && !lrclibEnabled) return
                                LyricsService.initiliazeLyrics()
                            }

                            FadeLoader {
                                shown: !lyricsItem.hasSyncedLines
                                anchors.fill: parent
                                sourceComponent: LyricsFlickable {
                                    anchors.fill: parent
                                    player: root.player
                                }
                            }
                            
                            FadeLoader {
                                shown: lyricsItem.hasSyncedLines
                                anchors.fill: parent
                                sourceComponent: LyricsSyllable {
                                    anchors.fill: parent
                                    anchors.rightMargin: 100
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
