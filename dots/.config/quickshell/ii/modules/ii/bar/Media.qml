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
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    
    property int customSize: Config.options.bar.mediaPlayer.customSize
    property int lyricsCustomSize: Config.options.bar.mediaPlayer.lyrics.customSize
    readonly property int maxWidth: 300

    readonly property bool showLoadingIndicator: Config.options.bar.mediaPlayer.lyrics.showLoadingIndicator
    readonly property bool lyricsEnabled: Config.options.bar.mediaPlayer.lyrics.enable
    readonly property bool useGradientMask: Config.options.bar.mediaPlayer.lyrics.useGradientMask
    readonly property string lyricsStyle: Config.options.bar.mediaPlayer.lyrics.style

    Layout.fillHeight: true
    implicitWidth: LyricsService.hasSyncedLines && root.lyricsEnabled ? lyricsCustomSize : customSize
    implicitHeight: Appearance.sizes.barHeight

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: LyricsService.hasSyncedLines ? 250 : Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
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

    ClippedFilledCircularProgress {
        id: mediaCircProg
        visible: !loadingIndLoader.active
        
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        lineWidth: Appearance.rounding.unsharpen
        value: activePlayer?.position / activePlayer?.length
        implicitSize: 20
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

    StyledText {
        visible: !LyricsService.hasSyncedLines || !lyricsEnabled
        width: parent.width - mediaCircProg.implicitSize * 2
        
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: mediaCircProg.implicitSize / 2
        anchors.verticalCenter: parent.verticalCenter
        
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight // Truncates the text on the right
        color: Appearance.colors.colOnLayer1
        text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    } 

    Loader {
        id: lyricsItemLoader 
        active: lyricsEnabled

        width: parent.width - mediaCircProg.implicitSize * 2
        height: parent.height
        
        anchors.left: parent.left
        anchors.leftMargin: mediaCircProg.implicitSize * 1.5

        sourceComponent: Item {
            id: lyricsItem
            visible: lyricsEnabled
            
            anchors.centerIn: parent

            Loader {
                active: lyricsStyle == "static"
                anchors.fill: parent
                anchors.centerIn: parent
                sourceComponent: LyricsStatic {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Loader {
                active: lyricsStyle == "scroller"
                anchors.fill: parent
                sourceComponent: LyricScroller {
                    id: lyricScroller
                    
                    anchors.fill: parent
                    visible: lyricsStyle == "scroller" && LyricsService.hasSyncedLines
                    
                    defaultLyricsSize: Appearance.font.pixelSize.smallest
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
