import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    // FIXED: Added baseSize property so we can reference it dynamically for the separator
    property real baseSize: 50

    implicitWidth: baseSize
    implicitHeight: baseSize
    buttonRadius: Appearance.rounding.normal
    background.implicitHeight: baseSize
}