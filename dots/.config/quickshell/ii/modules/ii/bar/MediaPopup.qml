import qs.modules.common
import qs.modules.common.functions
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
        compactMode: true
        anchors.centerIn: parent
        icon: "music_note"

        title: activePlayer?.trackArtist || Translation.tr("Unknown Artist")
        subtitle: activePlayer ? activePlayer.trackTitle : Translation.tr("No media")

        pillText: activePlayer ? (activePlayer.playbackState == MprisPlaybackState.Playing ? Translation.tr("Playing") : Translation.tr("Paused")) : ""
        pillIcon: activePlayer ? (activePlayer.playbackState == MprisPlaybackState.Playing ? "play_arrow" : "pause") : ""
    }
}
