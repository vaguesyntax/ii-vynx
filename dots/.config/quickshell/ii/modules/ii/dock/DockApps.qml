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

    property bool isVertical: GlobalStates.dockIsVertical
    property bool isPinned: false
    signal togglePinRequested()

    property real buttonPadding: 5
    property var processedApps: []

    property Item lastHoveredButton
    property bool buttonHovered: false

    // Drag state
    property string draggedAppId: ""
    property var dragSource: null
    property bool _dragActive: false
    property var liveOrder: []

    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

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

    // --- DRAG GHOST ---
    Item {
        id: dragGhost
        width: 55
        height: 55
        visible: root._dragActive
        z: 999

        IconImage {
            id: ghostIcon
            anchors.centerIn: parent
            implicitSize: 45
            opacity: 0.7
            source: root.draggedAppId !== "" ? Quickshell.iconPath(AppSearch.guessIcon(root.draggedAppId), "image-missing") : ""

            transform: Scale {
                origin.x: ghostIcon.width / 2
                origin.y: ghostIcon.height / 2
                xScale: 1.15
                yScale: 1.15
            }
        }

        Loader {
            active: Config.options.dock.monochromeIcons
            anchors.fill: ghostIcon
            sourceComponent: Item {
                Desaturate {
                    id: desaturatedIcon
                    visible: false
                    anchors.fill: parent
                    source: ghostIcon
                    desaturation: 0.8
                }
                ColorOverlay {
                    anchors.fill: desaturatedIcon
                    source: desaturatedIcon
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                }
            }
        }
    }

    // --- DRAG FUNCTIONS ---
    function startDrag(appId, sourceItem) {
        draggedAppId = appId
        dragSource = sourceItem
        liveOrder = Config.options.dock.pinnedApps.slice()
        const pos = sourceItem.mapToItem(root, 0, 0)
        dragGhost.x = pos.x
        dragGhost.y = pos.y
        _dragActive = true
    }

    function moveDragGhost(x, y) {
        dragGhost.x = x - dragGhost.width / 2
        dragGhost.y = y - dragGhost.height / 2

        const cx = dragGhost.x + dragGhost.width / 2
        const cy = dragGhost.y + dragGhost.height / 2

        let hoveredAppId = ""
        let hoveredPos = -1
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            if (!child.appToplevel?.pinned) continue
            if (child.appToplevel?.appId === root.draggedAppId) continue
            if (child.isSeparator) continue
            const p = child.mapToItem(root, 0, 0)
            if (cx >= p.x && cx <= p.x + child.width &&
                cy >= p.y && cy <= p.y + child.height) {
                hoveredAppId = child.appToplevel.appId
                break
            }
        }

        if (hoveredAppId !== "" && hoveredAppId !== root.draggedAppId) {
            const newOrder = liveOrder.filter(id => id !== root.draggedAppId)
            const targetIdx = newOrder.indexOf(hoveredAppId)
            if (targetIdx !== -1) {
                const oldIdx = liveOrder.indexOf(root.draggedAppId)
                const hoverIdx = liveOrder.indexOf(hoveredAppId)
                newOrder.splice(oldIdx < hoverIdx ? targetIdx + 1 : targetIdx, 0, root.draggedAppId)
                liveOrder = newOrder
            }
        }
    }

    function endDrag() {
        if (liveOrder.length > 0)
            Config.options.dock.pinnedApps = liveOrder

        _dragActive = false
        draggedAppId = ""
        liveOrder = []
        dragSource = null
    }

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
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.maximumWidth: 50
            Layout.maximumHeight: 50
            Layout.alignment: Qt.AlignCenter

            GroupButton {
                anchors.centerIn: parent
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
                        iconSize: Appearance.font.pixelSize.larger
                        color: root.isPinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
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
                values: {
                    if (!root._dragActive || root.liveOrder.length === 0)
                        return root.processedApps

                    const ordered = []
                    for (const appId of root.liveOrder) {
                        const found = root.processedApps.find(a => a.appData.appId === appId)
                        if (found) ordered.push(found)
                    }
                    for (const app of root.processedApps) {
                        if (!app.appData.pinned) ordered.push(app)
                    }
                    return ordered
                }
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
        Item {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.maximumWidth: 50
            Layout.maximumHeight: 50
            Layout.alignment: Qt.AlignCenter

            DockButton {
                id: overviewButton
                anchors.centerIn: parent
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
}