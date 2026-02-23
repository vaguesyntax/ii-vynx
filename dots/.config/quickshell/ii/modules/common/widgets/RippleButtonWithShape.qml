import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: buttonWithShapeRoot

    property string shapeString: ""
    property string mainText: ""

    property string extraIcon: ""
    property int extraIconSize: Appearance.font.pixelSize.large
    
    property Component mainContentComponent: Component {
        StyledText {
            visible: text !== ""
            text: buttonWithShapeRoot.mainText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSecondaryContainer
        }
    }
    implicitWidth: contentLayout.implicitWidth + horizontalPadding * 2
    implicitHeight: 35
    horizontalPadding: 10
    buttonRadius: Appearance.rounding.full

    colBackground: Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.colors.colSecondaryContainerActive

    contentItem: RowLayout {
        id: contentLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Loader {
            id: materialShapeLoader
            anchors.verticalCenter: parent.verticalCenter
            active: buttonWithShapeRoot.shapeString !== ""
            sourceComponent: MaterialShape {
                shapeString: buttonWithShapeRoot.shapeString
                width: Appearance.font.pixelSize.larger
                height: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
        MaterialSymbol {
            visible: buttonWithShapeRoot.extraIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: buttonWithShapeRoot.extraIcon
            iconSize: buttonWithShapeRoot.extraIconSize
        }
        Loader {
            Layout.fillWidth: true
            sourceComponent: buttonWithShapeRoot.mainContentComponent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
