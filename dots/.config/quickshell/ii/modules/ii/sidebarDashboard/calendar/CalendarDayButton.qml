import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: button

    property string day
    property int isToday
    property bool bold
    property var taskList
    readonly property int taskMargin: 5

    property bool showPopup: false

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38
    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small

    Rectangle {
        z: 10
        width: 8
        height: 8
        radius: Appearance.rounding.full
        color: (taskList.length > 0 && isToday !== -1 && !bold) ? toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary : "transparent"
        anchors {
            top: parent.top
            left: parent.left
            margins: 4
        }
    }

    LazyLoader {
        id: dayPopUpLoader
        active: button.showPopup
    
        PanelWindow {
            id: dayPopUp

            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:popup"
            WlrLayershell.layer: WlrLayer.Overlay
            implicitWidth: sidebarRoot.width
            implicitHeight: sidebarRoot.height
            property Rectangle dayPopRectProp: dayPopRect

            anchors {
                top: true
                right: true
                bottom: true
            }

            CalendarPopup {
                id: dayPopRect
            }

        }   
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            if  (button.taskList.length > 0 && button.isToday !== -1 && !button.bold) {
                button.showPopup = true
                // settings position to panelwindow popup
                const dayPopUp = dayPopUpLoader.item
                const dayPopRect = dayPopUp.dayPopRectProp
                const globalPos = dayPopUp.QsWindow?.mapFromItem(button, 0 , 0);
                dayPopRect.x =globalPos.x - dayPopRect.width/2;
                dayPopRect.y = globalPos.y + button.height  - dayPopRect.height 
            }
        }
        onExited: button.showPopup = false
    }

    

    StyledText {
        anchors.centerIn: parent
        text: day
        horizontalAlignment: Text.AlignHCenter
        font.weight: bold ? Font.DemiBold : Font.Normal
        color: (isToday == 1) ? Appearance.m3colors.m3onPrimary : (isToday == 0) ? Appearance.colors.colOnLayer1 : Appearance.colors.colOutlineVariant
    }

}
