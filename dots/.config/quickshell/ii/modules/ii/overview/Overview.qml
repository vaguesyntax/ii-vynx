import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    PanelWindow {
        id: root
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        property int monitorIndex: monitor.id
        property string overviewStyle: Config.options.overview.style

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        property var zoomLevels: {  // has to be reverted compared to background
            "in": { default: 1, zoomed: 1.04 },
            "out": { default: 1.04, zoomed: 1 }
        }

        readonly property bool isZoomInStyle: Config.options.overview.scrollingStyle.zoomStyle === "in"
        readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation

        property real defaultRatio: isZoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
        property real zoomedRatio: isZoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

        property bool isResettingZoom: false 
        property real scaleAnimated: showOpeningAnimation ? GlobalStates.overviewOpen ? zoomedRatio : defaultRatio : 1

        property real effectiveScale: showOpeningAnimation ? zoomedRatio - scaleAnimated + 1 : 1 

        onIsZoomInStyleChanged: isResettingZoom = true
        onScaleAnimatedChanged: {
            if (scaleAnimated === defaultRatio) {
                isResettingZoom = false
            }
        }

        visible: {
            if (isResettingZoom) return false // not showing when we are resetting 
            if (!showOpeningAnimation) return GlobalStates.overviewOpen // no anim
            
            return isZoomInStyle ? scaleAnimated > defaultRatio : scaleAnimated < defaultRatio
        }

        Behavior on scaleAnimated {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        property int barSize: Config.options.bar.vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
        property int margin: isZoomInStyle ? barSize : barSize * 2
        margins { 
            top: -margin
            bottom: -margin
            left: -margin
            right: -margin
        }

        HyprlandFocusGrab {
            id: grab
            windows: [root]
            property bool canBeActive: root.monitorIsFocused
            active: false
            onCleared: () => {
                if (!active)
                    GlobalStates.overviewOpen = false;
            }
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                } else {
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    delayedGrabTimer.start();
                }
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                GlobalStates.overviewOpen = false;
            }
        }

        

        Timer {
            id: delayedGrabTimer
            interval: Config.options.hacks.arbitraryRaceConditionDelay
            repeat: false
            onTriggered: {
                if (!grab.canBeActive)
                    return;
                grab.active = GlobalStates.overviewOpen;
            }
        }

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Item {
            id: contentItem
            anchors.fill: parent

            MouseArea { // We could have used PanelWindow.mask to detect this, but this is more stable
                anchors.fill: parent
                onClicked: GlobalStates.overviewOpen = false;
            }

            Item { // Wrapper for animation 
                id: searchWidgetWrapper
                implicitHeight: searchWidget.implicitHeight
                implicitWidth: searchWidget.implicitWidth
                z: 999

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    }
                }

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: root.margin + Appearance.sizes.elevationMargin
                }
                SearchWidget {
                    id: searchWidget
                    scale: root.effectiveScale
                    anchors.horizontalCenter: parent.horizontalCenter
                    Synchronizer on searchingText {
                        property alias source: root.searchingText
                    }
                }
            }
            

            Loader { // Classic overview
                id: overviewLoader
                scale: root.effectiveScale
                anchors.top: searchWidgetWrapper.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                active: root.visible && (Config?.options.overview.enable ?? true) && root.overviewStyle == "classic"
                sourceComponent: OverviewWidget {
                    panelWindow: root
                    visible: (root.searchingText == "")
                    monitorIndex: root.monitorIndex
                }
            }

            Loader { // Scrolling overview
                id: scrollingOverviewLoader
                scale: root.effectiveScale
                anchors.fill: parent
                active: root.visible && (Config?.options.overview.enable ?? true) && root.overviewStyle == "scrolling"
                sourceComponent: ScrollingOverviewWidget {
                    anchors.fill: parent
                    panelWindow: root
                    visible: (root.searchingText == "")
                    monitorIndex: root.monitorIndex
                }
            }
        }

        
    }
    

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        root.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        root.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
