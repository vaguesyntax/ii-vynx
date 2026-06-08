import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.settings

ContentPage {
    id: page
    readonly property int index: 8
    property bool register: parent.register ?? false
    forceWidth: true

    property string searchText: ""
    property var filteredExtensions: []
    property bool showCustomUrlInput: false

    function installFromUrl() {
        let input = customUrlField.textFieldText.trim()
        if (!input) return

        // Detect if input is a URL (http/https/git) or a local path
        if (input.match(/^(https?:\/\/|git@|git:\/\/)/)) {
            // URL — install via git clone
            let url = input
            let parts = url.replace(/\.git$/, "").split("/")
            let repoName = parts[parts.length - 1]
            if (!repoName) return
            ExtensionManager.installExtension(url, repoName, "main", url, true)
        } else {
            // Local path — register directly
            ExtensionManager.installLocalExtension(input)
        }

        page.showCustomUrlInput = false
        customUrlField.textFieldText = ""
    }

    Component.onCompleted: {
        if (!ExtensionManager.ready) return
        if (ExtensionManager.availableExtensions.length === 0) {
            ExtensionManager.refreshAvailableExtensions()
        }
        ExtensionManager.checkAllUpdates()
        page.filter()
    }

    Connections {
        target: ExtensionManager
        function onReadyChanged() { if (ExtensionManager.ready) page.filter() }
        function onExtensionSearchDone() { page.filter() }
        function onManifestReady(repoId) { page.filter() }
        function onExtensionInstalled(extId) { page.filter() }
        function onExtensionRemoved(extId) { page.filter() }
        function onExtensionToggled(extId) { page.filter() }
        function onUpdateCheckDone(extId, available, error) { page.filter() }
    }

    function filter() {
        let installed = ExtensionManager.installedExtensions
        let list = ExtensionManager.availableExtensions

        // Exclude installed extensions
        let installedIds = {}
        for (let id in installed) {
            installedIds[installed[id].name] = true
            installedIds[installed[id].id] = true
        }
        list = list.filter(e => !installedIds[e.name])

        // Filter by search text
        if (page.searchText.trim()) {
            let q = page.searchText.toLowerCase().trim()
            list = list.filter(e =>
                e.name.toLowerCase().includes(q) ||
                e.fullName.toLowerCase().includes(q) ||
                e.description.toLowerCase().includes(q) ||
                e.displayName?.toLowerCase().includes(q)
            )
        }
        page.filteredExtensions = list
    }

    ContentSection {
        icon: "extension"
        title: Translation.tr("Extensions")

        ButtonGroup {
            Layout.fillWidth: true

            GroupButtonWithIcon {
                buttonIcon: "link"
                baseHeight: 44
                extraWidth: 26
                onClicked: page.showCustomUrlInput = !page.showCustomUrlInput
                toggled: page.showCustomUrlInput
                StyledToolTip { text: Translation.tr("Install from custom URL (for developers)") }
            }

            GroupButtonWithTextField {
                buttonIcon: "search"
                buttonText: Translation.tr("Search extensions...")
                Layout.fillWidth: true
                
                onTextChanged: text => {
                    page.searchText = text
                    Qt.callLater(() => page.filter())
                }
            }

            GroupButtonWithIcon {
                Layout.fillWidth: true
                baseHeight: 44
                extraWidth: 26
                buttonIcon: ExtensionManager.loading ? "hourglass_bottom" : "refresh"
                toggled: ExtensionManager.loading
                onClicked: ExtensionManager.refreshAvailableExtensions()
                StyledToolTip { text: Translation.tr("Refresh extension list") }
            }
        }

        ButtonGroup {
            id: urlInputLayout
            clip: true
            Layout.fillWidth: true
            implicitHeight: page.showCustomUrlInput ? 44 : 0
            Behavior on implicitHeight { 
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            GroupButtonWithTextField {
                id: customUrlField
                buttonIcon: "add"
                buttonText: Translation.tr("GitHub URL or local path")
                Layout.fillWidth: true
                
                onAccepted: page.installFromUrl()
            }

            GroupButtonWithIcon {
                Layout.fillWidth: true
                baseHeight: 44
                extraWidth: 26
                buttonIcon: "download"
                onClicked: page.installFromUrl()
                StyledToolTip { text: Translation.tr("Install a custom extension") }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: ExtensionManager.error.length > 0
            text: ExtensionManager.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        InstalledExtensionList {}

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: page.filteredExtensions.length > 0
            text: Translation.tr("Browse Extensions")
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer0
        }

        ExtensionList {
            model: page.filteredExtensions
            searchText: page.searchText
            loading: ExtensionManager.loading
        }
    }
}
