import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    Layout.preferredWidth:  50
    Layout.preferredHeight: 50
    Layout.alignment: Qt.AlignCenter

    property bool toggled:    false
    property bool isVertical: false
    signal clicked()

    GroupButton {
        id: groupBtn
        anchors.fill: parent
        anchors.margins: 8
        baseWidth:    35
        baseHeight:   35
        buttonRadius: Appearance.rounding.normal
        clickedWidth:  isVertical ? baseWidth : baseWidth + 15
        clickedHeight: isVertical ? baseHeight + 15 : baseHeight
        toggled: parent.toggled
        onClicked: parent.clicked()

        contentItem: Item {
            implicitWidth:  35
            implicitHeight: 35
            MaterialSymbol {
                anchors.centerIn: parent
                text:     "keep"
                iconSize: Appearance.font.pixelSize.huge
                color: groupBtn.toggled
                    ? Appearance.m3colors.m3onPrimary
                    : Appearance.colors.colOnLayer0
            }
        }
    }
}