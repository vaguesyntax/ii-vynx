import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts

Item {
    id: root

    readonly property bool verticalStyle: Config.options?.bar?.date?.vertical ?? true
    readonly property string dateFormat: Config.options?.bar?.date?.format ?? "dd/MM"
    readonly property bool monthFirst: dateFormat.trim().startsWith("MM")
    readonly property string dayOfMonth: Qt.locale().toString(DateTime.clock.date, "dd")
    readonly property string monthOfYear: Qt.locale().toString(DateTime.clock.date, "MM")
    readonly property string formattedDate: Qt.locale().toString(DateTime.clock.date, dateFormat)

    implicitHeight: verticalStyle ? verticalContent.implicitHeight : Appearance.sizes.barHeight
    implicitWidth: verticalStyle ? Appearance.sizes.verticalBarWidth : horizontalContent.implicitWidth + horizontalContent.spacing * 8

    Item {
        id: verticalContent
        visible: root.verticalStyle
        anchors.centerIn: parent
        implicitWidth: 24
        implicitHeight: 30

        Shape {
            id: diagonalLine
            property real padding: 4
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 1.2
                strokeColor: Appearance.colors.colSubtext
                fillColor: "transparent"
                startX: verticalContent.width - diagonalLine.padding
                startY: diagonalLine.padding
                PathLine {
                    x: diagonalLine.padding
                    y: verticalContent.height - diagonalLine.padding
                }
            }
        }

        StyledText {
            anchors {
                top: parent.top
                left: parent.left
            }
            font.pixelSize: 13
            color: Appearance.colors.colOnLayer1
            text: root.monthFirst ? root.monthOfYear : root.dayOfMonth
        }

        StyledText {
            anchors {
                bottom: parent.bottom
                right: parent.right
            }
            font.pixelSize: 13
            color: Appearance.colors.colOnLayer1
            text: root.monthFirst ? root.dayOfMonth : root.monthOfYear
        }
    }

    RowLayout {
        id: horizontalContent
        visible: !root.verticalStyle
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
            text: root.formattedDate
        }
    }
}
