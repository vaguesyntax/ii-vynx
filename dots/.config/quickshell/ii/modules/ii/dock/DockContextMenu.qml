import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import qs
import "./widgets"

DockContextMenuBase {
    id: root

    property var appToplevel: null
    property var desktopEntry: null
    
    headerText: root.desktopEntry?.name ?? (root.appToplevel ? root.appToplevel.appId : "")
    headerIcon: Component {
        DockIcon {
            implicitWidth: 22
            implicitHeight: 22
            appId: root.appToplevel?.appId ?? ""
            isRunning: true
        }
    }

    contentComponent: ColumnLayout {
        spacing: 0
        
        // Desktop entry actions (e.g. "New Window", "New Private Window")
        Repeater {
            model: root.desktopEntry?.actions ?? []
            delegate: DockMenuButton {
                required property var modelData
                required property int index
                Layout.fillWidth: true

                readonly property var shapePool: [
                    "Clover4Leaf", "Arrow", "Pill", "SoftBurst",
                    "Diamond", "ClamShell", "Pentagon"
                ]

                shapeString: shapePool[index % shapePool.length]
                labelText: modelData.name ?? ""
                onTriggered: { modelData.execute(); root.close() }
            }
        }

        Rectangle {
            visible: (root.desktopEntry?.actions?.length ?? 0) > 0
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
        }

        DockMenuButton {
            Layout.fillWidth: true
            symbolName: "launch"
            labelText: qsTr("Launch")
            onTriggered: { root.desktopEntry?.execute(); root.close() }
        }

        DockMenuButton {
            Layout.fillWidth: true
            symbolName: (root.appToplevel && TaskbarApps.isPinned(root.appToplevel.appId)) ? "keep_off" : "keep"
            labelText: (root.appToplevel && TaskbarApps.isPinned(root.appToplevel.appId)) ? qsTr("Unpin") : qsTr("Pin")
            onTriggered: {
                if (root.appToplevel) TaskbarApps.togglePin(root.appToplevel.appId)
                root.close()
            }
        }

        DockMenuButton {
            visible: (root.appToplevel?.toplevels?.length ?? 0) > 0
            Layout.fillWidth: true
            symbolName: "close"
            labelText: (root.appToplevel?.toplevels?.length ?? 0) > 1
                       ? qsTr("Close all windows") : qsTr("Close window")
            isDestructive: true
            onTriggered: {
                if (root.appToplevel)
                    for (const t of root.appToplevel.toplevels) t.close()
                root.close()
            }
        }
    }
}
