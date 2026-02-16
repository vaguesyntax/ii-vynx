pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    // Derived CPU information
    property real cpuCurrentFreqMHz: 0
    property string cpuCurrentFreqString: "--"
    property real cpuTemperatureCelsius: 0
    property string cpuTemperatureString: "--"

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

	Timer {
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Update CPU frequency and temperature asynchronously
            if (!cpuFreqProcess.running) {
                cpuFreqProcess.running = true
            }
            if (!cpuTempProcess.running) {
                cpuTempProcess.running = true
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }

    // Best-effort CPU max frequency reader from sysfs, if available.
    // Reads /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq (kHz),
    // averages across cores, and exposes GHz.
    Process {
        id: cpuFreqProcess
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "awk '{sum+=$1; n++} END {if (n>0) print sum/n}' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null"]
        stdout: StdioCollector {
            id: cpuFreqOutputCollector
            onStreamFinished: {
                const avgKHz = parseFloat(cpuFreqOutputCollector.text)
                if (!isNaN(avgKHz)) {
                    const mhz = avgKHz / 1000.0
                    root.cpuCurrentFreqMHz = mhz
                    root.cpuCurrentFreqString = (mhz / 1000.0).toFixed(2) + " GHz"
                }
            }
        }
    }

    // Best-effort CPU temperature reader using lm-sensors + jq, if available.
    // Uses `sensors -j` and looks for common chips (k10temp, coretemp) and fields.
    Process {
        id: cpuTempProcess
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "sensors -j 2>/dev/null | jq -r 'to_entries[] | select(.key | test(\"k10temp|coretemp\")) | .value | .Tccd1?.temp2_input // .Tdie?.temp1_input // .[\"Package id 0\"]?.temp1_input // .Tctl?.temp1_input' | grep -v null | head -n1"]
        stdout: StdioCollector {
            id: cpuTempOutputCollector
            onStreamFinished: {
                const temp = parseFloat(cpuTempOutputCollector.text)
                if (!isNaN(temp)) {
                    root.cpuTemperatureCelsius = temp
                    root.cpuTemperatureString = temp.toFixed(0) + " °C"
                }
            }
        }
    }
}
