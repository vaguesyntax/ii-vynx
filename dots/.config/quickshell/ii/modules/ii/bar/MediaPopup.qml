import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    contentItem: HeroCard {
        id: mediaHero
        Layout.fillWidth: true
        anchors.centerIn: parent
        icon: "music_note"

        implicitHeight: 150

        titleSize: Appearance.font.pixelSize.huge
        subtitleSize: Appearance.font.pixelSize.large

        title: activePlayer?.trackArtist || Translation.tr("Unknown Artist")
        subtitle: activePlayer ? activePlayer.trackTitle : Translation.tr("No media")

        pillText: activePlayer ? (activePlayer.playbackState == MprisPlaybackState.Playing ? Translation.tr("Playing") : Translation.tr("Paused")) : ""
        pillIcon: activePlayer ? (activePlayer.playbackState == MprisPlaybackState.Playing ? "play_arrow" : "pause") : ""
    }
}
