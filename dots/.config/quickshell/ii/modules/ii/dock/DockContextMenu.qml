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
        color: "red"

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
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight - popupWindow.dockMargin
                } else if (pos === "top") {
                    anchor.rect.x = mapped.x - popupWindow.implicitWidth / 2
                    anchor.rect.y = mapped.y + popupWindow.dockMargin
                } else if (pos === "left") {
                    anchor.rect.x = mapped.x + popupWindow.dockMargin
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight / 2
                } else {
                    anchor.rect.x = mapped.x - popupWindow.implicitWidth - popupWindow.dockMargin
                    anchor.rect.y = mapped.y - popupWindow.implicitHeight / 2
                }
            }
        }

        implicitWidth:  menuContent.implicitWidth  + popupWindow.shadowMargin * 2
        implicitHeight: menuContent.implicitHeight + popupWindow.shadowMargin * 2

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
            property real menuMargin: 8
            anchors.centerIn: parent
            color: Appearance.m3colors.m3surfaceContainer // or Appearance.colors.colLayer0 idk which is better
            // border.width: 1
            // border.color: Appearance.colors.colLayer0Border
            radius: Appearance.rounding.normal
            implicitWidth:  menuColumn.implicitWidth + (appName.Layout.leftMargin * 2) + (menuMargin * 2) 
            implicitHeight: menuColumn.implicitHeight  + menuMargin * 2

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupWindow)
            }

        ColumnLayout {
            id: menuColumn
            anchors.fill: parent
            anchors.leftMargin: menuContent.menuMargin
            anchors.rightMargin: menuContent.menuMargin
            anchors.topMargin: menuContent.menuMargin
            anchors.bottomMargin: menuContent.menuMargin
            spacing: 0
            
                            // --- App name header ---
            Item {
                id: appName
                Layout.fillWidth: true
                implicitHeight: appNameRow.implicitHeight 
                implicitWidth:  appNameRow.implicitWidth
                Layout.bottomMargin: menuContent.menuMargin
                Layout.leftMargin: 2 
                Layout.rightMargin: 2
                RowLayout {
                    id: appNameRow
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6
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
                    Layout.bottomMargin: menuContent.menuMargin 
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
                }

                Repeater {
                    model: root.desktopEntry?.actions ?? []
                    delegate: DockMenuButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true

                        readonly property var shapePool: [
                            "Flower", "Gem", "SoftBurst", "Clover4Leaf",
                            "Heart", "Puffy", "Diamond", "Pentagon",
                            "Cookie6Sided", "SoftBoom", "Bun", "PuffyDiamond"
                        ]

                        shapeString: shapePool[index % shapePool.length]
                        labelText: modelData.name ?? ""
                        onTriggered: { modelData.execute(); root.active = false }
                    }
                }

                Rectangle {
                    visible: (root.desktopEntry?.actions?.length ?? 0) > 0
                    Layout.fillWidth: true
                    Layout.topMargin: menuContent.menuMargin
                    Layout.bottomMargin: menuContent.menuMargin
                    implicitHeight: 1
                    color: Appearance.colors.colLayer0Border
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
                                    Layout.leftMargin: 2

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
            }
        }
    }
}