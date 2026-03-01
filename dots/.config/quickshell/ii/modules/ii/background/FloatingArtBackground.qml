import QtQuick
import QtQuick.Effects
import qs
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property real animationSpeedScale
    required property string artFilePath
    required property color overlayColor
    required property bool animationEnabled

    // Parallax - sidebar
    property real parallaxStrength: 30
    // Parallax - workspace
    required property real workspaceNorm
    property real workspaceParallaxStrength: 40
    readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical

    property real parallaxX: {
        const sidebar = (GlobalStates.effectiveRightOpen - GlobalStates.effectiveLeftOpen) * parallaxStrength
        const ws = verticalParallax ? 0 : (workspaceNorm - 0.5) * -2 * workspaceParallaxStrength
        return sidebar + ws
    }
    property real parallaxY: {
        return verticalParallax ? (workspaceNorm - 0.5) * -2 * workspaceParallaxStrength : 0
    }
    
    // using normal animations feels too flat
    Behavior on parallaxX {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }
    Behavior on parallaxY {
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }

    TransitionImage {
        id: img
        anchors.fill: parent
        imageSource: root.artFilePath

        layer.enabled: true
        layer.effect: StyledBlurEffect { source: img }

        Rectangle { anchors.fill: parent; color: root.overlayColor }

        transform: [
            Scale {
                origin.x: img.width / 2; origin.y: img.height / 2
                xScale: 1.15; yScale: 1.15
            },
            Translate { id: floatTranslate },
            Translate { id: parallaxTranslate; x: -root.parallaxX; y: root.parallaxY }
        ]

        AxisAnimation {
            speed: root.animationSpeedScale
            axis: "x"
            frames: [-50,  30, -20,  50, -50]
            times:  [16500, 11500, 19500, 14500]
        }

        AxisAnimation {
            speed: root.animationSpeedScale
            axis: "y"
            frames: [20, -50,  30, -30,  20]
            times:  [20000, 14000, 19000, 14500]
        }
    }

    component AxisAnimation: SequentialAnimation {
        required property string axis
        required property var frames 
        required property var times 
        required property var speed

        loops: Animation.Infinite
        running: root.animationEnabled

        onSpeedChanged: { // to instantly update the speed, it waits for the full animation to end to take effect otherwise
            running = false
            Qt.callLater (() => {
                running = root.animationEnabled
            })
        }

        NumberAnimation { target: floatTranslate; property: axis; from: frames[0]; to: frames[1]; duration: times[0] / speed; easing.type: Easing.InOutSine }
        NumberAnimation { target: floatTranslate; property: axis; from: frames[1]; to: frames[2]; duration: times[1] / speed; easing.type: Easing.InOutSine }
        NumberAnimation { target: floatTranslate; property: axis; from: frames[2]; to: frames[3]; duration: times[2] / speed; easing.type: Easing.InOutSine }
        NumberAnimation { target: floatTranslate; property: axis; from: frames[3]; to: frames[4]; duration: times[3] / speed; easing.type: Easing.InOutSine }
    }
}