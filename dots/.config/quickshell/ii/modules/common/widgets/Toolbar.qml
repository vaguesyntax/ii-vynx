import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 expressive style toolbar.
 * https://m3.material.io/components/toolbars
 */
Item {
    id: root

    property bool enableShadow: true
    property real padding: 8
    property alias colBackground: background.color
    property alias spacing: toolbarLayout.spacing
    default property alias toolbarData: toolbarLayout.data
    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    property alias radius: background.radius

    Loader {
        active: root.enableShadow
        anchors.fill: background
        sourceComponent: StyledRectangularShadow {
            target: background
            anchors.fill: undefined
        }
    }

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Appearance.m3colors.m3surfaceContainer
        implicitHeight: 56
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : height / 2
        radius: fullRadius

        RowLayout {
            id: toolbarLayout
            spacing: 4
            anchors {
                fill: parent
                margins: root.padding
            }
        }
    }
}
