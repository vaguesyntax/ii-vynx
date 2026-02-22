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
    property string position: "bottom" // "auto" | "bottom" | "top" | "left" | "right"
    
    readonly property string effectivePosition: {
        if (position === "auto")
            return (Config.options?.bar.bottom && !Config.options?.bar.vertical) ? "top" : "bottom"
        return position
    }

    readonly property bool isVertical: effectivePosition === "left" || effectivePosition === "right"

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            visible: !GlobalStates.screenLocked

            readonly property real dockThickness: (Config.options?.dock.height ?? 70) + Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut

            property bool reveal: root.pinned || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse) || dockApps.requestDockShow || (!ToplevelManager.activeToplevel?.activated)

            anchors {
                top: root.effectivePosition === "top" || root.isVertical
                bottom: root.effectivePosition === "bottom" || root.isVertical
                left: root.effectivePosition === "left" || !root.isVertical
                right: root.effectivePosition === "right" || !root.isVertical
            }

            exclusiveZone: root.pinned ? dockThickness - Appearance.sizes.hyprlandGapsOut - (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut) : 0

            implicitWidth: root.isVertical ? dockThickness : dockBackground.implicitWidth
            implicitHeight: root.isVertical ? dockBackground.implicitHeight : dockThickness

            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            mask: Region {
                item: dockMouseArea
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                width: root.isVertical ? dockRoot.dockThickness : dockHoverRegion.implicitWidth + Appearance.sizes.elevationMargin * 2
                height: root.isVertical ? dockHoverRegion.implicitHeight + Appearance.sizes.elevationMargin * 2 : dockRoot.dockThickness

                anchors.horizontalCenter: root.isVertical ? undefined : parent.horizontalCenter
                anchors.verticalCenter: root.isVertical ? parent.verticalCenter : undefined

                anchors.top: root.effectivePosition === "top" ? parent.top : undefined
                anchors.bottom: root.effectivePosition === "bottom" ? parent.bottom : undefined
                anchors.left: root.effectivePosition === "left" ? parent.left : undefined
                anchors.right: root.effectivePosition === "right" ? parent.right : undefined

                anchors.topMargin: root.effectivePosition === "top" ? -currentOffset : 0
                anchors.bottomMargin: root.effectivePosition === "bottom" ? -currentOffset : 0
                anchors.leftMargin: root.effectivePosition === "left" ? -currentOffset : 0
                anchors.rightMargin: root.effectivePosition === "right" ? -currentOffset : 0

                Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                Item {
                    id: dockHoverRegion
                    anchors.fill: parent
                    implicitWidth: dockBackground.implicitWidth

                    Item { // Wrapper for the dock background
                        id: dockBackground
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                        }

                        implicitWidth: dockRow.implicitWidth + 5 * 2
                        height: parent.height - Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut

                        StyledRectangularShadow {
                            target: dockVisualBackground
                        }
                        Rectangle { // The real rectangle that is visible
                            id: dockVisualBackground
                            property real margin: Appearance.sizes.elevationMargin
                            anchors.fill: parent
                            anchors.topMargin: Appearance.sizes.elevationMargin
                            anchors.bottomMargin: Appearance.sizes.hyprlandGapsOut
                            color: Appearance.colors.colLayer0
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            radius: Appearance.rounding.large
                        }

                        RowLayout {
                            id: dockRow
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            property real padding: 5

                            VerticalButtonGroup {
                                Layout.topMargin: Appearance.sizes.hyprlandGapsOut // why does this work
                                GroupButton {
                                    // Pin button
                                    baseWidth: 35
                                    baseHeight: 35
                                    clickedWidth: baseWidth
                                    clickedHeight: baseHeight + 20
                                    buttonRadius: Appearance.rounding.normal
                                    toggled: root.pinned
                                    onClicked: root.pinned = !root.pinned
                                    contentItem: MaterialSymbol {
                                        text: "keep"
                                        horizontalAlignment: Text.AlignHCenter
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                                    }
                                }
                            }
                            DockSeparator {}
                            DockApps {
                                id: dockApps
                                buttonPadding: dockRow.padding
                            }
                        }
                    }
                }
            }
        }
    }
}
