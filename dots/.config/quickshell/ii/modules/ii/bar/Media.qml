import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import qs.modules.common.utils

Item {
    id: root
    Layout.fillHeight: true

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    
    property int customSize: Config.options.bar.mediaPlayer.customSize
    property int lyricsCustomSize: Config.options.bar.mediaPlayer.lyrics.customSize
    readonly property int maxWidth: 300

    property bool useFixedSize: Config.options.bar.mediaPlayer.useFixedSize
    readonly property bool lyricsEnabled: Config.options.bar.mediaPlayer.lyrics.enable
    readonly property bool hasLyrics: LyricsService.hasSyncedLines || LyricsService.geniusHasLyrics
    readonly property bool useGradientMask: Config.options.bar.mediaPlayer.lyrics.useGradientMask
    readonly property string lyricsStyle: Config.options.bar.mediaPlayer.lyrics.style
    readonly property bool artworkEnabled: Config.options.bar.mediaPlayer.artwork.enable

    readonly property int progressButtonSize: 20
    readonly property int artworkBoxSize: artworkEnabled ? Math.min(25, Appearance.sizes.barHeight - 8) : 0
    readonly property int artworkContentPadding: artworkEnabled ? 6 : 0

    property int textMetricsSpacing: artworkEnabled ? 70 : 50 // text metrics returns width without spacing
    property int textMetricsAdvance: Math.min(textMetrics.advanceWidth + textMetricsSpacing, Config.options.bar.mediaPlayer.maxSize)
    implicitWidth: root.hasLyrics && root.lyricsEnabled ? lyricsCustomSize : useFixedSize ? customSize : textMetricsAdvance
    implicitHeight: Appearance.sizes.barHeight

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    readonly property string artSource: activePlayer?.trackArtUrl && activePlayer.trackArtUrl !== "" ? activePlayer.trackArtUrl : ""

    Item {
        id: artworkItem
        visible: artworkEnabled
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: artworkEnabled ? artworkBoxSize : 0
        height: artworkEnabled ? artworkBoxSize : 0

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.full

            Image {
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                width: parent.width
                height: parent.height
                sourceSize.width: width
                sourceSize.height: height

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artworkItem.width
                        height: artworkItem.height
                        radius: Appearance.rounding.full
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.artSource.length === 0
                fill: 1
                text: "music_note"
                iconSize: Math.max(12, artworkItem.width * 0.5)
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
                var globalPos = root.mapToItem(null, 0, 0);
                Persistent.states.media.popupRect = Qt.rect(globalPos.x, globalPos.y, root.width, root.height);
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            }
        }   
    }

    Item {
        id: mediaCircProgSlot
        width: root.progressButtonSize
        height: root.progressButtonSize
        anchors.verticalCenter: parent.verticalCenter
        x: artworkEnabled ? root.width - width : 0

        ClippedFilledCircularProgress {
            id: mediaCircProg
            anchors.fill: parent
            visible: !loadingIndLoader.active
            implicitSize: root.progressButtonSize

            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    TextMetrics {
        id: textMetrics
        text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    }

    StyledText {
        visible: (!root.hasLyrics || !lyricsEnabled)
        anchors {
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: artworkEnabled ? 0 : mediaCircProgSlot.width / 2
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 1 // to vertically center it
        }
        horizontalAlignment: Text.AlignHCenter
        width: artworkEnabled ? parent.implicitWidth - (artworkItem.width + mediaCircProgSlot.width + artworkContentPadding + 16) : parent.implicitWidth - mediaCircProgSlot.width - 16
        elide: Text.ElideRight
        color: Appearance.colors.colOnLayer1
        text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    }

    Loader {
        id: lyricsItemLoader 
        active: lyricsEnabled

        width: artworkEnabled ? parent.width - (artworkItem.width + mediaCircProg.implicitSize * 2) : parent.width - mediaCircProg.implicitSize * 2
        height: parent.height
        
        anchors.left: parent.left
        anchors.leftMargin: artworkEnabled ? mediaCircProg.implicitSize * 1.5 + artworkContentPadding : mediaCircProg.implicitSize * 1.5

        sourceComponent: Item {
            id: lyricsItem
            visible: lyricsEnabled
            
            anchors.centerIn: parent

            Loader {
                active: lyricsStyle == "static" || (!LyricsService.hasSyncedLines && LyricsService.geniusHasLyrics)
                anchors.fill: parent
                anchors.centerIn: parent
                sourceComponent: LyricsStatic {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Loader {
                active: lyricsStyle == "scroller" && LyricsService.hasSyncedLines
                anchors.fill: parent
                sourceComponent: LyricScroller {
                    id: lyricScroller
                    
                    anchors.fill: parent
                    visible: lyricsStyle == "scroller" && LyricsService.hasSyncedLines
                    
                    defaultLyricsSize: Appearance.font.pixelSize.smallie - 2
                    useGradientMask: root.useGradientMask
                    halfVisibleLines: 1
                    downScale: 0.98
                    rowHeight: 10
                    gradientDensity: 0.25
                }
            }
        }   
    }
}
