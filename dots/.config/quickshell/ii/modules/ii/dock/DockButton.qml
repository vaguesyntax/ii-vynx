import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    property real baseSize: Config.options?.dock.height ?? 60
    property real buttonSize: baseSize * 0.85
    width:  buttonSize
    height: buttonSize
    buttonRadius: Appearance.rounding.normal
    background.implicitWidth:  buttonSize
    background.implicitHeight: buttonSize
    padding: 0

    rippleEnabled: false
    colBackground: "transparent"
    colBackgroundHover: "transparent"
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: "transparent"
    opacity: 1.0 // Necessary 
}