pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common

Singleton {
    id: root

    property bool loading: false
    property bool extensionJsonLoading: false
    property var availableExtensions: []
    property var _extensionJsonQueue: []

    signal extensionSearchDone()
    signal extensionJsonReady(int repoId)

    // ── Search cache ──

    function saveSearchCache(repos) {
        ExtensionManager.writeSearchCache({ cachedAt: new Date().toISOString(), results: repos })
    }

    function isCacheValid(cachedAt) {
        if (!cachedAt) return false
        return (new Date() - new Date(cachedAt)) / (1000 * 60 * 60) < 1
    }

    function loadFromCache(cache) {
        if (cache && cache.cachedAt && root.isCacheValid(cache.cachedAt) && cache.results) {
            root.availableExtensions = cache.results
            root.extensionSearchDone()
            root.startExtensionJsonFetchAll()
        }
    }

    // ── GitHub search ──

    function refreshAvailableExtensions() {
        if (root.loading) return
        root.loading = true
        ExtensionManager.error = ""
        ExtensionManager.loading = true
        searchProc.exec(["curl", "-s",
            "-H", "Accept: application/vnd.github+json",
            "https://api.github.com/search/repositories?q=ii-vynx-extension+in:topic&per_page=50"
        ])
    }

    function processSearchResults(jsonText) {
        root.loading = false
        ExtensionManager.loading = false
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
            root.availableExtensions = repos.filter(r => !ExtensionAudit.blockedIds[r.name])
            root.saveSearchCache(root.availableExtensions)
            root.extensionSearchDone()
            root.startExtensionJsonFetchAll()
        } catch (e) {
            ExtensionManager.error = "Parse error: " + e
            root.loading = false
            ExtensionManager.loading = false
            root.availableExtensions = []
            root.extensionSearchDone()
        }
    }

    // ── ExtensionJson fetch ──

    function fetchExtensionJson(repoId) {
        if (root.extensionJsonLoading) return
        root.extensionJsonLoading = true
        ExtensionManager.error = ""

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

    // ── Processes ──

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: root.processSearchResults(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: if (this.text) { ExtensionManager.error = this.text; root.loading = false; ExtensionManager.loading = false }
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
}
