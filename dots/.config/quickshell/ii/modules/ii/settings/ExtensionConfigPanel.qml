import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    required property string extensionId
    required property var schema

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors { left: parent.left; right: parent.right }
        spacing: 0

        Repeater {
            model: {
                let items = []
                for (let key in root.schema) {
                    let entry = root.schema[key]
                    if (!entry || !entry.type) continue
                    items.push({ key: key, entry: entry })
                }
                return items
            }

            delegate: Item {
                required property var modelData
                readonly property string cfgKey: modelData.key
                readonly property var cfgEntry: modelData.entry
                Layout.leftMargin: 8
                Layout.rightMargin: 8

                Layout.fillWidth: true
                implicitHeight: loader.implicitHeight

                Loader {
                    id: loader
                    anchors { left: parent.left; right: parent.right }

                    sourceComponent: {
                        if (!cfgEntry || !cfgEntry.type) return undefined
                        switch (cfgEntry.type) {
                            case "bool":   return boolConfigComp
                            case "int":    return intConfigComp
                            case "float":
                            case "slider": return sliderConfigComp
                            case "enum":   return enumConfigComp
                            case "string": return stringConfigComp
                            default:       return undefined
                        }
                    }

                    onLoaded: {
                        if (item) {
                            item.cfgKey = Qt.binding(() => cfgKey)
                            item.cfgEntry = Qt.binding(() => cfgEntry)
                            item.extId = Qt.binding(() => root.extensionId)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: boolConfigComp
        ConfigSwitch {
            property string cfgKey
            property var cfgEntry
            property string extId

            Connections {
                target: ExtensionManager

                onExtensionConfigsChanged: {
                    checked = ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? false
                }
            }

            buttonIcon: cfgEntry?.icon ?? ""
            text: cfgEntry?.label ?? cfgKey ?? ""
            checked: ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? false
            onCheckedChanged: {
                if (extId && cfgKey) ExtensionManager.setExtensionConfig(extId, cfgKey, checked)
            }
        }
    }

    Component {
        id: intConfigComp
        ConfigSpinBox {
            property string cfgKey
            property var cfgEntry
            property string extId

            Connections {
                target: ExtensionManager

                onExtensionConfigsChanged: {
                    value = ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? 0
                }
            }

            icon: cfgEntry?.icon ?? ""
            text: cfgEntry?.label ?? cfgKey ?? ""
            value: ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? 0
            from: cfgEntry?.min ?? 0
            to: cfgEntry?.max ?? 999999
            stepSize: cfgEntry?.stepSize ?? 1
            onValueChanged: {
                if (extId && cfgKey) ExtensionManager.setExtensionConfig(extId, cfgKey, value)
            }
        }
    }

    Component {
        id: sliderConfigComp
        ConfigSlider {
            property string cfgKey
            property var cfgEntry
            property string extId

            Connections {
                target: ExtensionManager

                onExtensionConfigsChanged: {
                    value = ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? 0
                }
            }

            buttonIcon: cfgEntry?.icon ?? ""
            text: cfgEntry?.label ?? cfgKey ?? ""
            value: ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? 0
            from: cfgEntry?.from ?? cfgEntry?.min ?? 0
            to: cfgEntry?.to ?? cfgEntry?.max ?? 100
            onValueChanged: {
                if (extId && cfgKey) ExtensionManager.setExtensionConfig(extId, cfgKey, value)
            }
        }
    }

    Component {
        id: enumConfigComp
        ConfigSelectionArray {
            property string cfgKey
            property var cfgEntry
            property string extId

            Connections {
                target: ExtensionManager

                onExtensionConfigsChanged: {
                    currentValue = ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? ""
                }
            }

            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8

            options: cfgEntry?.options ?? []
            currentValue: ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? ""
            onSelected: newValue => {
                if (extId && cfgKey) ExtensionManager.setExtensionConfig(extId, cfgKey, newValue)
            }
        }
    }

    Component {
        id: stringConfigComp
        Item {
            property string cfgKey
            property var cfgEntry
            property string extId

            implicitHeight: 44
            Layout.fillWidth: true

            Connections {
                target: ExtensionManager

                onExtensionConfigsChanged: {
                    textField.text = ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? ""
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                OptionalMaterialSymbol {
                    icon: cfgEntry?.icon ?? ""
                    iconSize: Appearance.font.pixelSize.larger
                }
                StyledText {
                    text: cfgEntry?.label ?? cfgKey ?? ""
                    color: Appearance.colors.colOnSecondaryContainer
                    Layout.fillWidth: true
                }
                TextField {
                    Layout.preferredWidth: 120
                    text: ExtensionManager.extensionConfigs?.[extId]?.[cfgKey] ?? cfgEntry?.default ?? ""
                    onEditingFinished: {
                        if (extId && cfgKey) ExtensionManager.setExtensionConfig(extId, cfgKey, text)
                    }
                }
            }
        }
    }
}
