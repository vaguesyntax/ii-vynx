import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool detach: false
    property bool pin: false
    property Component contentComponent: SidebarPoliciesContent {}
    property Item sidebarContent

    readonly property bool isOnLeft: {
        const pos = Config.options.sidebar.position;
        return pos === "default" || pos === "left"; 
    }

    function toggleDetach() {
        root.detach = !root.detach;
    }

    Process { // Dodge cursor away, pin, move cursor back
        id: pinWithFunnyHyprlandWorkaroundProc
        property var hook: null
        property int cursorX;
        property int cursorY;
        function doIt() {
            command = ["hyprctl", "cursorpos"]
            hook = (output) => {
                cursorX = parseInt(output.split(",")[0]);
                cursorY = parseInt(output.split(",")[1]);
                doIt2();
            }
            running = true;
        }
        function doIt2(output) {
            command = ["bash", "-c", "hyprctl dispatch movecursor 9999 9999"];
            hook = () => {
                doIt3();
            }
            running = true;
        }
        function doIt3(output) {
            root.pin = !root.pin;
            command = ["bash", "-c", `sleep 0.01; hyprctl dispatch movecursor ${cursorX} ${cursorY}`];
            hook = null
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                pinWithFunnyHyprlandWorkaroundProc.hook(text);
            }
        }
    }

    function togglePin() {
        if (!root.pin) pinWithFunnyHyprlandWorkaroundProc.doIt()
        else root.pin = !root.pin;
    }

    Component.onCompleted: {
        root.sidebarContent = contentComponent.createObject(null, {
            "scopeRoot": root,
        });
        sidebarLoader.item.contentParent.children = [root.sidebarContent];
    }

    onDetachChanged: {
        if (root.detach) {
            GlobalFocusGrab.removeDismissable(sidebarLoader.item) // Remove sidebar from the focus grab system
            sidebarContent.parent = null; // Detach content from sidebar
            sidebarLoader.active = false; // Unload sidebar
            detachedSidebarLoader.active = true; // Load detached window
            detachedSidebarLoader.item.contentParent.children = [sidebarContent];
        } else {
            sidebarContent.parent = null; // Detach content from window
            detachedSidebarLoader.active = false; // Unload detached window
            sidebarLoader.active = true; // Load sidebar
            sidebarLoader.item.contentParent.children = [sidebarContent];
        }
    }

    Loader {
        id: sidebarLoader
        active: true
        
        sourceComponent: PanelWindow {
            id: panelWindow
            visible: GlobalStates.sidebarLeftOpen
            
            property bool extend: false
            readonly property real sidebarWidth: {
                const p = Config.options.policies;
                const allFeatures = p.ai !== 0 && p.weeb == 1 && p.wallpapers !== 0 && p.translator !== 0;

                if (panelWindow.extend) return Appearance.sizes.sidebarWidthExtended;
                return allFeatures ? Appearance.sizes.sidebarWidthExpanded : Appearance.sizes.sidebarWidth;
            }
            
            property var contentParent: sidebarLeftBackground

            function hide() {
                GlobalStates.sidebarLeftOpen = false
            }

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.pin ? sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin : 0
            implicitWidth: Appearance.sizes.sidebarWidthExtended + Appearance.sizes.elevationMargin
            WlrLayershell.namespace: root.isOnLeft ? "quickshell:sidebarLeft" : "quickshell:sidebarRight"
            // Hyprland 0.49: OnDemand is Exclusive, Exclusive just breaks click-outside-to-close
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: root.isOnLeft
                right: !root.isOnLeft
                bottom: true
            }

            mask: Region {
                item: sidebarLeftBackground
            }

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }

            Connections {
                target: root
                function onPinChanged() {
                    if (panelWindow.visible) {
                        if (root.pin) GlobalFocusGrab.removeDismissable(panelWindow);
                        else GlobalFocusGrab.addDismissable(panelWindow);
                    }
                }
            }

            
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    if (!root.pin) panelWindow.hide();
                }
            }

            StyledRectangularShadow {
                target: sidebarLeftBackground
                radius: sidebarLeftBackground.radius
            }

            Rectangle {
                id: sidebarLeftBackground
                color: Appearance.colors.colLayer0
                border.width: root.pin ? 0 : 1
                border.color: root.pin ? "transparent" : Appearance.colors.colLayer0Border
                radius: root.pin ? 0 : Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
                
                height: root.pin ? parent.height : parent.height - (Appearance.sizes.hyprlandGapsOut * 2)
                y: root.pin ? 0 : Appearance.sizes.hyprlandGapsOut
                width: panelWindow.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                property bool _initialized: false

                Timer {
                    interval: 2500 // Avoid animations on first show
                    running: true
                    onTriggered: sidebarLeftBackground._initialized = true
                }

                Behavior on height {
                    enabled: sidebarLeftBackground._initialized
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }
                Behavior on width {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Behavior on anchors.leftMargin {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }
                Behavior on anchors.rightMargin {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }

                state: root.isOnLeft ? "left" : "right"
                states: [
                    State {
                        name: "left"
                        AnchorChanges { 
                            target: sidebarLeftBackground
                            anchors.left: parent.left
                            anchors.right: undefined 
                        }
                        PropertyChanges {
                            target: sidebarLeftBackground
                            anchors.leftMargin: root.pin ? 0 : Appearance.sizes.hyprlandGapsOut
                            anchors.rightMargin: 0
                        }
                    },
                    State {
                        name: "right"
                        AnchorChanges { 
                            target: sidebarLeftBackground
                            anchors.left: undefined
                            anchors.right: parent.right 
                        }
                        PropertyChanges {
                            target: sidebarLeftBackground
                            anchors.rightMargin: root.pin ? 0 : Appearance.sizes.hyprlandGapsOut
                            anchors.leftMargin: 0
                        }
                    }
                ]

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        panelWindow.hide();
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_O) {
                            panelWindow.extend = !panelWindow.extend;
                        } else if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        } else if (event.key === Qt.Key_P) {
                            root.togglePin();
                        }
                        event.accepted = true;
                    }
                }
            }

            property bool pinned: root.pin
            onPinnedChanged: {
                if (root.pin) return;
                roundDecorators.active = false
            }

            Timer {
                running: root.pin
                interval: 150
                onTriggered: {
                    if (!root.pin) return;
                    roundDecorators.active = true
                }
            }

            Loader {
                id: roundDecorators
                active: false
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: root.isOnLeft ? sidebarLeftBackground.right : undefined
                    right: !root.isOnLeft ? sidebarLeftBackground.left : undefined
                }
                width: Appearance.rounding.screenRounding

                sourceComponent: Item {
                    RoundCorner {
                        anchors {
                            top: parent.top
                            left: root.isOnLeft ? parent.left : undefined
                            right: !root.isOnLeft ? parent.right : undefined
                        }
                        implicitSize: Appearance.rounding.screenRounding
                        color: Appearance.colors.colLayer0
                        corner: root.isOnLeft ? RoundCorner.CornerEnum.TopLeft : RoundCorner.CornerEnum.TopRight
                    }
                    RoundCorner {
                        anchors {
                            bottom: parent.bottom
                            left: root.isOnLeft ? parent.left : undefined
                            right: !root.isOnLeft ? parent.right : undefined
                        }
                        implicitSize: Appearance.rounding.screenRounding
                        color: Appearance.colors.colLayer0
                        corner: root.isOnLeft ? RoundCorner.CornerEnum.BottomLeft : RoundCorner.CornerEnum.BottomRight
                    }
                }
            }
        }
    }
    
    Loader {
        id: detachedSidebarLoader
        active: false

        sourceComponent: FloatingWindow {
            id: detachedSidebarRoot
            property var contentParent: detachedSidebarBackground
            color: "transparent"

            visible: GlobalStates.sidebarLeftOpen
            onVisibleChanged: {
                if (visible) {
                    if (!root.pin) GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }
            
            Rectangle {
                id: detachedSidebarBackground
                anchors.fill: parent
                color: Appearance.colors.colLayer0

                Keys.onPressed: (event) => {
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
        }

        function close(): void {
            GlobalStates.sidebarLeftOpen = false
        }

        function open(): void {
            GlobalStates.sidebarLeftOpen = true
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = false;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggleDetach"
        description: "Detach left sidebar into a window/Attach it back"

        onPressed: {
            root.detach = !root.detach;
        }
    }

}
