import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    property bool active: false
    property bool isVertical: false
    property real buttonBaseSize: 40

    Layout.preferredWidth:  active ? 50 : 0
    Layout.preferredHeight: active ? 50 : 0

    Behavior on Layout.preferredWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    Behavior on Layout.preferredHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    MaterialSymbol {
        visible: active
        anchors.centerIn: parent
        text: "keep_off"
        iconSize: buttonBaseSize / 2
        color: Appearance.colors.colOnLayer0
    }
}