import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property var shape
    property bool rotateIcon: false
    property bool scaleIcon: false

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 15
    property real valueIndicatorRightPadding: 15 // An icon is circle ish, a column isn't, hence the extra padding

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: valueIndicator
    }
    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.m3colors.m3surfaceContainer

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout { // Icon on the left, stuff on the right
            id: valueRow
            Layout.margins: 10
            anchors.fill: parent
            spacing: 15

            Item {
                implicitWidth: 30
                implicitHeight: 35
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                MaterialShapeWrappedMaterialSymbol {
                    rotation: root.value * 360
                    anchors {
                        fill: parent
                        margins: -5
                    }
                    iconSize: Appearance.font.pixelSize.huge
                    shape: root.shape
                    text: root.icon
                }
            }
            ColumnLayout { // Stuff
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout { // Name fill left, value on the right end
                    Layout.leftMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end
                    Layout.rightMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: true
                        text: root.name
                    }

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        Layout.fillWidth: false
                        Layout.preferredWidth: 30
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(root.value * 100)
                        animateChange: true
                        animationDistanceY: 2 // for faster animation than default
                        
                    }
                }
                
                StyledProgressBar {
                    id: valueProgressBar
                    Layout.fillWidth: true
                    value: root.value
                }
            }
        }
    }
}
