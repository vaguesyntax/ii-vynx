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
            readonly property real dockThickness: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut

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
            // exclusiveZone: root.pinned ? dockThickness : 0
WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            // --- NUOVO ITEM INVISIBILE ---
            // Questo elemento occupa fisicamente tutto lo spazio laterale della finestra
            Item {
                id: fullScreenDragArea
                anchors.fill: parent
            }

            // --- MASCHERA CORRETTA ---
            // Usa l'area stretta del dock di default.
            // Passa a tutto lo schermo (fullScreenDragArea) SOLO durante il drag.
            mask: Region { 
                item: dockApps.dragActive ? fullScreenDragArea : dockMouseArea 
            }

            // Briefly hide during position change to avoid Hyprland animating the layer window moving
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

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                // MouseArea is always full dockThickness on the perpendicular axis.
                // On the parallel axis it is driven by dockApps directly.
                width:  dockRoot.isVertical ? dockRoot.dockThickness : dockApps.implicitWidth  + Appearance.sizes.hyprlandGapsOut * 2 + Appearance.sizes.elevationMargin * 2
                height: dockRoot.isVertical ? dockApps.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2 + Appearance.sizes.elevationMargin * 2 : dockRoot.dockThickness

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
                        AnchorChanges {
                            target: dockVisualBackground
                            anchors.top: dockMouseArea.top; anchors.bottom: undefined
                            anchors.left: undefined; anchors.right: undefined
                            anchors.horizontalCenter: dockMouseArea.horizontalCenter
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
                        AnchorChanges {
                            target: dockVisualBackground
                            anchors.bottom: dockMouseArea.bottom; anchors.top: undefined
                            anchors.left: undefined; anchors.right: undefined
                            anchors.horizontalCenter: dockMouseArea.horizontalCenter
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
                        AnchorChanges {
                            target: dockVisualBackground
                            anchors.left: dockMouseArea.left; anchors.right: undefined
                            anchors.top: undefined; anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: dockMouseArea.verticalCenter
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
                        AnchorChanges {
                            target: dockVisualBackground
                            anchors.right: dockMouseArea.right; anchors.left: undefined
                            anchors.top: undefined; anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: dockMouseArea.verticalCenter
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

                    width:  dockApps.implicitWidth  + Appearance.sizes.hyprlandGapsOut * 2
                    height: dockApps.implicitHeight + Appearance.sizes.hyprlandGapsOut * 2

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