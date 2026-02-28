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
    property bool popupIsResizing: false
    signal togglePinRequested()

    property real buttonPadding: 5
    property var processedApps: []

    // --- Hover State ---
    property Item lastHoveredButton
    property bool buttonHovered: false

    // --- UI Constants ---
    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30

    // --- Drag State ---
    property string draggedAppId: ""
    property var dragSource: null
    property bool dragActive: false
    property var liveOrder: []
    property bool willUnpin: false 

    property bool anyContextMenuOpen: false
    property bool requestDockShow: previewPopup.visible || anyContextMenuOpen

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

    function startDrag(appId, sourceItem) {
            draggedAppId = appId
            dragSource = sourceItem
            liveOrder = Config.options.dock.pinnedApps.slice()

            willUnpin = false
            const pos = sourceItem.mapToItem(root, 0, 0)
            dragGhost.x = pos.x
            dragGhost.y = pos.y
            dragActive = true
            
            root.buttonHovered = false
            if (typeof previewPopup !== "undefined") previewPopup.show = false
        }

    function moveDragGhost(x, y) {
        const halfWidth = dragGhost.width / 2;
        const halfHeight = dragGhost.height / 2;

        let minCenterX, minCenterY, maxCenterX, maxCenterY;

        if (GlobalStates.dockEffectivePosition === "bottom") {
            minCenterX = -20;
            maxCenterX = root.width + 15;
            minCenterY = 10;
            maxCenterY = root.height - 15;
        } else if (GlobalStates.dockEffectivePosition === "top") {
            minCenterX = -20;
            maxCenterX = root.width + 15;
            minCenterY = 15;
            maxCenterY = root.height - 10;
        } else if (GlobalStates.dockEffectivePosition === "left") {
            minCenterX = 15;
            maxCenterX = root.width - 10;
            minCenterY = -20;
            maxCenterY = root.height + 15;
        } else if (GlobalStates.dockEffectivePosition === "right") {
            minCenterX = 10;
            maxCenterX = root.width - 15;
            minCenterY = -20;
            maxCenterY = root.height + 15;
        }

        let clampedCenterX = Math.max(minCenterX, Math.min(x, maxCenterX));
        let clampedCenterY = Math.max(minCenterY, Math.min(y, maxCenterY));
            dragGhost.x = clampedCenterX - halfWidth;
            dragGhost.y = clampedCenterY - halfHeight;

            const cx = clampedCenterX;
            const cy = clampedCenterY;

            let isOutsideDock = (cx < -40 || cx > root.width + 40 || cy < -40 || cy > root.height + 40);
            
            let pinnedZoneEnd = 0;
            let foundSeparator = false;
            
            for (let i = 0; i < layout.children.length; i++) {
                let child = layout.children[i];
                if (child.appToplevel && child.appToplevel.appId === "SEPARATOR") {
                    let p = child.mapToItem(root, 0, 0);
                    pinnedZoneEnd = root.isVertical ? p.y : p.x;
                    foundSeparator = true;
                    break;
                }
            }
            
            if (!foundSeparator) {
                if (Config.options.dock.pinnedApps.length > 0) {
                    pinnedZoneEnd = root.isVertical ? root.height : root.width;
                } else {
                    pinnedZoneEnd = 60;
                }
            }
            let isPastSeparator = root.isVertical ? (cy > pinnedZoneEnd) : (cx > pinnedZoneEnd);
            root.willUnpin = isOutsideDock || isPastSeparator;
            if (!root.willUnpin) {
                
                if (!liveOrder.includes(root.draggedAppId)) {
                    liveOrder.push(root.draggedAppId);
                    liveOrder = liveOrder.slice();
                }
                let hoveredAppId = "";
                for (let i = 0; i < layout.children.length; i++) {
                    const child = layout.children[i];
                    if (!child.appToplevel || child.appToplevel.appId === root.draggedAppId || child.appToplevel.appId === "SEPARATOR") continue;
                    
                    if (root.liveOrder.includes(child.appToplevel.appId)) {
                        let p = child.mapToItem(root, 0, 0);
                        if (cx >= p.x && cx <= p.x + child.width && cy >= p.y && cy <= p.y + child.height) {
                            hoveredAppId = child.appToplevel.appId;
                            break;
                        }
                    }
                }
                
                if (hoveredAppId !== "") {
                    const newOrder = liveOrder.filter(id => id !== root.draggedAppId);
                    const targetIdx = newOrder.indexOf(hoveredAppId);
                    if (targetIdx !== -1) {
                        const oldIdx = liveOrder.indexOf(root.draggedAppId);
                        const hoverIdx = liveOrder.indexOf(hoveredAppId);
                        
                        if (oldIdx === -1) {
                            newOrder.splice(targetIdx, 0, root.draggedAppId);
                        } else {
                            newOrder.splice(oldIdx < hoverIdx ? targetIdx + 1 : targetIdx, 0, root.draggedAppId);
                        }
                        liveOrder = newOrder;
                    }
                }
            } else {
                let isOriginallyPinned = Config.options.dock.pinnedApps.includes(root.draggedAppId);
                if (!isOriginallyPinned && liveOrder.includes(root.draggedAppId)) {
                    liveOrder = liveOrder.filter(id => id !== root.draggedAppId);
                }
            }
        }

    function endDrag() {
            if (root.willUnpin) {
                Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== draggedAppId)
            } else {
                if (liveOrder.length > 0) Config.options.dock.pinnedApps = liveOrder
            }
            
            dragActive = false
            draggedAppId = ""
            liveOrder = []
            dragSource = null
            willUnpin = false
            root.buttonHovered = false
            root.lastHoveredButton = null

    }
        // --- Drag Ghost ---
        Item {
            id: dragGhost
            width: 55
            height: 55
            visible: root.dragActive
            z: 10

            readonly property bool isOriginallyPinned: Config.options.dock.pinnedApps.indexOf(root.draggedAppId) !== -1

            Item {
                id: iconContainer
                anchors.fill: parent

                opacity: root.willUnpin ? 0.3 : 0.8
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                IconImage {
                    id: ghostIcon
                    anchors.centerIn: parent
                    implicitSize: 45
                    source: root.draggedAppId !== "" ? Quickshell.iconPath(AppSearch.guessIcon(root.draggedAppId), "image-missing") : ""

                    transform: Scale {
                        origin.x: ghostIcon.width / 2
                        origin.y: ghostIcon.height / 2
                        xScale: root.willUnpin ? 0.85 : 1.15
                        yScale: root.willUnpin ? 0.85 : 1.15
                        Behavior on xScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on yScale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
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
                if (!root.dragActive) return root.processedApps

                const ordered = [];

                // 1. Mostra le app pinnate nel loro nuovo ordine
                for (const appId of root.liveOrder) {
                    const found = root.processedApps.find(a => a.appData.appId === appId)
                    if (found) ordered.push(found)
                }
                const separator = root.processedApps.find(a => a.appData.appId === "SEPARATOR")
                if (separator) {
                    ordered.push(separator)
                } else if (root.liveOrder.length > 0) {
                    ordered.push({ uniqueKey: "SEPARATOR_VIRTUAL", appData: { appId: "SEPARATOR", toplevels: [], pinned: false } })
                }
                for (const app of root.processedApps) {
                    if (app.appData.appId !== "SEPARATOR" && !root.liveOrder.includes(app.appData.appId) && !app.appData.pinned) {
                        ordered.push(app)
                    }
                }
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
            visible: root.processedApps.length > 0 && (!root.dragActive || root.processedApps.some(a => 
                a.appData.appId !== "SEPARATOR" && 
                !a.appData.pinned && 
                a.appData.appId !== root.draggedAppId
            ))
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
        property bool shouldShow: !root.dragActive && (backgroundHover.hovered || root.buttonHovered || root.popupIsResizing) && (appTopLevel?.toplevels?.length > 0)
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

        visible: show || popupBackground.opacity > 0
        color: "transparent"

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


            StyledRectangularShadow {
                target: popupBackground
                opacity: popupBackground.opacity
                visible: popupBackground.visible
            }

            Rectangle {
                id: popupBackground
                property real margins: 5
                property real padding: 6

                property bool isResizing: false

                onImplicitWidthChanged:  { root.popupIsResizing = true; resizeTimer.restart() }
                onImplicitHeightChanged: { root.popupIsResizing = true; resizeTimer.restart() }

                Timer {
                    id: resizeTimer
                    interval: 500
                    onTriggered: root.popupIsResizing = false
                }

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
                visible: true         
                clip: true
                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                implicitHeight: previewRowLayout.implicitHeight + padding * 2
                implicitWidth:  previewRowLayout.implicitWidth  + padding * 2

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
                }
                
                HoverHandler { 
                id: backgroundHover
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
                            onClicked: { 
                                modelData?.activate()
                                root.buttonHovered = false
                                root.lastHoveredButton = null
                            }
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
                                    RippleButton {
                                        id: closeButton
                                        colBackground: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                        implicitWidth: root.windowControlsHeight
                                        implicitHeight: root.windowControlsHeight
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
                                    live: true
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