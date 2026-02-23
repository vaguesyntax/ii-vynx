pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    readonly property string _sessionId: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    Timer {
        id: restoreTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!Persistent.ready) return
            const storedId = Persistent.states.idle.sessionId || ""
            if (storedId === root._sessionId) {
                root.inhibit = Persistent.states.idle.inhibit ?? false
            } else {
                root.inhibit = false
            }
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() { restoreTimer.restart() }
    }

    function toggleInhibit(active = null) {
        root.inhibit = active !== null ? active : !root.inhibit
        Persistent.states.idle.inhibit = root.inhibit
        Persistent.states.idle.sessionId = root._sessionId
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
