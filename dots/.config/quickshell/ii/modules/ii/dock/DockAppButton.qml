import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    // Index of this delegate within the Repeater model.
    // Used to compute the shift transform during drag.
    property int delegateIndex: -1
    property int lastFocused: -1
    property real iconSize: (Config.options?.dock.height ?? 60) * 0.85
    property real countDotWidth:  (Config.options?.dock.height ?? 60) * 0.17
    property real countDotHeight: (Config.options?.dock.height ?? 60) * 0.07

    property bool appIsActive: appToplevel && appToplevel.toplevels.find(t => t.activated === true) !== undefined
    property int _desktopEntriesUpdateTrigger: 0

    readonly property bool isSeparator: appToplevel && appToplevel.appId === "SEPARATOR"
    property var desktopEntry: appToplevel ? DesktopEntries.heuristicLookup(appToplevel.appId) : null
    property bool isVertical: appListRoot ? appListRoot.isVertical : false

    readonly property bool isDragging: appListRoot?.draggedAppId === appToplevel?.appId

    // ── Shift transform ───────────────────────────────────────────
    // How many pixels this delegate should visually shift to make room
    // for the dragged icon. The model order never changes during drag;
    // only this visual offset moves, animated via Behavior.
    readonly property real shiftOffset: {
        if (!appListRoot || appListRoot.draggedIndex < 0) return 0
        if (delegateIndex === appListRoot.draggedIndex) return 0

        const draggedAppId  = appListRoot.draggedAppId
        const draggedPinned = Config.options.dock.pinnedApps.includes(draggedAppId)
        const myAppId       = appToplevel?.appId ?? ""
        const myPinned      = Config.options.dock.pinnedApps.includes(myAppId)
        const dragIdx       = appListRoot.draggedIndex
        const dropIdx       = appListRoot.dropTargetIndex
        const myIdx         = delegateIndex
        const step          = root.buttonSize + (appListRoot.dockPadding ?? 0)

        if (draggedPinned) {
            // Reordering within pinned zone — only pinned apps shift, separator stays
            if (isSeparator) return 0
            if (!myPinned) return 0
            if (dragIdx < dropIdx && myIdx > dragIdx && myIdx <= dropIdx) return -step
            if (dragIdx > dropIdx && myIdx >= dropIdx && myIdx < dragIdx) return  step
            return 0
        } else {
            // Dragging unpinned into pinned zone —
            // separator AND unpinned apps shift right to make room
            if (myPinned) return 0
            if (myIdx > dropIdx) return step
            return 0
        }
    }

    transform: Translate {
        x: root.isVertical ? 0 : root.shiftOffset
        y: root.isVertical ? root.shiftOffset : 0

        Behavior on x {
            enabled: !appListRoot?.suppressAnimation
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !appListRoot?.suppressAnimation
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++
            if (root.appToplevel)
                root.desktopEntry = DesktopEntries.heuristicLookup(root.appToplevel.appId)
        }
    }

    enabled: !isSeparator

    width:  isSeparator ? (isVertical ? (Config.options?.dock.height ?? 60) * 0.83 : 1) : root.buttonSize
    height: isSeparator ? (isVertical ? 1 : (Config.options?.dock.height ?? 60) * 0.83) : root.buttonSize
    opacity: isDragging ? 0.0 : 1.0

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
        }
        sourceComponent: DockSeparator {}
    }

    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true

        property real pressedX: 0
        property real pressedY: 0
        property bool dragStarted: false
        property bool wasDragging: false

        onEntered: {
            if (appToplevel?.toplevels?.length > 0) {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
            } else {
                appListRoot.buttonHovered = false
                appListRoot.popupIsResizing = false
            }
            lastFocused = appToplevel.toplevels.length - 1
        }
        onExited: {
            if (appListRoot?.lastHoveredButton === root)
                appListRoot.buttonHovered = false
        }

        onPressed: (mouse) => {
            pressedX = mouse.x
            pressedY = mouse.y
            dragStarted = false
            wasDragging = false
        }

        onPositionChanged: (mouse) => {
            if (!pressed || root.isSeparator || !root.appToplevel) return
            if (!dragStarted) {
                const dist = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                if (dist < 10) return
                dragStarted = true
                wasDragging = true
                // Pass delegateIndex so DockApps can track position by index.
                appListRoot.startDrag(root.appToplevel.appId, root, root.delegateIndex)
            }
            if (dragStarted) {
                const pos = mapToItem(appListRoot, mouse.x, mouse.y)
                appListRoot.moveDragGhost(pos.x, pos.y)
            }
        }

        onReleased: {
            if (dragStarted) {
                appListRoot.endDrag()
                dragStarted = false
            }
        }

        onClicked: (mouse) => {
            if (wasDragging) {
                wasDragging = false
                return
            }
            if (!appToplevel || appToplevel.toplevels.length === 0) {
                root.desktopEntry?.execute()
                return
            }
            lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
            appToplevel.toplevels[lastFocused].activate()
        }
    }

    middleClickAction: () => root.desktopEntry?.execute()

    altAction: () => {
        appListRoot.buttonHovered = false
        appListRoot.lastHoveredButton = null
        dockContextMenu.open()
    }

    DockContextMenu {
        id: dockContextMenu
        appToplevel: root.appToplevel
        desktopEntry: root.desktopEntry
        anchorItem: root
    }

    Connections {
        target: dockContextMenu
        function onActiveChanged() {
            if (appListRoot)
                appListRoot.anyContextMenuOpen = dockContextMenu.active
        }
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.fill: parent

            Loader {
                id: iconImageLoader
                anchors.centerIn: parent
                active: !root.isSeparator
                sourceComponent: IconImage {
                    source: {
                        root._desktopEntriesUpdateTrigger
                        return Quickshell.iconPath(AppSearch.guessIcon(root.appToplevel.appId), "image-missing")
                    }
                    implicitSize: root.iconSize
                }
            }

            Loader {
                active: Config.options.dock.monochromeIcons
                anchors.fill: iconImageLoader
                sourceComponent: Item {
                    Desaturate {
                        id: desaturatedIcon
                        visible: false
                        anchors.fill: parent
                        source: iconImageLoader
                        desaturation: 0.8
                    }
                    ColorOverlay {
                        anchors.fill: desaturatedIcon
                        source: desaturatedIcon
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    }
                }
            }

            Loader {
                id: dotsLoader
                visible: root.appToplevel && root.appToplevel.toplevels.length > 0
                sourceComponent: root.isVertical ? columnDots : rowDots

                state: GlobalStates.dockEffectivePosition

                states: [
                    State {
                        name: "bottom"
                        AnchorChanges {
                            target: dotsLoader
                            anchors.top: parent.bottom
                            anchors.bottom: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: iconImageLoader.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dotsLoader; anchors.topMargin: appListRoot.dockPadding / 2 - (root.countDotHeight + root.countDotWidth) / 4 }
                    },
                    State {
                        name: "top"
                        AnchorChanges {
                            target: dotsLoader
                            anchors.bottom: parent.top
                            anchors.top: undefined
                            anchors.left: undefined
                            anchors.right: undefined
                            anchors.horizontalCenter: iconImageLoader.horizontalCenter
                            anchors.verticalCenter: undefined
                        }
                        PropertyChanges { target: dotsLoader; anchors.bottomMargin: appListRoot.dockPadding / 2 - (root.countDotHeight + root.countDotWidth) / 4 }
                    },
                    State {
                        name: "left"
                        AnchorChanges {
                            target: dotsLoader
                            anchors.right: parent.left
                            anchors.left: undefined
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: iconImageLoader.verticalCenter
                        }
                        PropertyChanges { target: dotsLoader; anchors.rightMargin: appListRoot.dockPadding / 2 - root.countDotHeight / 2 }
                    },
                    State {
                        name: "right"
                        AnchorChanges {
                            target: dotsLoader
                            anchors.left: parent.right
                            anchors.right: undefined
                            anchors.top: undefined
                            anchors.bottom: undefined
                            anchors.horizontalCenter: undefined
                            anchors.verticalCenter: iconImageLoader.verticalCenter
                        }
                        PropertyChanges { target: dotsLoader; anchors.leftMargin: appListRoot.dockPadding / 2 - root.countDotHeight / 2 }
                    }
                ]
            }

            Component {
                id: rowDots
                RowLayout {
                    spacing: 3
                    Repeater {
                        model: root.appToplevel ? Math.min(root.appToplevel.toplevels.length, 3) : 0
                        delegate: Rectangle {
                            required property int index
                            radius: Appearance.rounding.full
                            implicitWidth:  root.appToplevel.toplevels.length <= 3 ? root.countDotWidth : root.countDotHeight
                            implicitHeight: root.countDotHeight
                            color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(root)
                            }
                            Behavior on implicitWidth {
                                animation: Appearance.animation.elementMove.numberAnimation.createObject(root)
                            }
                        }
                    }
                }
            }

            Component {
                id: columnDots
                ColumnLayout {
                    spacing: 3
                    Repeater {
                        model: root.appToplevel ? Math.min(root.appToplevel.toplevels.length, 3) : 0
                        delegate: Rectangle {
                            required property int index
                            radius: Appearance.rounding.full
                            implicitWidth:  root.countDotHeight
                            implicitHeight: root.appToplevel.toplevels.length <= 3 ? root.countDotWidth : root.countDotHeight
                            color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(root)
                            }
                            Behavior on implicitHeight {
                                animation: Appearance.animation.elementMove.numberAnimation.createObject(root)
                            }
                        }
                    }
                }
            }
        }
    }
}