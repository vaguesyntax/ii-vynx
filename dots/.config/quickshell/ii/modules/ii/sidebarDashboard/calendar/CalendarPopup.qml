import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets


Rectangle {
    id: dayPopRect

    width: 200
    height: Math.min(columnLayout.implicitHeight + 2 * taskMargin, 1000)
    color: Appearance.m3colors.m3surfaceContainer
    radius: Appearance.rounding.normal + 4
    border.width: 2
    border.color: Appearance.colors.colLayer3

    StyledFlickable {
        id: styledFlicker

        contentWidth: parent.width
        contentHeight: columnLayout.implicitHeight

        ColumnLayout {
            id: columnLayout

            width: parent.width - 2 * taskMargin
            height: parent.height - 2 * taskMargin
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: ScriptModel {
                    values: taskList.slice(0, 6) // limiting the elements
                }

                delegate: Item {
                    width: parent.width
                    implicitHeight: contentColumn.implicitHeight

                    ColumnLayout {
                        id: contentColumn

                        width: parent.width
                        spacing: 0
                        Layout.margins: 10
                        
                        RowLayout {
                            Layout.fillWidth: true

                            StyledText {
                                Layout.fillWidth: true // Needed for wrapping
                                Layout.leftMargin: 10
                                Layout.rightMargin: 10
                                Layout.topMargin: 4
                                text: modelData.content
                                elide: Text.ElideRight
                            }

                            Rectangle { // color indicator
                                Layout.rightMargin: 10
                                width: 12
                                height: 12
                                radius: 6
                                color:  modelData.color
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true // Needed for wrapping
                            Layout.leftMargin: 10
                            Layout.rightMargin: 10
                                        
                            text: Qt.formatDateTime(modelData.startDate,  Config.options.time.format) + " - " + Qt.formatDateTime(modelData.endDate,  Config.options.time.format)
                            color: Appearance.m3colors.m3outline
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }   
    }
}
