pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.widgets
import qs.modules.common.functions

import qs.modules.ii.mediaControls
import qs.modules.ii.overlay

import Qt5Compat.GraphicalEffects

StyledOverlayWidget {
    id: root
    minimumWidth: 350
    minimumHeight: 150
    
    readonly property MprisPlayer currentPlayer: MprisController.activePlayer
    
    property bool downloaded: false
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    onArtFilePathChanged: updateArt()

    readonly property bool showSlider: Config.options.overlay.media.showSlider

    function updateArt() {
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: [ "bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'` ]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    LrclibLyrics {
        id: lrclibLyrics
        enabled: (root.currentPlayer?.trackTitle?.length > 0) && (root.currentPlayer?.trackArtist?.length > 0)
        title: root.currentPlayer?.trackTitle ?? ""
        artist: root.currentPlayer?.trackArtist ?? ""
        duration: root.currentPlayer?.length ?? 0
        position: root.currentPlayer?.position ?? 0
        selectedId: 0 //? I have no idea what this does, but it works so whatever
    }

    Timer {
        running: root.currentPlayer?.playbackState == MprisPlaybackState.Playing && lyricScroller.hasSyncedLines
        interval: 250
        repeat: true
        onTriggered: root.currentPlayer.positionChanged()
    }

    

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8
        color: ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainer, 1 - Config.options.overlay.media.backgroundOpacityPercentage / 100)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            // Top region for lyricss
            Item {
                id: lyricsItem
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height - mediaControlsRow.height - contentItem.padding * 2 - 20

                LyricScroller {
                    id: lyricScroller
                }
            }

            Loader {
                Layout.bottomMargin: -6
                Layout.fillWidth: true

                active: root.showSlider
                visible: active
                sourceComponent: StyledSlider { 
                    anchors.fill: parent

                    configuration: StyledSlider.Configuration.X0
                    highlightColor: Appearance.colors.colPrimary
                    trackColor: Appearance.colors.colSecondaryContainer
                    handleColor: Appearance.colors.colPrimary
                    value: root.currentPlayer?.position / root.currentPlayer?.length
                    onMoved: {
                        root.currentPlayer.position = value * root.currentPlayer.length;
                    }
                }
            }
            

            RowLayout {
                id: mediaControlsRow
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 10

                Rectangle { // Art background
                    id: artBackground
                    Layout.preferredWidth: parent.height
                    Layout.preferredHeight: parent.height
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimaryContainer
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artBackground.width
                            height: artBackground.height
                            radius: artBackground.radius
                        }
                    }

                    StyledImage { // Art image
                        id: mediaArt
                        property int size: parent.height
                        anchors.fill: parent

                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true

                        width: size
                        height: size
                        sourceSize.width: size
                        sourceSize.height: size
                    }
                }

                ColumnLayout {
                    id: textColumn
                    Layout.fillWidth: true

                    StyledText {
                        id: mediaActor
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackArtist || Translation.tr("Unknown Artist")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: mediaTitle
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackTitle || Translation.tr("Unknown Title")
                        font.pixelSize: Appearance.font.pixelSize.large
                        elide: Text.ElideRight
                    }
                }

                ButtonGroup {
                    Layout.preferredHeight: parent.height / 1.2
                    Layout.fillWidth: false

                    GroupButton { // Previous button
                        baseWidth: 30
                        baseHeight: parent.height
                        

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 1
                            iconSize: 24
                            color: Appearance.colors.colPrimary
                            text: "skip_previous"
                        }

                        onClicked: {
                            root.currentPlayer?.previous()
                        }

                    }

                    GroupButton { // Play/Pause button
                        baseWidth: 50
                        baseHeight: parent.height

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
                            text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                        }

                        onClicked: {
                            root.currentPlayer?.togglePlaying()
                        }

                    }

                    GroupButton { // Next button
                        baseWidth: 30
                        baseHeight: parent.height

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: 24
                            fill: 1
                            color: Appearance.colors.colPrimary
                            text: "skip_next"
                        }

                        onClicked: {
                            root.currentPlayer?.next()
                        }

                    }
                }
            }   
        }
    }

    component LyricScroller: Item {
        id: lyricScroller
        anchors.fill: parent
        clip: true

        readonly property bool hasSyncedLines: visible ? lrclibLyrics.lines.length > 0 : false
        readonly property int rowHeight: Math.max(10, Math.min(Math.floor(height / 3), Appearance.font.pixelSize.large))
        readonly property real baseY: Math.max(0, Math.round((height - rowHeight * 3) / 2))
        readonly property real downScale: Appearance.font.pixelSize.large / Appearance.font.pixelSize.larger

        readonly property int targetCurrentIndex: hasSyncedLines ? lrclibLyrics.currentIndex : -1

        readonly property string targetPrev: hasSyncedLines ? lrclibLyrics.prevLineText : ""
        readonly property string targetCurrent: hasSyncedLines ? (lrclibLyrics.currentLineText || "♪") : lrclibLyrics.displayText
        readonly property string targetNext: hasSyncedLines ? lrclibLyrics.nextLineText : ""

        property int lastIndex: -1
        property bool isMovingForward: true

        readonly property real animProgress: Math.abs(scrollOffset) / rowHeight
        readonly property real dimOpacity: 0.6
        readonly property real activeOpacity: 1.0

        property real scrollOffset: 0

        property int staticLineAnimDuration: 100 // a config option maybe? but it may be an overkill
        
        onTargetCurrentIndexChanged: {
            if (targetCurrentIndex !== lastIndex) {
                isMovingForward = targetCurrentIndex > lastIndex;
                lastIndex = targetCurrentIndex;
                scrollAnimation.restart();
            }
        }
        
        SequentialAnimation {
            id: scrollAnimation
            PropertyAction { // instant
                target: lyricScroller
                property: "scrollOffset"
                value: lyricScroller.isMovingForward ? -lyricScroller.rowHeight : lyricScroller.rowHeight 
            }
            NumberAnimation { // smooth
                target: lyricScroller
                property: "scrollOffset"
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
        
        Column {
            width: parent.width
            spacing: 0
            y: lyricScroller.baseY - lyricScroller.scrollOffset

            LyricLine {
                text: lyricScroller.targetPrev
                highlight: false
                useGradient: true
                gradientDirection: "top"
                
                opacity: (lyricScroller.isMovingForward) 
                    ? lyricScroller.dimOpacity + (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                    : lyricScroller.dimOpacity
                    
                scale: (lyricScroller.isMovingForward)
                    ? lyricScroller.downScale + (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
                    : lyricScroller.downScale
            }

            LyricLine {
                text: lyricScroller.targetCurrent
                highlight: true
                useGradient: false
                
                opacity: lyricScroller.activeOpacity - (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                scale: 1.0 - (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
            }

            LyricLine {
                text: lyricScroller.targetNext
                highlight: false
                useGradient: true
                gradientDirection: "bottom"
                
                opacity: (!lyricScroller.isMovingForward)
                    ? lyricScroller.dimOpacity + (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                    : lyricScroller.dimOpacity

                scale: (!lyricScroller.isMovingForward)
                    ? lyricScroller.downScale + (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
                    : lyricScroller.downScale
            }
        }
    }

    component LyricLine: Item {
        id: lyricLineItem
        required property string text
        property bool highlight: false
        property bool useGradient: false
        property string gradientDirection: "top" // "top" or "bottom"
        property bool reallyUseGradient: Config.options.overlay.media.useGradientMask && useGradient

        property real defaultLyricsSize: Config.options.overlay.media.lyricSize

        width: parent.width
        height: lyricScroller.rowHeight

        StyledText { // text for middle line
            id: lyricText
            anchors.fill: parent
            text: lyricLineItem.text
            color: lyricLineItem.highlight ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
            font.pixelSize: defaultLyricsSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !lyricLineItem.reallyUseGradient
        }

        Item {
            anchors.fill: parent
            visible: lyricLineItem.reallyUseGradient
            layer.enabled: visible
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: lyricLineItem.width
                    height: lyricLineItem.height
                    gradient: Gradient {
                        GradientStop { 
                            position: 0.0
                            color: lyricLineItem.gradientDirection === "top" ? "transparent" : "black" // colShadow makes it look bad
                        }
                        GradientStop { 
                            position: 1.0
                            color: lyricLineItem.gradientDirection === "top" ?  "black" : "transparent"
                        }
                    }
                }
            }

            StyledText { // text with gradient mask
                anchors.fill: parent
                text: lyricLineItem.text
                color: Appearance.colors.colSubtext
                font.pixelSize: defaultLyricsSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}