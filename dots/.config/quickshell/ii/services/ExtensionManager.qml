pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property bool loading: false
    property bool manifestLoading: false
    property bool ready: false
    property string error: ""
    property var availableExtensions: []
    property var installedExtensions: ({})
    property var updateStates: ({})
    property var _updateQueue: ({}) // { extId: string, repoUrl: string, branch: string, step: string }

    signal extensionSearchDone()
    signal extensionInstalled(string extId)
    signal extensionRemoved(string extId)
    signal extensionToggled(string extId)
    signal manifestReady(int repoId)
    signal updateCheckDone(string extId, bool available, string error)

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Directories.extensionsCachePath])
        Quickshell.execDetached(["mkdir", "-p", Directories.extensionsInstalledPath])
    }

    // ── Persistence ──

    function syncPluginsAdapter() {
        extensionsAdapter.extensions = root.installedExtensions
        extensionsFileView.writeAdapter()
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
                hasManifest: false,
                manifest: null,
                manifestError: null
            }))
            root.saveSearchCache(repos)
            root.availableExtensions = repos
            root.extensionSearchDone()
        } catch (e) {
            root.error = "Parse error: " + e
            root.loading = false
            root.availableExtensions = []
            root.extensionSearchDone()
        }
    }

    // ── Manifest fetch ──

    function fetchManifest(repoId) {
        if (root.manifestLoading) return
        root.manifestLoading = true
        root.error = ""

        let repo = null
        for (let i = 0; i < root.availableExtensions.length; i++) {
            if (root.availableExtensions[i].repoId === repoId) {
                repo = root.availableExtensions[i]
                break
            }
        }
        if (!repo) {
            root.manifestLoading = false
            return
        }

        let url = "https://raw.githubusercontent.com/" + repo.fullName + "/" + repo.defaultBranch + "/extension.json"
        fetchManifestProc._pendingRepoId = repoId
        fetchManifestProc.exec(["curl", "-s", "--connect-timeout", "5", url])
    }

    function processFetchedManifest(repoId, jsonText) {
        root.manifestLoading = false
        if (!jsonText || jsonText.length === 0) {
            root.updateManifestInList(repoId, null, "Empty response")
            return
        }
        try {
            let manifest = JSON.parse(jsonText)
            root.updateManifestInList(repoId, manifest, null)
        } catch (e) {
            root.updateManifestInList(repoId, null, "Invalid JSON: " + e)
        }
    }

    function updateManifestInList(repoId, manifest, error) {
        root.availableExtensions = root.availableExtensions.map(r =>
            r.repoId !== repoId ? r : Object.assign({}, r, {
                hasManifest: !error && !!manifest,
                manifest: manifest,
                manifestError: error ?? null
            })
        )
        root.manifestLoading = false
        root.manifestReady(repoId)
    }

    // ── Install / Uninstall ──

    function installExtension(repoUrl, extId, defaultBranch) {
        root.loading = true
        root.error = ""
        let dest = Directories.extensionsInstalledPath + "/" + extId
        installProc._pendingExtId = extId
        installProc._pendingDest = dest
        installProc._pendingRepoUrl = repoUrl
        installProc._pendingBranch = defaultBranch || "main"
        installProc.exec(["git", "clone", "--depth", "1", repoUrl, dest])
    }

    function registerInstalled(extId, dest, repoUrl, defaultBranch, jsonText) {
        try {
            let manifest = JSON.parse(jsonText)
            let entry = {
                id: extId,
                name: manifest.name || extId,
                description: manifest.description || "",
                version: manifest.version || "0.0.0",
                author: manifest.author || "",
                coverArt: manifest.coverArt || "",
                enabled: true,
                installedPath: dest,
                installedAt: new Date().toISOString(),
                repoUrl: repoUrl || "",
                defaultBranch: defaultBranch || "main",
                contributes: manifest.contributes || {}
            }
            root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: entry })
            root.syncPluginsAdapter()
            root.loading = false
            root.extensionInstalled(extId)
        } catch (e) {
            root.error = "Invalid extension.json: " + e
            root.loading = false
        }
    }

    function uninstallExtension(extId) {
        let entry = root.installedExtensions[extId]
        if (!entry) return
        removeProc._pendingExtId = extId
        removeProc.exec(["rm", "-rf", entry.installedPath])
    }

    function finalizeUninstall(extId) {
        let ext = Object.assign({}, root.installedExtensions)
        delete ext[extId]
        root.installedExtensions = ext
        root.syncPluginsAdapter()
        root.extensionRemoved(extId)
    }

    function toggleExtension(extId, enabled) {
        if (!root.installedExtensions[extId]) return
        // Deep copy the entry to avoid mutating in place — QML won't fire bindings otherwise
        let updated = Object.assign({}, root.installedExtensions[extId], { enabled: enabled })
        root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: updated })
        root.syncPluginsAdapter()
        root.extensionToggled(extId)
    }

    // ── Update management ──

    function checkUpdate(extId) {
        let ext = root.installedExtensions[extId]
        if (!ext || !ext.repoUrl) {
            root.updateCheckDone(extId, false, ext ? "No repo URL" : "Not installed")
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
            let manifest = JSON.parse(jsonText)
            let existing = root.installedExtensions[extId]
            if (!existing) return
            let updated = Object.assign({}, existing, {
                name: manifest.name || existing.name,
                description: manifest.description || existing.description,
                version: manifest.version || existing.version,
                author: manifest.author || existing.author,
                coverArt: manifest.coverArt || existing.coverArt,
                contributes: manifest.contributes || existing.contributes
            })
            root.installedExtensions = Object.assign({}, root.installedExtensions, { [extId]: updated })
            root.syncPluginsAdapter()
            // Re-enable the extension
            root.toggleExtension(extId, true)
        } catch (e) {
            root.error = "Failed to re-read extension.json: " + e
            root.toggleExtension(extId, true)
        }
        root.loading = false
        root._updateQueue = {}
    }

    function getContributionPoint(pointName) {
        let result = []
        for (let id in root.installedExtensions) {
            let ext = root.installedExtensions[id]
            if (!ext.enabled) continue
            let items = ext.contributes && ext.contributes[pointName]
            if (!items) continue
            for (let i = 0; i < items.length; i++) {
                let item = items[i]
                result.push({
                    extensionId: id,
                    title: item.title || item.name || "",
                    icon: item.icon || "",
                    identifier: item.identifier || item.id || "",
                    component: item.component || "",
                    fullPath: ext.installedPath + "/" + (item.component || "")
                })
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
        id: fetchManifestProc
        property int _pendingRepoId: -1
        stdout: StdioCollector {
            onStreamFinished: root.processFetchedManifest(fetchManifestProc._pendingRepoId, this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) root.manifestLoading = false
        }
    }

    Process {
        id: installProc
        property string _pendingExtId: ""
        property string _pendingDest: ""
        property string _pendingRepoUrl: ""
        property string _pendingBranch: "main"
        onExited: (exitCode, _) => {
            if (exitCode === 0) {
                installReader._pendingExtId = installProc._pendingExtId
                installReader._pendingDest = installProc._pendingDest
                installReader._pendingRepoUrl = installProc._pendingRepoUrl
                installReader._pendingBranch = installProc._pendingBranch
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
            }
        }
    }

    Process {
        id: updatePullProc
        property string _pendingExtId: ""
        onExited: (exitCode, _) => root.finalizeUpdate(updatePullProc._pendingExtId, exitCode)
    }

    // ── File persistence ──

    FileView {
        id: extensionsFileView
        path: Directories.pluginsJsonPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.installedExtensions = extensionsAdapter.extensions || {}
            let cache = extensionsAdapter.searchCache
            if (cache && cache.cachedAt && root.isCacheValid(cache.cachedAt) && cache.results) {
                root.availableExtensions = cache.results
                root.extensionSearchDone()
            }
            root.ready = true
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter()
            root.ready = true
        }

        adapter: JsonAdapter {
            id: extensionsAdapter
            property var extensions: ({})
            property var searchCache: ({})
        }
    }

    FileView {
        id: installReader
        property string _pendingExtId: ""
        property string _pendingDest: ""
        property string _pendingRepoUrl: ""
        property string _pendingBranch: "main"
        onLoaded: root.registerInstalled(installReader._pendingExtId, installReader._pendingDest, installReader._pendingRepoUrl, installReader._pendingBranch, installReader.text())
        onLoadFailed: {
            root.error = "Installed extension has no extension.json"
            root.loading = false
        }
    }

    FileView {
        id: updateReader
        property string _pendingExtId: ""
        onLoaded: root.reRegisterUpdated(updateReader._pendingExtId, updateReader.text())
    }
}
