import qs.modules.common.widgets
import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string text: ""
    property string icon
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight

    HighlightOverlay {
        id: highlightOverlay
        anchors.fill: parent
        anchors.topMargin: -2
        anchors.bottomMargin: -2
        anchors.leftMargin: -4
        anchors.rightMargin: -4
    }

    SearchHandler {
        searchString: root.text
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 0

        RowLayout {
            spacing: 10
            OptionalMaterialSymbol {
                icon: root.icon
                opacity: root.enabled ? 1 : 0.4
            }
            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                text: root.text
                color: Appearance.colors.colOnSecondaryContainer
                opacity: root.enabled ? 1 : 0.4
            }
        }

        StyledSpinBox {
            id: spinBoxWidget
            Layout.fillWidth: false
            value: root.value
        }
    }
}
