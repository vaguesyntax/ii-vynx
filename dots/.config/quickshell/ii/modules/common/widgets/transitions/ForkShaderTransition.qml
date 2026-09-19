import QtQuick

// Ported and adapted from https://github.com/pctrade/end4-pC.
Item {
    id: effect
    property Item frontImg
    property Item backImg
    property int duration: 1200
    required property string shaderFile
    property bool hideFront: true
    property bool waitForReady: true
    signal finished()

    function start() {
        shader.progress = 0
        shader.visible = true
        progressAnimation.restart()
    }

    function cleanup() {
        progressAnimation.stop()
        shader.visible = false
        shader.progress = 0
    }

    NumberAnimation {
        id: progressAnimation
        target: shader
        property: "progress"
        from: 0
        to: 1
        duration: effect.duration
        easing.type: Easing.InOutCubic
        onFinished: effect.finished()
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        visible: false
        property var fromImage: effect.backImg
        property var toImage: effect.frontImg
        property real progress: 0
        property real aspectX: width / height
        property real aspectY: 1
        property vector2d aspectRatio: Qt.vector2d(aspectX, aspectY)
        property vector2d origin: Qt.vector2d(0.5, 0.5)
        fragmentShader: Qt.resolvedUrl("shaders/" + effect.shaderFile)
    }
}
