import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick

// Variables are being auto cascaded, so this widget cannot be used anywhere else than MediaMode.qml (for now)

Item {
    id: coverArt

    property string backgroundShapeString: Config.options.background.mediaMode.backgroundShape
    
    // We add a little delay to showing the loading indicator in order to avoid showing it on every track change for a split second
    property bool showLoadingIndicator: false
    property bool effectiveShowLoadingIndicator: false
    onShowLoadingIndicatorChanged: {
        if (coverArt.showLoadingIndicator) {
            loadingIndTimer.restart()   
        } else {
            loadingIndTimer.stop() 
            coverArt.effectiveShowLoadingIndicator = false
        }
    }
    Timer {
        id: loadingIndTimer
        interval: 200
        repeat: false
        running: false
        onTriggered: {
            coverArt.effectiveShowLoadingIndicator = true
        }
    }

    ColumnLayout {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width

        StyledDropShadow {
            target: artBackgroundLoader
        }
        
        Loader {
            id: artBackgroundLoader
            Layout.preferredWidth: 400
            Layout.preferredHeight: 400
            Layout.alignment: Qt.AlignHCenter
            active: true // we have to use a loader (or a wrapper object) in order to achieve a drop shadow
            sourceComponent: MaterialShape { // Art background
                id: artBackground
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.5)
                shapeString: coverArt.backgroundShapeString

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: MaterialShape {
                        width: artBackground.width
                        shapeString: coverArt.backgroundShapeString
                        height: artBackground.height
                    }
                }

                TransitionImage { // Art image
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent

                    imageSource: root.displayedArtFilePath

                    width: size
                    height: size
                }

                FadeLoader {
                    shown: coverArt.effectiveShowLoadingIndicator
                    anchors.centerIn: parent
                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        loading: true
                        visible: loading
                        implicitSize: 96
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

                    FadeLoader {
                        anchors.fill: parent
                        shown: artMouseArea.containsMouse
                        sourceComponent: MusicControlLayout {}
                    }

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

    component MusicControlLayout: ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 10

        Item {
            Layout.fillHeight: true
        }

        MaterialMusicControls {
            id: musicControls
            
            baseButtonHeight: 60
            baseButtonWidth: 60
            player: root.player
            
            Layout.alignment: Qt.AlignCenter
            Layout.fillHeight: false
            Layout.preferredHeight: baseButtonHeight
            Layout.topMargin: layout.spacing * 2 
        }

        StyledSlider { 
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            Layout.fillWidth: false
            Layout.preferredWidth: parent.implicitWidth

            configuration: StyledSlider.Configuration.Wavy
            highlightColor: Appearance.colors.colPrimary
            trackColor: Appearance.colors.colSecondaryContainer
            handleColor: Appearance.colors.colPrimary
            value: root.player?.position / root.player?.length
            onMoved: {
                root.player.position = value * root.player.length;
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}