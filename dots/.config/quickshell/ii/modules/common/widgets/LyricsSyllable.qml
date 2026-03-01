import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects 
import Quickshell.Services.Mpris

// An animated version on LyricsSyllable (i have no idea why it is named as syllable dont judge me)

Item {
    id: root
    clip: true

    readonly property int highlightStyle: Config.options.background.mediaMode.syllable.textHighlightStyle
    readonly property int currentIndex: LyricsService.currentIndex
    readonly property bool isPlaying: LyricsService.activePlayer.isPlaying 
    
    property real largeFontSize: Appearance.font.pixelSize.hugeass * 2.0

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    Item {
        id: listMaskSource
        anchors.fill: parent
        visible: false
        LinearGradient {
            anchors.fill: parent
            start: Qt.point(0, 0)
            end: Qt.point(0, parent.height)
            gradient: Gradient {
                GradientStop { position: 0.1; color: "transparent" }
                GradientStop { position: 0.25; color: "black" } 
                GradientStop { position: 0.85; color: "black" } 
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Item {
        id: maskedContainer
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: listMaskSource
        }

        ListView {
            id: lyricsList
            anchors.fill: parent 
            model: LyricsService.syncedLines
            interactive: true
            currentIndex: root.currentIndex

            onMovingChanged: {
                if (!moving) return
                highlightFollowsCurrentItem = false
            }
            
            highlightFollowsCurrentItem: true
            highlightRangeMode: highlightFollowsCurrentItem ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            preferredHighlightBegin: parent.height / 2 - 60
            preferredHighlightEnd: parent.height / 2
            highlightMoveDuration: 600

            function scrollToCurrentItem() {
                if (!lyricsList.currentItem || lyricsList.moving) return
                let item = lyricsList.currentItem
                let targetY = item.y - (lyricsList.height / 2 - item.height / 2)
                
                contentYAnim.to = targetY
                contentYAnim.restart()
            }

            NumberAnimation {
                id: contentYAnim
                target: lyricsList
                property: "contentY"
                duration: 250
                easing.type: Easing.InOutQuad
                onStopped: {
                    lyricsList.highlightFollowsCurrentItem = true
                }
            }

            delegate: Item {
                id: delegateRoot
                width: lyricsList.width
                height: lyricText.implicitHeight + 40 

                readonly property bool isCurrent: index === lyricsList.currentIndex
                onIsCurrentChanged: {
                    if (!isCurrent || lyricsList.highlightFollowsCurrentItem || lyricsList.moving) return
                    let margin = -200
                    let visible = delegateRoot.y + delegateRoot.height > lyricsList.contentY - margin &&
                                delegateRoot.y < lyricsList.contentY + lyricsList.height + margin
                    if (visible) {
                        lyricsList.scrollToCurrentItem()
                    }
                }

                
                Item {
                    id: scalerItem
                    anchors.fill: parent
                    scale: isCurrent ? 1.0 : 0.85
                    
                    Behavior on scale { 
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    // Maske için kullanılan görünmez metin
                    StyledText {
                        id: lyricText
                        text: modelData.text
                        anchors.centerIn: parent
                        width: parent.width - 40 
                        font.pixelSize: root.largeFontSize
                        font.family: Appearance.font.family.title
                        font.weight: isCurrent ? Font.Bold : Font.DemiBold
                        font.styleName: "" // Set empty to prevent conflicts, not meaningless
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: false 
                    }

                    // Pasif Arka Plan Metni
                    StyledText {
                        id: backgroundText
                        text: lyricText.text
                        anchors.fill: lyricText
                        font: lyricText.font
                        horizontalAlignment: lyricText.horizontalAlignment
                        wrapMode: lyricText.wrapMode
                        color: "#22ffffff"
                        opacity: isCurrent ? 1.0 : 0.4

                        layer.enabled: isCurrent
                        layer.effect: DropShadow {
                            color: Appearance.colors.colPrimary
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 20
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LyricsService.changeDurationToIndex(index)
                            }
                        }
                    }

                    Item {
                        anchors.fill: lyricText
                        visible: isCurrent

                        HorizontalHighlight { id: horizontalGrad }
                        VerticalHighlight { id: verticalGrad }

                        OpacityMask {
                            anchors.fill: parent
                            source: root.highlightStyle === 0 ? verticalGrad : horizontalGrad
                            maskSource: lyricText
                        }
                    }
                }
            }
        }
    }

    component HorizontalHighlight: LinearGradient {
        anchors.fill: parent
        visible: false 
        
        property real currentX: -150

        NumberAnimation on currentX {
            from: -150
            to: lyricsList.width + 150
            duration: isCurrent ? LyricsService.getLineDuration(index) * 1000 : 0
            running: isCurrent && root.isPlaying
            easing.type: Easing.Linear
        }

        start: Qt.point(currentX, 0)
        end: Qt.point(currentX + 200, 0)
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: Appearance.colors.colPrimary } 
            GradientStop { position: 0.8; color: "white" } 
            GradientStop { position: 1.0; color: "transparent" } 
        }
    }

    component VerticalHighlight: LinearGradient {
        anchors.fill: parent
        visible: false 

        property real currentY: -20 

        NumberAnimation on currentY {
            from: -20
            to: lyricText.height + 20
            duration: isCurrent ? LyricsService.getLineDuration(index) * 1000 : 0
            running: isCurrent && root.isPlaying
            easing.type: Easing.Linear
        }

        start: Qt.point(0, currentY)
        end: Qt.point(0, currentY + 100)

        gradient: Gradient {
            GradientStop { position: 0.0; color: Appearance.colors.colPrimary }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}