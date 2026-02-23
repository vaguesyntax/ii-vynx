import QtQuick
import qs.modules.common
import qs.modules.common.widgets

ButtonGroup {
    id: root
    property int baseButtonWidth: 50
    property int baseButtonHeight: 50
    property real playPauseButtonWidthScale: 1.5


    property var player: MprisController.activePlayer

    GroupButton { // Previous button
        baseWidth: baseButtonWidth
        baseHeight: baseButtonHeight
        

        MaterialSymbol {
            anchors.centerIn: parent
            fill: 1
            iconSize: 24
            color: Appearance.colors.colPrimary
            text: "skip_previous"
        }

        onClicked: {
            root.player?.previous()
        }

    }

    GroupButton { // Play/Pause button
        baseWidth: baseButtonWidth * playPauseButtonWidthScale
        baseHeight: baseButtonHeight

        buttonRadius: Appearance.rounding.full
        buttonRadiusPressed: Appearance.rounding.full
        colBackground: Appearance.colors.colPrimary
        colBackgroundHover: Appearance.colors.colPrimaryHover
        colBackgroundActive: Appearance.colors.colPrimaryActive
        colBackgroundToggled: Appearance.colors.colPrimary
        colBackgroundToggledHover: Appearance.colors.colPrimaryHover
        colBackgroundToggledActive: Appearance.colors.colPrimaryActive

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 24
            fill: 1
            color: Appearance.colors.colOnPrimary
            text: root.player?.isPlaying ? "pause" : "play_arrow"
        }

        onClicked: {
            root.player?.togglePlaying()
        }

    }

    GroupButton { // Next button
        baseWidth: baseButtonWidth
        baseHeight: baseButtonHeight

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 24
            fill: 1
            color: Appearance.colors.colPrimary
            text: "skip_next"
        }

        onClicked: {
            root.player?.next()
        }

    }
}