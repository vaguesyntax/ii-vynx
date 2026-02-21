import QtQuick
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// i hope this import works :)
import "../../../scripts/lyrics/genius-lyrics.js" as GeniusLyrics

Item {
    id: root
    visible: false


    function fetchLyrics(artist, title) {
        return GeniusLyrics.fetchLyrics(artist, title)
    }
}