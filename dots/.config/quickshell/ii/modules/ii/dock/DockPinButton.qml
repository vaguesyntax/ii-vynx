import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

GroupButton {
    id: root

    property real dockHeight: Config.options?.dock.height ?? 60
    property real buttonSize: dockHeight * 0.85
    property bool isVertical: false

    Layout.alignment: Qt.AlignCenter

    baseWidth:  buttonSize
    baseHeight: buttonSize

    buttonRadius:        Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.large

    clickedWidth:  isVertical ? buttonSize : buttonSize + dockHeight * 0.20
    clickedHeight: isVertical ? buttonSize + dockHeight * 0.20 : buttonSize

    bounce: true

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        text:     "keep"
        iconSize: root.dockHeight * 0.35
        color:    root.toggled
            ? Appearance.m3colors.m3onPrimary
            : Appearance.colors.colOnLayer0
    }
}