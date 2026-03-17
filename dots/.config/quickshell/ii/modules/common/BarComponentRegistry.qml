pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var allComponents: [
        { id: "policies_panel_button", icon: "star", title: "Policies panel button" },
        { id: "active_window", icon: "label", title: "Active window" },
        { id: "music_player", icon: "music_note", title: "Music player" },
        { id: "workspaces", icon: "workspaces", title: "Workspaces" },
        { id: "system_monitor", icon: "monitor_heart", title: "System monitor" },
        { id: "clock", icon: "nest_clock_farsight_analog", title: "Clock" },
        { id: "system_tray", icon: "system_update_alt", title: "System tray" },
        { id: "dashboard_panel_button", icon: "notifications", title: "Dashboard panel button" },
        { id: "record_indicator", icon: "screen_record", title: "Record indicator" },
        { id: "screen_share_indicator", icon: "screen_share", title: "Screen share indicator" },
        { id: "date", icon: "date_range", title: "Date" },
        { id: "battery", icon: "battery_android_6", title: "Battery" },
        { id: "timer", icon: "timer", title: "Timer & Pomodoro" },
        { id: "weather", icon: "weather_mix", title: "Weather" },
        { id: "utility_buttons", icon: "build", title: "Utility buttons" }
    ]

    function getComponent(id) {
        return allComponents.find(c => c.id === id) || null
    }

    function getAvailableComponents(usedIds) {
        return allComponents.filter(c => !usedIds.includes(c.id))
    }
}
