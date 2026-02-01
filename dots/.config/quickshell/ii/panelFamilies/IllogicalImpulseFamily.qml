import QtQuick
import Quickshell

import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.bar
import qs.modules.ii.cheatsheet
import qs.modules.ii.dock
import qs.modules.ii.lock
import qs.modules.ii.mediaControls
import qs.modules.ii.notificationPopup
import qs.modules.ii.onScreenDisplay
import qs.modules.ii.onScreenKeyboard
import qs.modules.ii.overview
import qs.modules.ii.polkit
import qs.modules.ii.regionSelector
import qs.modules.ii.screenCorners
import qs.modules.ii.sessionScreen
import qs.modules.ii.sidebarPolicies
import qs.modules.ii.sidebarDashboard
import qs.modules.ii.overlay
import qs.modules.ii.verticalBar
import qs.modules.ii.wallpaperSelector
import qs.modules.ii.wrappedFrame

Scope {
    property bool barExtraCondition: true
    readonly property bool usingWrappedFrame: Config.options.appearance.fakeScreenRounding === 3
    readonly property bool barBot: Config.options.bar.bottom
    readonly property bool barVert: Config.options.bar.vertical

    Component.onCompleted: Qt.callLater(() => updateBarExtraCondition())
    onUsingWrappedFrameChanged: updateBarExtraCondition()
    onBarBotChanged: updateBarExtraCondition()
    onBarVertChanged: updateBarExtraCondition()

    function updateBarExtraCondition() {
        if (!usingWrappedFrame) return

        barExtraCondition = false
        Qt.callLater(() => barExtraCondition = true)
    }

    PanelLoader { extraCondition: !Config.options.bar.vertical && barExtraCondition; component: Bar {} }
    PanelLoader { component: Background {} }
    PanelLoader { component: Cheatsheet {} }
    PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
    PanelLoader { component: Lock {} }
    PanelLoader { component: MediaControls {} }
    PanelLoader { component: NotificationPopup {} }
    PanelLoader { component: OnScreenDisplay {} }
    PanelLoader { component: OnScreenKeyboard {} }
    PanelLoader { component: Overlay {} }
    PanelLoader { component: Overview {} }
    PanelLoader { component: Polkit {} }
    PanelLoader { component: RegionSelector {} }
    PanelLoader { component: ScreenCorners {} }
    PanelLoader { component: SessionScreen {} }
    PanelLoader { component: SidebarPolicies {} }
    PanelLoader { component: SidebarDashboard {} }
    PanelLoader { extraCondition: Config.options.bar.vertical && barExtraCondition; component: VerticalBar {} }
    PanelLoader { component: WallpaperSelector {} }
    PanelLoader { component: WrappedFrame {} }
}
