pragma ComponentBehavior: Bound
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

Item { // MediaMode instance
    id: root

    property MprisPlayer player: MprisController.activePlayer
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property string displayedArtFilePath: ""

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer;
            root.displayedArtFilePath = "";
            return;
        }

        // Binding does not work in Process
        coverArtDownloader.targetFile = root.artUrl;
        coverArtDownloader.artFilePath = root.artFilePath;
        // Download
        root.downloaded = false;
        coverArtDownloader.running = true;
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.displayedArtFilePath = Qt.resolvedUrl(root.artFilePath);
                root.downloaded = true;
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing

        onColorsChanged: {
            if (root.downloaded && colors.length > 0) {
                let colStr = colors[0].toString();
                switchColorProc.colorString = colStr;
                switchColorProc.running = true;
            }
        }
    }

    // sometimes color quantizer's color change does not work (i have no idea why)
    onDisplayedArtFilePathChanged: {
        colorQuantizer.source = root.displayedArtFilePath;
        let colStr = colorQuantizer.colors[0].toString();
        if (root.artUrl && root.downloaded) {
            switchColorProc.colorString = colStr;
            switchColorProc.running = true;
        }
    }
    

    Process {
        id: switchColorProc
        property string colorString: ""
        command: [`${Directories.wallpaperSwitchScriptPath}`, "--noswitch", "--color", switchColorProc.colorString]
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: true
        sourceComponent: Item {
            anchors.fill: parent

            Rectangle { // Background
                id: background
                anchors.fill: parent
                color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)

                Image {
                    id: blurredArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    sourceSize.width: background.width
                    sourceSize.height: background.height
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    asynchronous: true

                    layer.enabled: true
                    layer.effect: StyledBlurEffect {
                        source: blurredArt
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 13
                    spacing: 15

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // We wrap the Left Side (Art + Text) into a ColumnLayout
                        ColumnLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width

                            Rectangle { // Art background
                                id: artBackground
                                Layout.preferredWidth: 400
                                Layout.preferredHeight: 400
                                Layout.alignment: Qt.AlignHCenter
                                radius: Appearance.rounding.verysmall
                                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

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
                                Layout.fillWidth: true
                                spacing: 8
                                Layout.topMargin: 20

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.player?.trackArtist || Translation.tr("Unknown Artist")
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.huge
                                    font.family: Appearance.font.family.title
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    font.variableAxes: ({
                                            "ROND": 75
                                        })
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.player?.trackTitle || Translation.tr("Unknown Title")
                                    font.pixelSize: Appearance.font.pixelSize.hugeass * 1.5
                                    font.weight: Font.Bold
                                    font.family: Appearance.font.family.title
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    horizontalAlignment: Text.AlignHCenter
                                    font.variableAxes: ({
                                            "ROND": 75
                                        })
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: -120
                            anchors.rightMargin: 120
                            anchors.topMargin: 40
                            anchors.bottomMargin: 40

                            LrclibLyrics {
                                id: lrclibLyrics
                                enabled: (root.player?.trackTitle?.length > 0) && (root.player?.trackArtist?.length > 0)
                                title: root.player?.trackTitle ?? ""
                                artist: root.player?.trackArtist ?? ""
                                duration: root.player?.length ?? 0
                                position: root.player?.position ?? 0
                                selectedId: 0
                            }

                            Timer {
                                running: root.player?.playbackState == MprisPlaybackState.Playing && lyricScroller.hasSyncedLines
                                interval: 250
                                repeat: true
                                onTriggered: root.player.positionChanged()
                            }

                            LyricScroller {
                                id: lyricScroller
                            }
                        }
                    }
                }
            }
        }
    }

    component LyricScroller: Item {
        anchors.fill: parent
        clip: true

        readonly property bool hasSyncedLines: visible ? lrclibLyrics.lines.length > 0 : false
        readonly property int rowHeight: Math.max(30, Math.min(Math.floor(height / 5), Appearance.font.pixelSize.hugeass * 3))
        readonly property real baseY: (height - rowHeight) / 2
        readonly property real downScale: 0.85

        property int halfVisibleLines: 3
        property int visibleLineCount: halfVisibleLines * 2 + 1

        readonly property int targetCurrentIndex: hasSyncedLines ? lrclibLyrics.currentIndex : -1

        property int lastIndex: -1
        property bool isMovingForward: true
        property real scrollOffset: 0

        readonly property real animProgress: Math.abs(scrollOffset) / rowHeight

        onTargetCurrentIndexChanged: {
            if (targetCurrentIndex !== lastIndex) {
                isMovingForward = targetCurrentIndex > lastIndex;
                lastIndex = targetCurrentIndex;
                scrollAnimation.stop();
                lyricScroller.scrollOffset = lyricScroller.isMovingForward ? -lyricScroller.rowHeight : lyricScroller.rowHeight;
                scrollAnimation.start();
            }
        }

        NumberAnimation {
            id: scrollAnimation
            target: lyricScroller
            property: "scrollOffset"
            to: 0
            duration: 400
            easing.type: Easing.OutQuart
        }

        Column {
            width: parent.width
            spacing: 0
            y: lyricScroller.baseY - (lyricScroller.halfVisibleLines * lyricScroller.rowHeight) - lyricScroller.scrollOffset

            Repeater {
                model: lyricScroller.visibleLineCount

                LyricLine {
                    required property int index
                    property int lineOffset: index - lyricScroller.halfVisibleLines
                    property int actualIndex: lyricScroller.targetCurrentIndex + lineOffset
                    property bool isValidLine: lyricScroller.hasSyncedLines && actualIndex >= 0 && actualIndex < lrclibLyrics.lines.length

                    text: isValidLine ? lrclibLyrics.lines[actualIndex].text : (lineOffset === 0 && lyricScroller.targetCurrentIndex === -1 ? (lrclibLyrics.displayText || "♪") : "")

                    // The old line offset maps where this visual line was logically positioned in the previous state.
                    property int oldLineOffset: lyricScroller.isMovingForward ? lineOffset + 1 : lineOffset - 1

                    // Highlight animation
                    property real targetHighlight: Math.abs(lineOffset) === 0 ? 1.0 : 0.0
                    property real startHighlight: Math.abs(oldLineOffset) === 0 ? 1.0 : 0.0
                    property real highlightFactor: startHighlight + (targetHighlight - startHighlight) * (1.0 - lyricScroller.animProgress)

                    highlight: highlightFactor > 0.5

                    // Opacity animation
                    function getOpacityForOffset(offset) {
                        let dist = Math.abs(offset);
                        if (dist === 0)
                            return 1.0;
                        if (dist === 1)
                            return 0.5;
                        if (dist === 2)
                            return 0.2;
                        return 0.0;
                    }
                    property real targetOpacity: getOpacityForOffset(lineOffset)
                    property real startOpacity: getOpacityForOffset(oldLineOffset)
                    opacity: startOpacity + (targetOpacity - startOpacity) * (1.0 - lyricScroller.animProgress)

                    // Scale animation
                    function getScaleForOffset(offset) {
                        return Math.abs(offset) === 0 ? 1.0 : lyricScroller.downScale;
                    }
                    property real targetScale: getScaleForOffset(lineOffset)
                    property real startScale: getScaleForOffset(oldLineOffset)
                    scale: startScale + (targetScale - startScale) * (1.0 - lyricScroller.animProgress)

                    useGradient: highlightFactor <= 0.5
                    gradientDirection: lineOffset < 0 ? "top" : "bottom"
                }
            }
        }
    }

    component LyricLine: Item {
        id: lyricLineItem
        required property string text
        property bool highlight: false
        property bool useGradient: false
        property string gradientDirection: "top"
        property bool reallyUseGradient: useGradient

        property real defaultLyricsSize: Appearance.font.pixelSize.hugeass * 1.5

        width: parent.width
        height: lyricScroller.rowHeight
        transformOrigin: Item.Left

        // Expose defaultLyricsSize properly
        property real currentLyricsSize: defaultLyricsSize

        StyledText {
            id: lyricText
            anchors.fill: parent
            text: lyricLineItem.text
            color: lyricLineItem.highlight ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
            font.pixelSize: lyricLineItem.currentLyricsSize * (lyricLineItem.highlight ? 1.2 : 1.0)
            font.weight: lyricLineItem.highlight ? Font.Bold : Font.Medium
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !lyricLineItem.reallyUseGradient
            wrapMode: Text.Wrap
            maximumLineCount: 2
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
                            color: lyricLineItem.gradientDirection === "top" ? "transparent" : "black"
                        }
                        GradientStop {
                            position: 1.0
                            color: lyricLineItem.gradientDirection === "top" ? "black" : "transparent"
                        }
                    }
                }
            }

            StyledText {
                anchors.fill: parent
                text: lyricLineItem.text
                color: Appearance.colors.colSubtext
                font.pixelSize: lyricLineItem.currentLyricsSize
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
    }
}
