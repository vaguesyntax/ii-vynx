import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.services
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    signal requestReset()

    configEntryName: "media"

    readonly property bool useAlbumColors: Config.options.background.widgets.media.useAlbumColors
    readonly property bool useDynamicColors: root.useAlbumColors && root.currentPlayer != null 
    readonly property bool showPreviousToggle: Config.options.background.widgets.media.showPreviousToggle
    readonly property bool hideAllButtons: Config.options.background.widgets.media.hideAllButtons
    readonly property bool showRestButtons: hideAllButtons ? hovering : true

    readonly property var playerList: MprisController.players

    // not using for now, but could be useful in the future 
    property var filteredPlayerList: playerList.filter(player => player != null && player.trackAlbum != "")
    
    property MprisPlayer currentPlayer : MprisController.activePlayer
    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    property real widgetSize: 200
    property real controlsSize: 55
    property real buttonIconSize: 30
    property bool showSwitchButton: false

    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }
    property var dynamicColors: {
        return {
            colPrimary: root.useDynamicColors                  ?  blendedColors.colPrimary                  : Appearance.colors.colPrimary,
            colPrimaryBackground: root.useDynamicColors        ?  blendedColors.colPrimaryContainer         : Appearance.colors.colPrimaryContainer,
            colPrimaryBackgroundHover: root.useDynamicColors   ?  blendedColors.colPrimaryContainerHover    : Appearance.colors.colPrimaryContainerHover,
            colPrimaryRipple: root.useDynamicColors            ?  blendedColors.colPrimaryContainerActive   : Appearance.colors.colPrimaryContainerActive,

            colSecondary: root.useDynamicColors                ?  blendedColors.colSecondary                : Appearance.colors.colSecondary,
            colSecondaryBackground: root.useDynamicColors      ?  blendedColors.colSecondaryContainer       : Appearance.colors.colSecondaryContainer,
            colSecondaryBackgroundHover: root.useDynamicColors ?  blendedColors.colSecondaryContainerHover  : Appearance.colors.colSecondaryContainerHover,
            colSecondaryRipple: root.useDynamicColors          ?  blendedColors.colSecondaryContainerActive : Appearance.colors.colSecondaryContainerActive,

            colTertiary: root.useDynamicColors                 ? blendedColors.colTertiary                  : Appearance.colors.colTertiary,
            colTertiaryBackground: root.useDynamicColors       ? blendedColors.colTertiaryContainer         : Appearance.colors.colTertiaryContainer,
            colTertiaryBackgroundHover: root.useDynamicColors  ? blendedColors.colTertiaryContainerHover    : Appearance.colors.colTertiaryContainerHover,
            colTertiaryRipple: root.useDynamicColors           ? blendedColors.colTertiaryContainerActive   : Appearance.colors.colTertiaryContainerActive
            
        }
    }

    property bool downloaded: false
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    property list<real> visualizerPoints: [] 

    implicitHeight: contentItem.implicitHeight
    implicitWidth: contentItem.implicitWidth

    // 'Switch button' visiblity on hover
    property bool hovering: false
    hoverEnabled: true
    onEntered: {
        hovering = true
    }
    onExited: {
        hovering = false
    }
        
    allowMiddleClick: true
    onClicked: (event) => {
        if (event.button === Qt.MiddleButton) {
            root.requestReset()
        }
    }

    onArtFilePathChanged: updateArt()

    function nextPlayer() {
        root.currentPlayer = root.playerList[(root.playerList.indexOf(root.currentPlayer) + 1) % root.playerList.length]
    }

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

    Process {
        id: cavaProc
        running: Config.options.background.widgets.media.visualizer.enable
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
    }

    Item {
        id: contentItem

        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

    
        Image { // using a loader somehow breaks the image
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: contentItem.implicitWidth
            sourceSize.height: sourceSize.width
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            opacity: Config.options.background.widgets.media.glow.enable ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            
            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
                brightness: 0.002 * Config.options.background.widgets.media.glow.brightness
            }
        }
        
        FadeLoader {
            id: loopButtonLoader
            anchors {
                right: parent.right
                bottom: parent.bottom
            }
            z: 3
            shown: root.hovering
            sourceComponent: ControlButton {
                colBackground: root.dynamicColors.colPrimaryBackground
                colBackgroundHover: root.dynamicColors.colPrimaryBackgroundHover
                colRipple: root.dynamicColors.colPrimaryRipple
                symbolColor: root.dynamicColors.colSecondary
                symbolText: "360"
                onClicked: {
                    root.nextPlayer()
                }
            }
        }

        FadeLoader {
            z: 2
            anchors.centerIn: parent
            shown: root.currentPlayer == null
            sourceComponent: MaterialShapeWrappedMaterialSymbol {
                fill: 1
                padding: 20
                text: root.currentPlayer == null ? "music_off" : !root.downloaded ? "hourglass_bottom" : ""
                anchors.centerIn: parent
                iconSize: root.widgetSize / 4
                shape: MaterialShape.Shape.Cookie12Sided
                color: blendedColors.colOnSecondaryContainer
                colSymbol: Appearance.colors.colPrimaryContainer
            }
        }
        
        MaterialShape { // Art background
            id: artBackground
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shapeString: Config.options.background.widgets.media.backgroundShape
            
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: MaterialShape {
                    width: artBackground.width
                    shapeString: Config.options.background.widgets.media.backgroundShape
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

            FadeLoader {
                shown: Config.options.background.widgets.media.tintArtCover
                anchors.fill: mediaArt
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false // There's already color overlay
                        anchors.fill: parent
                        source: mediaArt
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimary, 0.9)
                    }
                }
            
            }

            RadialWaveVisualizer {
                z: 1
                id: visualizer
                anchors.fill: parent
                points: root.visualizerPoints
                live: root.currentPlayer?.isPlaying ?? false
                color: root.dynamicColors.colSecondaryBackground
                waveOpacity: Config.options.background.widgets.media.visualizer.opacity
                waveBlur: Config.options.background.widgets.media.visualizer.blur
                smoothing: Config.options.background.widgets.media.visualizer.smoothing
            }
        }

        FadeLoader {
            shown: root.showRestButtons
            anchors {
                left: parent.left
                bottom: parent.bottom
            }
            sourceComponent: ControlButton {
                id: playButton
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                }
                buttonRadius: root.currentPlayer?.isPlaying ? Appearance.rounding.normal : controlsSize / 2
                colBackground: root.dynamicColors.colSecondaryBackground
                colBackgroundHover: root.dynamicColors.colSecondaryBackgroundHover
                colRipple: root.dynamicColors.colSecondaryRipple
                symbolText: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                symbolColor: useAlbumColors ?  blendedColors.colTertiary : Appearance.colors.colTertiary
                onClicked: {
                    root.currentPlayer.togglePlaying()
                }
            }
        }
        

        Loader {
            active: root.showRestButtons
            anchors {
                top: parent.top
                right: parent.right
            }
            sourceComponent: Rectangle {
                anchors {
                    top: parent.top
                    right: parent.right
                }
                implicitWidth: root.showPreviousToggle ? controlsSize * 2 : controlsSize
                implicitHeight: controlsSize
                z: 2
                radius: Appearance.rounding.full
                color: dynamicColors.colTertiaryBackground

                Behavior on implicitWidth {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }

                FadeLoader {
                    shown: root.showPreviousToggle
                    sourceComponent: ControlButton {
                        anchors.left: parent.left
                        colBackground: root.dynamicColors.colTertiaryBackground
                        colBackgroundHover: root.dynamicColors.colTertiaryBackgroundHover
                        colRipple: root.dynamicColors.colTertiaryRipple
                        symbolColor: root.dynamicColors.colSecondary
                        symbolText: "skip_previous"
                        onClicked: {
                            currentPlayer.previous()
                        }
                    }
                }

                ControlButton {
                    anchors.right: parent.right 

                    colBackground: root.dynamicColors.colTertiaryBackground
                    colBackgroundHover: root.dynamicColors.colTertiaryBackgroundHover
                    colRipple: root.dynamicColors.colTertiaryRipple
                    symbolColor: root.dynamicColors.colSecondary
                    symbolText: "skip_next"
                    onClicked: {
                        currentPlayer.next()
                    }
                }

            }
        }
        
    }

    component ControlButton : RippleButton {
        id: button
        property string symbolText
        property color symbolColor
        
        z: 2
        implicitWidth: controlsSize
        implicitHeight: implicitWidth
        buttonRadius: Appearance.rounding.full

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: root.buttonIconSize
            text: button.symbolText
            fill: 1
            color: button.symbolColor
        }
    }
}