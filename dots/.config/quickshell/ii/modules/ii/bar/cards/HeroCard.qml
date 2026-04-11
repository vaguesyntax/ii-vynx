import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: heroCardRoot

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    implicitWidth: 380  // fixed sizes to keep consistency
    implicitHeight: 180

    radius: Appearance.rounding.normal
    color: Appearance.colors.colPrimaryContainer

    property int margins: 24
    property int iconSize: 110
    property real iconFontSize: 48

    property string shapeString: "Cookie9Sided"
    property string icon: ""

    property string title: ""
    property string subtitle: ""
    property int titleSize: Appearance.font.pixelSize.hugeass * 2.5
    property int subtitleSize: Appearance.font.pixelSize.hugeass

    property string pillText: ""
    property string pillIcon: ""

    property color shapeColor: Appearance.colors.colPrimary
    property color symbolColor: Appearance.colors.colOnPrimary
    property color textColor: Appearance.colors.colOnPrimaryContainer

    property alias shapeContent: shapeItem.data
    property int spacing: 16

    MaterialShape {
        id: shapeItem
        shapeString: heroCardRoot.shapeString
        implicitSize: heroCardRoot.iconSize
        color: heroCardRoot.shapeColor
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            margins: heroCardRoot.margins
        }

        MaterialSymbol {
            id: iconSymbol
            visible: heroCardRoot.icon !== "" && shapeItem.children.length <= 1
            anchors.centerIn: parent
            text: heroCardRoot.icon
            iconSize: heroCardRoot.iconFontSize
            color: heroCardRoot.symbolColor
        }
    }

    Rectangle {
        visible: heroCardRoot.pillText !== "" && heroCardRoot.pillIcon !== ""
        implicitHeight: cityRow.implicitHeight + 12
        implicitWidth: cityRow.implicitWidth + 20
        radius: Appearance.rounding.full
        color: Appearance.colors.colSecondaryContainer
        anchors {
            right: parent.right
            top: parent.top
            margins: heroCardRoot.margins
        }

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
                Layout.topMargin: 1 // to center the text
            }
        }
    }

    StyledText {
        text: heroCardRoot.title
        font.pixelSize: heroCardRoot.titleSize
        font.family: Appearance.font.family.title
        font.weight: Font.Black
        color: heroCardRoot.textColor
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        anchors {
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 4
            right: parent.right
            margins: heroCardRoot.margins
        }
        width: 150
    }

    StyledText {
        text: heroCardRoot.subtitle
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: heroCardRoot.margins
        }
        font {
            pixelSize: heroCardRoot.subtitleSize
            family: Appearance.font.family.title
            weight: Font.Black
        }
        color: heroCardRoot.textColor
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        width: 200
    }
}
