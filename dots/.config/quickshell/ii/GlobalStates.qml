import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property alias sidebarLeftOpen: root.policiesPanelOpen // Until all sidebars naming is fixed
    property alias sidebarRightOpen: root.dashboardPanelOpen // Until all sidebars naming is fixed

    property bool barOpen: true
    property bool crosshairOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false

    property bool dashboardPanelOpen: false // formerly sidebarRightOpen
    property bool policiesPanelOpen: false  // formerly sidebarLeftOpen

    readonly property bool effectiveLeftOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return policiesPanelOpen;  
            case "inverted": return dashboardPanelOpen;  
            case "left":     return dashboardPanelOpen || policiesPanelOpen;
            case "right":    return false;
            default:         return policiesPanelOpen;
        }
    }
    readonly property bool effectiveRightOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return dashboardPanelOpen; 
            case "inverted": return policiesPanelOpen; 
            case "left":     return false;
            case "right":    return dashboardPanelOpen || policiesPanelOpen;
            default:         return dashboardPanelOpen;
        }
    }

    onPoliciesPanelOpenChanged: {
        if (policiesPanelOpen) {
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.dashboardPanelOpen = false
            }
        }
        
    }

    onDashboardPanelOpenChanged: {
        if (dashboardPanelOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.policiesPanelOpen = false
            }
        }
        
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}