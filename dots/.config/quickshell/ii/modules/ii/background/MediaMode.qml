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
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // MediaMode instance
    id: root

    property MprisPlayer player: MprisController.activePlayer
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: colorQuantizer.colors[0] ?? "#31313131"
    property bool downloaded: false
    property string displayedArtFilePath: ""

    function updateArt() {
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer;
            root.displayedArtFilePath = "";
            return;
        }

        updateArt();
    }

    property bool canChangeColor: true

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
    
    property string geniusLyricsString: LyricsService.geniusLyrics


    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing

        onColorsChanged: {
            if (!Config.options.background.mediaMode.changeShellColor) return;
            if (!root.canChangeColor) {
                console.log("[Media Mode] Color change delayed, pending color:", colorQuantizer.colors[0])
                switchColorDelayTimer.pendingColor = colorQuantizer.colors[0]
                switchColorDelayTimer.restart()
                return;
            }
            else {
                switchColorProc.colorString = colorQuantizer.colors[0] 
                Qt.callLater(() => {
                    switchColorProc.running = true
                    root.canChangeColor = false
                    switchColorDelayTimer.restart()
                })
            }
            

        }
    }

    Timer {
        id: switchColorDelayTimer
        interval: 2500
        property string pendingColor: ""
        onTriggered: {
            if (pendingColor == "") root.canChangeColor = true 
            else {
                console.log("[Media Mode] Delay timer triggered, pending color:", pendingColor)
                switchColorProc.colorString = pendingColor
                Qt.callLater(() => {
                    switchColorProc.running = true
                    root.canChangeColor = false
                    switchColorDelayTimer.restart()
                })
                pendingColor = ""
            }
            
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

                    transform: [
                        Scale {
                            id: floatScale
                            origin.x: blurredArt.width / 2
                            origin.y: blurredArt.height / 2
                            xScale: 1.15
                            yScale: 1.15
                        },
                        Translate {
                            id: floatTranslate
                            x: 0
                            y: 0
                        }
                    ]

                    SequentialAnimation {
                        running: Config.options.background.mediaMode.enableBackgroundAnimation
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: floatTranslate
                            property: "x"
                            from: -50
                            to: 30
                            duration: 16500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "x"
                            from: 30
                            to: -20
                            duration: 11500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "x"
                            from: -20
                            to: 50
                            duration: 19500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "x"
                            from: 50
                            to: -50
                            duration: 14500
                            easing.type: Easing.InOutSine
                        }
                    }

                    SequentialAnimation {
                        running: Config.options.background.mediaMode.enableBackgroundAnimation
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: floatTranslate
                            property: "y"
                            from: 20
                            to: -50
                            duration: 20000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "y"
                            from: -50
                            to: 30
                            duration: 14000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "y"
                            from: 30
                            to: -30
                            duration: 19000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            target: floatTranslate
                            property: "y"
                            from: -30
                            to: 20
                            duration: 14500
                            easing.type: Easing.InOutSine
                        }
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
                            
                            StyledRectangularShadow {
                                target: artBackground
                            }
                            

                            Rectangle { // Art background
                                id: artBackground
                                Layout.preferredWidth: 400
                                Layout.preferredHeight: 400
                                Layout.alignment: Qt.AlignHCenter
                                radius: Appearance.rounding.large
                                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: artBackground.width
                                        height: artBackground.height
                                        radius: artBackground.radius
                                    }
                                }

                                MouseArea {
                                    id: artMouseArea
                                    z: 10
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.MiddleButton
                                    onClicked: {
                                        root.displayedArtFilePath = "" // Force
                                        root.updateArt()
                                    }
                                    onEntered: musicControls.opacity = 1
                                    onExited: musicControls.opacity = 0

                                    MaterialMusicControls {
                                        id: musicControls

                                        opacity: 0
                                        Behavior on opacity {
                                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                        }
                                        
                                        player: root.player
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 20
                                        Layout.preferredWidth: parent.width
                                        Layout.preferredHeight: parent.height / 3
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

                            Timer {
                                running: root.player?.playbackState == MprisPlaybackState.Playing && lyricScroller.hasSyncedLines
                                interval: 250
                                repeat: true
                                onTriggered: root.player.positionChanged()
                            }

                            MaterialLoadingIndicator {
                                anchors.left: parent.left
                                anchors.leftMargin: 250
                                anchors.verticalCenter: parent.verticalCenter
                                loading: geniusFlickable.opacity == 0 && !lyricScroller.hasSyncedLines
                                visible: loading
                                implicitSize: 96
                            }

                            Flickable {
                                id: geniusFlickable
                                anchors.fill: parent
                                
                                opacity: !lyricScroller.hasSyncedLines && LyricsService.geniusHasLyrics ? 1 : 0
                                Behavior on opacity {
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }
                                

                                clip: true
                                contentHeight: geniusText.implicitHeight
                                interactive: true

                                property real userOffset: 0
                                property bool isSyncing: true

                                readonly property real rawTargetY: {
                                    var lines = root.geniusLyricsString.split('\n')
                                    var totalLines = lines.length
                                    
                                    var currentLineIndex = (root.player.position / root.player.length) * totalLines
                                    
                                    var averageLineHeight = contentHeight / totalLines
                                    var targetY = (currentLineIndex * averageLineHeight)
                                    
                                    return Math.max(0, targetY - (geniusFlickable.height / 2))
                                }

                                onMovementEnded: {
                                    userOffset = contentY - rawTargetY
                                    isSyncing = true 
                                }

                                onMovementStarted: isSyncing = false

                                onRawTargetYChanged: {
                                    if (isSyncing && !dragging && !flicking) {
                                        contentY = Math.min(contentHeight - height, rawTargetY + userOffset)
                                    }
                                }

                                Behavior on contentY {
                                    enabled: geniusFlickable.isSyncing
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }

                                layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: geniusFlickable.width
                                            height: geniusFlickable.height
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.3; color: "black" }
                                                GradientStop { position: 0.7; color: "black" }
                                                GradientStop { position: 1.0; color: "transparent" }
                                            }
                                        }
                                    }


                                StyledText {
                                    id: geniusText
                                    width: parent.width
                                    text: root.geniusLyricsString
                                    color: Appearance.colors.colOnLayer0
                                    font.pixelSize: Appearance.font.pixelSize.hugeass * 1.2
                                    font.weight: Font.Medium
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignTop
                                    lineHeight: 1.6
                                }
                            }


                            LyricScroller {
                                id: lyricScroller
                                anchors.fill: parent
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
        visible: LyricsService.syncedLines.length > 0

        readonly property bool hasSyncedLines: LyricsService.syncedLines.length > 0
        readonly property int rowHeight: Math.max(30, Math.min(Math.floor(height / 5), Appearance.font.pixelSize.hugeass * 3))
        readonly property real baseY: (height - rowHeight) / 2
        readonly property real downScale: 0.85

        property int halfVisibleLines: 3
        property int visibleLineCount: halfVisibleLines * 2 + 1

        readonly property int targetCurrentIndex: hasSyncedLines ? LyricsService.currentIndex : -1

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
                    property bool isValidLine: lyricScroller.hasSyncedLines && actualIndex >= 0 && actualIndex < LyricsService.syncedLines.length

                    text: isValidLine ? LyricsService.syncedLines[actualIndex].text : (lineOffset === 0 && lyricScroller.targetCurrentIndex === -1 ? (LyricsService.statusText || "♪") : "")

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
