import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MouseArea {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    implicitWidth: 20
    implicitHeight: 20
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu) menu.open();
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.text = TrayService.getTooltipForItem(root.item);
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            anchor {
                window: root.QsWindow.window
                rect.x: {
                    var globalPos = root.mapToGlobal(0, 0);
                    return globalPos.x + (Config.options.bar.vertical ? 0 : root.width / 2);
                }
                rect.y: {
                    var globalPos = root.mapToGlobal(0, 0);
                    return globalPos.y + (Config.options.bar.vertical ? root.height / 2 : 0);
                }
                rect.height: root.height
                rect.width: root.width
                edges: {
                    if (Config.options.bar.vertical) {
                        return Config.options.bar.bottom ? 
                            (Edges.Middle | Edges.Right) :  // right bar - vertical center
                            (Edges.Middle | Edges.Left);    // left bar - vertical center
                    } else {
                        return Config.options.bar.bottom ? 
                            (Edges.Top | Edges.Center) :    // bottom bar - horizontal center
                            (Edges.Bottom | Edges.Center);  // top bar - horizontal center
                    }
                }
                gravity: {
                    if (Config.options.bar.vertical) {
                        return Config.options.bar.bottom ? 
                            (Edges.Middle | Edges.Right) : 
                            (Edges.Middle | Edges.Left);
                    } else {
                        return Config.options.bar.bottom ? 
                            (Edges.Top | Edges.Center) : 
                            (Edges.Bottom | Edges.Center);
                    }
                }
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }


    IconImage {
        id: trayIcon
        visible: !Config.options.tray.monochromeIcons
        source: root.item.icon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    Loader {
        active: Config.options.tray.monochromeIcons
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

}
