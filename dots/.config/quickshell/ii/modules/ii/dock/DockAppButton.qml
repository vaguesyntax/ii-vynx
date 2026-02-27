import qs.services
import qs.modules.common
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

DockButton {
    id: root
    property var appToplevel
    property var appListRoot
    property int lastFocused: -1
    property real iconSize: 35
    property real countDotWidth: 10
    property real countDotHeight: 4

    property bool appIsActive: appToplevel && appToplevel.toplevels.find(t => t.activated === true) !== undefined
    property int _desktopEntriesUpdateTrigger: 0

    readonly property bool isSeparator: appToplevel && appToplevel.appId === "SEPARATOR"
    property var desktopEntry: appToplevel ? DesktopEntries.heuristicLookup(appToplevel.appId) : null
    property bool isVertical: appListRoot ? appListRoot.isVertical : false

    readonly property bool isDragging: appListRoot?.draggedAppId === appToplevel?.appId

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++
            if (root.appToplevel)
                root.desktopEntry = DesktopEntries.heuristicLookup(root.appToplevel.appId)
        }
    }

    enabled: !isSeparator

    Layout.preferredWidth:  isSeparator ? (isVertical ? root.baseSize : 1) : root.baseSize
    Layout.preferredHeight: isSeparator ? (isVertical ? 1 : root.baseSize) : root.baseSize
    Layout.minimumWidth:    Layout.preferredWidth
    Layout.minimumHeight:   Layout.preferredHeight
    Layout.maximumWidth:    Layout.preferredWidth
    Layout.maximumHeight:   Layout.preferredHeight

    implicitWidth:  isDragging ? 0 : root.baseSize
    implicitHeight: isDragging ? 0 : root.baseSize

    Behavior on implicitWidth  { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root) }
    Behavior on implicitHeight { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root) }

    opacity: isDragging ? 0.0 : 1.0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            topMargin:    isVertical ? 0 : 8
            bottomMargin: isVertical ? 0 : 8
            leftMargin:   isVertical ? 8 : 0
            rightMargin:  isVertical ? 8 : 0
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
            if (!pressed || !root.appToplevel?.pinned) return
            if (!dragStarted) {
                const dist = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
                if (dist < 10) return
                dragStarted = true
                wasDragging = true
                appListRoot.startDrag(root.appToplevel.appId, root)
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
        if (appToplevel)
            TaskbarApps.togglePin(appToplevel.appId)
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.fill: parent

            Loader {
                id: iconImageLoader
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
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

            RowLayout {
                spacing: 3
                anchors {
                    top: iconImageLoader.bottom
                    topMargin: 2
                    horizontalCenter: parent.horizontalCenter
                }
                Repeater {
                    model: root.appToplevel ? Math.min(root.appToplevel.toplevels.length, 3) : 0
                    delegate: Rectangle {
                        required property int index
                        radius: Appearance.rounding.full
                        implicitWidth: root.appToplevel.toplevels.length <= 3 ?
                            root.countDotWidth : root.countDotHeight
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
    }
}