import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    property real baseSize: Config.options?.dock.height ?? 60
    property real buttonSize: baseSize * 0.85
    implicitWidth:  buttonSize
    implicitHeight: buttonSize
    buttonRadius: Appearance.rounding.normal
    background.implicitWidth:  buttonSize
    background.implicitHeight: buttonSize
    padding:0
}