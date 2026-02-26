import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

StyledText {

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    font.pixelSize: Appearance.font.pixelSize.smallie
    text: LyricsService.syncedLines[LyricsService.currentIndex].text
    animateChange: true
    elide: Text.ElideRight
}