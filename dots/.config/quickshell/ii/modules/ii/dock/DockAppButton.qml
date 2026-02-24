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
    
    // Sicurezza contro null pointer se appToplevel non è ancora caricato
    property bool appIsActive: appToplevel && appToplevel.toplevels.find(t => (t.activated == true)) !== undefined
    
    property int _desktopEntriesUpdateTrigger: 0

    readonly property bool isSeparator: appToplevel && appToplevel.appId === "SEPARATOR"
    property var desktopEntry: appToplevel ? DesktopEntries.heuristicLookup(appToplevel.appId) : null
    
    // FIXED: Leggiamo isVertical da appListRoot, evitando il ReferenceError su GlobalStates
    property bool isVertical: appListRoot ? appListRoot.isVertical : false
    
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            _desktopEntriesUpdateTrigger++;
            if (root.appToplevel) {
                root.desktopEntry = DesktopEntries.heuristicLookup(root.appToplevel.appId);
            }
        }
    }

    enabled: !isSeparator
    
    // FIXED: Forziamo i limiti massimi e minimi per impedire che il RippleButton espanda il separatore
    Layout.preferredWidth:  isSeparator ? (isVertical ? root.baseSize : 1) : root.baseSize
    Layout.preferredHeight: isSeparator ? (isVertical ? 1 : root.baseSize) : root.baseSize
    Layout.minimumWidth:    Layout.preferredWidth
    Layout.minimumHeight:   Layout.preferredHeight
    Layout.maximumWidth:    Layout.preferredWidth
    Layout.maximumHeight:   Layout.preferredHeight

    Loader {
        active: isSeparator
        anchors {
            fill: parent
            // Il margin inverte l'asse a seconda se il dock è verticale o orizzontale
            topMargin:    isVertical ? 0 : 8
            bottomMargin: isVertical ? 0 : 8
            leftMargin:   isVertical ? 8 : 0
            rightMargin:  isVertical ? 8 : 0
        }
        sourceComponent: DockSeparator {}
    }

    Loader {
        anchors.fill: parent
        active: appToplevel && appToplevel.toplevels.length > 0
        sourceComponent: MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                appListRoot.lastHoveredButton = root
                appListRoot.buttonHovered = true
                lastFocused = appToplevel.toplevels.length - 1
            }
            onExited: {
                if (appListRoot.lastHoveredButton === root) {
                    appListRoot.buttonHovered = false
                }
            }
        }
    }

    onClicked: {
        if (!appToplevel || appToplevel.toplevels.length === 0) {
            root.desktopEntry?.execute();
            return;
        }
        lastFocused = (lastFocused + 1) % appToplevel.toplevels.length
        appToplevel.toplevels[lastFocused].activate()
    }

    middleClickAction: () => {
        root.desktopEntry?.execute();
    }

    altAction: () => {
        if (appToplevel) {
            TaskbarApps.togglePin(appToplevel.appId);
        }
    }

    contentItem: Loader {
        active: !isSeparator
        sourceComponent: Item {
            anchors.centerIn: parent

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
                        root._desktopEntriesUpdateTrigger;
                        return Quickshell.iconPath(AppSearch.guessIcon(root.appToplevel.appId), "image-missing");
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
                        implicitWidth: (root.appToplevel.toplevels.length <= 3) ? 
                            root.countDotWidth : root.countDotHeight
                        implicitHeight: root.countDotHeight
                        color: appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                        Behavior on implicitWidth {
                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                        }
                    }
                }
            }
        }
    }
}