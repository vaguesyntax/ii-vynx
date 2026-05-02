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
        spacing: 15

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                text: "devices"
                iconSize: 28
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: "LocalSend"
                font.pixelSize: Appearance.font.pixelSize.enormous
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
            }

            Item { Layout.fillWidth: true }

            // Server toggle
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

        // Server status
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statusRow.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: statusRow
                anchors.centerIn: parent
                spacing: 10

                MaterialSymbol {
                    text: LocalSend.serverRunning ? "check_circle" : "cancel"
                    iconSize: 20
                    color: LocalSend.serverRunning ? "#4CAF50" : "#F44336"
                }

                StyledText {
                    text: LocalSend.serverRunning ? "Sunucu çalışıyor" : "Sunucu durdu"
                    color: Appearance.colors.colOnLayer2
                    font.pixelSize: Appearance.font.pixelSize.large
                }
            }
        }

        // Current transfer
        Loader {
            Layout.fillWidth: true
            active: LocalSend.currentTransfer !== null
            Layout.preferredHeight: active ? implicitHeight : 0

            sourceComponent: Rectangle {
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                border.color: Appearance.colors.colLayer3
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

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
                    }

                    Repeater {
                        model: LocalSend.currentTransfer?.files || []
                        delegate: RowLayout {
                            spacing: 8
                            MaterialSymbol {
                                text: "description"
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: modelData.name + " (" + (modelData.size < 1024 ? modelData.size + " B" : modelData.size < 1024*1024 ? (modelData.size/1024).toFixed(1) + " KB" : (modelData.size/(1024*1024)).toFixed(1) + " MB") + ")"
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.normal
                            }
                        }
                    }
                }
            }
        }

        // Transfer history
        StyledText {
            Layout.topMargin: 10
            text: "Son Transferler"
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Bold
            color: Appearance.colors.colOnLayer1
            visible: LocalSend.transferHistory.length > 0
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: LocalSend.transferHistory.length > 0
            clip: true

            ListView {
                model: LocalSend.transferHistory
                spacing: 8

                delegate: Rectangle {
                    width: ListView.view.width
                    height: delegateLayout.implicitHeight + 20
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: delegateLayout
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        MaterialSymbol {
                            text: modelData.text !== undefined ? "text_snippet" : "file_present"
                            iconSize: 20
                            color: Appearance.colors.colSubtext
                        }

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true

                            StyledText {
                                text: modelData.fileName || modelData.text || "Transfer"
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.normal
                                elide: Text.ElideMiddle
                            }

                            StyledText {
                                text: modelData.sender || ""
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }

                        StyledText {
                            text: Qt.formatDateTime(new Date(modelData.timestamp), "HH:mm")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }

        // Empty state
        Item {
            Layout.fillHeight: true
            visible: LocalSend.transferHistory.length === 0 && LocalSend.currentTransfer === null
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: LocalSend.transferHistory.length === 0 && LocalSend.currentTransfer === null
            text: "Henüz transfer yapılmadı"
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }
    }
}
