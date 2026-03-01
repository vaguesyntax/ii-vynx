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
    property string symbolName: ""
    property string symbolSize: root.dockHeight * 0.35
    property color activeColor: Appearance.m3colors.m3onPrimary
    property color inactiveColor: Appearance.colors.colOnLayer0

    Layout.alignment: Qt.AlignCenter

    baseWidth:  buttonSize
    baseHeight: buttonSize

    property real buttonInset: 0
    rightInset:  buttonInset
    leftInset:   buttonInset
    topInset:    buttonInset
    bottomInset: buttonInset

    buttonRadius:        Appearance.rounding.full
    buttonRadiusPressed: Appearance.rounding.normal

    clickedWidth:  isVertical ? buttonSize : buttonSize + dockHeight * 0.20
    clickedHeight: isVertical ? buttonSize + dockHeight * 0.20 : buttonSize

    bounce: true

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
        text: root.symbolName
        iconSize: root.symbolSize
        color:    root.toggled ? root.activeColor : root.inactiveColor
    }
}