import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 200
    property int value: 25
    property bool running: false
    signal dragFinished(int value)
    signal dragStarted()
    signal dragEnded()

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real radius: Math.min(width, height) / 2 - 10
    readonly property real angle: (value / 60) * 2 * Math.PI - Math.PI / 2

    Rectangle { anchors.fill: parent; radius: width / 2; color: Appearance.colors.colLayer1 }

    Repeater {
        model: 12
        delegate: Item {
            required property int index
            readonly property int minuteValue: (index + 1) * 5
            readonly property real tickAngle: ((index + 1) / 12) * 2 * Math.PI - Math.PI / 2
            readonly property real numberRadius: root.radius - 18
            readonly property bool selected: root.value === minuteValue

            Rectangle {
                x: root.centerX + numberRadius * Math.cos(tickAngle) - width / 2
                y: root.centerY + numberRadius * Math.sin(tickAngle) - height / 2
                width: 28; height: 28; radius: 14
                color: root.running && selected ? Appearance.colors.colPrimary : "transparent"
                StyledText {
                    anchors.centerIn: parent
                    visible: !selected || root.running
                    text: minuteValue.toString()
                    font.pixelSize: 11; font.weight: 700
                    color: root.running && selected ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                }
            }
            Rectangle {
                readonly property real tickRadius: root.radius - 4
                x: root.centerX + tickRadius * Math.cos(tickAngle) - width / 2
                y: root.centerY + tickRadius * Math.sin(tickAngle) - height / 2
                width: minuteValue % 15 === 0 ? 5 : 3
                height: width; radius: width / 2
                visible: !(root.running && selected)
                color: selected ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colSubtext, 0.5)
            }
        }
    }

    Canvas {
        id: handCanvas
        anchors.fill: parent
        visible: !root.running
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            const handLength = root.radius - 30;
            context.beginPath();
            context.moveTo(root.centerX, root.centerY);
            context.lineTo(root.centerX + handLength * Math.cos(root.angle), root.centerY + handLength * Math.sin(root.angle));
            context.strokeStyle = Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.9);
            context.lineWidth = 2;
            context.lineCap = "round";
            context.stroke();
        }
        Connections {
            target: root
            function onAngleChanged() { handCanvas.requestPaint() }
            function onValueChanged() { handCanvas.requestPaint() }
        }
        Connections {
            target: Appearance
            function onColorsChanged() { handCanvas.requestPaint() }
        }
    }

    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Appearance.colors.colPrimary; visible: !root.running }
    Rectangle {
        width: 28; height: 28; radius: 14; color: Appearance.colors.colPrimary
        visible: !root.running
        x: root.centerX + (root.radius - 30) * Math.cos(root.angle) - width / 2
        y: root.centerY + (root.radius - 30) * Math.sin(root.angle) - height / 2
        StyledText { anchors.centerIn: parent; text: root.value.toString(); font.pixelSize: 9; font.weight: 700; color: Appearance.colors.colOnPrimary }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.running
        spacing: 2
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, "0")}:${Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, "0")}`
            font.pixelSize: 36; font.weight: 700; font.features: { "tnum": 1 }
            color: Appearance.m3colors.m3onSurface
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: TimerService.pomodoroLongBreak ? Translation.tr("Long break") : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
            font.pixelSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.running
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function valueForPoint(x, y) {
            let angle = Math.atan2(y - root.centerY, x - root.centerX) + Math.PI / 2;
            if (angle < 0) angle += 2 * Math.PI;
            const snapped = Math.round((angle / (2 * Math.PI) * 60) / 5) * 5;
            return snapped === 0 ? 60 : snapped;
        }
        onPressed: event => {
            root.dragStarted()
            root.value = valueForPoint(event.x, event.y)
        }
        onPositionChanged: event => { if (pressed) root.value = valueForPoint(event.x, event.y) }
        onReleased: {
            root.dragFinished(root.value)
            root.dragEnded()
        }
        onCanceled: root.dragEnded()
    }
}
