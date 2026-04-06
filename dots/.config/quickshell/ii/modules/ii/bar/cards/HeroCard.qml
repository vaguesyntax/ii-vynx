import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: heroCardRoot

    Layout.fillWidth: true
    Layout.minimumWidth: 320
    implicitWidth: heroRow.implicitWidth + margins * 2
    implicitHeight: heroRow.implicitHeight + margins * 2

    radius: Appearance.rounding.normal
    color: Appearance.colors.colPrimaryContainer

    property int margins: 24
    property int iconSize: 110
    property real iconFontSize: 48
    
    property string shapeString: "Cookie9Sided"
    property string icon: ""
    
    property string title: ""
    property string subtitle: ""

    property string pillText: ""
    property string pillIcon: ""

    property color shapeColor: Appearance.colors.colPrimary
    property color symbolColor: Appearance.colors.colOnPrimary
    property color textColor: Appearance.colors.colOnPrimaryContainer

    default property alias content: contentColumn.children
    property alias shapeContent: shapeItem.data

    RowLayout {
        id: heroRow
        anchors.fill: parent
        anchors.margins: heroCardRoot.margins
        spacing: 20

        MaterialShape {
            id: shapeItem
            shapeString: heroCardRoot.shapeString
            implicitSize: heroCardRoot.iconSize
            color: heroCardRoot.shapeColor

            MaterialSymbol {
                id: iconSymbol
                visible: heroCardRoot.icon !== "" && shapeItem.children.length <= 1
                anchors.centerIn: parent
                text: heroCardRoot.icon
                iconSize: heroCardRoot.iconFontSize
                color: heroCardRoot.symbolColor
            }
        }

        Item {
            Layout.fillWidth: true
        }

        ColumnLayout {
            id: contentColumn
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: true
            
            Rectangle {
                visible: heroCardRoot.city !== "" && heroCardRoot.pillIcon !== ""
                Layout.alignment: Qt.AlignRight
                implicitHeight: cityRow.implicitHeight + 12
                implicitWidth: cityRow.implicitWidth + 20
                radius: 100
                color: Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: cityRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: heroCardRoot.pillIcon
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: heroCardRoot.pillText
                        font {
                            weight: Font.Bold
                            pixelSize: Appearance.font.pixelSize.small
                        }
                        color: Appearance.colors.colOnSecondaryContainer
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                    }
                }
            }

            StyledText {
                text: heroCardRoot.title
                font.pixelSize: Appearance.font.pixelSize.hugeass * 2.5
                font.family: Appearance.font.family.title
                font.weight: Font.Black
                color: heroCardRoot.textColor
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            StyledText {
                text: heroCardRoot.subtitle
                font {
                    pixelSize: Appearance.font.pixelSize.hugeass
                    family: Appearance.font.family.title
                    weight: Font.Black
                }
                color: heroCardRoot.textColor
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}
