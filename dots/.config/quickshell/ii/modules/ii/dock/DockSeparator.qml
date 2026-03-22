import QtQuick
import qs.modules.common
import qs.services
import qs

Item {
    id: root
    
    property bool isVertical: true
    property real marginScale: 0.15
    property color color: Appearance.colors.colOutlineVariant

    Rectangle {
        id: line
        readonly property real currentMargin: Math.round((root.isVertical 
            ? root.width : root.height) * root.marginScale)

        anchors.centerIn: parent
        
        width: root.isVertical ? root.width - currentMargin * 2 : root.width
        height: root.isVertical ? root.height : root.height - currentMargin * 2
        
        radius: Appearance.rounding.full
        color: root.color
    }
}