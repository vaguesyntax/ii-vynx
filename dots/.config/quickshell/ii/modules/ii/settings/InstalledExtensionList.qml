import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

ColumnLayout {
    id: root

    readonly property var installedList: {
        let list = []
        for (let id in ExtensionManager.installedExtensions) {
            if (!ExtensionManager._blockedIds[id]) {
                list.push(ExtensionManager.installedExtensions[id])
            }
        }
        return list
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 20
        visible: root.installedList.length > 0
        text: Translation.tr("Installed")
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: Font.Medium
        color: Appearance.colors.colOnLayer0
    }

    Repeater {
        model: root.installedList
        delegate: InstalledExtensionCard {
            listCount: root.installedList.length
        }
    }
}
