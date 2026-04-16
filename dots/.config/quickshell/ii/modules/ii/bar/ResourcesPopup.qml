import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    // Helper function to format KB to GB
    function formatGB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        HeroCard {
            id: resourcesHero
            Layout.fillWidth: true
            adaptiveWidth: true
            icon: "developer_board"
            title: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            subtitle: ResourceUsage.cpuModel
            pillText: ResourceUsage.cpuTemp
            pillIcon: "device_thermostat"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: Appearance.colors.colSurfaceContainerHighest
            radius: 1
        }

        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                ResourceCard {
                    title: Translation.tr("RAM")
                    icon: "memory"
                    shapeString: "Clover4Leaf"
                    shapeColor: Appearance.colors.colSecondaryContainer
                    symbolColor: Appearance.colors.colOnSecondaryContainer

                    resourceName: Translation.tr("Used") 
                    resourceValueText: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`
                    resourcePercentage: ResourceUsage.memoryUsedPercentage
                    highlightColor: Appearance.colors.colSecondary
                }
                
                ResourceCard {
                    title: Translation.tr("Storage")
                    icon: "hard_drive"
                    shapeString: "Cookie9Sided"
                    shapeColor: Appearance.colors.colTertiaryContainer
                    symbolColor: Appearance.colors.colOnTertiaryContainer

                    resourceName: Translation.tr("Disk")
                    resourceValueText: `${root.formatGB(ResourceUsage.diskUsed).split(" ")[0]} / ${root.formatGB(ResourceUsage.diskTotal)}`
                    resourcePercentage: ResourceUsage.diskUsedPercentage
                    highlightColor: Appearance.colors.colTertiary
                }
            }
        }
    }
}
