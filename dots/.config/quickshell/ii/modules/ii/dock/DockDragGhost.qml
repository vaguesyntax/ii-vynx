import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    width: 55
    height: 55

    property string draggedAppId: ""
    property bool willUnpin: false

    Item {
        anchors.fill: parent
        opacity: willUnpin ? 0.3 : 0.8

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        IconImage {
            id: ghostIcon
            anchors.centerIn: parent
            implicitSize: 45
            source: draggedAppId !== ""
                ? Quickshell.iconPath(AppSearch.guessIcon(draggedAppId), "image-missing")
                : ""

            transform: Scale {
                origin.x: ghostIcon.width / 2
                origin.y: ghostIcon.height / 2
                xScale: willUnpin ? 0.85 : 1.15
                yScale: willUnpin ? 0.85 : 1.15
                Behavior on xScale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }
                Behavior on yScale {
                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                }
            }
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