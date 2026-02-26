import qs.modules.ii.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

import Quickshell.Io

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property int monitorIndex
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

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

    ////// Definning places of center modules //////
    property var fullModel: Config.options.bar.layouts.center

    property var leftList: []
    property var centerList: []
    property var rightList: []

    onFullModelChanged: {
        const idx = fullModel.findIndex(item => item.centered)
        
        if (idx === -1) {
            leftList = []
            centerList = fullModel
            rightList = []
            return
        }

        leftList = fullModel.slice(0, idx)
        centerList = [fullModel[idx]]
        rightList = fullModel.slice(idx + 1)
    }

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
        z: -10 // making sure its behind everything
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: root.showBarBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: middleSection.left
        }
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        onScrollUp: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button !== Qt.LeftButton)
                return;
        
            const leftIds = Config.options.bar.layouts.left.map(c => c.id)
            if (leftIds.includes("dashboard_panel_button") && !leftIds.includes("policies_panel_button")) {
                GlobalStates.dashboardPanelOpen = !GlobalStates.dashboardPanelOpen;
            } else {
                GlobalStates.policiesPanelOpen = !GlobalStates.policiesPanelOpen;
            }
        }

        ScrollHint {
            reveal: barLeftSideMouseArea.hovered
            icon: "light_mode"
            tooltipText: Translation.tr("Scroll to change brightness")
            side: "left"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    

    Item {
        id: leftStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            leftMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        width: 1
    }

    RowLayout { // Left section
        id: leftSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: leftStopper.right
        }
        spacing: 4

        Repeater {
            id: leftRepeater
            model: Config.options.bar.layouts.left
            delegate: BarComponent {
                list: Config.options.bar.layouts.left
                barSection: 0
            }
        }
    }

    Row { // Middle section
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }

        RowLayout {
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: centerCenter.left
                rightMargin: 4
            }
            Repeater {
                id: middleLeftRepeater
                model: root.leftList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id) // we have to recalculate the index because repeater.model has changed
                }
            }
        }

        RowLayout { //center
            id: centerCenter
            anchors {
                top: parent.top
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
            }
            Repeater {
                model: root.centerList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

        RowLayout {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: centerCenter.right
                leftMargin: 4
            }
            Repeater {
                id: middleRightRepeater
                model: root.rightList
                delegate: BarComponent {
                    list: Config.options.bar.layouts.center
                    barSection: 1
                    originalIndex: Config.options.bar.layouts.center.findIndex(e => e.id === modelData.id)
                }
            }
        }

    }

    RowLayout { // Right section
        id: rightSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: rightStopper.left
            rightMargin: Math.ceil(Appearance.rounding.screenRounding / 2)
        }
        spacing: 4

        Repeater {
            id: rightRepeater
            model: Config.options.bar.layouts.right
            delegate: BarComponent {
                list: rightRepeater.model
                barSection: 2
            }
        }
    }


    Item {
        id: rightStopper
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: 1
    }

    

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        z: -1
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: middleSection.right
            right: parent.right
        }
        implicitHeight: Appearance.sizes.baseBarHeight

        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button !== Qt.LeftButton)
                return;
        
            const leftIds = Config.options.bar.layouts.left.map(c => c.id)
            if (leftIds.includes("dashboard_panel_button") && !leftIds.includes("policies_panel_button")) {
                GlobalStates.policiesPanelOpen = !GlobalStates.policiesPanelOpen;
            } else {
                GlobalStates.dashboardPanelOpen = !GlobalStates.dashboardPanelOpen;
            }
        }

        ScrollHint {
            reveal: barRightSideMouseArea.hovered
            icon: "volume_up"
            tooltipText: Translation.tr("Scroll to change volume")
            side: "right"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
