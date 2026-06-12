import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

GroupButton {
    id: button
    property string buttonIcon: ""
    property string buttonText: ""

    property int extraWidth: 46
    baseHeight: 36
    baseWidth: content.implicitWidth + extraWidth
    clickedWidth: baseWidth + 6

    readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : baseHeight / 2
    buttonRadius: fullRadius
    buttonRadiusPressed: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colBackgroundActive: Appearance.colors.colLayer2Active
    property color colText: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1

    contentItem: Item {
        id: content
        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight
        RowLayout {
            id: contentRowLayout
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                visible: buttonIcon !== ""
                text: buttonIcon
                iconSize: Appearance.font.pixelSize.huge
                color: button.colText
            }
            StyledText {
                visible: buttonText !== ""
                text: buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                color: button.colText
            }
        }
    }

}