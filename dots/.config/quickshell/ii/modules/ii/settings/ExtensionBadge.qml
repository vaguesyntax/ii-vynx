import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string tooltip: ""

    property color bgColor: Appearance.colors.colSecondaryContainer
    property color fgColor: Appearance.colors.colOnSecondaryContainer
    property int iconSize: 16
    property int extraWidth: label.length > 0 ? 0 : 14

    visible: false
    radius: Appearance.rounding.full
    color: root.bgColor

    implicitWidth: root.icon.length > 0 ? 22 + root.extraWidth : childrenRect.width + 20 + root.extraWidth
    implicitHeight: 24

    MaterialSymbol {
        visible: root.icon.length > 0
        anchors.centerIn: parent
        text: root.icon
        iconSize: root.iconSize
        color: root.fgColor
    }

    StyledText {
        visible: root.icon.length === 0 && root.label.length > 0
        text: root.label
        font.pixelSize: Appearance.font.pixelSize.smallest
        color: root.fgColor
        anchors.centerIn: parent
    }

    HoverHandler {
        id: hover
    }

    StyledToolTip {
        extraVisibleCondition: hover.hovered
        text: root.tooltip
    }
}
