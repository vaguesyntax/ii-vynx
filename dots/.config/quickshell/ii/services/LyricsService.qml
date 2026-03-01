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
    readonly property bool geniusEnabled: Config.options.lyricsService.enableGenius
    readonly property bool lrclibEnabled: Config.options.lyricsService.enableLrclib
    
    property bool isInitialized: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string currentTrackId: root.activePlayer?.trackTitle ?? ""

    readonly property bool effectiveLrclibEnabled: lyricsEnabled && lrclibEnabled && isInitialized && (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0)
    readonly property bool effectiveGeniusEnabled: lyricsEnabled && geniusEnabled && isInitialized

    readonly property alias syncedLines: lrclib.lines
    readonly property alias currentIndex: lrclib.currentIndex
    readonly property string statusText: lrclib.displayText
    readonly property bool hasSyncedLines: lrclib.lines.length > 0

    readonly property alias geniusHasLyrics: genius.hasString
    readonly property string plainLyrics: genius.lyricsString

    readonly property bool mediaModeEnabled: Persistent.states.background.mediaMode.enabled

    // We use this flag to change shell color just once, otherwise it will be called 3-4 times depending on the user's monitor count
    property bool shellColorChanged: false

    // Function to initialize the lyrics service, to prevent unnecessary API calls when no lyrics UI is being use
    // Its being called in LyricsStatic, LyricsScroller and LyricsFlickable files
    function initiliazeLyrics() {
        root.isInitialized = true
    }

    function filterLyricLines(lyrics) { // for clearing the metadata in genius lyrics
        return lyrics
            .split("\n")
            .filter(line => {
                const trimmed = line.trim()
                return !(trimmed.startsWith("[") && trimmed.endsWith("]"))
            })
            .slice(1)
            .join("\n")
    }

    function getLineDuration(index) { // for lrclib of to be used in syllable style
        if (!lrclib.lines || index < 0 || index >= lrclib.lines.length) 
            return 0;
        
        if (index === lrclib.lines.length - 1) {
            let total = lrclib.duration > 0 ? lrclib.duration : lrclib.lines[index].time + 5;
            return Math.max(0, total - lrclib.lines[index].time);
        }
        
        return lrclib.lines[index + 1].time - lrclib.lines[index].time;
    }

    function changeDurationToIndex(index) { // for lrclib, called by LyricsSyllable
        if (!hasSyncedLines) return;
        root.activePlayer.position = root.syncedLines[index].time
    }
    
    // https://quickshell.org/docs/master/types/Quickshell.Services.Mpris/MprisPlayer/#position
    Timer {
        running: root.activePlayer?.playbackState == MprisPlaybackState.Playing && root.hasSyncedLines && root.isInitialized
        interval: 250
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    Component.onCompleted: geniusFirstFetchDelay.restart()
    Timer {
        id: geniusFirstFetchDelay
        running: false
        interval: 1000
        onTriggered: {
            if (root.activePlayer && effectiveGeniusEnabled) {
                genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
            }
        }
    }

    LrclibLyrics {
        id: lrclib
        enabled: effectiveLrclibEnabled
        title: root.activePlayer?.trackTitle ?? ""
        artist: root.activePlayer?.trackArtist ?? ""
        duration: root.activePlayer?.length ?? 0
        position: root.activePlayer?.position ?? 0
    }

    GeniusLyrics {
        id: genius
        readonly property string trackTitle: root.activePlayer?.trackTitle
        onTrackTitleChanged: {
            if (root.activePlayer) {
                if (!effectiveGeniusEnabled) return;
                genius.hasString = false
                genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
            }
        }
        property string lyricsString: ""
        property bool hasString: false
        onLyricsUpdated: (lyrics) => {
            if (!effectiveGeniusEnabled) return
            genius.hasString = true
            genius.lyricsString = filterLyricLines(lyrics)
        }
    }
    
    onCurrentTrackIdChanged: {

        if (!effectiveGeniusEnabled) return;
        if (currentTrackId !== "" && root.activePlayer?.trackArtist) {
            genius.fetchLyrics(root.activePlayer.trackArtist, root.activePlayer.trackTitle)
        } else {
            genius.lyricsString = ""
        }

        shellColorChanged = false // reseting at each track change
    }

    // I dont know if this is the correct place for this, but we only call this from MediaMode so it should be fine
    function changeShellColor(color, force = false) {
        console.log("[Lyrics Service] Color change requested, is it changed: ", shellColorChanged)
        if (!mediaModeEnabled || shellColorChanged && !force) return;
        console.log("[Lyrics Service] Changing the shell color with color:   ", color)
        Quickshell.execDetached([`${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", color])
        shellColorChanged = true
    }
}