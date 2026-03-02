import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    width:  Config.options?.dock.height ?? 60
    height: Config.options?.dock.height ?? 60

    property string draggedAppId: ""
    property bool willUnpin: false

    Item {
        anchors.fill: parent
        opacity: willUnpin ? 0.3 : 1
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        IconImage {
            id: ghostIcon
            anchors.centerIn: parent
            implicitSize: (Config.options?.dock.height ?? 60) * 0.90
            source: draggedAppId !== "" ? Quickshell.iconPath(AppSearch.guessIcon(draggedAppId), "image-missing")
                : ""
        }

        Loader {
            active: Config.options.dock.monochromeIcons
            anchors.fill: ghostIcon
            sourceComponent: Item {
                Desaturate {
                    id: desaturatedIcon
                    visible: false
                    anchors.fill: parent
                    source: ghostIcon
                    desaturation: 0.8
                }
                ColorOverlay {
                    anchors.fill: desaturatedIcon
                    source: desaturatedIcon
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                }
            }
        }
    }
}