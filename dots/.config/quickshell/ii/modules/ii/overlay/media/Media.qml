pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.services

import qs.modules.common
import qs.modules.common.widgets

import qs.modules.ii.mediaControls
import qs.modules.ii.overlay

import Qt5Compat.GraphicalEffects

StyledOverlayWidget {
    id: root
    minimumWidth: 400
    minimumHeight: 400

    
    readonly property MprisPlayer currentPlayer: MprisController.activePlayer
    
    property bool downloaded: false
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`


    onArtFilePathChanged: updateArt()

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

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8

            // Top region for lyricss
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.88

                Rectangle {
                    anchors.fill: parent
                    color: "red"
                    opacity: 0.1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.12
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
                    Layout.fillWidth: false

                    StyledText {
                        id: mediaActor
                        text: root.currentPlayer?.trackArtist || Translation.tr("Unknown Artist")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: mediaTitle
                        Layout.maximumWidth: 180
                        text: root.currentPlayer?.trackTitle || Translation.tr("Unknown Title")
                        font.pixelSize: Appearance.font.pixelSize.large
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                ButtonGroup {
                    Layout.preferredHeight: parent.height / 1.2
                    //Layout.preferredWidth: 90

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
}