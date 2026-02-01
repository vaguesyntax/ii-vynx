import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

Rectangle {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    property real verticalPadding: 4
    property real horizontalPadding: 12

    property bool showBrightness: Config.options.sidebar.quickSliders.showBrightness 
    property bool showVolume: Config.options.sidebar.quickSliders.showVolume 
    property bool showMic: Config.options.sidebar.quickSliders.showMic 

    RowLayout {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }

        spacing: 8


        property int activeCount: {
            let count = 0;
            for (let i = 0; i < repeater.count; i++) {
                if (repeater.itemAt(i) && repeater.itemAt(i).visible) count++;
            }
            return count;
        }


        Repeater {
            id: repeater
            model: [
                { show: showBrightness, icon: "brightness_6", 
                getVal: () => root.brightnessMonitor.brightness, 
                setVal: (v) => root.brightnessMonitor.setBrightness(v) },
                { show: showVolume, icon: "volume_up", 
                getVal: () => Audio.sink.audio.volume, 
                setVal: (v) => { Audio.sink.audio.volume = v } },
                { show: showMic, icon: "mic", 
                getVal: () => Audio.source.audio.volume, 
                setVal: (v) => { Audio.source.audio.volume = v } }
            ]

            QuickSlider {
                required property var modelData
                Layout.fillWidth: true
                visible: modelData.show
                materialSymbol: modelData.icon
                value: modelData.getVal()
                onMoved: modelData.setVal(value)
            }
        }
    }

    component QuickSlider: StyledSlider { 
        id: quickSlider
        required property string materialSymbol
        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        
        MaterialSymbol {
            id: icon
            property bool nearFull: quickSlider.value >= 0.82
            anchors {
                verticalCenter: parent.verticalCenter
                right: nearFull ? quickSlider.handle.right : parent.right
                rightMargin: quickSlider.nearFull ? 14 : 8
            }
            iconSize: 20
            color: nearFull ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            text: quickSlider.materialSymbol

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            Behavior on anchors.rightMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

        }
    }
}
