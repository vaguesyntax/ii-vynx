pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    signal refreshExtensions()

    property bool loading: false
    property bool extensionJsonLoading: false
    property bool ready: false
    property string error: ""
    property var availableExtensions: []
    property var installedExtensions: ({})
    property var updateStates: ({})
    property var extensionWidgetConfigs: ({}) // { extId: { widgetId: { enable, x, y } } }
    property var extensionOverlayConfigs: ({}) // { extId: { widgetId: { x, y, width, height, pinned, clickthrough } } }
    property var extensionConfigs: ({}) // { extId: { key: value } }
    property var _updateQueue: ({}) // { extId: string, repoUrl: string, branch: string, step: string }
    property var _updateCheckQueue: []
    property bool _updateCheckRunning: false
    property bool auditDatabaseReady: false
    property var cachedAuditDb: ({trustedExtensions: [], blockedExtensions: []})
    property var _blockedIds: ({})
    property var _trustedMap: ({})
    property var _recommendedIds: ({})
    property int _auditDbVersion: 0

    onAvailableExtensionsChanged: { root.refreshExtensions() }
    onInstalledExtensionsChanged: { root.refreshExtensions() }
    onUpdateStatesChanged: { root.refreshExtensions() }
    onReadyChanged: { root.refreshExtensions() }

    property var _extensionJsonQueue: []

    signal extensionSearchDone()
    signal extensionInstalled(string extId)
    signal extensionRemoved(string extId)
    signal extensionToggled(string extId)
    signal extensionJsonReady(int repoId)
    signal updateCheckDone(string extId, bool available, string error)

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Directories.extensionsCachePath])
        Quickshell.execDetached(["mkdir", "-p", Directories.extensionsInstalledPath])
    }

    // ── Persistence ──

    function syncPluginsAdapter() {
        extensionsAdapter.extensions = root.installedExtensions
        extensionsAdapter.extensionConfigs = root.extensionConfigs
        extensionsAdapter.extensionOverlayConfigs = root.extensionOverlayConfigs
        extensionsFileView.writeAdapter()
    }

    // ── Search cache ──

    function saveExtensionWidgetConfig(extId, widgetId, config) {
        let extConfigs = Object.assign({}, root.extensionWidgetConfigs)
        if (!extConfigs[extId]) extConfigs[extId] = {}
        extConfigs[extId][widgetId] = { enable: config.enable, x: config.x, y: config.y }
        root.extensionWidgetConfigs = extConfigs
        extensionsAdapter.extensionWidgetConfigs = extConfigs
        extensionsFileView.writeAdapter()
    }

    function getExtensionWidgetConfig(extId, widgetId) {
        return root.extensionWidgetConfigs?.[extId]?.[widgetId] ?? null
    }

    // ── Extension overlay widget config API ──

    function saveExtensionOverlayConfig(extId, widgetId, config) {
        let extConfigs = Object.assign({}, root.extensionOverlayConfigs)
        if (!extConfigs[extId]) extConfigs[extId] = {}
        extConfigs[extId][widgetId] = {
            x: config.x ?? 100,
            y: config.y ?? 100,
            width: config.width ?? 300,
            height: config.height ?? 200,
            pinned: config.pinned ?? false,
            clickthrough: config.clickthrough ?? true
        }
        root.extensionOverlayConfigs = extConfigs
        extensionsAdapter.extensionOverlayConfigs = extConfigs
        extensionsFileView.writeAdapter()
    }

    function getExtensionOverlayConfig(extId, widgetId) {
        return root.extensionOverlayConfigs?.[extId]?.[widgetId] ?? null
    }

    // ── Extension config API ──

    function setExtensionConfig(extId, key, value) {
        let allConfigs = Object.assign({}, root.extensionConfigs)
        if (!allConfigs[extId]) allConfigs[extId] = {}
        allConfigs[extId][key] = value
        root.extensionConfigs = allConfigs
        extensionsAdapter.extensionConfigs = allConfigs
        extensionsFileView.writeAdapter()
    }

    function getExtensionConfig(extId, key, defaultValue) {
        return root.extensionConfigs?.[extId]?.[key] ?? defaultValue
    }

    // ── Search cache ──

    function saveSearchCache(repos) {
        extensionsAdapter.searchCache = { cachedAt: new Date().toISOString(), results: repos }
        extensionsFileView.writeAdapter()
    }

    function isCacheValid(cachedAt) {
        if (!cachedAt) return false
        return (new Date() - new Date(cachedAt)) / (1000 * 60 * 60) < 1
    }

    // ── GitHub search ──

    function refreshAvailableExtensions() {
        if (root.loading) return
        root.loading = true
        root.error = ""
        searchProc.exec(["curl", "-s",
            "-H", "Accept: application/vnd.github+json",
            "https://api.github.com/search/repositories?q=ii-vynx-extension+in:topic&per_page=50"
        ])
    }

    function processSearchResults(jsonText) {
        root.loading = false
        try {
            let resp = JSON.parse(jsonText)
            if (!resp.items || resp.items.length === 0) {
                root.availableExtensions = []
                root.extensionSearchDone()
                return
            }
            let repos = resp.items.map(item => ({
                repoId: item.id,
                name: item.name,
                fullName: item.full_name,
                description: item.description || "",
                stars: item.stargazers_count,
                owner: item.owner.login,
                avatarUrl: item.owner.avatar_url,
                repoUrl: item.clone_url,
                htmlUrl: item.html_url,
                defaultBranch: item.default_branch || "main",
                icon: "",
                hasExtensionJson: false,
                extensionJson: null,
                extensionJsonError: null
            }))
            root.saveSearchCache(repos)
            root.availableExtensions = repos.filter(r => !root._blockedIds[r.name])
            root.extensionSearchDone()
            root.startExtensionJsonFetchAll()
        } catch (e) {
            root.error = "Parse error: " + e
            root.loading = false
            root.availableExtensions = []
            root.extensionSearchDone()
        }
    }

    // ── ExtensionJson fetch ──

    function fetchExtensionJson(repoId) {
        if (root.extensionJsonLoading) return
        root.extensionJsonLoading = true
        root.error = ""

        let repo = null
        for (let i = 0; i < root.availableExtensions.length; i++) {
            if (root.availableExtensions[i].repoId === repoId) {
                repo = root.availableExtensions[i]
                break
            }
        }
        if (!repo) {
            root.extensionJsonLoading = false
            root._processExtensionJsonQueue()
            return
        }

        let url = "https://raw.githubusercontent.com/" + repo.fullName + "/" + repo.defaultBranch + "/extension.json"
        fetchExtensionJsonProc._pendingRepoId = repoId
        fetchExtensionJsonProc.exec(["curl", "-s", "--connect-timeout", "5", url])
    }

    function processFetchedExtensionJson(repoId, jsonText) {
        root.extensionJsonLoading = false
        if (!jsonText || jsonText.length === 0) {
            root.updateExtensionJsonInList(repoId, null, "Empty response")
            return
        }
        try {
            let extensionJson = JSON.parse(jsonText)
            root.updateExtensionJsonInList(repoId, extensionJson, null)
        } catch (e) {
            root.updateExtensionJsonInList(repoId, null, "Invalid JSON: " + e)
        }
    }

    function updateExtensionJsonInList(repoId, extensionJson, error) {
        root.availableExtensions = root.availableExtensions.map(r =>
            r.repoId !== repoId ? r : Object.assign({}, r, {
                hasExtensionJson: !error && !!extensionJson,
                extensionJson: extensionJson,
                extensionJsonError: error ?? null,
                icon: extensionJson && extensionJson.icon || r.icon || "",
                shapeString: extensionJson && extensionJson.shapeString || r.shapeString || "",
                description: extensionJson && extensionJson.description || r.description || "",
                displayName: extensionJson && extensionJson.name || r.name || "",
                version: extensionJson && extensionJson.version || ""
            })
        )
        root.extensionJsonLoading = false
        root.extensionJsonReady(repoId)
        if (root._extensionJsonQueue.length === 0) {
            root.saveSearchCache(root.availableExtensions)
        }
        root._processExtensionJsonQueue()
    }

    // ── Install / Uninstall ──

    function installExtension(repoUrl, extId, defaultBranch, htmlUrl, isCustomUrl) {
        root.loading = true
        root.error = ""
        let dest = Directories.extensionsInstalledPath + "/" + extId
        installProc._pendingExtId = extId
        installProc._pendingDest = dest
        installProc._pendingRepoUrl = repoUrl
        installProc._pendingBranch = defaultBranch || "main"
        installProc._pendingHtmlUrl = htmlUrl || ""
        installProc._pendingIsCustomUrl = !!isCustomUrl
        installProc.exec(["git", "clone", "--depth", "1", repoUrl, dest])
    }

    function installLocalExtension(localPath) {
        root.loading = true
        root.error = ""
        let resolvedPath = localPath.replace(/^~/, Directories.home).replace(/\/+$/, "")
        localReader._pendingPath = resolvedPath
        localReader.path = resolvedPath + "/extension.json"
        localReader.reload()
    }

    function reinstallLocalExtension(extId) {
        let ext = root.installedExtensions[extId]
        if (!ext || !ext.isLocal) return

        root.loading = true
        root.error = ""

        reloadLocalProc._pendingExtId = extId
        reloadLocalProc.exec(["cat", ext.installedPath + "/extension.json"])
    }

    function processLocalExtensionReload(extId, jsonText) {
        try {
            let extensionJson = JSON.parse(jsonText)
            let existing = root.installedExtensions[extId]
            if (!existing) return

            let wasEnabled = existing.enabled

            // Disable first to remove all extension components from shell
            if (wasEnabled) {
                root.toggleExtension(extId, false)
            }

            // Update entry with new contributes
            let updated = Object.assign({}, root.installedExtensions[extId], {
                name: extensionJson.name || existing.name,
                description: extensionJson.description || existing.description,
                version: extensionJson.version || existing.version,
                author: extensionJson.author || existing.author,
                icon: extensionJson.icon || existing.icon,
                shapeString: extensionJson.shapeString || existing.shapeString,
                contributes: extensionJson.contributes || {},
                configDefaults: extensionJson.configDefaults || {}
            })
            root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: updated })
            root.syncPluginsAdapter()
            root.applyExtensionConfigDefaults(extId)

            // Re-enable to trigger full re-creation with fresh QML
            if (wasEnabled) {
                root.toggleExtension(extId, true)
            }

            root.loading = false
        } catch (e) {
            root.error = "Failed to parse extension.json: " + e
            root.loading = false
        }
    }

    /**
     * Loads a QML component from a file path, bypassing QML engine cache
     * by adding a unique query parameter to force recompilation.
     */
    function loadExtensionQmlComponent(fullPath) {
        return Qt.createComponent("file://" + fullPath + "?_t=" + Date.now())
    }

    function registerInstalled(extId, dest, repoUrl, defaultBranch, htmlUrl, jsonText, isLocal, isCustomUrl) {
        // Check if extension is blocked
        if (root._blockedIds[extId]) {
            let reason = root._blockedIds[extId]
            root.error = reason !== true
                ? "Extension blocked: " + reason
                : "This extension is blocked and cannot be installed"
            root.loading = false
            return
        }

        try {
            let extensionJson = JSON.parse(jsonText)
            let entry = {
                id: extId,
                name: extensionJson.name || extId,
                description: extensionJson.description || "",
                version: extensionJson.version || "0.0.0",
                author: extensionJson.author || "",
                icon: extensionJson.icon || "",
                shapeString: extensionJson.shapeString || "",
                enabled: true,
                installedPath: dest,
                installedAt: new Date().toISOString(),
                repoUrl: repoUrl || "",
                htmlUrl: htmlUrl || "",
                defaultBranch: defaultBranch || "main",
                isLocal: isLocal || false,
                isCustomUrl: isCustomUrl || false,
                contributes: extensionJson.contributes || {},
                configDefaults: extensionJson.configDefaults || {}
            }
            root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: entry })
            root.syncPluginsAdapter()
            root.loading = false
            root.extensionInstalled(extId)
            root.loadExtensionServices(extId)
            root.applyExtensionConfigDefaults(extId)
        } catch (e) {
            root.error = "Invalid extension.json: " + e
            root.loading = false
        }
    }

    function applyExtensionConfigDefaults(extId) {
        let entry = root.installedExtensions[extId]
        if (!entry || !entry.configDefaults) return
        let defaults = entry.configDefaults
        let current = root.extensionConfigs[extId]
        let merged = {}
        if (current) {
            for (let key in current) merged[key] = current[key]
        }
        let changed = false
        for (let key in defaults) {
            if (!(key in merged)) {
                merged[key] = defaults[key]
                changed = true
            }
        }
        if (changed) {
            let allConfigs = Object.assign({}, root.extensionConfigs)
            allConfigs[extId] = merged
            root.extensionConfigs = allConfigs
            extensionsAdapter.extensionConfigs = allConfigs
            extensionsFileView.writeAdapter()
        }
    }

    function resetExtensionConfig(extId) {
        let entry = root.installedExtensions[extId]
        if (!entry || !entry.configDefaults) return
        let allConfigs = Object.assign({}, root.extensionConfigs)
        allConfigs[extId] = Object.assign({}, entry.configDefaults)
        root.extensionConfigs = allConfigs
        extensionsAdapter.extensionConfigs = allConfigs
        extensionsFileView.writeAdapter()
    }

    function uninstallExtension(extId) {
        let entry = root.installedExtensions[extId]
        if (!entry) return
        if (entry.isLocal) {
            // Local path extension — just remove from registry, keep files
            root.finalizeUninstall(extId)
            return
        }
        removeProc._pendingExtId = extId
        removeProc.exec(["rm", "-rf", entry.installedPath])
    }

    function finalizeUninstall(extId) {
        root.unloadExtensionServices(extId)
        let ext = Object.assign({}, root.installedExtensions)
        delete ext[extId]
        root.installedExtensions = ext
        // Clean up extension config
        let allConfigs = Object.assign({}, root.extensionConfigs)
        delete allConfigs[extId]
        root.extensionConfigs = allConfigs
        // Also clean up widget configs
        let widgetConfigs = Object.assign({}, root.extensionWidgetConfigs)
        delete widgetConfigs[extId]
        root.extensionWidgetConfigs = widgetConfigs
        let overlayConfigs = Object.assign({}, root.extensionOverlayConfigs)
        delete overlayConfigs[extId]
        root.extensionOverlayConfigs = overlayConfigs
        root.syncPluginsAdapter()
        root.extensionRemoved(extId)
    }

    function loadExtensionServices(extId) {
        let ext = root.installedExtensions[extId]
        if (!ext || !ext.contributes || !ext.contributes.services) return
        let svcs = ext.contributes.services
        for (let i = 0; i < svcs.length; i++) {
            let svc = svcs[i]
            if (!svc.id || !svc.qml) continue
            ExtensionServices.ensure(extId, svc.id, ext.installedPath + "/" + svc.qml)
        }
    }

    function unloadExtensionServices(extId) {
        ExtensionServices.unloadExtension(extId)
    }

    function toggleExtension(extId, enabled) {
        if (!root.installedExtensions[extId]) return
        // Deep copy the entry to avoid mutating in place — QML won't fire bindings otherwise
        let updated = Object.assign({}, root.installedExtensions[extId], { enabled: enabled })
        root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: updated })
        root.syncPluginsAdapter()

        if (enabled) {
            root.loadExtensionServices(extId)
        } else {
            root.unloadExtensionServices(extId)
        }

        root.extensionToggled(extId)
    }

    // ── Update management ──

    function checkUpdate(extId) {
        let ext = root.installedExtensions[extId]
        if (!ext || !ext.repoUrl) {
            root.updateCheckDone(extId, false, ext ? "No repo URL" : "Not installed")
            root._advanceUpdateCheckQueue()
            return
        }

        root.updateStates = Object.assign({}, root.updateStates, {
            [extId]: { checking: true, localHash: "", remoteHash: "", updateAvailable: false, error: "" }
        })

        updateCheckProc._pendingExtId = extId
        updateCheckProc.exec(["bash", "-c",
            "local=$(git -C \"" + ext.installedPath + "\" rev-parse HEAD 2>/dev/null) && " +
            "remote=$(git ls-remote \"" + ext.repoUrl + "\" \"" + ext.defaultBranch + "\" 2>/dev/null | head -1 | awk '{print $1}') && " +
            "echo \"$local $remote\""
        ])
    }

    function processUpdateCheck(extId, output) {
        let parts = output.trim().split(/\s+/)
        let localHash = parts[0] || ""
        let remoteHash = parts[1] || ""
        let available = localHash.length > 0 && remoteHash.length > 0 && localHash !== remoteHash

        root.updateStates = Object.assign({}, root.updateStates, {
            [extId]: {
                checking: false,
                localHash: localHash,
                remoteHash: remoteHash,
                updateAvailable: available,
                error: ""
            }
        })
        root.updateCheckDone(extId, available, "")
        root._advanceUpdateCheckQueue()
    }

    function updateExtension(extId) {
        let ext = root.installedExtensions[extId]
        if (!ext || !ext.repoUrl) return

        root.loading = true
        root.error = ""
        root._updateQueue = { extId: extId, step: "disable" }

        // Step 1: disable
        root.toggleExtension(extId, false)

        // Step 2: pull (after toggle syncs)
        root._updateQueue.step = "pull"
        updatePullProc._pendingExtId = extId
        updatePullProc.exec(["git", "-C", ext.installedPath, "pull", "--ff-only"])
    }

    function finalizeUpdate(extId, exitCode) {
        if (exitCode !== 0) {
            root.error = "Update failed (exit " + exitCode + ")"
            root.loading = false
            // Re-enable even if pull failed
            root.toggleExtension(extId, true)
            root._updateQueue = {}
            return
        }
        // Re-read extension.json to update the entry
        let ext = root.installedExtensions[extId]
        if (ext) {
            updateReader._pendingExtId = extId
            updateReader.path = ext.installedPath + "/extension.json"
        } else {
            root.loading = false
            root._updateQueue = {}
        }
    }

    function reRegisterUpdated(extId, jsonText) {
        try {
            let extensionJson = JSON.parse(jsonText)
            let existing = root.installedExtensions[extId]
            if (!existing) return
            let updated = Object.assign({}, existing, {
                name: extensionJson.name || existing.name,
                description: extensionJson.description || existing.description,
                version: extensionJson.version || existing.version,
                author: extensionJson.author || existing.author,
                contributes: extensionJson.contributes || existing.contributes,
                icon: extensionJson.icon || existing.icon,
                shapeString: extensionJson.shapeString || existing.shapeString,
                configDefaults: extensionJson.configDefaults || {}
            })
            root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: updated })
            root.syncPluginsAdapter()
            root.applyExtensionConfigDefaults(extId)
            // Clear update state since we just updated
            let states = Object.assign({}, root.updateStates)
            delete states[extId]
            root.updateStates = states
            root.updateCheckDone(extId, false, "")
            // Re-enable the extension
            root.toggleExtension(extId, true)
        } catch (e) {
            root.error = "Failed to re-read extension.json: " + e
            root.toggleExtension(extId, true)
        }
        root.loading = false
        root._updateQueue = {}
    }

    function checkAllUpdates() {
        let ids = []
        for (let id in root.installedExtensions) {
            let ext = root.installedExtensions[id]
            if (ext.repoUrl) ids.push(id)
        }
        root._updateCheckQueue = ids
        root._updateCheckRunning = false
        root._processUpdateCheckQueue()
    }

    function _processUpdateCheckQueue() {
        if (root._updateCheckRunning) return
        if (root._updateCheckQueue.length === 0) return
        root._updateCheckRunning = true
        root.checkUpdate(root._updateCheckQueue.shift())
    }

    function _advanceUpdateCheckQueue() {
        if (!root._updateCheckRunning) return
        root._updateCheckRunning = false
        if (root._updateCheckQueue.length > 0) {
            Qt.callLater(root._processUpdateCheckQueue)
        }
    }

    // ── ExtensionJson auto-fetch queue ──

    function startExtensionJsonFetchAll() {
        let ids = []
        for (let i = 0; i < root.availableExtensions.length; i++) {
            if (!root.availableExtensions[i].hasExtensionJson) {
                ids.push(root.availableExtensions[i].repoId)
            }
        }
        root._extensionJsonQueue = ids
        if (ids.length > 0) root._processExtensionJsonQueue()
    }

    function _processExtensionJsonQueue() {
        if (root._extensionJsonQueue.length === 0) return
        if (root.extensionJsonLoading) {
            extensionJsonQueueTimer.start()
            return
        }
        root.fetchExtensionJson(root._extensionJsonQueue.shift())
    }

    Timer {
        id: extensionJsonQueueTimer
        interval: 500
        repeat: false
        onTriggered: root._processExtensionJsonQueue()
    }

    // ── Audit database ──

    function fetchAuditDatabase() {
        auditFetchProc.exec(["curl", "-s", "--connect-timeout", "5",
            "https://raw.githubusercontent.com/vaguesyntax/vynx-extension-audit/refs/heads/main/extension-database.json"])
    }

    function _processAuditDatabase(db) {
        root.cachedAuditDb = db
        let blocked = {}
        let trusted = {}
        let recommended = {}
        let blockedList = db["blocked-extensions"] || []
        for (let i = 0; i < blockedList.length; i++) {
            blocked[blockedList[i]["extension-id"]] = blockedList[i].reason || true
        }
        let trustedList = db["trusted-extensions"] || []
        for (let i = 0; i < trustedList.length; i++) {
            trusted[trustedList[i]["extension-id"]] = { trustedCommit: trustedList[i].trustedCommit }
        }
        let recommendedList = db["recommended-extensions"] || []
        for (let i = 0; i < recommendedList.length; i++) {
            recommended[recommendedList[i]] = true
        }
        root._blockedIds = blocked
        root._trustedMap = trusted
        root._recommendedIds = recommended
        root.auditDatabaseReady = true

        root.availableExtensions = root.availableExtensions.filter(r => !blocked[r.name])

        root._auditDbVersion++
    }

    function isExtensionRecommended(extId) {
        return !!root._recommendedIds[extId]
    }

    function getExtensionAuditState(extId) {
        if (root._blockedIds[extId]) return "blocked"
        if (root._trustedMap[extId]) return "trusted"
        return "unaudited"
    }

    function getContributionPoint(pointName) {
        let result = []
        for (let id in root.installedExtensions) {
            let ext = root.installedExtensions[id]
            if (!ext.enabled) continue
            let items = ext.contributes && ext.contributes[pointName]
            if (!items) {
                continue
            }
            for (let i = 0; i < items.length; i++) {
                let item = items[i]
                let base = {
                    extensionId: id,
                    title: item.title || item.name || "",
                    icon: item.icon || "",
                    identifier: item.identifier || item.id || "",
                    component: item.component || item.qml || "",
                    fullPath: ext.installedPath + "/" + (item.component || item.qml || ""),
                    qml: item.qml || "",
                    verticalQml: item.verticalQml || "",
                    fullPathVertical: item.verticalQml ? (ext.installedPath + "/" + item.verticalQml) : "",
                    x: item.x ?? 100,
                    y: item.y ?? 100,
                    placementStrategy: item.placementStrategy ?? "free"
                }
                if (pointName === "overlayWidgets") {
                    let saved = root.getExtensionOverlayConfig(id, base.identifier)
                    base.materialSymbol = item.materialSymbol || item.icon || "extension"
                    base.width = saved?.width ?? item.width ?? 300
                    base.height = saved?.height ?? item.height ?? 200
                    base.pinned = saved?.pinned ?? item.pinned ?? false
                    base.clickthrough = saved?.clickthrough ?? item.clickthrough ?? true
                    base.x = saved?.x ?? item.x ?? 100
                    base.y = saved?.y ?? item.y ?? 100
                }
                result.push(base)
            }
        }
        return result
    }

    // ── Processes ──

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: root.processSearchResults(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) { root.error = this.text; root.loading = false }
        }
    }

    Process {
        id: fetchExtensionJsonProc
        property int _pendingRepoId: -1
        stdout: StdioCollector {
            onStreamFinished: root.processFetchedExtensionJson(fetchExtensionJsonProc._pendingRepoId, this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) {
                root.extensionJsonLoading = false
                root._processExtensionJsonQueue()
            }
        }
    }

    Process {
        id: installProc
        property string _pendingExtId: ""
        property string _pendingDest: ""
        property string _pendingRepoUrl: ""
        property string _pendingBranch: "main"
        property string _pendingHtmlUrl: ""
        property bool _pendingIsCustomUrl: false
        onExited: (exitCode, _) => {
            if (exitCode === 0) {
                installReader._pendingExtId = installProc._pendingExtId
                installReader._pendingDest = installProc._pendingDest
                installReader._pendingRepoUrl = installProc._pendingRepoUrl
                installReader._pendingBranch = installProc._pendingBranch
                installReader._pendingHtmlUrl = installProc._pendingHtmlUrl
                installReader._pendingIsCustomUrl = installProc._pendingIsCustomUrl
                installReader.path = installProc._pendingDest + "/extension.json"
            } else {
                root.error = "Git clone failed (exit " + exitCode + ")"
                root.loading = false
            }
        }
    }

    Process {
        id: removeProc
        property string _pendingExtId: ""
        onExited: root.finalizeUninstall(removeProc._pendingExtId)
    }

    Process {
        id: updateCheckProc
        property string _pendingExtId: ""
        stdout: StdioCollector {
            onStreamFinished: root.processUpdateCheck(updateCheckProc._pendingExtId, this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) {
                root.updateStates = Object.assign({}, root.updateStates, {
                    [updateCheckProc._pendingExtId]: { checking: false, localHash: "", remoteHash: "", updateAvailable: false, error: this.text }
                })
                root.updateCheckDone(updateCheckProc._pendingExtId, false, this.text)
                root._advanceUpdateCheckQueue()
            }
        }
    }

    Process {
        id: updatePullProc
        property string _pendingExtId: ""
        onExited: (exitCode, _) => root.finalizeUpdate(updatePullProc._pendingExtId, exitCode)
    }

    Process {
        id: reloadLocalProc
        property string _pendingExtId: ""
        stdout: StdioCollector {
            onStreamFinished: root.processLocalExtensionReload(reloadLocalProc._pendingExtId, this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) { console.log("Local extension reload error:", this.text) }
        }
    }

    // ── Audit database ──

    function _processAuditDatabaseFetch(jsonText) {
        try {
            let db = JSON.parse(jsonText)
            root._processAuditDatabase(db)
        } catch (e) {
            console.warn("Audit DB fetch parse failed:", e)
        }
    }

    Process {
        id: auditFetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.length > 0) {
                    root._processAuditDatabaseFetch(this.text)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text) console.warn("Audit DB fetch error:", this.text)
            }
        }
    }

    // ── File persistence ──

    FileView {
        id: extensionsFileView
        path: Directories.pluginsJsonPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.installedExtensions = extensionsAdapter.extensions || {}
            root.extensionWidgetConfigs = extensionsAdapter.extensionWidgetConfigs || {}
            root.extensionOverlayConfigs = extensionsAdapter.extensionOverlayConfigs || {}
            root.extensionConfigs = extensionsAdapter.extensionConfigs || {}
            let cache = extensionsAdapter.searchCache
            if (cache && cache.cachedAt && root.isCacheValid(cache.cachedAt) && cache.results) {
                root.availableExtensions = cache.results
                root.extensionSearchDone()
                root.startExtensionJsonFetchAll()
            }
            root.fetchAuditDatabase()

            root.ready = true
            for (let id in root.installedExtensions) {
                root.applyExtensionConfigDefaults(id)
                if (root.installedExtensions[id].enabled) {
                    root.loadExtensionServices(id)
                }
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
            root.fetchAuditDatabase()
            root.ready = true
        }

        adapter: JsonAdapter {
            id: extensionsAdapter
            property var extensions: ({})
            property var searchCache: ({})
            property var extensionWidgetConfigs: ({})
            property var extensionOverlayConfigs: ({})
            property var extensionConfigs: ({})
        }
    }

    FileView {
        id: installReader
        property string _pendingExtId: ""
        property string _pendingDest: ""
        property string _pendingRepoUrl: ""
        property string _pendingBranch: "main"
        property string _pendingHtmlUrl: ""
        property bool _pendingIsCustomUrl: false
        onLoaded: root.registerInstalled(installReader._pendingExtId, installReader._pendingDest, installReader._pendingRepoUrl, installReader._pendingBranch, installReader._pendingHtmlUrl, installReader.text(), false, installReader._pendingIsCustomUrl)
        onLoadFailed: {
            root.error = "Installed extension has no extension.json"
            root.loading = false
        }
    }

    FileView {
        id: localReader
        property string _pendingPath: ""
        onLoaded: {
            let path = localReader._pendingPath
            let parts = path.replace(/\/$/, "").split("/")
            let extId = parts[parts.length - 1]
            root.registerInstalled(extId, path, "", "", "", localReader.text(), true)
        }
        onLoadFailed: {
            root.error = "Local extension has no extension.json"
            root.loading = false
        }
    }

    FileView {
        id: updateReader
        property string _pendingExtId: ""
        onLoaded: root.reRegisterUpdated(updateReader._pendingExtId, updateReader.text())
    }
}
