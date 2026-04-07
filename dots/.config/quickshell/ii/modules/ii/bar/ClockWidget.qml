import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 10
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        property bool compactMode: Config.options.bar.tooltips.compactPopups

        Loader {
            active: true
            sourceComponent: compactMode ? clockPopupCompact : clockPopup
        }
        Component {
            id: clockPopup
            ClockWidgetPopup {
                hoverTarget: mouseArea
            }
        }
        Component {
            id: clockPopupCompact
            ClockWidgetPopupCompact {
                hoverTarget: mouseArea
            }
        }
    }
}
