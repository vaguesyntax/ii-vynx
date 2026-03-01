import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    property real baseSize: Config.options?.dock.height ?? 60
    property real buttonSize: baseSize * 0.85
    Layout.preferredWidth:  buttonSize
    Layout.preferredHeight: buttonSize
    buttonRadius: Appearance.rounding.normal
    background.implicitWidth:  buttonSize
    background.implicitHeight: buttonSize
    padding: 0
}