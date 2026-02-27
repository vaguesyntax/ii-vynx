import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

Loader {
    id: root

    property var appToplevel: null
    property var desktopEntry: null
    property Item anchorItem: parent
    signal closed()

    function open() {
        root.active = true
    }

    function close() {
        if (root.item) root.item.close()
    }

    onActiveChanged: {
        if (!root.active) root.closed()
    }

    active: false
    visible: active

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        color: "transparent"

        property real dockMargin: 25
        property real shadowMargin: 20
        

        anchor {
            adjustment: PopupAdjustment.None
            window: root.anchorItem?.QsWindow.window
            onAnchoring: {
                const item = root.anchorItem
                if (!item) return
                const pos = GlobalStates.dockEffectivePosition
                const mapped = item.mapToItem(null, item.width / 2, item.height / 2)
                if (pos === "bottom") {
                    anchor.rect.x = mapped.x - popupWindow.implicitWidth / 2
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight - dockMargin
                } else if (pos === "top") {
                    anchor.rect.x = mapped.x - popupWindow.implicitWidth / 2
                    anchor.rect.y = mapped.y + dockMargin
                } else if (pos === "left") {
                    anchor.rect.x = mapped.x + dockMargin
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight / 2
                } else {
                    anchor.rect.x = mapped.x - popupWindow.implicitWidth - dockMargin
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight / 2
                }
            }
        }

        implicitWidth:  menuContent.implicitWidth  + shadowMargin * 2
        implicitHeight: menuContent.implicitHeight + shadowMargin * 2

        HyprlandFocusGrab {
            id: focusGrab
            active: true
            windows: [popupWindow]
            onCleared: root.active = false
        }

        function close() {
            root.active = false
        }

        StyledRectangularShadow {
            target: menuContent
            opacity: menuContent.opacity
            visible: menuContent.visible
        }

        Rectangle {
            id: menuContent
            anchors.centerIn: parent
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            radius: Appearance.rounding.normal
            implicitWidth:  menuColumn.implicitWidth  + 8
            implicitHeight: menuColumn.implicitHeight + 8

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupWindow)
            }

        ColumnLayout {
            id: menuColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 6
            }
            spacing: 0
            
                            // --- App name header ---
            Item {
                Layout.fillWidth: true
                implicitHeight: appNameRow.implicitHeight + 15
                implicitWidth:  appNameRow.implicitWidth  + 32
                RowLayout {
                    id: appNameRow
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 8
                    }
                    spacing: 8
                    IconImage {
                        Layout.alignment: Qt.AlignLeft
                        implicitSize: 22
                        source: root.appToplevel
                            ? Quickshell.iconPath(AppSearch.guessIcon(root.appToplevel.appId), "image-missing")
                            : ""
                    }
                    StyledText {
                        text: root.desktopEntry?.name ?? (root.appToplevel ? root.appToplevel.appId : "")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        font.weight: Font.DemiBold
                    }
                }
            }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                // --- Desktop Entry Actions ---
                Repeater {
                    model: root.desktopEntry?.actions ?? []
                    delegate: DockMenuButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignLeft
                        labelText: modelData.name ?? ""
                        onTriggered: { modelData.execute(); root.active = false }
                    }
                }

                Rectangle {
                    visible: (root.desktopEntry?.actions?.length ?? 0) > 0
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                }

                // --- Launch ---
                DockMenuButton {
                    Layout.fillWidth: true
                    symbolName: "launch"
                    labelText: qsTr("Launch")
                    onTriggered: { root.desktopEntry?.execute(); root.active = false }
                }

                // --- Pin / Unpin ---
                DockMenuButton {
                    Layout.fillWidth: true
                    symbolName: root.appToplevel?.pinned ? "keep_off" : "keep"
                    labelText: root.appToplevel?.pinned ? qsTr("Unpin") : qsTr("Pin")
                    onTriggered: {
                        if (root.appToplevel) TaskbarApps.togglePin(root.appToplevel.appId)
                        root.active = false
                    }
                }

                // --- Close window(s) ---
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
                        root.active = false
                    }
                }

                Item { implicitHeight: 4 }
            }
        }
    }
}