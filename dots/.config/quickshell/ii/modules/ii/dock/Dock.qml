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

    // Whether the dock is pinned (always visible, reserves screen space via exclusiveZone)
    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    // Create one dock instance per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked && !positionChanging

            // Temporarily hidden while changing position to avoid
            // Hyprland layer animation glitches during anchor transitions
            property bool positionChanging: false

            // Total thickness of the dock panel including margins and gaps
            readonly property real dockThickness: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut

            // The dock is visible when: manually pinned, hover-to-reveal is active and mouse is over it,
            // or no window is currently active on the workspace
            property bool reveal: root.pinned || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) || (!ToplevelManager.activeToplevel?.activated)

            // Anchor to all 4 sides so the panel covers the full edge.
            // For horizontal positions (top/bottom): anchor left+right to stretch full width.
            // For vertical positions (left/right): anchor top+bottom to stretch full height.
            anchors {
                top: GlobalStates.dockEffectivePosition === "top" || GlobalStates.dockIsVertical
                bottom: GlobalStates.dockEffectivePosition === "bottom" || GlobalStates.dockIsVertical
                left: GlobalStates.dockEffectivePosition === "left" || !GlobalStates.dockIsVertical
                right: GlobalStates.dockEffectivePosition === "right" || !GlobalStates.dockIsVertical
            }

            // Reserve screen space only when pinned, so windows don't go under the dock
            exclusiveZone: root.pinned ? dockThickness - Appearance.sizes.hyprlandGapsOut - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut) : 0

            // Placeholder size — will be replaced by actual content dimensions
            implicitWidth: GlobalStates.dockIsVertical ? dockThickness : 400
            implicitHeight: GlobalStates.dockIsVertical ? 400 : dockThickness

            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            // Restrict input to the dock area only, ignoring the transparent panel space
            mask: Region {
                item: dockMouseArea
            }

            // Brief hide during position change to avoid Hyprland animating the layer window moving
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

                // Offset when dock is partially hidden — leaves a thin strip for hover detection
                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                // Offset when dock is fully hidden — no strip visible
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                // Selects the correct offset based on reveal state and config
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                // Placeholder size — will be replaced by actual content dimensions
                width: GlobalStates.dockIsVertical ? dockRoot.dockThickness : 400
                height: GlobalStates.dockIsVertical ? 400 : dockRoot.dockThickness

                // Use states + AnchorChanges instead of conditional bindings to ensure
                // previous anchors are properly cleared when switching position,
                // preventing layout conflicts and stretching artifacts
                state: GlobalStates.dockEffectivePosition

                states: [
                    State {
                        name: "top"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.top: parent.top
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dockMouseArea; anchors.topMargin: -currentOffset }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.bottom: parent.bottom
                            anchors.top: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dockMouseArea; anchors.bottomMargin: -currentOffset }
                    },
                    State {
                        name: "left"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.left: parent.left
                            anchors.right: undefined
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PropertyChanges { target: dockMouseArea; anchors.leftMargin: -currentOffset }
                    },
                    State {
                        name: "right"
                        AnchorChanges {
                            target: dockMouseArea
                            anchors.right: parent.right
                            anchors.left: undefined
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        PropertyChanges { target: dockMouseArea; anchors.rightMargin: -currentOffset }
                    }
                ]

                // Animate the slide in/out when reveal state changes
                Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                StyledRectangularShadow {
                    target: dockVisualBackground
                }

                Rectangle {
                    id: dockVisualBackground
                    anchors.fill: parent
                    // Push the background away from the screen edge, toward the screen center
                    anchors.topMargin: GlobalStates.dockEffectivePosition === "top" ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.elevationMargin
                    anchors.bottomMargin: GlobalStates.dockEffectivePosition === "bottom" ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.elevationMargin
                    anchors.leftMargin: GlobalStates.dockEffectivePosition === "left" ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.elevationMargin
                    anchors.rightMargin: GlobalStates.dockEffectivePosition === "right" ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.elevationMargin
                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.large
                }
            }
        }
    }
}