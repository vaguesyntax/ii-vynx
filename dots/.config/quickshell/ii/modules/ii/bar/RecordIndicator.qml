import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import "./cards"


MouseArea {
    id: indicator
    property bool vertical: false

    property bool minimal: Config.options.bar.indicators.record.minimal
    property bool activelyRecording: Persistent.states.screenRecord.active
    property color colText: Appearance.colors.colOnPrimary

    hoverEnabled: true
    implicitWidth: vertical ? 20 : minimal ? 50 : 80 // NOTE: Why do we have to enter a fixed size to make it dull?
    implicitHeight: vertical ? 50 : 20

    Component.onCompleted: updateVisibility()
    onActivelyRecordingChanged: updateVisibility()

    function updateVisibility() {
        rootItem.toggleVisible(activelyRecording)
    }

    function formatTime(totalSeconds) {
        let mins = Math.floor(totalSeconds / 60);
        let secs = totalSeconds % 60;
        return String(mins).padStart(2, '0') + ":" + String(secs).padStart(2, '0');
    }

    RippleButton {
        anchors.centerIn: parent
        implicitWidth: indicator.vertical ? 20 : parent.implicitWidth
        implicitHeight: indicator.vertical ? parent.implicitHeight : 20
        colBackgroundHover: "transparent"
        colRipple: "transparent"
        
        onClicked: {
            Quickshell.execDetached(Directories.recordScriptPath)
        }
        StyledPopup {
            hoverTarget: indicator
            contentItem: PopupContent {}
        }
    }

    Loader {
        active: !indicator.vertical
        anchors.centerIn: parent
        sourceComponent: RowLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                text: "screen_record"
                color: indicator.colText
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignVCenter
            }

            MaterialSymbol {
                text: "stop"
                fill: 1
                visible: minimal
                color: indicator.colText
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignVCenter
            }
            
            StyledText {
                id: textIndicator                
                Layout.topMargin: 2
                visible: !minimal

                text: indicator.formatTime(Persistent.states.screenRecord.seconds)
                color: indicator.colText
            }
        }
    }

    Loader {
        active: indicator.vertical
        anchors.centerIn: parent
        sourceComponent: ColumnLayout {
            id: contentLayout
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                Layout.topMargin: parent.spacing
                Layout.alignment: Text.AlignHCenter
                text: "screen_record"
                color: indicator.colText
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
            }

            MaterialSymbol {
                Layout.alignment: Text.AlignHCenter
                text: "stop"
                fill: 1
                color: indicator.colText
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    
    component PopupContent: HeroCard {
        id: mediaHero
        anchors.centerIn: parent
        compactMode: true
        icon: "screen_record"

        title: Translation.tr("Recording...")
        subtitle: Translation.tr("Click to stop recording")

        pillText: indicator.formatTime(Persistent.states.screenRecord.seconds)
        pillIcon: "timer"
    }
    
}