import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

Item {
    id: root
    property real padding: 10

    Component.onCompleted: {
        if (LocalSend.localSendEnabled && LocalSend.autoStart && !LocalSend.serverRunning) {
            LocalSend.startServer()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 8

        // 1. TOP: Server Status + Toggle
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: headerRow.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: headerRow
                anchors.centerIn: parent
                spacing: 10

                MaterialSymbol {
                    text: "devices"
                    iconSize: 28
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: "LocalSend Server"
                    font.pixelSize: Appearance.font.pixelSize.enormous
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    id: toggleBtn
                    buttonRadius: Appearance.rounding.normal
                    colBackground: LocalSend.serverRunning ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                    onClicked: {
                        if (LocalSend.serverRunning) {
                            LocalSend.stopServer()
                        } else {
                            LocalSend.startServer()
                        }
                    }

                    contentItem: RowLayout {
                        spacing: 6
                        anchors.centerIn: parent
                        MaterialSymbol {
                            text: LocalSend.serverRunning ? "stop_circle" : "play_circle"
                            iconSize: 18
                            color: LocalSend.serverRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                        }
                        StyledText {
                            text: LocalSend.serverRunning ? "Durdur" : "Başlat"
                            color: LocalSend.serverRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                            font.pixelSize: Appearance.font.pixelSize.normal
                        }
                    }
                }
            }
        }

        // 2. MIDDLE (350px): Incoming Transfers
        Rectangle {
            id: incomingContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 350
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.color: Appearance.colors.colLayer3
            border.width: LocalSend.currentTransfer !== null ? 1 : 0

            // Empty state (shown when no active transfer)
            StyledText {
                anchors.centerIn: parent
                visible: LocalSend.currentTransfer === null
                text: "Henüz transfer yapılmadı"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            // Active transfer details
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                visible: LocalSend.currentTransfer !== null

                StyledText {
                    text: "Bekleyen Transfer"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer2
                }

                StyledText {
                    text: "Gönderen: " + (LocalSend.currentTransfer?.sender || "Unknown")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.normal
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        model: LocalSend.currentTransfer?.files || []
                        spacing: 8

                        delegate: RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                text: "description"
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    var size = modelData.size || 0;
                                    var sizeStr = size + " B";
                                    if (size >= 1024 && size < 1024 * 1024) {
                                        sizeStr = (size / 1024).toFixed(1) + " KB";
                                    } else if (size >= 1024 * 1024) {
                                        sizeStr = (size / (1024 * 1024)).toFixed(1) + " MB";
                                    }
                                    return modelData.name + " (" + sizeStr + ")";
                                }
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.topMargin: 10
                    spacing: 10

                    RippleButton {
                        Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.normal
                        colBackground: Appearance.colors.colPrimary
                        onClicked: LocalSend.acceptTransfer()

                        contentItem: RowLayout {
                            spacing: 6
                            anchors.centerIn: parent
                            MaterialSymbol {
                                text: "check_circle"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                text: "Kabul Et"
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        buttonRadius: Appearance.rounding.normal
                        colBackground: "#F44336"
                        onClicked: LocalSend.denyTransfer()

                        contentItem: RowLayout {
                            spacing: 6
                            anchors.centerIn: parent
                            MaterialSymbol {
                                text: "cancel"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                text: "Reddet"
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }
                }
            }
        }
    }
}
