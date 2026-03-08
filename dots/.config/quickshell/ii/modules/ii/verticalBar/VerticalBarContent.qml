import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property bool hasActiveWindows: false
    property bool showBarBackground: root.hasActiveWindows && Config.options.bar.barBackgroundStyle === 2 || Config.options.bar.barBackgroundStyle === 1
    
    Connections {
        enabled: Config.options.bar.barBackgroundStyle === 2
        target: HyprlandData
        function onWindowListChanged() {
            const monitor = HyprlandData.monitors.find(m => m.id === monitorIndex);
            const wsId = monitor?.activeWorkspace?.id;

            const hasWindow = wsId ? HyprlandData.windowList.some(w => w.workspace.id === wsId && !w.floating) : false;

            root.hasActiveWindows = hasWindow
        }
    }

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }


    ////// Definning places of center modules //////
    property var fullModel: Config.options?.bar?.layouts?.center

    property int centerIdx: (fullModel || []).findIndex(item => item.centered)

    property var leftList: centerIdx === -1 ? [] : fullModel.slice(0, centerIdx)
    property var centerList: centerIdx === -1 ? fullModel : [fullModel[centerIdx]]
    property var rightList: centerIdx === -1 ? [] : fullModel.slice(centerIdx + 1)

    // Background shadow
    Loader {
        active: root.showBarBackground && Config.options.bar.cornerStyle === 1 && Config.options.bar.floatStyleShadow
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        z: -10 // making sure its behind everything
        color: root.showBarBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    FocusedScrollMouseArea { // Top section | scroll to change brightness
        id: barTopSectionMouseArea
        anchors.top: parent.top
        

        anchors {
            top: parent.top
            bottom: middleSection.top
            left: parent.left
            right: parent.right
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth

        onScrollDown: {
            if (!Config.options.interactions.valueScroll.enable) return;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        }
        onScrollUp: {
            if (!Config.options.interactions.valueScroll.enable) return;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        }
        onMovedAway: {
            if (!Config.options.interactions.valueScroll.enable) return;
            GlobalStates.osdBrightnessOpen = false
        }
        onPressed: event => {
            if (event.button === Qt.LeftButton && Config.options.bar.sideClickOpensSidebar)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

    }

    Item {
        id: topStopper
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: Math.ceil(Appearance.rounding.screenRounding / 2.5)
        }
        height: 1
    }

    ColumnLayout { // Top section
        id: topSection
        anchors {
            top: topStopper.bottom
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 4

        Repeater {
            id: leftRepeater
            model: Config.options.bar.layouts.left
            delegate: Bar.BarComponent {
                vertical: true
                list: leftRepeater.model
                barSection: 0
            }
        }
    }

    Item {
        id: middleSection
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }

        ColumnLayout {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: centerCenter.top
                bottomMargin: 4
            }
            Repeater {
                id: middleLeftRepeater
                model: root.leftList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id) // we have to recalculate the index because repeater.model has changed
                }
            }
        }

        ColumnLayout { //center
            id: centerCenter
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }
            Repeater {
                model: root.centerList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        ColumnLayout {
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: centerCenter.bottom
                topMargin: 4
            }
            Repeater {
                id: middleRightRepeater
                model: root.rightList
                delegate: Bar.BarComponent {
                    vertical: true
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

    }

    ColumnLayout { // Bottom section
        id: bottomSection
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: bottomStopper.top
        }
        spacing: 4

        Repeater {
            id: rightRepeater
            model: Config.options.bar.layouts.right
            delegate: Bar.BarComponent {
                vertical: true
                list: rightRepeater.model
                barSection: 2
            }
        }
    }

    Item {
        id: bottomStopper
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: Math.ceil(Appearance.rounding.screenRounding / 2.5)
        }
        height: 1
    }

    FocusedScrollMouseArea { // Bottom section | scroll to change volume
        id: barBottomSectionMouseArea

        z: -1
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: middleSection.bottom
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        
        onScrollDown: {
            if (!Config.options.interactions.valueScroll.enable) return;
            Audio.decrementVolume();
        }
        onScrollUp: {
            if (!Config.options.interactions.valueScroll.enable) return;
            Audio.incrementVolume();
        }
        onMovedAway: {
            if (!Config.options.interactions.valueScroll.enable) return;
            GlobalStates.osdVolumeOpen = false;
        }
        onPressed: event => {
            if (event.button === Qt.LeftButton && Config.options.bar.sideClickOpensSidebar) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }
    }
}
