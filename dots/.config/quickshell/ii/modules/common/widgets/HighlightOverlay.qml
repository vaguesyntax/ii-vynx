import qs.modules.common.widgets
import qs.modules.common
import QtQuick

Rectangle {
    id: highlightOverlay
    color: Appearance.colors.colSecondaryContainer
    radius: Appearance.rounding.small
    opacity: 0
    z: -1

    function startAnimation() {
        blinkAnimation.start()
    }
    
    SequentialAnimation {
        id: blinkAnimation
        loops: 3
        
        NumberAnimation {
            target: highlightOverlay
            property: "opacity"
            to: 0.8
            duration: 150
        }
        
        NumberAnimation {
            target: highlightOverlay
            property: "opacity"
            to: 0
            duration: 150
        }
    }
    
}