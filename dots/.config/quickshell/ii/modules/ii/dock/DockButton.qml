import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    property real baseSize: Config.options?.dock.height ?? 60
    implicitWidth: baseSize
    implicitHeight: baseSize
    buttonRadius: Appearance.rounding.normal
    background.implicitHeight: baseSize
}