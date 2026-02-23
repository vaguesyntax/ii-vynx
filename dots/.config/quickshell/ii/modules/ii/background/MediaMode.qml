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

        // We have to delay the color change if the media changes too quickly...
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
                            
                            // TODO: we have to add a drop shadow to cover art but it doesnt work somehow?
                            MaterialShape { // Art background
                                id: artBackground
                                Layout.preferredWidth: 400
                                Layout.preferredHeight: 400
                                Layout.alignment: Qt.AlignHCenter
                                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)
                                shapeString: Config.options.background.mediaMode.backgroundShape

                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: MaterialShape {
                                        width: artBackground.width
                                        shapeString: Config.options.background.mediaMode.backgroundShape
                                        height: artBackground.height
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

                            // Genius lyrics
                            LyricsFlickable {
                                anchors.fill: parent
                                player: root.player
                            }

                            // Lrclib (synced) lyrics
                            LyricScroller {
                                id: lyricScroller
                                anchors.fill: parent
                                defaultLyricsSize: Appearance.font.pixelSize.hugeass * 1.5
                                textAlign: "left"
                                changeTextWeight: true
                            }
                        }

                    }
                }
            }
        }
    }
}
