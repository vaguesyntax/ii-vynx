import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

GroupButton {
    id: root

    property real dockHeight: Config.options?.dock.height ?? 60
    property bool isVertical: false

    Layout.alignment: Qt.AlignCenter

    baseWidth:  dockHeight * 0.58
    baseHeight: dockHeight * 0.58

    topInset:    isVertical ? 0              : (dockHeight - baseHeight) / 2
    bottomInset: isVertical ? 0              : (dockHeight - baseHeight) / 2
    leftInset:   isVertical ? (dockHeight - baseWidth) / 2 : 0
    rightInset:  isVertical ? (dockHeight - baseWidth) / 2 : 0

    buttonRadius:        Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.large

    clickedWidth:  isVertical ? baseWidth                      : baseWidth  + dockHeight * 0.30
    clickedHeight: isVertical ? baseHeight + dockHeight * 0.30 : baseHeight

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