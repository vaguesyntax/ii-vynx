import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

StyledPopup {
    id: root

    property bool useSystemLanguage: true

    readonly property var _locale: Qt.locale()
    readonly property string _localeName: _locale ? String(_locale.name || "") : ""
    readonly property bool _isSpanish: root.useSystemLanguage
                                      && (_localeName.toLowerCase().startsWith("es") || _localeName.toLowerCase().includes("_es"))

    function tr(key) {
        const en = {
            headerTitle: "SYSTEM MONITOR",
            active: "Active",
            processor: "Processor",
            temp: "Temp",
            ram: "RAM Memory",
            used: "USED",
            free: "FREE",
            total: "TOTAL",
            swap: "Swap",
            na: "N/A"
        }

        const es = {
            headerTitle: "MONITOR DE SISTEMA",
            active: "Activo",
            processor: "Procesador",
            temp: "Temp",
            ram: "Memoria RAM",
            used: "USADO",
            free: "LIBRE",
            total: "TOTAL",
            swap: "Swap",
            na: "N/A"
        }

        const dict = root._isSpanish ? es : en
        return dict[key] !== undefined ? dict[key] : (en[key] !== undefined ? en[key] : key)
    }

    property bool optShowHeader: true
    property bool optShowCpuCard: true
    property bool optShowRamCard: true
    property bool optShowSwapCard: true

    property bool optReadCpuTemp: true
    property int optRefreshMs: 2000
    property int optTempReadbackMs: 80

    property bool optReadTempsFromJson: true
    property string optTempsJsonPath: "/home/jcgomez91/.cache/quickshell/temps.json"
    property string optCpuTempPath: "/sys/class/thermal/thermal_zone0/temp"

    property bool optAnimations: true
    property int optWidth: 420
    property int optSpacing: 18

    property real cpuTempC: 0
    property string cpuTemp: root.tr("na")

    function parseTempCFromSysfs(raw) {
        let val = (raw !== undefined && raw !== null ? raw : "").toString().trim()
        if (!val || val === "0") return 0
        let t = parseInt(val)
        if (isNaN(t) || t === 0) return 0
        if (t > 1000) t = t / 1000
        return Number(t) || 0
    }

    function formatTempLabel(tempC) {
        let t = Number(tempC)
        if (!isFinite(t) || t <= 0) return root.tr("na")
        return Math.round(t) + "°C"
    }

    function formatGB(kb) {
        if (kb === undefined || kb === null || isNaN(kb) || kb <= 0) return "0.0 GB"
        let gb = kb / (1024 * 1024)
        return gb.toFixed(1) + " GB"
    }

    function clamp01(x) {
        if (x === undefined || isNaN(x)) return 0
        if (x < 0) return 0
        if (x > 1) return 1
        return x
    }

    function memRatio() {
        const total = ResourceUsage.memoryTotal
        if (!total || total <= 0) return 0
        const used = ResourceUsage.memoryUsed !== undefined ? ResourceUsage.memoryUsed : 0
        return clamp01(used / total)
    }

    function swapRatio() {
        const total = ResourceUsage.swapTotal
        if (!total || total <= 0) return 0
        const used = ResourceUsage.swapUsed !== undefined ? ResourceUsage.swapUsed : 0
        return clamp01(used / total)
    }

    function parseTempsJson(raw) {
        let s = String(raw || "").trim()
        if (!s.length) return 0
        try {
            let obj = JSON.parse(s)
            let t = Number(obj.cpu_c) || 0
            return t
        } catch (e) {
            return 0
        }
    }

    Item {
        id: logic
        visible: false
        width: 0
        height: 0

        FileView { id: fileTemps; path: root.optTempsJsonPath }

        Timer {
            id: tempTimer
            interval: root.optRefreshMs
            running: root.optReadCpuTemp
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (root.optReadTempsFromJson) {
                    fileTemps.reload()
                    readBack.restart()
                } else {
                    cpuProc.running = false
                    cpuProc.running = true
                    readBack.restart()
                }
            }
        }

        Timer {
            id: readBack
            interval: root.optTempReadbackMs
            repeat: false
            onTriggered: {
                let tC = 0
                if (root.optReadTempsFromJson) {
                    tC = root.parseTempsJson(fileTemps.text())
                } else {
                    tC = root.parseTempCFromSysfs(cpuProc.stdout)
                }
                root.cpuTempC = tC
                root.cpuTemp = root.formatTempLabel(tC)
            }
        }

        Process {
            id: cpuProc
            command: ["cat", root.optCpuTempPath]
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        implicitWidth: root.optWidth
        spacing: root.optSpacing

        RowLayout {
            visible: root.optShowHeader
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 80; height: 42; radius: 18
                color: Qt.alpha(Appearance.colors.colSecondaryContainer, 0.6)
                border.width: 1
                border.color: Qt.alpha(Appearance.colors.colOutline, 0.1)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "monitor_heart"
                    iconSize: 22
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                spacing: 2

                StyledText {
                    text: root.tr("headerTitle")
                    font.bold: true
                    font.pixelSize: 13
                    font.letterSpacing: 2.0
                    color: Appearance.colors.colOnSurface
                }

                RowLayout {
                    spacing: 6
                    Rectangle { width: 6; height: 6; radius: 3; color: "#4CAF50" }

                    StyledText {
                        text: root.tr("active") + " · " + (DateTime.uptime ? DateTime.uptime : "...")
                        font.pixelSize: 11
                        font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }

        Rectangle {
            visible: root.optShowHeader
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.15
        }

        Rectangle {
            visible: root.optShowCpuCard
            Layout.fillWidth: true
            height: 95
            radius: 18
            color: Appearance.colors.colSurfaceContainer
            border.width: 1
            border.color: Qt.alpha(Appearance.colors.colOutline, 0.08)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 36; height: 36; radius: 12
                        color: Qt.alpha(Appearance.colors.colPrimaryContainer, 0.4)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "memory"
                            iconSize: 20
                            color: Appearance.m3colors.m3primary
                        }
                    }

                    ColumnLayout {
                        spacing: 1

                        StyledText {
                            text: root.tr("processor")
                            font.bold: true
                            font.pixelSize: 13
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            visible: root.optReadCpuTemp
                            text: root.tr("temp") + ": " + (root.cpuTemp && root.cpuTemp.length ? root.cpuTemp : root.tr("na"))
                            font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                            font.pixelSize: 11
                            color: Appearance.colors.colOnSurface
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Math.round(root.clamp01(ResourceUsage.cpuUsage !== undefined ? ResourceUsage.cpuUsage : 0) * 100) + "%"
                        font.bold: true
                        font.pixelSize: 24
                        font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                        color: Appearance.m3colors.m3primary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.alpha(Appearance.colors.colOnSurface, 0.1)

                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * root.clamp01(ResourceUsage.cpuUsage !== undefined ? ResourceUsage.cpuUsage : 0)
                        color: Appearance.m3colors.m3error

                        Behavior on width {
                            enabled: root.optAnimations
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.optShowRamCard
            Layout.fillWidth: true
            height: 155
            radius: 18
            color: Appearance.colors.colSurfaceContainer
            border.width: 1
            border.color: Qt.alpha(Appearance.colors.colOutline, 0.08)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 36; height: 36; radius: 12
                        color: Qt.alpha(Appearance.colors.colPrimaryContainer, 0.4)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "dns"
                            iconSize: 20
                            color: Appearance.m3colors.m3primary
                        }
                    }

                    StyledText {
                        text: root.tr("ram")
                        font.bold: true
                        font.pixelSize: 13
                        color: Appearance.colors.colOnSurface
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: Math.round(root.memRatio() * 100) + "%"
                        font.bold: true
                        font.pixelSize: 24
                        font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                        color: Appearance.m3colors.m3primary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Qt.alpha(Appearance.colors.colOnSurface, 0.1)

                    Rectangle {
                        height: parent.height
                        radius: 3
                        width: parent.width * root.memRatio()
                        color: Appearance.m3colors.m3primary

                        Behavior on width {
                            enabled: root.optAnimations
                            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Layout.topMargin: 5

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: 12
                        color: Qt.alpha(Appearance.colors.colSurfaceContainerHigh, 0.5)
                        border.width: 1
                        border.color: Qt.alpha(Appearance.colors.colOutline, 0.05)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            StyledText { text: root.tr("used"); font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Appearance.colors.colOnSurfaceVariant }
                            StyledText {
                                text: root.formatGB(ResourceUsage.memoryUsed !== undefined ? ResourceUsage.memoryUsed : 0)
                                font.bold: true
                                font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                                font.pixelSize: 12
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: 12
                        color: Qt.alpha(Appearance.colors.colSurfaceContainerHigh, 0.5)
                        border.width: 1
                        border.color: Qt.alpha(Appearance.colors.colOutline, 0.05)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            StyledText { text: root.tr("free"); font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Appearance.colors.colOnSurfaceVariant }
                            StyledText {
                                text: root.formatGB(ResourceUsage.memoryFree !== undefined ? ResourceUsage.memoryFree : 0)
                                font.bold: true
                                font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                                font.pixelSize: 12
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 50; radius: 12
                        color: Qt.alpha(Appearance.colors.colSurfaceContainerHigh, 0.5)
                        border.width: 1
                        border.color: Qt.alpha(Appearance.colors.colOutline, 0.05)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            StyledText { text: root.tr("total"); font.pixelSize: 9; font.bold: true; font.letterSpacing: 1; color: Appearance.colors.colOnSurfaceVariant }
                            StyledText {
                                text: root.formatGB(ResourceUsage.memoryTotal !== undefined ? ResourceUsage.memoryTotal : 0)
                                font.bold: true
                                font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                                font.pixelSize: 12
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.optShowSwapCard && (ResourceUsage.swapTotal !== undefined ? ResourceUsage.swapTotal : 0) > 0
            Layout.fillWidth: true
            height: 75
            radius: 18
            color: Appearance.colors.colSurfaceContainer
            border.width: 1
            border.color: Qt.alpha(Appearance.colors.colOutline, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Rectangle {
                    width: 40; height: 40; radius: 12
                    color: Qt.alpha(Appearance.colors.colSecondaryContainer, 0.4)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "swap_horiz"
                        iconSize: 20
                        color: Appearance.m3colors.m3secondary
                    }
                }

                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            text: root.tr("swap")
                            font.bold: true
                            font.pixelSize: 13
                            color: Appearance.colors.colOnSurface
                        }

                        Item { Layout.fillWidth: true }

                        StyledText {
                            text: root.formatGB(ResourceUsage.swapUsed !== undefined ? ResourceUsage.swapUsed : 0) + " / " +
                                  root.formatGB(ResourceUsage.swapTotal !== undefined ? ResourceUsage.swapTotal : 0)
                            Layout.minimumWidth: 0
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideNone
                            font.pixelSize: 10
                            font.family: (Appearance.font && Appearance.font.name ? Appearance.font.name : "")
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 4
                        radius: 2
                        color: Qt.alpha(Appearance.colors.colOnSurface, 0.1)

                        Rectangle {
                            height: parent.height
                            radius: 2
                            width: parent.width * root.swapRatio()
                            color: Appearance.m3colors.m3secondary

                            Behavior on width {
                                enabled: root.optAnimations
                                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }
            }
        }
    }
}

