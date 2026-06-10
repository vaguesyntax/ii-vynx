import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: root
    required property var modelData
    required property int listCount
    required property int index
    property var ext: modelData
    property var updateState: ExtensionManager.updateStates[ext.id] || {}
    property bool updateChecking: updateState.checking || false
    property bool updateAvailable: updateState.updateAvailable || false
    property bool expanded: false
    readonly property bool hasConfigSchema: ext.configSchema && Object.keys(ext.configSchema).length > 0
    readonly property string _auditState: {
        ExtensionAudit.auditDbVersion
        if (!ExtensionAudit.auditDatabaseReady) return ""
        return ExtensionAudit.getExtensionAuditState(ext.id)
    }

    property real topRadius: {
        if (listCount == 1 || index == 0) return Appearance.rounding.large
        return Appearance.rounding.verysmall
    }
    property real bottomRadius: {
        if (listCount == 1 || index == listCount - 1) return Appearance.rounding.large
        return Appearance.rounding.verysmall
    }

    Layout.fillWidth: true
    implicitHeight: 80 + panelArea.implicitHeight
    clip: true

    Rectangle {
        anchors.fill: parent
        topLeftRadius: topRadius
        topRightRadius: topRadius
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius
        color: Appearance.colors.colLayer1

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                spacing: 12

                MaterialShape {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 60
                    shapeString: ext.shapeString || ""
                    color: iconArea.containsMouse && !iconArea.held ? Appearance.colors.colPrimaryContainerHover
                        : ext.enabled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: iconArea.containsMouse ? "info" : (ext.icon || "extension")
                        iconSize: 28
                        color: iconArea.containsMouse ? Appearance.colors.colOnPrimaryContainer
                            : ext.enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    }

                    MouseArea {
                        id: iconArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: {
                            let url = ext.htmlUrl || ext.repoUrl
                            if (url) Qt.openUrlExternally(url)
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StyledText {
                            text: ext.name
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                        ExtensionBadge {
                            label: Translation.tr("Official")
                            tooltip: Translation.tr("Created by the ii-vynx developer")
                            visible: ext.repoUrl && ext.repoUrl.includes("vaguesyntax")
                        }
                        ExtensionBadge {
                            icon: "link"
                            tooltip: Translation.tr("Custom URL — installed from a custom link")
                            visible: ext.isCustomUrl
                        }
                        ExtensionBadge {
                            icon: "folder"
                            tooltip: Translation.tr("Local path extension — files linked from your filesystem")
                            visible: ext.isLocal
                        }
                    }

                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: "v" + ext.version + " by " + ext.author
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            visible: ext.repoUrl && updateChecking
                            text: Translation.tr("Checking update...")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colTertiary
                        }
                        StyledText {
                            visible: ext.repoUrl && updateAvailable && !updateChecking
                            text: Translation.tr("Update available!")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            visible: ext.repoUrl && !updateChecking && !updateAvailable && !!updateState.localHash
                            text: Translation.tr("Up to date")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                StyledSwitch {
                    checked: ext.enabled
                    onClicked: ExtensionManager.toggleExtension(ext.id, !ext.enabled)
                }

                RippleButton {
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    visible: ext.enabled
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer2

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.expanded ? "expand_less" : "expand_more"
                        iconSize: 20
                        color: Appearance.colors.colSubtext
                    }
                    onClicked: root.expanded = !root.expanded
                }
            }

            Item {
                id: panelArea
                Layout.fillWidth: true
                implicitHeight: expanded ? panelContent.implicitHeight : 0
                clip: true
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                ColumnLayout {
                    id: panelContent
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: 0

                    ExtensionConfigPanel {
                        id: configPanel
                        Layout.fillWidth: true
                        extensionId: ext.id
                        schema: ext.configSchema || {}
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        spacing: 8

                        StyledText {
                            Layout.leftMargin: 8
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: ext.description || ""
                            visible: ext.description && ext.description.length > 0
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        RippleButton {
                            visible: hasConfigSchema
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: Translation.tr("Reset to defaults")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            onClicked: ExtensionManager.resetExtensionConfig(ext.id)
                        }

                        RippleButton {
                            implicitWidth: 80
                            implicitHeight: 28
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            visible: ext.repoUrl && ext.repoUrl.length > 0 && !ext.isLocal
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: updateChecking ? "..." : (updateAvailable ? Translation.tr("Update") : Translation.tr("Check"))
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            onClicked: {
                                if (updateAvailable) {
                                    ExtensionManager.updateExtension(ext.id)
                                } else {
                                    ExtensionManager.checkUpdate(ext.id)
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 80
                            implicitHeight: 28
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colTertiaryContainer
                            colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                            visible: ext.isLocal
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Translation.tr("Reload")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnTertiaryContainer
                            }
                            onClicked: ExtensionManager.reinstallLocalExtension(ext.id)
                        }

                        RippleButton {
                            implicitWidth: 80
                            implicitHeight: 28
                            padding: 0
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colErrorContainer
                            colBackgroundHover: Appearance.colors.colErrorContainerHover
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: Translation.tr("Remove")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnErrorContainer
                            }
                            onClicked: ExtensionManager.uninstallExtension(ext.id)
                        }
                    }
                }
            }
        }
    }
}
