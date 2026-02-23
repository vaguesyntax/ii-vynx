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
    property bool useCustomSize: Config.options.bar.mediaPlayer.useCustomSize 
    readonly property int maxWidth: 300

    readonly property bool showLoadingIndicator: Config.options.bar.mediaPlayer.lyrics.showLoadingIndicator
    readonly property bool lyricsEnabled: Config.options.bar.mediaPlayer.lyrics.enable
    readonly property bool useGradientMask: Config.options.bar.mediaPlayer.lyrics.useGradientMask
    readonly property string lyricsStyle: Config.options.bar.mediaPlayer.lyrics.style

    Layout.fillHeight: true
    implicitWidth: useCustomSize ? lyricScroller.hasSyncedLines ? lyricsCustomSize :customSize : Math.min(rowLayout.implicitWidth + rowLayout.spacing, maxWidth)
    implicitHeight: Appearance.sizes.barHeight

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Loader {
        id: lyricsLoader
        active: lyricsEnabled
        sourceComponent: LrclibLyrics {
            id: lrclibLyrics
            enabled: (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0) && root.visible && root.lyricsEnabled
            title: root.activePlayer?.trackTitle ?? ""
            artist: root.activePlayer?.trackArtist ?? ""
            duration: root.activePlayer?.length ?? 0
            position: root.activePlayer?.position ?? 0
            selectedId: 0 //? I have no idea what this does, but it works so whatever
        }
    }

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: lyricScroller.hasSyncedLines ? 250 : Config.options.resources.updateInterval
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

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        Loader {
            id: loadingIndLoader
            active: root.showLoadingIndicator && !lyricScroller.hasSyncedLines && root.lyricsEnabled && (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0)
            visible: active
            
            Layout.preferredWidth: active ? item.implicitWidth : 0
            Layout.preferredHeight: active ? item.implicitHeight : 0

            Timer {
                id: loadingIndicatorDissappearTimer
                interval: 1500
                onTriggered: loadingIndLoader.active = false
            }

            sourceComponent: MaterialLoadingIndicator {
                id: lyricsLoadingIndicator
                property bool couldntFetch: lyricsLoader.item?.error === "No synced lyrics" 
                
                loading: !couldntFetch
                color: couldntFetch ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
                shapeColor: couldntFetch ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                implicitSize: 24

                onCouldntFetchChanged: {
                    if (couldntFetch) {
                        loadingIndicatorDissappearTimer.start()
                    }
                }
            }
        }

        ClippedFilledCircularProgress {
            id: mediaCircProg
            visible: !loadingIndLoader.active
            Layout.alignment: Qt.AlignVCenter
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
            visible: !lyricScroller.hasSyncedLines
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: visible // Ensures the text takes up available space
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight // Truncates the text on the right
            color: Appearance.colors.colOnLayer1
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        }

        //TODO: i hate putting these to a loader rn, add this to a loader later
        LyricScroller {
            id: lyricScroller
            Layout.preferredWidth: hasSyncedLines ? root.implicitWidth - (mediaCircProg.implicitSize + rowLayout.spacing * 2) : 0
            Layout.preferredHeight: parent.height
            Layout.alignment: Qt.AlignCenter
            
            defaultLyricsSize: Appearance.font.pixelSize.smallest
            useGradientMask: root.useGradientMask
            halfVisibleLines: 2
            downScale: 0.95
            rowHeight: 10
        }
    }
}
