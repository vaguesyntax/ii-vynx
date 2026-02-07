pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    property bool hyprscrollingEnabled: Config.options.overview.hyprscrollingImplementation.enable
    property int maxWorkspaceWidth: Config.options.overview.hyprscrollingImplementation.maxWorkspaceWidth
    property int minWorkspaceWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    // Clamp to avoid lock-screen temp workspace (2147483647 - N) leaking into UI
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    //TODO: I may have to use effectibeActiveWorkspace ID like this: 
    // readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    // readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    
    readonly property bool useWorkspaceMap: Config.options.overview.useWorkspaceMap
    readonly property list<int> workspaceMap: Config.options.overview.workspaceMap
    property int monitorIndex // to be set by parent
    property int workspaceOffset: useWorkspaceMap ? workspaceMap[monitorIndex] : 0
    
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - workspaceOffset - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: minWorkspaceWidth
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    // we are using a width map to get all windows width and settings workspaceImplicitWidth to the maximum item of this list/map
    property list<int> widthMap: [] 

    onWidthMapChanged: root.workspaceImplicitWidth = getMaxWidth()

    function getMaxWidth() {
        if (widthMap.length === 0) return minWorkspaceWidth;
        const max = Math.max(...widthMap);
        return Math.min(max, maxWorkspaceWidth);
    }

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 10

    property int dragDropType: -1 // 0: workspace, 1: window
    
    property string draggingFromWindowAddress
    property string draggingTargetWindowAdress
    property string draggingDirection  // options: 'l' or 'r' // only for window dragging

    property bool draggingWindowsFloating

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1


    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    Behavior on workspaceImplicitWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    property var activeWindow: windows.find(w =>
        w.focusHistoryID === 0 &&
        w.workspace?.id === monitor.activeWorkspace?.id &&
        w.monitor === monitor.id
    )

    property var activeWindowData
    
    function getWsRow(ws) {
        var wsAdjusted = ws - root.workspaceOffset
        var normalRow = Math.floor((wsAdjusted - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }

    function getWsColumn(ws) {
        var wsAdjusted = ws - root.workspaceOffset
        var normalCol = (wsAdjusted - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }

    function getWsInCell(ri, ci) {
        var wsInCell = (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) 
                    * Config.options.overview.columns 
                    + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) 
                    + 1
        return wsInCell + root.workspaceOffset
    }


    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.columns
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + getWsInCell(row.index, colIndex)
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === Config.options.overview.rows - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`workspace ${workspace.workspaceValue}`)
                                    }
                                }
                            }

                            DropArea { // Workspace drop
                                anchors.fill: parent
                                onEntered: {
                                    root.dragDropType = 0
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    root.dragDropType = -1
                                    hoveredWhileDragging = false
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) root.draggingTargetWorkspace = -1
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                id: windowRepeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            const win = windowByAddress[address]
                            if (!win) return false

                            const inWorkspaceGroup =
                                (root.workspaceGroup * root.workspacesShown + root.workspaceOffset <
                                win.workspace?.id &&
                                win.workspace?.id <=
                                (root.workspaceGroup + 1) * root.workspacesShown + root.workspaceOffset)

                            return inWorkspaceGroup
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property int index
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    property int wsId: windowData?.workspace?.id

                    property var wsWindowsSorted: {
                        const arr = []
                        const all = windowRepeater.model.values

                        for (let i = 0; i < all.length; i++) {
                            const t = all[i]
                            const addr = `0x${t.HyprlandToplevel.address}`
                            const w = windowByAddress[addr]

                            if (!w) continue
                            if (w.floating) continue
                            if (w.workspace?.id !== wsId) continue

                            arr.push(w)
                        }

                        arr.sort((a, b) => a.at[0] - b.at[0])
                        return arr
                    }


                    property int wsIndex: {
                        for (let i = 0; i < wsWindowsSorted.length; i++) {
                            if (wsWindowsSorted[i].address === windowData.address)
                                return i
                        }
                        return 0
                    }

                    property real workspaceTotalWindowWidth: {
                        let sum = 0
                        for (let i = 0; i < wsWindowsSorted.length; i++) {
                            const w = wsWindowsSorted[i]
                            sum += w.size?.[0] ?? 0
                        }
                        return sum * root.scale
                    }

                    onWorkspaceTotalWindowWidthChanged: { // we have to update widthMap here to prevent 'Binding Loop' error
                        if (workspaceTotalWindowWidth > 0 && root.hyprscrollingEnabled) {
                            root.widthMap.push(workspaceTotalWindowWidth)
                        }
                    }

                    property real windowWidthRatio: {
                        if (!windowData?.size?.[0] || workspaceTotalWindowWidth === 0)
                            return 1 / wsCount

                        return (windowData.size[0] * root.scale) / workspaceTotalWindowWidth
                    }

                    function calculateXPos() {
                        let x = xOffset
                        for (let i = 0; i < wsIndex; i++) {
                            const w = wsWindowsSorted[i]
                            const wRatio = (w.size?.[0] ?? 0) * root.scale / workspaceTotalWindowWidth
                            x += root.workspaceImplicitWidth * wRatio
                        }
                        return x
                    }


                    property int wsCount: wsWindowsSorted.length || 1

                    scrollWidth: windowData.floating ? windowData.size[0] * root.scale : root.workspaceImplicitWidth * windowWidthRatio
                    scrollHeight: windowData.floating ? windowData.size[1] * root.scale : root.workspaceImplicitHeight

                    scrollX: windowData.floating ? xOffset + xWithinWorkspaceWidget : calculateXPos()
                    scrollY: windowData.floating ? yOffset + yWithinWorkspaceWidget : yOffset

                    property bool isActiveWindow: { // we have to set root.activeWindowData here instead of component.oncompleted
                        if (window.address == root.activeWindow?.address) {
                            root.activeWindowData = {
                                x: scrollX,
                                y: scrollY,
                                width: scrollWidth,
                                height: scrollHeight
                            }
                            return true
                        }
                        return false
                    }

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - monitorData?.reserved[0]) * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - monitorData?.reserved[1]) * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === Config.options.overview.columns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    property int hoveringDir: 0 // 0: none, 1: right, 2: left
                    property bool hovering: false

                    Loader { // Hover indicator (only works with hyprscrolling)
                        active: root.hyprscrollingEnabled && !root.draggingWindowsFloating
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: Rectangle {
                            anchors.verticalCenter: parent.verticalCenter            

                            x: hoveringDir == 1 ? window.width / 2 : 0
                            implicitWidth: window.hovering ? window.width / 2 : 0
                            implicitHeight: window.height

                            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                            opacity: window.hovering ? 1 : 0
                            topRightRadius: window.topLeftRadius
                            bottomRightRadius: window.topLeftRadius
                            topLeftRadius: window.topLeftRadius
                            bottomLeftRadius: window.topLeftRadius

                            Behavior on x {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }
                    }
                    

                    DropArea { // Window drop
                        anchors.fill:  parent 
                        onEntered: {
                            parent.hovering = true
                            root.dragDropType = 1 // window
                            root.draggingTargetWindowAdress = windowData?.address
                            root.draggingTargetWorkspace = window?.wsId
                            const localX = drag.x
                            const half = width / 2

                            if (localX < half) {
                                root.draggingDirection = "l"
                                hoveringDir = 2
                            } else {
                                root.draggingDirection = "r"
                                hoveringDir = 1
                            }
                        }
                        onExited: {
                            parent.hovering = false
                            root.dragDropType = -1
                            if (root.draggingTargetWindowAdress == windowData?.address) root.draggingTargetWindowAdress = ""
                        }
                    }

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay 
                        repeat: false
                        running: false
                        onTriggered: {
                            if (windowData?.floating) return
                            window.x = calculateXPos()
                            window.y = yOffset
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true // For hover color change
                        onExited: hovered = false // For hover color change
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = windowData?.workspace.id
                            root.draggingFromWindowAddress = windowData?.address
                            root.draggingWindowsFloating = windowData?.floating
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                            // console.log(`[OverviewWindow] Dragging window ${windowData?.address} from position (${window.x}, ${window.y})`)
                        }
                        onReleased: { // Dropping Event

                            if (root.dragDropType === 0) { // Workspace drop
                                const targetWorkspace = root.draggingTargetWorkspace
                                window.pressed = false
                                window.Drag.active = false
                                root.draggingFromWorkspace = -1
                                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                                    Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${window.windowData?.address}`)
                                    updateWindowPosition.restart()
                                }
                                else {
                                    if (!window.windowData.floating) {
                                        updateWindowPosition.restart()
                                        return
                                    }
                                    const percentageX = Math.round((window.x - xOffset) / root.workspaceImplicitWidth * 100)
                                    const percentageY = Math.round((window.y - yOffset) / root.workspaceImplicitHeight * 100)
                                    Hyprland.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${window.windowData?.address}`)
                                }
                            } else if (root.dragDropType === 1) { // Window drop
                                const targetWindowAdress = root.draggingTargetWindowAdress
                                const targetWorkspace = root.draggingTargetWorkspace
                                window.pressed = false
                                window.Drag.active = false
                                if (targetWindowAdress !== "" && targetWindowAdress !== windowData?.address) {
                                    if (root.draggingTargetWorkspace === root.draggingFromWorkspace) { // plugin directly supports same workspace switch
                                        Hyprland.dispatch(`layoutmsg swapaddrdir ${targetWindowAdress} ${root.draggingDirection} ${window.windowData?.address} true`)
                                    } else { // different workspace
                                        Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${root.draggingFromWindowAddress}`)
                                        Qt.callLater(() => {
                                            Hyprland.dispatch(`layoutmsg swapaddrdir ${targetWindowAdress} ${root.draggingDirection} ${window.windowData?.address} true`)
                                        })
                                    }
                                }
                                Qt.callLater(() => {
                                    root.draggingFromWindowAddress = "";
                                    root.draggingTargetWindowAdress = "";
                                    updateWindowPosition.restart();
                                    HyprlandData.updateWindowList();
                                })   
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                const sameWorkspaceWithTarget = windowData?.workspace.id === root.activeWindow?.workspace?.id

                                if (!root.hyprscrollingEnabled) {
                                    Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                    GlobalStates.overviewOpen = false; 
                                    return
                                }

                                if (sameWorkspaceWithTarget) {
                                    Hyprland.dispatch(`layoutmsg focusaddr ${windowData.address}`)
                                    GlobalStates.overviewOpen = false;
                                } else {
                                    Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                    Qt.callLater(() => {
                                        Hyprland.dispatch(`layoutmsg focusaddr ${windowData.address}`);
                                        GlobalStates.overviewOpen = false;
                                    });

                                }
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title}${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(monitor.activeWorkspace?.id)
                property int colIndex: getWsColumn(monitor.activeWorkspace?.id)

                z: 999

                x: root.hyprscrollingEnabled ? root.activeWindowData?.x ?? 0 : (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: root.hyprscrollingEnabled ? root.activeWindowData?.y ?? 0 : (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                width: root.hyprscrollingEnabled ?  root.activeWindowData?.width ?? 0 : root.workspaceImplicitWidth + 4
                height: root.hyprscrollingEnabled ? root.activeWindowData?.height ?? 0 : root.workspaceImplicitHeight

                radius: Appearance.rounding.normal
                color: "transparent"
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on width {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on height {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}