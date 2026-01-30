import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    readonly property bool useWorkspaceMap: Config.options.bar.workspaces.useWorkspaceMap
    readonly property list<int> workspaceMap: Config.options.bar.workspaces.workspaceMap 
    readonly property int monitorIndex: barLoader.monitorIndex
    property int workspaceOffset: useWorkspaceMap ? workspaceMap[monitorIndex] : 0 // not sure if this works for more than 2 monitors

    readonly property int workspacesShown: Config.options.bar.workspaces.shown
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - root.workspaceOffset - 1) / root.workspacesShown)
    property list<bool> workspaceOccupied: []
    property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - root.workspaceOffset - 1) % root.workspacesShown    
    property var monitorWindows

    property int individualIconBoxHeight: 24
    property int iconBoxWrapperSize: 28
    property int workspaceDotSize: 4
    property real iconRatio: 0.8
    property bool showIcons: Config.options.bar.workspaces.showAppIcons

    property bool showNumbersByMs: false
    Timer {
        id: showNumbersTimer
        interval: (Config.options.bar.workspaces.showNumberDelay ?? 100)
        repeat: false
        onTriggered: {
            root.showNumbersByMs = true
        }
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
            if (GlobalStates.superDown) showNumbersTimer.restart();
            else {
                showNumbersTimer.stop();
                root.showNumbersByMs = false;
            }
        }
        function onSuperReleaseMightTriggerChanged() { 
            showNumbersTimer.stop()
        }
    }


    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
            return Hyprland.workspaces.values.some(ws => ws.id === workspaceOffset + workspaceGroup * root.workspacesShown + i + 1);
        })
    }

    function hasWindowsInWorkspace(workspaceId) {
        return HyprlandData.windowList.some(w => w.workspace.id === workspaceId);
    }


    // Window list updates
    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            const windowsOnMonitor = HyprlandData.windowList.filter(win => win.monitor === root.monitorIndex && !win.floating)

            windowsOnMonitor.sort((a, b) => a.at[0] - b.at[0])

            root.monitorWindows = windowsOnMonitor.map(win => ({
                icon: Quickshell.iconPath(AppSearch.guessIcon(win?.class), "image-missing"),
                workspace: win.workspace?.id
            }))
        }
    }

    // Occupied workspace updates
    Component.onCompleted: {
        updateWorkspaceOccupied()
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            updateWorkspaceOccupied();
        }
    }
    onWorkspaceGroupChanged: {
        updateWorkspaceOccupied();
    }

    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea { 
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            } 
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            } 
        }
    }


    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : contentLayout.implicitWidth
    implicitHeight: root.vertical ? contentLayout.implicitHeight : Appearance.sizes.barHeight

    Behavior on implicitHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // Active workspace indicator
    Rectangle {
        z: 2
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        color: Appearance.colors.colPrimary
        radius: Appearance.rounding.full
        
        AnimatedTabIndexPair {
            id: idxPair
            index: root.workspaceIndexInGroup
        }

        function offsetFor(index) {
            let y = 0
            for (let i = 0; i < index; i++) {
                const item = contentLayout.children[i]
                y += root.vertical ? item?.height - baseHeight : item?.width - baseHeight
            }
            return y
        }

        function getWindowCount(workspaceId) {
            return HyprlandData.windowList.filter( w => w.workspace.id === workspaceId && !w.floating ).length;
        }

        property int index: root.workspaceIndexInGroup
        property int baseHeight: root.iconBoxWrapperSize
        property int windowCount: getWindowCount(index + root.workspaceOffset + 1)

        property bool isEmptyWorkspace: windowCount === 0
        property bool isOneWindow: windowCount === 1

        // insets to create perfect round circles
        property real indicatorInsetEmpty: root.iconBoxWrapperSize * 0.07
        property real indicatorInsetOneWindow: root.iconBoxWrapperSize * 0.1
        property real indicatorInset: root.iconBoxWrapperSize * 0.1

        property real visualInset: {
            if (isEmptyWorkspace)
                return indicatorInsetEmpty
            if (isOneWindow)
                return indicatorInsetOneWindow
            return indicatorInset
        }

        property real pairMin: Math.min(idxPair.idx1, idxPair.idx2)
        property real pairAbs: Math.abs(idxPair.idx1 - idxPair.idx2)

        property real currentItemOffset: {
            const item = contentLayout.children[root.workspaceIndexInGroup]
            const itemSize = root.vertical ? item?.height : item?.width
            return itemSize - baseHeight
        }

        readonly property real accumulatedPreviousOffsets: offsetFor(root.workspaceIndexInGroup + 1)

        readonly property real baseIndicatorPosition: pairMin * root.iconBoxWrapperSize
        readonly property real baseIndicatorLength: (pairAbs + 1) * root.iconBoxWrapperSize

        property real indicatorPosition: baseIndicatorPosition + accumulatedPreviousOffsets - currentItemOffset + visualInset
        property real indicatorLength: baseIndicatorLength + currentItemOffset - visualInset * 2

        y: root.vertical ? indicatorPosition : 0
        x: root.vertical ? 0 : indicatorPosition
        implicitHeight: root.vertical ? indicatorLength : individualIconBoxHeight
        implicitWidth: root.vertical ? individualIconBoxHeight : indicatorLength
    }

    

    GridLayout {
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
        z: 1

        columns: root.vertical ? 1 : 99
        rows: root.vertical ? 99 : 1

        Repeater {
            model: root.workspacesShown
            delegate: Rectangle { // background
                Layout.alignment: Qt.AlignCenter

                property var previousOccupied: (workspaceOccupied[index-1] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index))
                property var rightOccupied: (workspaceOccupied[index+1] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index+2))
                property var radiusPrev: previousOccupied ? 0 : (width / 2)
                property var radiusNext: rightOccupied ? 0 : (width / 2)

                topLeftRadius: radiusPrev
                bottomLeftRadius: root.vertical ? radiusNext : radiusPrev
                topRightRadius: root.vertical ? radiusPrev : radiusNext
                bottomRightRadius: radiusNext

                implicitWidth: root.vertical ? root.iconBoxWrapperSize : contentLayout.children[index]?.width ?? 0
                implicitHeight: root.vertical ? contentLayout.children[index]?.height ?? 0 : root.iconBoxWrapperSize

                color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                opacity: (workspaceOccupied[index] && !(!activeWindow?.activated && monitor?.activeWorkspace?.id === index+1)) ? 1 : 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on radiusPrev {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on radiusNext {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on implicitHeight {
                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                }
            }
        }
    } 

    GridLayout {
        id: contentLayout
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
        z: 3

        columns: root.vertical ? 1 : 99
        rows: root.vertical ? 99 : 1

        Repeater {
            id: workspaceRepeater
            model: root.workspacesShown

            delegate: MouseArea {
                id: background
                Layout.alignment: Qt.AlignCenter
                implicitWidth: root.vertical ? root.iconBoxWrapperSize : Math.max(layout.implicitWidth + 8, root.iconBoxWrapperSize)
                implicitHeight: root.vertical ? Math.max(layout.implicitHeight + 8, root.iconBoxWrapperSize) : root.iconBoxWrapperSize
                onClicked: Hyprland.dispatch(`workspace ${workspaceOffset + workspaceGroup * workspacesShown + index + 1}`)
                
                WorkspaceBackgroundIndicator {
                    workspaceValue: workspaceOffset + workspaceGroup * workspacesShown + index + 1
                    activeWorkspace: monitor?.activeWorkspace?.id === workspaceValue
                }
                
                GridLayout {
                    id: layout
                    anchors.centerIn: parent
                    columnSpacing: 0
                    rowSpacing: 0
                    columns: root.vertical ? 1 : 99
                    rows: root.vertical ? 99 : 1
                    
                    
                    Repeater {
                        property int workspaceIndex: workspaceOffset + workspaceGroup * workspacesShown + index + 1
                        model: root.showIcons ? root.monitorWindows?.filter(win => win.workspace === workspaceIndex).splice(0, Config.options.bar.workspaces.maxWindowCount) : []
                        delegate: Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: root.individualIconBoxHeight
                            height: root.individualIconBoxHeight
                            IconImage {
                                id: mainAppIcon
                                Layout.alignment: Qt.AlignHCenter
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    leftMargin: root.showNumbersByMs ? 15 : 2
                                    topMargin: root.showNumbersByMs ? 15 : 2
                                }
                                source: modelData.icon
                                implicitSize: (root.individualIconBoxHeight * root.iconRatio) * (root.showNumbersByMs ? 1 / 1.5 : 1)

                                Behavior on anchors.leftMargin {
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }
                                Behavior on anchors.topMargin {
                                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                                }
                                Behavior on implicitSize {
                                    animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
                                }
                            }
                            Loader {
                                active: Config.options.bar.workspaces.monochromeIcons
                                anchors.fill: mainAppIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desaturatedIcon
                                        visible: false // There's already color overlay
                                        anchors.fill: parent
                                        source: mainAppIcon
                                        desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desaturatedIcon
                                        source: desaturatedIcon
                                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
    }

    component WorkspaceBackgroundIndicator: Rectangle { // dot or number
        property bool showNumbers: Config.options.bar.workspaces.alwaysShowNumbers || root.showNumbersByMs
        property int workspaceValue
        property bool activeWorkspace
        property color indColor: (activeWorkspace) ? Appearance.m3colors.m3onPrimary : (root.workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1Inactive)

        anchors.centerIn: parent
        width: root.workspaceDotSize
        height: width
        radius: width / 2
        visible: layout.implicitHeight + 8 < root.iconBoxWrapperSize || root.showNumbersByMs
        color: !showNumbers ?  indColor : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledText {
            opacity: showNumbers ? 1 : 0
            anchors.centerIn: parent
            text: Config.options?.bar.workspaces.numberMap[workspaceValue - 1] || workspaceValue
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: indColor
            Behavior on opacity {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }
        }
    }

}
