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
    property int lineHeight: 0
    property int textHorizontalAlignment: Text.AlignHCenter
    property real gradientDensity: 1.0
    property color activeTextColor: Appearance.colors.colOnLayer0
    property color inactiveTextColor: Appearance.colors.colSubtext
    property color gradientTextColor: inactiveTextColor

    width: parent.width
    height: lineHeight
    transformOrigin: lyricLineItem.textHorizontalAlignment === Text.AlignLeft  ? Item.Left  :
                 lyricLineItem.textHorizontalAlignment === Text.AlignRight ? Item.Right :
                                                                              Item.Center

    property real currentLyricsSize: defaultLyricsSize

    property bool changeTextWeight: false

    StyledText {
        id: lyricText
        anchors.fill: parent
        text: lyricLineItem.text
        color: lyricLineItem.highlight ? lyricLineItem.activeTextColor : lyricLineItem.inactiveTextColor
        font.pixelSize: lyricLineItem.currentLyricsSize * (lyricLineItem.highlight ? 1.2 : 1.0)
        font.weight: changeTextWeight ? lyricLineItem.highlight ? Font.Bold : Font.Medium : Font.Medium
        horizontalAlignment: lyricLineItem.textHorizontalAlignment
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
                        color: lyricLineItem.gradientDirection === "top" ? Qt.rgba(0,0,0,gradientDensity) : "black"
                    }
                    GradientStop {
                        position: 1.0
                        color: lyricLineItem.gradientDirection === "top" ? "black" : Qt.rgba(0,0,0,gradientDensity)
                    }
                }
            }
        }

        StyledText {
            anchors.fill: parent
            text: lyricLineItem.text
            color: lyricLineItem.gradientTextColor
            font.pixelSize: lyricLineItem.currentLyricsSize
            font.weight: Font.Medium
            horizontalAlignment: lyricLineItem.textHorizontalAlignment
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
    }
}
