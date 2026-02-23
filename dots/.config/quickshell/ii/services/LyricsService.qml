pragma Singleton

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.utils
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property bool lyricsEnabled: Config.options.lyricsService.enable
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    
    readonly property alias syncedLines: lrclib.lines
    readonly property alias currentIndex: lrclib.currentIndex
    readonly property string plainLyrics: genius.lyricsString
    readonly property bool hasSynced: lrclib.lines.length > 0
    readonly property string statusText: lrclib.displayText

    LrclibLyrics {
        id: lrclib
        enabled: (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0) && lyricsEnabled
        title: root.activePlayer?.trackTitle ?? ""
        artist: root.activePlayer?.trackArtist ?? ""
        duration: root.activePlayer?.length ?? 0
        position: root.activePlayer?.position ?? 0
    }

    readonly property alias geniusLyrics: genius.lyricsString
    readonly property alias geniusHasLyrics: genius.hasString

    Component.onCompleted: geniusFirstFetchDelay.restart()

    Timer {
        id: geniusFirstFetchDelay
        running: false
        interval: 1000
        onTriggered: {
            if (root.activePlayer) {
                genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
            }
        }
    }

    GeniusLyrics {
        id: genius
        readonly property string trackTitle: root.activePlayer?.trackTitle
        onTrackTitleChanged: {
            if (root.activePlayer) {
                if (!lyricsEnabled) return;
                genius.hasString = false
                genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
            }
        }
        property string lyricsString: ""
        property bool hasString: false
        onLyricsUpdated: (lyrics) => {
            if (!lyricsEnabled) return;
            // console.log("Got Genius lyrics:", lyrics)
            let lines = lyrics.split("\n")
            let filtered = lines.filter(line => {
                let trimmed = line.trim()
                return !(trimmed.startsWith("[") && trimmed.endsWith("]"))
            })
            genius.hasString = true
            lyricsString = filtered.slice(1).join("\n")
        }
    }

    readonly property string currentTrackId: root.activePlayer?.trackTitle ?? ""
    
    onCurrentTrackIdChanged: {
        if (!lyricsEnabled) return;
        if (currentTrackId !== "" && root.activePlayer?.trackArtist) {
            genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
        } else {
            genius.lyricsString = ""
        }
    }
}