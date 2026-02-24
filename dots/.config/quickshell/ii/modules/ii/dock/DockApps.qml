import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// The root Item acts as the container for all the dock buttons.
// Its size is entirely dictated by the GridLayout inside it.
Item {
    id: root

    // Tracks the global orientation of the dock (horizontal or vertical).
    // Read from GlobalStates to keep the UI in sync with the config.
    property bool isVertical: GlobalStates.dockIsVertical

    // Padding applied around the buttons inside the dock.
    // This keeps the icons from touching the outer border of the dock pill.
    property real buttonPadding: 5

    // An array that holds the processed list of apps to display.
    property var processedApps: []

    // --- STUBS FOR FUTURE POPUP LOGIC ---
    // We keep these properties so DockAppButton doesn't throw ReferenceErrors
    // when assigning them on mouse enter/exit. They are ready for when you re-add the popup.
    property Item lastHoveredButton
    property bool buttonHovered: false

    // Expose the layout's calculated size to this root Item.
    // The parent pill background (in the main dock file) uses this implicit size 
    // to wrap tightly around the buttons without creating circular dependency loops.
    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    // Function to transform the raw TaskbarApps data into an array of objects.
    // We assign a "uniqueKey" (the appId) to each item so the Repeater knows exactly 
    // which app is which, preventing visual glitches when windows are opened or closed.
    function updateModel() {
        const apps = TaskbarApps.apps || []
        const newModel = []
        for (let i = 0; i < apps.length; i++) {
            const app = apps[i]
            newModel.push({ uniqueKey: app.appId, appData: app })
        }
        processedApps = newModel
    }

    // Listens to changes in the open/pinned apps from the backend service 
    // and refreshes our local model immediately.
    Connections {
        target: TaskbarApps
        function onAppsChanged() { updateModel() }
    }

    // Initialize the model as soon as this component is created.
    Component.onCompleted: updateModel()

    // We use GridLayout because it calculates dimensions mathematically and reliably.
    // It prevents the transient "bounding box spikes" that Flow or ListView can cause 
    // during orientation changes, which was the root cause of the giant background bug.
    GridLayout {
        id: layout

        // Switch the layout direction based on the dock's global orientation.
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        
        // Force the grid to strictly stay on a single row or single column. 
        // This prevents the dock from splitting into multiple rows if too many apps are open.
        // (-1 means "infinite limit" on that axis).
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        
        // Spacing applied strictly between the app buttons.
        columnSpacing: 2
        rowSpacing: 2

        // Anchoring to center ensures the layout is properly positioned within the parent Item.
        anchors.centerIn: parent

        // Repeater creates a new UI element (DockAppButton) for every item in our processedApps array.
        Repeater {
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: root.processedApps
            }
            
            delegate: DockAppButton {
                required property var modelData
                
                // Pass the raw app data and a reference to the root Item down to the button.
                appToplevel: modelData.appData
                appListRoot: root

                // Symmetrical insets guarantee that the button remains a perfect square (50x50).
                // The parent pill background already handles the outer screen margins (hyprlandGapsOut),
                // so we only need to apply our inner padding (buttonPadding) here.
                topInset:    root.buttonPadding
                bottomInset: root.buttonPadding
                leftInset:   root.buttonPadding
                rightInset:  root.buttonPadding
            }
        }
    }
}