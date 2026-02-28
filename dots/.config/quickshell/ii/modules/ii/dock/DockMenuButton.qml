import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

RippleButton {
    id: root
    property string iconName: ""
    property string symbolName: ""
    property string shapeString: ""  
    property string labelText: ""
    property bool isDestructive: false
    signal triggered()

    implicitHeight: 35
    buttonRadius: Appearance.rounding.normal

    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    // colBackgroundHover: isDestructive
    //     ? Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.15)
    //     : Appearance.colors.colLayer1Hover
    // colRipple: isDestructive
    //     ? Qt.rgba(Appearance.colors.colError.r, Appearance.colors.colError.g, Appearance.colors.colError.b, 0.25)
    //     : Appearance.colors.colLayer1Active

    releaseAction: () => root.triggered()

    contentItem: RowLayout {
        spacing: 6
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 2
            rightMargin: 2
            verticalCenter: parent.verticalCenter
        }

        // MaterialShape
        Loader {
            active: root.shapeString !== ""
            visible: active
            sourceComponent: MaterialShape {
                shapeString: root.shapeString
                implicitSize: 18
                color: root.isDestructive
                    ? Appearance.colors.colError
                    : Appearance.colors.colOnLayer0
            }
        }

        // MaterialSymbol
        MaterialSymbol {
            visible: root.symbolName !== "" && root.shapeString === ""
            text: root.symbolName
            iconSize: 18
            color: root.isDestructive
                ? Appearance.colors.colError
                : Appearance.colors.colOnLayer0
        }

        // IconImage
        IconImage {
            visible: root.iconName !== "" && root.symbolName === "" && root.shapeString === ""
            implicitSize: 18
            source: root.iconName !== "" ? Quickshell.iconPath(root.iconName, "") : ""
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: root.isDestructive
                    ? Appearance.colors.colError
                    : Appearance.colors.colOnLayer0
            }
        }

        StyledText {
            text: root.labelText
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.isDestructive
                ? Appearance.colors.colError
                : Appearance.colors.colOnLayer0
        }
    }
}