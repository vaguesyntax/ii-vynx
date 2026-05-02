pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * LocalSend service for receiving files via localsend-cli.
 * Monitors incoming file transfers and emits signals on events.
 */
Singleton {
    id: root

    property bool available: false
    property bool serverRunning: receiveProc.running
    property bool autoStart: Config.options?.localsend?.autoStart ?? false
    property string downloadPath: Config.options?.localsend?.downloadPath ?? (Directories.homePath + "/Downloads")
    property bool showNotifications: Config.options?.localsend?.showNotifications ?? true
    property bool localSendEnabled: Config.options?.policies?.localSend !== 0

    // Transfer state
    property var currentTransfer: null
    property list<var> pendingTransfers: []
    property list<var> transferHistory: []

    signal transferRequested(var transfer)
    signal transferStarted(var transfer)
    signal transferCompleted(var transfer)
    signal transferCancelled(var transfer)
    signal serverStarted()
    signal serverStopped()

    function isReady(): bool {
        return Config.ready && root.localSendEnabled
    }

    // Check if localsend-cli is available
    Process {
        id: checkAvailabilityProc
        running: false
        command: ["which", "localsend-cli"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0)
            if (root.available && root.autoStart && root.localSendEnabled) {
                Qt.callLater(() => {
                    root.startServer()
                })
            }
        }
    }

    // Notification process for incoming transfers
    Process {
        id: notificationProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === "") return
                const action = this.text.trim()
                console.log("[LocalSend] Notification action received:", action)
                if (action === "accept") {
                    root.acceptTransfer()
                } else if (action === "deny") {
                    root.denyTransfer()
                }
            }
        }
    }

    function showIncomingNotification(transfer: var): void {
        const fileNames = transfer.files.map(f => f.name).join(", ")
        const fileSizes = transfer.files.map(f => {
            const size = f.size || 0
            if (size < 1024) return size + " B"
            if (size < 1024 * 1024) return (size / 1024).toFixed(1) + " KB"
            return (size / (1024 * 1024)).toFixed(1) + " MB"
        }).join(", ")

        notificationProc.command = [
            "notify-send",
            Translation.tr("LocalSend: Incoming Transfer"),
            Translation.tr("From: %1\nFiles: %2 (%3)").arg(transfer.sender).arg(fileNames).arg(fileSizes),
            "-A", "accept=Kabul Et",
            "-A", "deny=Reddet",
            "-a", "LocalSend",
        ]
        notificationProc.running = true
    }

    // Main receive server process
    Process {
        id: receiveProc
        running: false
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                if (!line || line.trim().length === 0) return
                try {
                    const event = JSON.parse(line)
                    root.handleLocalSendEvent(event)
                } catch (e) {
                    console.error("[LocalSend] Failed to parse JSON:", line, e)
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                console.log("[LocalSend] stderr:", line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[LocalSend] Server stopped with exit code:", exitCode)
            root.serverStopped()
        }
    }

    function handleLocalSendEvent(event: var): void {
        if (!event || !event.event) return
        console.log("[LocalSend] Event:", JSON.stringify(event))

        switch (event.event) {
            case "ready":
                root.serverStarted()
                break

            case "device":
                console.log("[LocalSend] Device registered:", event.alias)
                break

            case "incoming":
                const transfer = {
                    sender: event.sender || "Unknown",
                    senderIp: event.ip || "",
                    files: event.files || [],
                    isText: event.is_text || false,
                    sessionId: ""
                }
                root.currentTransfer = transfer
                root.pendingTransfers.push(transfer)
                root.transferRequested(transfer)
                break

            case "prompt":
                console.log("[LocalSend] Prompt received, showing notification")
                if (root.currentTransfer && root.showNotifications) {
                    root.showIncomingNotification(root.currentTransfer)
                }
                break

            case "text":
                const textTransfer = {
                    sender: event.sender || "Unknown",
                    text: event.text || "",
                    timestamp: Date.now()
                }
                root.transferCompleted(textTransfer)
                root.addToHistory(textTransfer)
                if (root.showNotifications) {
                    Quickshell.execDetached([
                        "notify-send",
                        Translation.tr("LocalSend: Text Received"),
                        Translation.tr("From: %1\n%2").arg(event.sender || "Unknown").arg(event.text || ""),
                        "-a", "LocalSend",
                    ])
                }
                root.currentTransfer = null
                break

            case "saved":
                const fileTransfer = {
                    sender: event.sender || "Unknown",
                    fileName: event.name || "",
                    filePath: event.path || "",
                    fileSize: event.size || 0,
                    timestamp: Date.now()
                }
                root.transferCompleted(fileTransfer)
                root.addToHistory(fileTransfer)
                if (root.showNotifications) {
                    Quickshell.execDetached([
                        "notify-send",
                        Translation.tr("LocalSend: File Received"),
                        Translation.tr("From: %1\n%2").arg(event.sender || "Unknown").arg(event.name || ""),
                        "-a", "LocalSend",
                    ])
                }
                root.currentTransfer = null
                break

            case "cancelled":
                root.transferCancelled(event)
                root.currentTransfer = null
                break
        }
    }

    function startServer(): void {
        if (!root.available) {
            console.warn("[LocalSend] localsend-cli is not available")
            return
        }
        if (!root.localSendEnabled) {
            console.log("[LocalSend] LocalSend is disabled in policies")
            return
        }
        if (receiveProc.running) {
            console.log("[LocalSend] Server is already running")
            return
        }
        // Set command with current downloadPath
        receiveProc.command = ["localsend-cli", "receive", "--interactive-json", "--output", root.downloadPath]
        console.log("[LocalSend] Starting receive server with output dir:", root.downloadPath)
        receiveProc.running = true
    }

    function stopServer(): void {
        console.log("[LocalSend] Stopping receive server...")
        receiveProc.running = false
    }

    function restartServer(): void {
        if (receiveProc.running) {
            console.log("[LocalSend] Restarting server...")
            receiveProc.running = false
            // Wait for process to stop, then start again
            restartDelayTimer.restart()
        } else if (root.localSendEnabled && root.available) {
            root.startServer()
        }
    }

    Timer {
        id: restartDelayTimer
        interval: 2000 // 2 seconds delay
        repeat: false
        onTriggered: {
            console.log("[LocalSend] Restarting server after delay...")
            root.startServer()
        }
    }

    function acceptTransfer(): void {
        console.log("[LocalSend] Accepting transfer...")
        receiveProc.write("y\n")
    }

    function denyTransfer(): void {
        console.log("[LocalSend] Denying transfer...")
        receiveProc.write("n\n")
    }

    function addToHistory(transfer: var): void {
        root.transferHistory.push(transfer)
        // Keep only last 50 transfers
        if (root.transferHistory.length > 50) {
            root.transferHistory = root.transferHistory.slice(-50)
        }
    }

    function clearHistory(): void {
        root.transferHistory = []
    }

    function getPendingTransfers(): list<var> {
        return root.pendingTransfers
    }

    function clearPendingTransfers(): void {
        root.pendingTransfers = []
    }

    Component.onCompleted: {
        if (Config.ready) {
            checkAvailabilityProc.running = true
        }
    }

    onLocalSendEnabledChanged: {
        if (root.localSendEnabled && root.available && root.autoStart) {
            root.startServer()
        } else if (!root.localSendEnabled && receiveProc.running) {
            root.stopServer()
        }
    }

    onDownloadPathChanged: {
        // Restart server if download path changed while running
        if (receiveProc.running) {
            console.log("[LocalSend] Download path changed, restarting server...")
            root.restartServer()
        }
    }

    IpcHandler {
        target: "localsend"

        function start(): void {
            root.startServer()
        }

        function stop(): void {
            root.stopServer()
        }

        function status(): string {
            return JSON.stringify({
                available: root.available,
                running: root.serverRunning,
                downloadPath: root.downloadPath
            })
        }
    }
}
