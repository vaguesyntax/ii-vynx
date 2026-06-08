pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool auditDatabaseReady: false
    property var cachedAuditDb: ({trustedExtensions: [], blockedExtensions: []})
    property var blockedIds: ({})
    property var trustedMap: ({})
    property var recommendedIds: ({})
    property int auditDbVersion: 0

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
        root.blockedIds = blocked
        root.trustedMap = trusted
        root.recommendedIds = recommended
        root.auditDatabaseReady = true
        root.auditDbVersion++
    }

    function isExtensionRecommended(extId) {
        return !!root.recommendedIds[extId]
    }

    function getExtensionAuditState(extId) {
        if (root.blockedIds[extId]) return "blocked"
        if (root.trustedMap[extId]) return "trusted"
        return "unaudited"
    }

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
}
