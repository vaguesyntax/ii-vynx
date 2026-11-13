import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland

import qs.modules.ii.sidebarDashboard.quickToggles
import qs.modules.ii.sidebarDashboard.quickToggles.classicStyle

import qs.modules.ii.sidebarDashboard.bluetoothDevices
import qs.modules.ii.sidebarDashboard.nightLight
import qs.modules.ii.sidebarDashboard.volumeMixer
import qs.modules.ii.sidebarDashboard.wifiNetworks

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 10
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")
    property bool showAudioOutputDialog: false
    property bool showAudioInputDialog: false
    property bool showBluetoothDialog: false
    property bool showNightLightDialog: false
    property bool showWifiDialog: false
    property bool editMode: false

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.showWifiDialog = false;
                root.showBluetoothDialog = false;
                root.showAudioOutputDialog = false;
                root.showAudioInputDialog = false;
            }
        }
    }

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    StyledRectangularShadow {
        target: sidebarRightBackground
    }
    Rectangle {
        id: sidebarRightBackground

        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            Loader {
                Layout.fillHeight: false
                Layout.fillWidth: true
                Layout.topMargin: 5
                Layout.bottomMargin: 0
                sourceComponent: Config.options.sidebar.profileBannerEnabled ? profileBanner : systemButtons

                Component {
                    id: profileBanner

                    Item {
                        implicitHeight: 180
                        implicitWidth: parent?.width ?? 0

                        Rectangle {
                            id: bannerCard
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colLayer1

                            StyledImage {
                                id: bannerImage
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    margins: 2
                                }
                                height: 120
                                fillMode: Image.PreserveAspectCrop
                                source: Config.options.sidebar.profileBannerImage !== "" ? Config.options.sidebar.profileBannerImage : Config.options.background.wallpaperPath
                                cache: false
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: bannerImage.width
                                        height: bannerImage.height
                                        radius: bannerCard.radius
                                    }
                                }
                            }

                            Column {
                                anchors {
                                    left: parent.left
                                    bottom: parent.bottom
                                    leftMargin: 13
                                    bottomMargin: 8
                                }
                                spacing: 1

                                Rectangle {
                                    id: avatarFrame
                                    width: 48
                                    height: 48
                                    radius: width / 2
                                    color: Appearance.colors.colPrimaryContainer

                                    Image {
                                        id: avatarImage
                                        anchors.fill: parent
                                        source: Config.options.profile.avatarPicture !== "" ? "file://" + Config.options.profile.avatarPicture : "file://" + Directories.userAvatarPathRicersAndWeirdSystems
                                        sourceSize.width: width * 2
                                        sourceSize.height: height * 2
                                        fillMode: Image.PreserveAspectCrop
                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: avatarFrame.width
                                                height: avatarFrame.height
                                                radius: avatarFrame.radius
                                            }
                                        }
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "account_circle"
                                        iconSize: 32
                                        color: Appearance.colors.colOnPrimaryContainer
                                        visible: avatarImage.status === Image.Error
                                    }
                                }

                                StyledText {
                                    text: Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    text: Config.options.profile.descriptionText === "::distro::" ? SystemInfo.distroName : Config.options.profile.descriptionText
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnLayer1
                                    opacity: 0.6
                                }
                            }

                            ButtonGroup {
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: 4
                                }
                                color: "transparent"
                                padding: 4

                                QuickToggleButton {
                                    toggled: root.editMode
                                    visible: Config.options.sidebar.quickToggles.style === "android"
                                    buttonIcon: "edit"
                                    onClicked: root.editMode = !root.editMode
                                }
                                QuickToggleButton {
                                    buttonIcon: "restart_alt"
                                    onClicked: {
                                        Quickshell.execDetached(["hyprctl", "reload"])
                                        Quickshell.reload(true)
                                    }
                                }
                                QuickToggleButton {
                                    buttonIcon: "settings"
                                    onClicked: {
                                        GlobalStates.sidebarRightOpen = false
                                        Quickshell.execDetached(["qs", "-p", root.settingsQmlPath])
                                    }
                                }
                                QuickToggleButton {
                                    buttonIcon: "power_settings_new"
                                    onClicked: GlobalStates.sessionOpen = true
                                }
                            }
                        }
                    }
                }

                Component {
                    id: systemButtons
                    SystemButtonRow {}
                }
            }

            Loader {
                id: slidersLoader
                Layout.fillWidth: true
                visible: active
                active: {
                    const configQuickSliders = Config.options.sidebar.quickSliders
                    if (!configQuickSliders.enable) return false
                    if (!configQuickSliders.showMic && !configQuickSliders.showVolume && !configQuickSliders.showBrightness) return false;
                    return true;
                }
                sourceComponent: QuickSliders {}
            }

            LoaderedQuickPanelImplementation {
                styleName: "classic"
                sourceComponent: ClassicQuickPanel {}
            }

            LoaderedQuickPanelImplementation {
                styleName: "android"
                sourceComponent: AndroidQuickPanel {
                    editMode: root.editMode
                }
            }

            CenterWidgetGroup {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
            }

            BottomWidgetGroup {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioOutputDialog"
        dialog: VolumeDialog {
            isSink: true
        }
    }

    ToggleDialog {
        shownPropertyString: "showAudioInputDialog"
        dialog: VolumeDialog {
            isSink: false
        }
    }

    ToggleDialog {
        shownPropertyString: "showBluetoothDialog"
        dialog: BluetoothDialog {}
        onShownChanged: {
            if (!shown) {
                Bluetooth.defaultAdapter.discovering = false;
            } else {
                Bluetooth.defaultAdapter.enabled = true;
                Bluetooth.defaultAdapter.discovering = true;
            }
        }
    }

    ToggleDialog {
        shownPropertyString: "showNightLightDialog"
        dialog: NightLightDialog {}
    }

    ToggleDialog {
        shownPropertyString: "showWifiDialog"
        dialog: WifiDialog {}
        onShownChanged: {
            if (!shown) return;
            Network.enableWifi();
            Network.rescanWifi();
        }
    }

    component ToggleDialog: Loader {
        id: toggleDialogLoader
        required property string shownPropertyString
        property alias dialog: toggleDialogLoader.sourceComponent
        readonly property bool shown: root[shownPropertyString]
        anchors.fill: parent

        onShownChanged: if (shown) toggleDialogLoader.active = true;
        active: shown
        onActiveChanged: {
            if (active) {
                item.show = true;
                item.forceActiveFocus();
            }
        }
        Connections {
            target: toggleDialogLoader.item
            function onDismiss() {
                toggleDialogLoader.item.show = false
                root[toggleDialogLoader.shownPropertyString] = false;
            }
            function onVisibleChanged() {
                if (!toggleDialogLoader.item.visible && !root[toggleDialogLoader.shownPropertyString]) toggleDialogLoader.active = false;
            }
        }
    }

    component LoaderedQuickPanelImplementation: Loader {
        id: quickPanelImplLoader
        required property string styleName
        Layout.alignment: item?.Layout.alignment ?? Qt.AlignHCenter
        Layout.fillWidth: item?.Layout.fillWidth ?? false
        visible: active
        active: Config.options.sidebar.quickToggles.style === styleName
        Connections {
            target: quickPanelImplLoader.item
            function onOpenAudioOutputDialog() {
                root.showAudioOutputDialog = true;
            }
            function onOpenAudioInputDialog() {
                root.showAudioInputDialog = true;
            }
            function onOpenBluetoothDialog() {
                root.showBluetoothDialog = true;
            }
            function onOpenNightLightDialog() {
                root.showNightLightDialog = true;
            }
            function onOpenWifiDialog() {
                root.showWifiDialog = true;
            }
        }
    }

    component SystemButtonRow: Item {
        implicitHeight: Math.max(uptimeContainer.implicitHeight, systemButtonsRow.implicitHeight)

        Rectangle {
            id: uptimeContainer
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            color: Appearance.colors.colLayer1
            readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : height / 2
            radius: fullRadius
            implicitWidth: uptimeRow.implicitWidth + 24
            implicitHeight: uptimeRow.implicitHeight + 8
            
            Row {
                id: uptimeRow
                anchors.centerIn: parent
                spacing: 8
                CustomIcon {
                    id: distroIcon
                    anchors.verticalCenter: parent.verticalCenter
                    width: 25
                    height: 25
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: Appearance.colors.colOnLayer0
                }
                ColumnLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -4
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        text: Translation.tr("Up")
                        textFormat: Text.MarkdownText
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        text: DateTime.uptime
                        textFormat: Text.MarkdownText
                    }
                }
                
            }
        }

        ButtonGroup {
            id: systemButtonsRow
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            color: Appearance.colors.colLayer1
            padding: 4

            QuickToggleButton {
                toggled: root.editMode
                visible: Config.options.sidebar.quickToggles.style === "android"
                buttonIcon: "edit"
                onClicked: root.editMode = !root.editMode
                StyledToolTip {
                    text: Translation.tr("Edit quick toggles") + (root.editMode ? Translation.tr("\nLMB to enable/disable\nRMB to toggle size\nScroll to swap position") : "")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "restart_alt"
                onClicked: {
                    Quickshell.execDetached(["hyprctl", "reload"])
                    Quickshell.reload(true);
                }
                StyledToolTip {
                    text: Translation.tr("Reload Hyprland & Quickshell")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "settings"
                onClicked: {
                    GlobalStates.sidebarRightOpen = false;
                    Quickshell.execDetached(["qs", "-p", root.settingsQmlPath]);
                }
                StyledToolTip {
                    text: Translation.tr("Settings")
                }
            }
            QuickToggleButton {
                id: updateButton
                toggled: confirm
                property bool confirm: false
                buttonIcon: confirm ? "check" : "download"
                Timer {
                    id: confirmTimer
                    interval: 2000
                    onTriggered: {
                        confirmTimer.stop();
                        updateButton.confirm = false
                    }
                }
                onClicked: {
                    if (confirm) {
                        Quickshell.execDetached([Directories.cliPath, "update", "--no-confirm", "--no-backup"]);
                        GlobalStates.sidebarRightOpen = false;
                    } else {
                        confirm = true
                        confirmTimer.start()
                    }
                    
                }
                StyledToolTip {
                    text: Translation.tr("Update the ii-vynx, make sure you have the vynx-cli installed")
                }
            }
            QuickToggleButton {
                toggled: false
                buttonIcon: "power_settings_new"
                onClicked: {
                    GlobalStates.sessionOpen = true;
                }
                StyledToolTip {
                    text: Translation.tr("Session")
                }
            }
        }
    }
}
