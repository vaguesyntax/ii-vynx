pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions


Item {
    id: root
    visible: false

    signal lyricsUpdated(string lyrics)

    readonly property var geniusApiKey: KeyringStorage.keyringData?.apiKeys?.genius

    function fetchLyrics(artist, title) {
        console.log("[Genius Lyrics] Fetching lyrics for", artist, "-", title)
        fetchLyricsProcess.command = ["node", Directories.geniusLyricsScriptPath, root.geniusApiKey, artist, title]
        fetchLyricsProcess.running = true
    }

    Process {
        id: fetchLyricsProcess
        running: false
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                lyricsUpdated(this.text)
            }   
        }
    }   
}