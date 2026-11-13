pragma Singleton
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // just fb fixme later
    readonly property var fallbackTimezones: [
        // O
        "Pacific/Auckland", "Pacific/Fiji", "Pacific/Guam", "Pacific/Honolulu",
        "Pacific/Pago_Pago", "Pacific/Apia", "Pacific/Tahiti",
        "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane",
        "Australia/Adelaide", "Australia/Darwin", "Australia/Perth",

        // A
        "Asia/Tokyo", "Asia/Seoul", "Asia/Shanghai", "Asia/Hong_Kong",
        "Asia/Taipei", "Asia/Singapore", "Asia/Kuala_Lumpur", "Asia/Manila",
        "Asia/Makassar", "Asia/Jakarta", "Asia/Bangkok", "Asia/Ho_Chi_Minh",
        "Asia/Yangon", "Asia/Dhaka", "Asia/Kathmandu", "Asia/Kolkata",
        "Asia/Karachi", "Asia/Tashkent", "Asia/Kabul", "Asia/Dubai",
        "Asia/Muscat", "Asia/Tehran", "Asia/Baghdad", "Asia/Riyadh",
        "Asia/Kuwait", "Asia/Qatar", "Asia/Jerusalem", "Asia/Beirut",
        "Asia/Damascus", "Asia/Nicosia",

        // UE
        "Europe/Moscow", "Europe/Istanbul", "Europe/Athens", "Europe/Bucharest",
        "Europe/Helsinki", "Europe/Kiev", "Europe/Minsk", "Europe/Warsaw",
        "Europe/Vienna", "Europe/Prague", "Europe/Budapest", "Europe/Berlin",
        "Europe/Paris", "Europe/Brussels", "Europe/Amsterdam", "Europe/Zurich",
        "Europe/Madrid", "Europe/Rome", "Europe/London", "Europe/Dublin",
        "Europe/Lisbon", "Atlantic/Reykjavik", "Atlantic/Azores",

        // A
        "Africa/Cairo", "Africa/Johannesburg", "Africa/Nairobi", "Africa/Addis_Ababa",
        "Africa/Khartoum", "Africa/Lagos", "Africa/Kinshasa", "Africa/Algiers",
        "Africa/Casablanca", "Africa/Tunis", "Africa/Accra", "Africa/Dakar",

        // SA
        "America/Sao_Paulo", "America/Rio_Branco", "America/Buenos_Aires",
        "America/Cordoba", "America/Santiago", "America/Asuncion", "America/Montevideo",
        "America/La_Paz", "America/Cuiaba", "America/Lima", "America/Bogota",
        "America/Guayaquil", "America/Caracas",

        // CA
        "America/Panama", "America/Costa_Rica", "America/El_Salvador",
        "America/Guatemala", "America/Managua", "America/Tegucigalpa",
        "America/Havana", "America/Santo_Domingo", "America/Puerto_Rico",
        "America/Jamaica",

        // NA
        "America/Mexico_City", "America/Monterrey", "America/Tijuana",
        "America/New_York", "America/Miami", "America/Detroit", "America/Chicago",
        "America/Houston", "America/Denver", "America/Phoenix", "America/Los_Angeles",
        "America/Anchorage", "America/Vancouver", "America/Edmonton",
        "America/Winnipeg", "America/Toronto", "America/Halifax", "America/St_Johns"
    ]

    readonly property var timezoneList: {
        if (typeof Intl !== "undefined" && typeof Intl.supportedValuesOf === "function") {
            try {
                return Intl.supportedValuesOf("timeZone")
            } catch (e) {
                return root.fallbackTimezones
            }
        }
        return root.fallbackTimezones
    }

    function labelFor(tz) {
        const parts = tz.split("/")
        const city = (parts[parts.length - 1] ?? tz).replace(/_/g, " ")
        const region = parts[0] ?? ""
        return region ? `${city} (${region})` : city
    }

    readonly property var comboModel: root.timezoneList.map(tz => ({ label: root.labelFor(tz), tz: tz, icon: "" }))

    property list<string> timezones: Config.options?.background?.widgets?.worldClock?.timezones ?? [
        "Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"
    ]

    function setTimezone(index, tz) {
        let updated = root.timezones.slice()
        updated[index] = tz
        root.timezones = updated
        Config.options.background.widgets.worldClock.timezones = updated
    }

    onTimezonesChanged: root.refreshOffsets()
    Component.onCompleted: root.refreshOffsets()

    readonly property string ampmToken: {
        const fmt = Config.options?.time.format ?? "HH:mm"
        if (fmt.includes("AP")) return "AP"
        if (fmt.includes("ap")) return "ap"
        return ""
    }
    readonly property bool use24h: root.ampmToken === ""

    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    property var offsetsMinutes: [0, 0, 0, 0]

    function refreshOffsets() {
        offsetProc.running = false
        offsetProc.running = true
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refreshOffsets()
    }

    Process {
        id: offsetProc
        command: ["bash", "-c", root.timezones.map(tz => `TZ='${tz}' date +%z`).join("; ")]
        stdout: StdioCollector {
            id: offsetCollector
            onStreamFinished: {
                const lines = offsetCollector.text.trim().split("\n")
                root.offsetsMinutes = lines.map(line => {
                    const m = line.trim().match(/^([+-])(\d{2})(\d{2})$/)
                    if (!m) return 0
                    const sign = m[1] === "-" ? -1 : 1
                    return sign * (parseInt(m[2]) * 60 + parseInt(m[3]))
                })
            }
        }
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n
    }

    function cityDate(index) {
        const offsetMin = root.offsetsMinutes[index] ?? 0
        return new Date(root.now.getTime() + offsetMin * 60000)
    }

    function timeStringFor(index) {
        const cd = root.cityDate(index)
        let h = cd.getUTCHours()
        let m = cd.getUTCMinutes()
        if (root.use24h) {
            return pad(h) + ":" + pad(m)
        }
        let h12 = h % 12
        if (h12 === 0) h12 = 12
        const base = pad(h12) + ":" + pad(m)
        if (root.ampmToken === "AP") return base + " " + (h >= 12 ? "PM" : "AM")
        return base + " " + (h >= 12 ? "pm" : "am")
    }

    function offsetLabelFor(index) {
        const offsetMin = root.offsetsMinutes[index] ?? 0
        const sign = offsetMin >= 0 ? "+" : "-"
        const abs = Math.abs(offsetMin)
        const h = Math.floor(abs / 60)
        const m = abs % 60
        return "UTC" + sign + h + (m > 0 ? ":" + pad(m) : "")
    }

    function isDaytimeFor(index) {
        const cd = root.cityDate(index)
        const h = cd.getUTCHours()
        return h >= 6 && h < 18
    }

    readonly property var entries: root.timezones.map((tz, i) => ({
        tz: tz,
        name: root.labelFor(tz).split(" (")[0],
        time: root.timeStringFor(i),
        offset: root.offsetLabelFor(i),
        isDay: root.isDaytimeFor(i)
    }))
}
