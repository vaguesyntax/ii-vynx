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

    function computeSizes(opts) {
        const gapsOut = opts.gapsOut
        const barConflicts = opts.barActive && (opts.isVertical !== opts.barIsVertical)
        
        const barOffset = barConflicts ? (opts.isVertical ? opts.barThickness : 0) : 0
        const barOffsetH = barConflicts ? (!opts.isVertical ? opts.barThickness : 0) : 0

        const maxW = Math.max(1, opts.availableW - gapsOut * 2 - barOffsetH)
        const maxH = Math.max(1, opts.availableH - gapsOut * 2 - barOffset)

        const unloadedW = maxW
        const unloadedH = maxH

        const contentW = opts.isLoaded ? opts.contentVisualWidth : (opts.isVertical ? 60 : unloadedW)
        const contentH = opts.isLoaded ? opts.contentVisualHeight : (opts.isVertical ? unloadedH : 60)
        const dockPadding = opts.isLoaded ? opts.dockPadding : 0

        return {
            maxWidth: maxW,
            maxHeight: maxH,
            dockWidth: opts.isVertical ? contentW + dockPadding * 2 + gapsOut * 2 : Math.min(contentW + dockPadding * 2 + gapsOut * 2, maxW),
            dockHeight: opts.isVertical ? Math.min(contentH + dockPadding * 2 + gapsOut * 2, maxH) : contentH + dockPadding * 2 + gapsOut * 2,
            dockThickness: opts.isVertical ? contentW + dockPadding * 2 + gapsOut * 2 : contentH + dockPadding * 2 + gapsOut * 2,
            backgroundWidth:  Math.max(1, opts.isVertical ? contentW : Math.min(contentW, maxW - gapsOut * 2)),
            backgroundHeight: Math.max(1, opts.isVertical ? Math.min(contentH, maxH - gapsOut * 2) : contentH)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockRoot
            required property var modelData
            screen: modelData
            
            visible: !GlobalStates.screenLocked && !positionChanging 
            // using a flag for positionChanging is not really necessary, but it prevents some graphical issues caused by qml when the dock is moving

            readonly property real availableW: screen?.width ?? 1920
            readonly property real availableH: screen?.height ?? 1080
            readonly property bool barActive: GlobalStates.barOpen
            readonly property bool barIsVertical: Config.options?.bar?.vertical ?? false
            readonly property real barThickness: barActive ? (barIsVertical ? (Config.options?.bar?.sizes?.width ?? Appearance.sizes.verticalBarWidth) : (Config.options?.bar?.sizes?.height ?? Appearance.sizes.barHeight)) : 0

            readonly property bool isVertical: dock.isVertical
            readonly property real dockThickness: isVertical ? dockRoot.sizing.dockWidth : dockRoot.sizing.dockHeight

            // reveal is set imperatively (not as a binding) to avoid a binding loop:
            property bool reveal: false
            property bool positionChanging: false
            readonly property bool readyToReveal: reveal && (dockLoader.item?.ready ?? false)

            function updateReveal() {
                var shouldReveal = dock.pinned
                    || (dockMouseArea.containsMouse || graceTimer.running)
                    || (dockLoader.item?.requestDockShow ?? false)
                    || (Config.options?.dock?.revealOnEmptyWorkspace && workspaceEmpty)
                if (reveal !== shouldReveal)
                    reveal = shouldReveal
            }

            // TODO: check for multi-monitor situations
            readonly property bool workspaceEmpty: {
                const wsId = HyprlandData.activeWorkspace?.id ?? -1
                if (wsId === -1) return true
                return HyprlandData.hyprlandClientsForWorkspace(wsId).length === 0
            }

            onWorkspaceEmptyChanged: updateReveal()

            readonly property var sizing: dock.computeSizes({
                gapsOut: Appearance.sizes.hyprlandGapsOut,
                isVertical: dock.isVertical,
                barActive: dockRoot.barActive,
                barIsVertical: dockRoot.barIsVertical,
                barThickness: dockRoot.barThickness,
                availableW: dockRoot.availableW,
                availableH: dockRoot.availableH,
                isLoaded: dockLoader.activeAsync,
                contentVisualWidth: dockLoader.item?.contentVisualWidth ?? 0,
                contentVisualHeight: dockLoader.item?.contentVisualHeight ?? 0,
                dockPadding: dockLoader.item?.dockPadding ?? 0
            })

            implicitWidth: Math.max(1, dockRoot.sizing.dockWidth)
            implicitHeight: Math.max(1, dockRoot.sizing.dockHeight)

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
                id: unloadTimer
                interval: Appearance.animation.elementMoveFast.duration + 100 
            }

            // Grace timer: keeps the dock revealed for 1 second after the initial
            // hover trigger, giving the user time to reach the dock as it expands.
            Timer {
                id: graceTimer
                interval: 1000
                onRunningChanged: dockRoot.updateReveal()
            }

            onRevealChanged: {
                if (!reveal) unloadTimer.restart()
                else unloadTimer.stop()
            }

            // Watch dock.pinned changes to update reveal
            Connections {
                target: dock
                function onPinnedChanged() { dockRoot.updateReveal() }
                function onDockEffectivePositionChanged() {
                    dockRoot.positionChanging = true
                    positionChangeTimer.restart()
                }
            }

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: dockRoot.positionChanging = false
            }

            HyprlandFocusGrab {
                id: dragFocusGrab
                active: dockLoader.activeAsync && (dockLoader.item?.dragState ?? "idle") !== "idle"
                windows: [dockRoot]
                onCleared: {
                    if (dockLoader.item && dockLoader.item.dragState !== "idle") {
                        dockLoader.item.endDrag()
                        dockLoader.item.endFileDrag()
                    }
                }
            }

            MouseArea {
                id: dockMouseArea
                hoverEnabled: true

                // When the mouse enters the hover strip and the dock is hidden,
                // start the grace timer so the dock stays open for 1 second while
                // it animates and the user moves the cursor onto it.
                onContainsMouseChanged: {
                    if (containsMouse && !dockRoot.reveal && !dock.pinned) {
                        graceTimer.restart()
                    }
                    // Update reveal imperatively to avoid binding loop
                    dockRoot.updateReveal()
                }

                property real hiddenOffset: dockRoot.dockThickness - (Config.options?.dock.hoverRegionHeight ?? 2)
                property real currentOffset: dockRoot.readyToReveal ? 0 : hiddenOffset

                width: dock.isVertical ? dockRoot.dockThickness : dockRoot.sizing.dockWidth
                height: dock.isVertical ? dockRoot.sizing.dockHeight : dockRoot.dockThickness

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

                Item {
                    id: dockContentHost
                    anchors.fill: parent

                    LazyLoader {
                        id: dockLoader
                        loading: true
                        active: dockRoot.reveal || unloadTimer.running

                        Item {
                            id: wrapper
                            parent: dockContentHost
                            anchors.fill: parent

                            readonly property real contentVisualWidth: content.visualWidth
                            readonly property real contentVisualHeight: content.visualHeight
                            readonly property real dockPadding: content.dockPadding
                            readonly property string dragState: content.dragState
                            readonly property bool requestDockShow: content.requestDockShow
                            readonly property bool ready: content.ready

                            function endDrag() { content.endDrag() }
                            function endFileDrag() { content.endFileDrag() }
                            function mimeIconFromPath(p) { return content.mimeIconFromPath(p) }

                            // When requestDockShow changes inside the loaded content, update reveal
                            onRequestDockShowChanged: dockRoot.updateReveal()

                            // Only show once DockContent itself is ready 
                            readonly property bool contentReady: content.ready && !dockRoot.positionChanging
                            opacity: contentReady ? 1.0 : 0.0

                            StyledRectangularShadow { 
                                target: visualBackground
                            }

                            Rectangle {
                                id: visualBackground
                                anchors.centerIn: parent
                                width: dockRoot.sizing.backgroundWidth
                                height: dockRoot.sizing.backgroundHeight
                                color: Appearance.colors.colLayer0
                                border.width: 1
                                border.color: Appearance.colors.colLayer0Border
                                radius: Appearance.rounding.large

                                DropArea {
                                    id: fileDropArea
                                    anchors.fill: parent
                                    keys: ["text/uri-list"]
                                    enabled: content.dragActive === false

                                    onEntered: (drag) => {
                                        if (!drag.hasUrls) return
                                        const url = drag.urls[0]?.toString() ?? ""
                                        content.externalDragIcon = content.mimeIconFromPath(url)
                                        content.externalDragOver = true
                                    }
                                    onExited: {
                                        content.externalDragIcon = ""
                                        content.externalDragOver = false
                                    }
                                    onDropped: (drop) => {
                                        if (!drop.hasUrls) return
                                        for (let i = 0; i < drop.urls.length; i++)
                                            TaskbarApps.addPinnedFile(drop.urls[i])
                                        drop.accept(Qt.CopyAction)
                                        content.externalDragIcon = ""
                                        content.externalDragOver = false
                                    }
                                }

                                DockContent {
                                    id: content
                                    anchors.fill: parent
                                    isPinned: dock.pinned
                                    currentScreen: dockRoot.screen
                                    onTogglePinRequested: dock.pinned = !dock.pinned
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
