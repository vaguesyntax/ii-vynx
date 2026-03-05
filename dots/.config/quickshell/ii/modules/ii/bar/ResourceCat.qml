import QtQuick

Item {
    id: root
    width: 46
    height: 35

    // Control desde Resources.qml
    property bool running: false
    property url runSource: ""
    property url sleepSource: ""

    // Intensidad/estilo del efecto al dormir
    property real sleepBreathScale: 0.035      // respiración
    property real sleepFloatPx: 1.6            // flotación
    property int  sleepAnimMs: 1100


    // RUN (corriendo)
     AnimatedImage {
        id: runGif
        anchors.fill: parent
        visible: root.running
        source: root.runSource
        playing: visible
        fillMode: Image.PreserveAspectFit
        smooth: true
    }


    Item {
        id: sleepLayer
        anchors.fill: parent
        visible: !root.running

        // GIF durmiendo
        AnimatedImage {
            id: sleepGif
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: root.sleepSource
            playing: visible
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Efecto de “respirar” (escala)
        SequentialAnimation on scale {
            running: sleepLayer.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: 1.0 + root.sleepBreathScale
                duration: root.sleepAnimMs
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1.0
                duration: root.sleepAnimMs
                easing.type: Easing.InOutSine
            }
        }

           SequentialAnimation on y {
            running: sleepLayer.visible
            loops: Animation.Infinite
            NumberAnimation {
                to: -root.sleepFloatPx
                duration: root.sleepAnimMs
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0
                duration: root.sleepAnimMs
                easing.type: Easing.InOutSine
            }
        }
    }
}

