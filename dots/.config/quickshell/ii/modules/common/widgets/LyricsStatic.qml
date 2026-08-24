import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

StyledText {
    readonly property string syncedLine: LyricsService.currentIndex >= 0 && LyricsService.syncedLines[LyricsService.currentIndex]
        ? LyricsService.syncedLines[LyricsService.currentIndex].text
        : ""
    readonly property string geniusLine: LyricsService.plainLyrics
        .split("\\n")
        .find(line => line.trim().length > 0) ?? ""

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    font.pixelSize: Appearance.font.pixelSize.smallie
    text: syncedLine || geniusLine
    animateChange: true
    elide: Text.ElideRight
}