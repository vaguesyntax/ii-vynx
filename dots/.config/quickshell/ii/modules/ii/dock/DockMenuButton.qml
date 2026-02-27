import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    property string iconName: ""
    property string symbolName: ""
    property string labelText: ""
    property bool isDestructive: false
    signal triggered()

    // DockMenuButton.qml
    implicitWidth:  rowContent.implicitWidth  + 24  
    implicitHeight: rowContent.implicitHeight + 12  
    radius: Appearance.rounding.normal  
        color: hoverHandler.hovered
                ? (isDestructive
                    ? Qt.rgba(
                            Appearance.colors.colError.r,
                            Appearance.colors.colError.g,
                            Appearance.colors.colError.b,
                            0.15)
                    : Appearance.colors.colLayer1)
                : "transparent"
        Behavior on color {
            ColorAnimation { duration: 80 }
        }
        

RowLayout {
    id: rowContent
    anchors {
        left: parent.left
        right: parent.right
        leftMargin: 10
        rightMargin: 10
        verticalCenter: parent.verticalCenter
    }
    spacing: 8

        // MaterialSymbol
        MaterialSymbol {
            visible: root.symbolName !== ""
            text: root.symbolName
            iconSize: 18
            color: root.isDestructive
                   ? Appearance.colors.colError
                   : Appearance.colors.colOnLayer0
        }

        // IconImage 
        IconImage {
            visible: root.iconName !== "" && root.symbolName === ""
            implicitSize: 18
            source: root.iconName !== ""
                    ? Quickshell.iconPath(root.iconName, "")
                    : ""
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: root.isDestructive
                       ? Appearance.colors.colError
                       : Appearance.colors.colOnLayer0
            }
        }

        // Placeholder if no icons
        // Item {
        //     visible: root.iconName === "" && root.symbolName === ""
        //     implicitWidth: 16
        //     implicitHeight: 16
        // }

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

            HoverHandler { id: hoverHandler }
            TapHandler {
                onTapped: root.triggered()
            }
        }