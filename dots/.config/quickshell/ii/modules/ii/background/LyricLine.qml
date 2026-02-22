import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects

Item {
    id: lyricLineItem
    required property string text
    property bool highlight: false
    property bool useGradient: false
    property string gradientDirection: "top"
    property bool reallyUseGradient: useGradient

    property real defaultLyricsSize: Appearance.font.pixelSize.hugeass * 1.5

    width: parent.width
    height: lyricScroller.rowHeight
    transformOrigin: Item.Left

    // Expose defaultLyricsSize properly
    property real currentLyricsSize: defaultLyricsSize

    StyledText {
        id: lyricText
        anchors.fill: parent
        text: lyricLineItem.text
        color: lyricLineItem.highlight ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
        font.pixelSize: lyricLineItem.currentLyricsSize * (lyricLineItem.highlight ? 1.2 : 1.0)
        font.weight: lyricLineItem.highlight ? Font.Bold : Font.Medium
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        visible: !lyricLineItem.reallyUseGradient
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }

    Item {
        anchors.fill: parent
        visible: lyricLineItem.reallyUseGradient
        layer.enabled: visible
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: lyricLineItem.width
                height: lyricLineItem.height
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: lyricLineItem.gradientDirection === "top" ? "transparent" : "black"
                    }
                    GradientStop {
                        position: 1.0
                        color: lyricLineItem.gradientDirection === "top" ? "black" : "transparent"
                    }
                }
            }
        }

        StyledText {
            anchors.fill: parent
            text: lyricLineItem.text
            color: Appearance.colors.colSubtext
            font.pixelSize: lyricLineItem.currentLyricsSize
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}