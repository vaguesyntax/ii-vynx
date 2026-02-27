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
    property Item anchorItem: null
    // --- Core Properties ---
    property bool isVertical: GlobalStates.dockIsVertical
    property bool isPinned: false
    signal togglePinRequested()

    property real buttonPadding: 5
    property var processedApps: []

    // --- Hover State ---
    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool requestDockShow: previewPopup.visible

    // --- UI Constants ---
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30

    // --- Drag State ---
    property string draggedAppId: ""
    property var dragSource: null
    property bool _dragActive: false
    property var liveOrder: []

    implicitWidth:  layout.implicitWidth
    implicitHeight: layout.implicitHeight

    property real hoveredButtonCenterX: {
        if (!root.lastHoveredButton) return 0
        const mapped = root.lastHoveredButton.mapToItem(null,
            root.lastHoveredButton.width / 2,
            root.lastHoveredButton.height / 2)
        return mapped.x
    }
    property real hoveredButtonCenterY: {
        if (!root.lastHoveredButton) return 0
        const mapped = root.lastHoveredButton.mapToItem(null,
            root.lastHoveredButton.width / 2,
            root.lastHoveredButton.height / 2)
        return mapped.y
    }

    // --- Model Update ---
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

    Connections {
        target: GlobalStates
        function onDockEffectivePositionChanged() {
            if (root.lastHoveredButton) previewPopup.anchor.updateAnchor()
        }
    }

    Component.onCompleted: updateModel()

    // --- Drag Functions ---
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
        for (let i = 0; i < layout.children.length; i++) {
            const child = layout.children[i]
            if (!child.appToplevel || child.appToplevel.appId === root.draggedAppId) continue
            const p = child.mapToItem(root, 0, 0)
            if (cx >= p.x && cx <= p.x + child.width && cy >= p.y && cy <= p.y + child.height) {
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
        if (liveOrder.length > 0) Config.options.dock.pinnedApps = liveOrder
        _dragActive = false; draggedAppId = ""; liveOrder = []; dragSource = null
    }

    // --- Drag Ghost ---
    Item {
        id: dragGhost
        width: 55
        height: 55
        visible: root._dragActive
        z: 10

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

    // --- Main Dock Layout ---
    GridLayout {
        id: layout
        flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.isVertical ? -1 : 1
        columns: root.isVertical ? 1 : -1
        columnSpacing: 2; rowSpacing: 2
        anchors.centerIn: parent

        Item {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignCenter

            GroupButton {
                anchors.fill: parent
                anchors.margins: 8
                baseWidth: 35
                baseHeight: 35
                buttonRadius: Appearance.rounding.normal
                clickedWidth:  root.isVertical ? baseWidth : baseWidth + 15
                clickedHeight: root.isVertical ? baseHeight + 15 : baseHeight
                toggled: root.isPinned
                onClicked: root.togglePinRequested()

                contentItem: Item {
                    implicitWidth: 35
                    implicitHeight: 35
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keep"
                        iconSize: Appearance.font.pixelSize.huge
                        color: root.isPinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                    }
                }
            }
        }

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

        Repeater {
            model: ScriptModel {
                objectProp: "uniqueKey"
                values: {
                    if (!root._dragActive || root.liveOrder.length === 0) return root.processedApps
                    const ordered = [];
                    for (const appId of root.liveOrder) {
                        const found = root.processedApps.find(a => a.appData.appId === appId)
                        if (found) ordered.push(found)
                    }
                    for (const app of root.processedApps) { if (!app.appData.pinned) ordered.push(app) }
                    return ordered
                }
            }
            delegate: DockAppButton {
                required property var modelData
                appToplevel: modelData.appData
                appListRoot: root
                topInset: root.buttonPadding
                bottomInset: root.buttonPadding
            }
        }

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

        Item {
            Layout.preferredWidth: 50
            Layout.preferredHeight: 50
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

    PopupWindow {
        id: previewPopup
        property var appTopLevel: root.lastHoveredButton?.appToplevel
        property bool shouldShow: (popupMouseArea.containsMouse || root.buttonHovered) && (appTopLevel?.toplevels?.length > 0)
        property bool show: false

        onShouldShowChanged: {
            if (shouldShow)
                show = true 
            else
                hideTimer.restart() 
        }

        Timer {
            id: hideTimer
            interval: 150
            onTriggered: {
                previewPopup.show = previewPopup.shouldShow
            }
        }

        visible: show
        color: "red"

        anchor {
            window: root.QsWindow.window
            adjustment: PopupAdjustment.None

            rect {
                x: GlobalStates.dockEffectivePosition === "left"  ? (root.QsWindow.window?.width ?? 0) :  0
                y: GlobalStates.dockEffectivePosition === "bottom" ? 0 : GlobalStates.dockEffectivePosition === "top" ? (root.QsWindow.window?.height ?? 0) : 0
            }

            gravity: {
                if (GlobalStates.dockEffectivePosition === "left")   return Edges.Right | Edges.Bottom
                if (GlobalStates.dockEffectivePosition === "right")  return Edges.Left  | Edges.Bottom
                if (GlobalStates.dockEffectivePosition === "top")    return Edges.Bottom | Edges.Right
                return Edges.Top | Edges.Right
            }

            edges: Edges.Top | Edges.Left
        }

        implicitWidth: root.isVertical
            ? root.maxWindowPreviewWidth
                + root.windowControlsHeight
                + popupBackground.padding * 2
                + popupBackground.margins * 2
                - 25
            : QsWindow.window?.width ?? 0

        implicitHeight: root.isVertical
            ? QsWindow.window?.height ?? 0
            : root.maxWindowPreviewHeight
                + root.windowControlsHeight
                + popupBackground.padding * 2
                + popupBackground.margins * 2
                + 5

        MouseArea {
            id: popupMouseArea
            anchors.fill: parent
            hoverEnabled: true

            StyledRectangularShadow {
                target: popupBackground
                opacity: popupBackground.opacity
                visible: popupBackground.visible
            }

            Rectangle {
                id: popupBackground
                property real margins: 5
                property real padding: 6

                x: root.isVertical
                    ? (GlobalStates.dockEffectivePosition === "left"
                        ? margins
                        : parent.width - implicitWidth - margins)
                    : root.hoveredButtonCenterX - implicitWidth / 2

                y: root.isVertical
                    ? root.hoveredButtonCenterY - implicitHeight / 2
                    : (GlobalStates.dockEffectivePosition === "top"
                        ? margins
                        : parent.height - implicitHeight - margins)

                opacity: previewPopup.show ? 1 : 0
                visible: opacity > 0
                clip: true
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                implicitHeight: previewRowLayout.implicitHeight + padding * 2
                implicitWidth:  previewRowLayout.implicitWidth  + padding * 2

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
                }
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
                }
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
                }
                
                GridLayout {
                    id: previewRowLayout
                    anchors {
                        top: parent.top
                        left: parent.left
                        topMargin: popupBackground.padding
                        leftMargin: popupBackground.padding
                    }
                    flow: root.isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                    columnSpacing: 6; rowSpacing: 6

                    Repeater {
                        model: ScriptModel { values: (previewPopup.appTopLevel?.toplevels ?? []) }
                        delegate: RippleButton {
                            id: windowButton
                            required property var modelData
                            padding: 0
                            onClicked: { modelData?.activate(); root.buttonHovered = false }
                            middleClickAction: () => modelData?.close()

                            contentItem: ColumnLayout {
                                implicitWidth:  screencopyView.implicitWidth
                                implicitHeight: screencopyView.implicitHeight

                                ButtonGroup {
                                    contentWidth: parent.width - anchors.margins * 2
                                    WrapperRectangle {
                                        Layout.fillWidth: true
                                        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        radius: Appearance.rounding.small
                                        margin: 5
                                        StyledText {
                                            Layout.fillWidth: true
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            text: windowButton.modelData?.title ?? ""
                                            elide: Text.ElideRight
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                    }
                                    GroupButton {
                                        id: closeButton
                                        colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        baseWidth: root.windowControlsHeight
                                        baseHeight: root.windowControlsHeight
                                        buttonRadius: Appearance.rounding.full
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.m3colors.m3onSurface
                                        }
                                        onClicked: windowButton.modelData?.close()
                                    }
                                }

                                ScreencopyView {
                                    id: screencopyView
                                    captureSource: windowButton.modelData
                                    live: previewPopup.show
                                    paintCursor: true
                                    constraintSize: Qt.size(root.maxWindowPreviewWidth, root.maxWindowPreviewHeight)

                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width:  screencopyView.width
                                            height: screencopyView.height
                                            radius: Appearance.rounding.small
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
