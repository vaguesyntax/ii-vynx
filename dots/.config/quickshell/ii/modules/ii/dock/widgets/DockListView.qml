import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import "../"

StyledListView {
    property alias modelValues: scriptModel.values
    required property Component delegateComp
    property int listLayoutDirection: Qt.LeftToRight
    property int listVerticalLayoutDirection: ListView.TopToBottom

    layoutDirection: listLayoutDirection
    verticalLayoutDirection: listVerticalLayoutDirection
    orientation: root.isVertical ? ListView.Vertical : ListView.Horizontal
    spacing: 0
    interactive: false
    clip: true
    animateAppearance: false
    animateMovement: false
    popin: false
    removeOvershoot: 0
    ScrollBar.vertical: null
    implicitWidth: root.isVertical ? root.buttonSlotSize : Math.max(1, contentWidth)
    implicitHeight: root.isVertical ? Math.max(1, contentHeight) : root.buttonSlotSize
    Behavior on implicitWidth {
        enabled: !root.suppressSizeAnimation && !root.dragActive && !root.isFileDrag
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        enabled: !root.suppressSizeAnimation && !root.dragActive && !root.isFileDrag
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    removeDisplaced: Transition {
        enabled: !root.suppressAnimation && !root.dragActive && !root.fileSuppressAnim
        NumberAnimation {
            properties: root.isVertical ? "y" : "x"
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }
    model: ScriptModel {
        id: scriptModel
        objectProp: "uniqueKey"
    }
    delegate: delegateComp
}