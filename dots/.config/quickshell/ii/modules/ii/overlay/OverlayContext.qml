pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import qs.services
import QtQuick

Singleton {
    id: root
    
    signal requestCenter(string identifier)

    readonly property list<var> availableWidgets: [
        { identifier: "crosshair", materialSymbol: "point_scan" },
        { identifier: "fpsLimiter", materialSymbol: "animation" },
        { identifier: "floatingImage", materialSymbol: "imagesmode" },
        { identifier: "recorder", materialSymbol: "screen_record" },
        { identifier: "media", materialSymbol: "music_note" },
        { identifier: "resources", materialSymbol: "browse_activity" },
        { identifier: "notes", materialSymbol: "note_stack" },
        { identifier: "volumeMixer", materialSymbol: "volume_up" },
    ]

    property list<var> extensionWidgets: []

    readonly property bool hasPinnedWidgets: root.pinnedWidgetIdentifiers.length > 0

    property list<string> pinnedWidgetIdentifiers: []
    property list<var> clickableWidgets: []

    function refreshExtensionWidgets() {
        root.extensionWidgets = ExtensionManager.getContributionPoint("overlayWidgets")
    }

    function pin(identifier: string, pin = true) {
        if (pin) {
            if (!root.pinnedWidgetIdentifiers.includes(identifier)) {
                root.pinnedWidgetIdentifiers.push(identifier)
            }
        } else {
            root.pinnedWidgetIdentifiers = root.pinnedWidgetIdentifiers.filter(id => id !== identifier)
        }
    }

    function registerClickableWidget(widget: var, clickable = true) {
        if (clickable) {
            if (!root.clickableWidgets.includes(widget)) {
                root.clickableWidgets.push(widget)
            }
        } else {
            root.clickableWidgets = root.clickableWidgets.filter(w => w !== widget)
        }
    }

    Connections {
        target: ExtensionManager
        function onRefreshExtensions() {
            root.refreshExtensionWidgets()
        }
    }

    Component.onCompleted: {
        if (ExtensionManager.ready) {
            root.refreshExtensionWidgets()
        } else {
            let checkReady = () => {
                if (ExtensionManager.ready) {
                    root.refreshExtensionWidgets()
                } else {
                    Qt.callLater(checkReady)
                }
            }
            Qt.callLater(checkReady)
        }
    }
}
