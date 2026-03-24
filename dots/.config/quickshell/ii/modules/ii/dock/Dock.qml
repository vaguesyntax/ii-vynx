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

pragma ComponentBehavior: Bound

Scope {
    id: dock

    property bool pinned: Config.options?.dock.pinnedOnStartup ?? false

    readonly property string dockEffectivePosition: {
        const pos = Config.options?.dock.position ?? "bottom"
        if (pos !== "auto") return pos
        return (Config.options?.bar.bottom && !Config.options?.bar.vertical) ? "top" : "bottom"
    }

    readonly property bool isVertical: dockEffectivePosition === "left" || dockEffectivePosition === "right"

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            
            visible: !GlobalStates.screenLocked && !positionChanging

            property bool positionChanging: false
            
            readonly property bool isVertical: dock.isVertical

            readonly property real availableW: screen?.width ?? 1920
            readonly property real availableH: screen?.height ?? 1080

            readonly property bool barActive: GlobalStates.barOpen
            readonly property bool barIsVertical: Config.options?.bar?.vertical ?? false

            readonly property real barThickness: barActive
                ? (barIsVertical
                    ? (Config.options?.bar?.sizes?.width ?? Appearance.sizes.verticalBarWidth)
                    : (Config.options?.bar?.sizes?.height ?? Appearance.sizes.barHeight))
                : 0

            readonly property bool barConflictsWithDock: barActive && (isVertical !== barIsVertical)

            // this math.max(s) prevents wayland crashes somehow
            readonly property real maxWidth: Math.max(1, availableW - (Appearance.sizes.hyprlandGapsOut * 2)
                - (!isVertical && barConflictsWithDock ? barThickness : 0))

            readonly property real maxHeight: Math.max(1, availableH - (Appearance.sizes.hyprlandGapsOut * 2)
                - (isVertical && barConflictsWithDock ? barThickness : 0))

            readonly property real dockWidth: isVertical
                ? dockContent.visualWidth + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2
                : Math.min(dockContent.visualWidth + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2, maxWidth)

            readonly property real dockHeight: isVertical
                ? Math.min(dockContent.visualHeight + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2, maxHeight)
                : dockContent.visualHeight + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2

            implicitWidth: Math.max(1, dockWidth)
            implicitHeight: Math.max(1, dockHeight)

            readonly property real dockThickness: isVertical ? dockWidth : dockHeight

            property bool reveal: dock.pinned
                            || (Config.options?.dock.hoverToReveal && dockMouseArea.containsMouse)
                            || (dockContent.requestDockShow)
                            || (ToplevelManager.activeToplevel?.activated === false)

            anchors {
                top: dock.dockEffectivePosition !== "bottom"
                bottom: dock.dockEffectivePosition !== "top"
                left: dock.dockEffectivePosition !== "right"
                right: dock.dockEffectivePosition !== "left"
            }

            exclusiveZone: dock.pinned ? dockThickness : 0
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            mask: Region {
                item: dockMouseArea
            }

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: dockRoot.positionChanging = false
            }

            Connections {
                target: dock
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockContent.dragActive || dockContent.fileDragActive
                windows: [dockRoot]
                onCleared: {
                    if (dockContent.dragActive) dockContent.endDrag()
                    if (dockContent.fileDragActive) dockContent.endFileDrag()
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 10)
                property real fullyHiddenOffset: dockRoot.dockThickness + 1
                property real currentOffset: dockRoot.reveal ? 0 : (Config.options?.dock.hoverToReveal ? hiddenOffset : fullyHiddenOffset)

                width: dock.isVertical ? dockRoot.dockThickness
                    : dockContent.visualWidth + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2
                height: dock.isVertical ? dockContent.visualHeight + dockContent.dockPadding * 2 + Appearance.sizes.hyprlandGapsOut * 2
                    : dockRoot.dockThickness

                state: dock.dockEffectivePosition

                states: [
                    State {
                        name: "top"
                        AnchorChanges { target: dockMouseArea; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.topMargin: -currentOffset }
                    },
                    State {
                        name: "bottom"
                        AnchorChanges { target: dockMouseArea; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.bottomMargin: -currentOffset }
                    },
                    State {
                        name: "left"
                        AnchorChanges { target: dockMouseArea; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.leftMargin: -currentOffset }
                    },
                    State {
                        name: "right"
                        AnchorChanges { target: dockMouseArea; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                        PropertyChanges { target: dockMouseArea; anchors.rightMargin: -currentOffset }
                    }
                ]

                Behavior on anchors.topMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.bottomMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.leftMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }
                Behavior on anchors.rightMargin { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(dockMouseArea) }

                StyledRectangularShadow { target: dockVisualBackground }

                Rectangle {
                    id: dockVisualBackground
                    anchors.centerIn: parent

                    width: dock.isVertical
                        ? dockContent.visualWidth + dockContent.dockPadding * 2
                        : Math.min(dockContent.visualWidth + dockContent.dockPadding * 2, maxWidth - Appearance.sizes.hyprlandGapsOut * 2)

                    height: dock.isVertical
                        ? Math.min(dockContent.visualHeight + dockContent.dockPadding * 2, maxHeight - Appearance.sizes.hyprlandGapsOut * 2)
                        : dockContent.visualHeight + dockContent.dockPadding * 2

                    color: Appearance.colors.colLayer0
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                    radius: Appearance.rounding.large

                    DropArea {
                        id: fileDropArea
                        anchors.fill: parent

                        onEntered: (drag) => {
                            if (!drag.hasUrls) return
                            const url = drag.urls[0]?.toString() ?? ""
                            dockContent.externalDragIcon = dockContent.mimeIconFromPath(url)
                            dockContent.externalDragOver = true
                        }
                        onExited: {
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                        onDropped: (drop) => {
                            if (!drop.hasUrls) return
                            for (let i = 0; i < drop.urls.length; i++)
                                TaskbarApps.addPinnedFile(drop.urls[i])
                            drop.accept(Qt.CopyAction)
                            dockContent.externalDragIcon = ""
                            dockContent.externalDragOver = false
                        }
                    }

                    DockContent {
                        id: dockContent
                        anchors.fill: parent
                        isPinned: dock.pinned
                        currentScreen: dockRoot.screen
                        onTogglePinRequested: {
                            dock.pinned = !dock.pinned
                        }
                    }
                }
            }
        }
    }
}