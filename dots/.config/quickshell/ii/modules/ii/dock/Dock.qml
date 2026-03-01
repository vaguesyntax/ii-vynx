import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked && !positionChanging

            property bool positionChanging: false
            readonly property bool isVertical: GlobalStates.dockIsVertical
            readonly property real dockThickness: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin * 2 + Appearance.sizes.hyprlandGapsOut * 2

            property bool reveal: root.pinned 
                            || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) 
                            || (dockApps.requestDockShow)
                            || (!ToplevelManager.activeToplevel?.activated)

            anchors {
                top:    GlobalStates.dockEffectivePosition !== "bottom"
                bottom: GlobalStates.dockEffectivePosition !== "top"
                left:   GlobalStates.dockEffectivePosition !== "right"
                right:  GlobalStates.dockEffectivePosition !== "left"
            }

            implicitWidth:  isVertical ? dockThickness : 0
            implicitHeight: isVertical ? 0 : dockThickness

            exclusiveZone: root.pinned ? (Config.options?.dock.height ?? 70) + Appearance.sizes.hyprlandGapsOut : 0
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "red" 

            mask: Region { 
                item: dockMouseArea 
            }

            Timer {
                id: positionChangeTimer
                interval: 150
                onTriggered: dockRoot.positionChanging = false
            }

            Connections {
                target: GlobalStates
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockApps.dragActive
                windows: [dockRoot]
                onCleared: {
                    if (dockApps.dragActive)
                        dockApps.endDrag()
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                width:  dockRoot.isVertical ? dockRoot.dockThickness 
                    : dockApps.implicitWidth + Appearance.sizes.hyprlandGapsOut * 2 + Appearance.sizes.elevationMargin * 2

                height: dockRoot.isVertical ? dockApps.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2 + Appearance.sizes.elevationMargin * 2
                    : dockRoot.dockThickness

                state: GlobalStates.dockEffectivePosition

                states: [
                    State {
                        name: "top"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.top: parent.top; anchors.bottom: undefined
                            anchors.left: undefined; anchors.right: undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dockMouseArea; anchors.topMargin: -currentOffset }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.bottom: parent.bottom; anchors.top: undefined
                            anchors.left: undefined; anchors.right: undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dockMouseArea; anchors.bottomMargin: -currentOffset }
                    },
                    State {
                        name: "left"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.left: parent.left; anchors.right: undefined
                            anchors.top: undefined; anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PropertyChanges { target: dockMouseArea; anchors.leftMargin: -currentOffset }
                    },
                    State {
                        name: "right"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.right: parent.right; anchors.left: undefined
                            anchors.top: undefined; anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PropertyChanges { target: dockMouseArea; anchors.rightMargin: -currentOffset }
                    }
                ]

                Behavior on anchors.topMargin    { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin   { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin  { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                StyledRectangularShadow { target: dockVisualBackground }

                Rectangle {
                    id: dockVisualBackground
                    anchors.centerIn: parent
                    width:  dockApps.implicitWidth  + dockApps.dockPadding * 2
                    height: dockApps.implicitHeight + dockApps.dockPadding * 2

                    anchors.topMargin:    Appearance.sizes.hyprlandGapsOut
                    anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
                    anchors.leftMargin:   Appearance.sizes.hyprlandGapsOut
                    anchors.rightMargin:  Appearance.sizes.hyprlandGapsOut

                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.large

                    DockApps {
                        id: dockApps
                        anchors.centerIn: parent
                        // Pass properties to DockApps
                        isPinned: root.pinned
                        onTogglePinRequested: {
                            root.pinned = !root.pinned
                        }
                    }
                }
            }
        }
    }
}