import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
Item {
    id: root
    required property var modelData
    required property int index

    readonly property var ext: modelData
    readonly property bool isInstalled: {
        let installed = ExtensionManager.installedExtensions
        for (let id in installed) {
            if (installed[id].name === ext.name || installed[id].id === ext.name) return true
        }
        return false
    }
    readonly property bool isEnabled: {
        let installed = ExtensionManager.installedExtensions
        for (let id in installed) {
            if ((installed[id].name === ext.name || installed[id].id === ext.name) && installed[id].enabled) return true
        }
        return false
    }

    Layout.fillWidth: true
    Layout.preferredHeight: 90
    visible: true

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: (isEnabled || ext.owner === "vaguesyntax") ? 1 : 0
        border.color: isEnabled
            ? Appearance.colors.colPrimary
            : (ext.owner === "vaguesyntax" ? Appearance.colors.colSecondary : "transparent")

        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer3
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "extension"
                    iconSize: 28
                    color: Appearance.colors.colSubtext
                }
                Image {
                    anchors.fill: parent
                    visible: ext.hasManifest && ext.manifest && ext.manifest.coverArt
                    source: ext.hasManifest && ext.manifest && ext.manifest.coverArt ? ext.manifest.coverArt : ""
                    fillMode: Image.PreserveAspectCrop
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    StyledText {
                        text: ext.manifest && ext.manifest.name ? ext.manifest.name : ext.name
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        visible: ext.repoUrl && ext.repoUrl.includes("vaguesyntax")
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer
                        implicitWidth: childrenRect.width + 20
                        implicitHeight: childrenRect.height + 8
                        StyledText {
                            x: 3; y: 1
                            text: Translation.tr("Official")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnSecondaryContainer
                            anchors.centerIn: parent
                        }
                        HoverHandler {
                            id: hoverOff
                        }
                        StyledToolTip { 
                            extraVisibleCondition: hoverOff.hovered
                            text: Translation.tr("Created by the ii-vynx developer") 
                        }
                    }
                    Rectangle {
                        visible: ExtensionManager.recommendedExtensions.includes(ext.name)
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colTertiaryContainer
                        implicitWidth: childrenRect.width + 20
                        implicitHeight: childrenRect.height + 8
                        StyledText {
                            x: 3; y: 1
                            text: Translation.tr("Recommended")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnTertiaryContainer
                            anchors.centerIn: parent
                        }
                        HoverHandler {
                            id: hoverRec
                        }
                        StyledToolTip { 
                            extraVisibleCondition: hoverRec.hovered
                            text: Translation.tr("Recommended by the ii-vynx developer based on user feedback") 
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: ext.manifest && ext.manifest.description ? ext.manifest.description : ext.description
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    spacing: 6
                    StyledText {
                        text: "★ " + ext.stars
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colTertiary
                    }
                    StyledText {
                        visible: ext.hasManifest
                        text: "• " + (ext.manifest ? (ext.manifest.version || "?") : "?")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        visible: ext.manifestError !== null
                        text: "• " + Translation.tr("No manifest")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colError
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                spacing: 4

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 80
                    implicitHeight: 28
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colSecondaryContainer
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Translation.tr("Info")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    onClicked: Qt.openUrlExternally(ext.htmlUrl)
                }

                RippleButton {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: 80
                    implicitHeight: 28
                    padding: 0
                    buttonRadius: Appearance.rounding.full
                    colBackground: isInstalled ? Appearance.colors.colError : Appearance.colors.colPrimaryContainer
                    colBackgroundHover: isInstalled ? Appearance.colors.colErrorHover : Appearance.colors.colPrimaryContainerHover
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: isInstalled ? Translation.tr("Remove") : Translation.tr("Install")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: isInstalled ? Appearance.colors.colOnError : Appearance.colors.colOnPrimaryContainer
                    }
                    onClicked: {
                        if (isInstalled) {
                            for (let id in ExtensionManager.installedExtensions) {
                                let e = ExtensionManager.installedExtensions[id]
                                if (e.name === ext.name || e.id === ext.name) {
                                    ExtensionManager.uninstallExtension(id)
                                    break
                                }
                            }
                        } else {
                            ExtensionManager.installExtension(ext.repoUrl, ext.name, ext.defaultBranch || "main")
                        }
                    }
                }
            }
        }
    }
}
