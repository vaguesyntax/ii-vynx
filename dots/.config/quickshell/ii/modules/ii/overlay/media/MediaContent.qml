pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.widgets
import qs.modules.common.functions

import qs.modules.ii.mediaControls
import qs.modules.ii.overlay

import Qt5Compat.GraphicalEffects

StyledOverlayWidget {
    id: root
    minimumWidth: 350
    minimumHeight: 150
    
    readonly property MprisPlayer currentPlayer: MprisController.activePlayer
    
    property bool downloaded: false
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    onArtFilePathChanged: updateArt()

    readonly property bool showSlider: Config.options.overlay.media.showSlider

    function updateArt() {
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: [ "bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'` ]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 1 - Config.options.overlay.media.backgroundOpacityPercentage / 100)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            // Top region for lyricss
            Item {
                id: lyricsItem
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height - mediaControlsRow.height - contentItem.padding * 2 - 20

                LyricScroller {
                    id: lyricScroller
                    anchors.fill: parent
                    defaultLyricsSize: Config.options.overlay.media.lyricSize
                    halfVisibleLines: 2
                    rowHeight: 20
                }
            }

            Loader {
                Layout.bottomMargin: -6
                Layout.fillWidth: true

                active: root.showSlider
                visible: active
                sourceComponent: StyledSlider { 
                    anchors.fill: parent

                    configuration: StyledSlider.Configuration.X0
                    highlightColor: Appearance.colors.colPrimary
                    trackColor: Appearance.colors.colSecondaryContainer
                    handleColor: Appearance.colors.colPrimary
                    value: root.currentPlayer?.position / root.currentPlayer?.length
                    onMoved: {
                        root.currentPlayer.position = value * root.currentPlayer.length;
                    }
                }
            }
            

            RowLayout {
                id: mediaControlsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 10

                Rectangle { // Art background
                    id: artBackground
                    Layout.preferredWidth: parent.height
                    Layout.preferredHeight: parent.height
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artBackground.width
                            height: artBackground.height
                            radius: artBackground.radius
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        onClicked: root.updateArt()
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

                ColumnLayout {
                    id: textColumn
                    Layout.fillWidth: true

                    StyledText {
                        id: mediaActor
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackArtist || Translation.tr("Unknown Artist")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: mediaTitle
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackTitle || Translation.tr("Unknown Title")
                        font.pixelSize: Appearance.font.pixelSize.large
                        elide: Text.ElideRight
                    }
                }

                MaterialMusicControls {
                    id: musicControls
                    Layout.alignment: Qt.AlignVCenter
                    player: root.currentPlayer
                    baseButtonWidth: 30
                    baseButtonHeight: 35
                    playPauseButtonWidthScale: 1.75
                }
            }   
        }
    }
}