import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    // Tracks the global orientation of the dock (horizontal or vertical).
    property bool isVertical: GlobalStates.dockIsVertical

    // State passed from the main Dock file to know if the dock is pinned
    property bool isPinned: false
    // Signal emitted when the user clicks the Pin button
    signal togglePinRequested()

    // Padding applied around all buttons inside the dock.
    property real buttonPadding: 5

    // An array that holds the processed list of apps to display.
    property var processedApps: []

    // --- STUBS FOR FUTURE POPUP LOGIC ---
    property Item lastHoveredButton
    property bool buttonHovered: false

    // Expose the layout's calculated size to this root Item.
    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Function to transform the raw TaskbarApps data into an array of objects.
    function updateModel() {
        const apps = TaskbarApps.apps || []
        const newModel = []
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i]
            newModel.push({ uniqueKey: app.appId, appData: app })
        }
        processedApps = newModel
    }

    Connections {
        target: TaskbarApps
        function onAppsChanged() { updateModel() }
    }

    Component.onCompleted: updateModel()

    GridLayout {
        id: layout

        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        columnSpacing: 2
        rowSpacing: 2
        anchors.centerIn: parent

        // --- 1. PIN BUTTON ---
        Item {
            id: pinButton
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignCenter

            VerticalButtonGroup {
                anchors.centerIn: parent

                GroupButton {
                    baseWidth: 35
                    baseHeight: 35
                    buttonRadius: Appearance.rounding.normal
                    clickedWidth:  root.isVertical ? baseWidth : baseWidth + 20
                    clickedHeight: root.isVertical ? baseHeight + 20 : baseHeight
                    toggled: root.isPinned
                    onClicked: root.togglePinRequested()

                    contentItem: Item {
                        implicitWidth: 35
                        implicitHeight: 35

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keep"
                            iconSize: pinButton.Layout.preferredWidth / 2
                            color: root.isPinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                        }
                    }
                }
            }
        }

        // --- 2. LEFT/TOP SEPARATOR ---
        Item {
            visible: root.processedApps.length > 0
            Layout.preferredWidth:  root.isVertical ? 50 : 1
            Layout.preferredHeight: root.isVertical ? 1 : 50
            
            DockSeparator {
                anchors.fill: parent
                anchors.topMargin:    root.isVertical ? 0 : 8
                anchors.bottomMargin: root.isVertical ? 0 : 8
                anchors.leftMargin:   root.isVertical ? 8 : 0
                anchors.rightMargin:  root.isVertical ? 8 : 0
            }
        }

        // --- 3. THE APPS ---
        Repeater {
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: root.processedApps
            }
            delegate: DockAppButton {
                required property var modelData
                appToplevel: modelData.appData
                appListRoot: root

                topInset:    root.buttonPadding
                bottomInset: root.buttonPadding
                leftInset:   root.buttonPadding
                rightInset:  root.buttonPadding
            }
        }

        // --- 4. RIGHT/BOTTOM SEPARATOR ---
        Item {
            visible: root.processedApps.length > 0
            Layout.preferredWidth:  root.isVertical ? 50 : 1
            Layout.preferredHeight: root.isVertical ? 1 : 50
            
            DockSeparator {
                anchors.fill: parent
                anchors.topMargin:    root.isVertical ? 0 : 8
                anchors.bottomMargin: root.isVertical ? 0 : 8
                anchors.leftMargin:   root.isVertical ? 8 : 0
                anchors.rightMargin:  root.isVertical ? 8 : 0
            }
        }
        // --- 5. OVERVIEW BUTTON ---
        DockButton {
            id: overviewButton
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignCenter
            onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen

            contentItem: Item {
                implicitWidth: overviewButton.baseSize
                implicitHeight: overviewButton.baseSize

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "apps"
                    iconSize: overviewButton.baseSize / 2
                    color: Appearance.colors.colOnLayer0
                }
            }
        }
    }
}