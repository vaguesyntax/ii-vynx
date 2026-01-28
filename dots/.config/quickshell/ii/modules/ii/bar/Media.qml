import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import qs.modules.common.utils

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    
    property int customSize: Config.options.bar.mediaPlayer.customSize
    property bool useCustomSize: Config.options.bar.mediaPlayer.useCustomSize 
    readonly property int maxWidth: 300

    readonly property bool showLoadingIndicator: Config.options.bar.mediaPlayer.lyrics.showLoadingIndicator
    readonly property bool lyricsEnabled: Config.options.bar.mediaPlayer.lyrics.enable
    readonly property bool useGradientMask: Config.options.bar.mediaPlayer.lyrics.useGradientMask
    readonly property string lyricsStyle: Config.options.bar.mediaPlayer.lyrics.style

    Layout.fillHeight: true
    implicitWidth: useCustomSize ? customSize : Math.min(rowLayout.implicitWidth + rowLayout.spacing, maxWidth)
    implicitHeight: Appearance.sizes.barHeight

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Loader {
        id: lyricsLoader
        active: lyricsEnabled
        sourceComponent: LrclibLyrics {
            id: lrclibLyrics
            enabled: (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0) && root.visible && root.lyricsEnabled
            title: root.activePlayer?.trackTitle ?? ""
            artist: root.activePlayer?.trackArtist ?? ""
            duration: root.activePlayer?.length ?? 0
            position: root.activePlayer?.position ?? 0
            selectedId: 0 //? I have no idea what this does, but it works so whatever
        }
    }

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: lyricScroller.hasSyncedLines ? 250 : Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            } else if (event.button === Qt.LeftButton) {
        var globalPos = root.mapToItem(null, 0, 0);
        GlobalStates.mediaWidgetRect = Qt.rect(globalPos.x, globalPos.y, root.width, root.height);     
        GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            }
        }   
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        Loader {
            id: loadingIndLoader
            active: root.showLoadingIndicator && !lyricScroller.hasSyncedLines && root.lyricsEnabled && (root.activePlayer?.trackTitle?.length > 0) && (root.activePlayer?.trackArtist?.length > 0)
            visible: active
            
            Layout.preferredWidth: active ? item.implicitWidth : 0
            Layout.preferredHeight: active ? item.implicitHeight : 0

            Timer {
                id: loadingIndicatorDissappearTimer
                interval: 1500
                onTriggered: loadingIndLoader.active = false
            }

            sourceComponent: MaterialLoadingIndicator {
                id: lyricsLoadingIndicator
                property bool couldntFetch: lyricsLoader.item?.error === "No synced lyrics" 
                
                loading: !couldntFetch
                color: couldntFetch ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
                shapeColor: couldntFetch ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                implicitSize: 24

                onCouldntFetchChanged: {
                    if (couldntFetch) {
                        loadingIndicatorDissappearTimer.start()
                    }
                }
            }
        }

        ClippedFilledCircularProgress {
            id: mediaCircProg
            visible: !loadingIndLoader.active
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            implicitSize: 20
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }

        StyledText {
            visible: !lyricScroller.hasSyncedLines
            width: rowLayout.width - (CircularProgress.size + rowLayout.spacing * 2)
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: visible // Ensures the text takes up available space
            Layout.rightMargin: rowLayout.spacing
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight // Truncates the text on the right
            color: Appearance.colors.colOnLayer1
            text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        }

        //TODO: i hate putting these to a loader rn, add this to a loader later
        Item {
            id: lyricScroller
            visible: root.lyricsEnabled
            Layout.preferredWidth: hasSyncedLines ? root.implicitWidth - (mediaCircProg.implicitSize + rowLayout.spacing * 2) : 0
            Layout.preferredHeight: parent.height
            Layout.alignment: Qt.AlignCenter
            clip: true

            readonly property bool hasSyncedLines: visible ? lyricsLoader.item?.lines.length > 0 : false
            readonly property int rowHeight: Math.max(10, Math.min(Math.floor(height / 3), Appearance.font.pixelSize.smallie))
            readonly property real baseY: Math.max(0, Math.round((height - rowHeight * 3) / 2))
            readonly property real downScale: Appearance.font.pixelSize.smaller / Appearance.font.pixelSize.smallie
            
            readonly property int targetCurrentIndex: hasSyncedLines ? lyricsLoader.item?.currentIndex : -1
            
            readonly property string targetPrev: hasSyncedLines ? lyricsLoader.item?.prevLineText : ""
            readonly property string targetCurrent: hasSyncedLines ? (lyricsLoader.item?.currentLineText || "♪") : lyricsLoader.item?.displayText
            readonly property string targetNext: hasSyncedLines ? lyricsLoader.item?.nextLineText : ""

            property int lastIndex: -1
            property bool isMovingForward: true

            readonly property real animProgress: Math.abs(scrollOffset) / rowHeight
            readonly property real dimOpacity: 0.6
            readonly property real activeOpacity: 1.0

            property real scrollOffset: 0

            property int staticLineAnimDuration: 100 // a config option maybe? but it may be an overkill
            
            onTargetCurrentIndexChanged: {
                if (targetCurrentIndex !== lastIndex) {
                    staticLyricBlinkAnimation.start()
                    isMovingForward = targetCurrentIndex > lastIndex;
                    lastIndex = targetCurrentIndex;
                    scrollAnimation.restart();
                }
            }
            
            SequentialAnimation {
                id: scrollAnimation
                PropertyAction { // instant
                    target: lyricScroller
                    property: "scrollOffset"
                    value: lyricScroller.isMovingForward ? -lyricScroller.rowHeight : lyricScroller.rowHeight 
                }
                NumberAnimation { // smooth
                    target: lyricScroller
                    property: "scrollOffset"
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            SequentialAnimation {
                id: staticLyricBlinkAnimation
                
                NumberAnimation {
                    target: staticLyricLine
                    property: "opacity"
                    from: 1.0
                    to: 0.0
                    duration: staticLineAnimDuration
                    easing.type: Easing.InOutSine
                }

                PropertyAction {
                    target: staticLyricLine
                    property: "text"
                    value: lyricScroller.targetCurrent 
                }

                NumberAnimation {
                    target: staticLyricLine
                    property: "opacity"
                    from: 0.0
                    to: 1.0
                    duration: staticLineAnimDuration
                    easing.type: Easing.InOutSine
                }
            }

            LyricLine {
                id: staticLyricLine
                highlight: true
                opacity: 0
                anchors.centerIn: parent
                text: "♪"
                visible: root.lyricsStyle == "static"
            }
            
            Loader {
                anchors.fill: parent
                active: root.lyricsStyle == "scrolling"
                sourceComponent: Column {
                    width: parent.width
                    spacing: 0
                    y: lyricScroller.baseY - lyricScroller.scrollOffset

                    LyricLine {
                        text: lyricScroller.targetPrev
                        highlight: false
                        useGradient: true
                        gradientDirection: "top"
                        
                        opacity: (lyricScroller.isMovingForward) 
                            ? lyricScroller.dimOpacity + (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                            : lyricScroller.dimOpacity
                            
                        scale: (lyricScroller.isMovingForward)
                            ? lyricScroller.downScale + (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
                            : lyricScroller.downScale
                    }

                    LyricLine {
                        text: lyricScroller.targetCurrent
                        highlight: true
                        useGradient: false
                        
                        opacity: lyricScroller.activeOpacity - (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                        scale: 1.0 - (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
                    }

                    LyricLine {
                        text: lyricScroller.targetNext
                        highlight: false
                        useGradient: true
                        gradientDirection: "bottom"
                        
                        opacity: (!lyricScroller.isMovingForward)
                            ? lyricScroller.dimOpacity + (lyricScroller.activeOpacity - lyricScroller.dimOpacity) * lyricScroller.animProgress
                            : lyricScroller.dimOpacity

                        scale: (!lyricScroller.isMovingForward)
                            ? lyricScroller.downScale + (1.0 - lyricScroller.downScale) * lyricScroller.animProgress
                            : lyricScroller.downScale
                    }
                }
            }
            
        }
    }

    component LyricLine: Item {
        id: lyricLineItem
        required property string text
        property bool highlight: false
        property bool useGradient: false
        property string gradientDirection: "top" // "top" or "bottom"
        property bool reallyUseGradient: useGradient && root.useGradientMask

        width: parent.width
        height: lyricScroller.rowHeight

        StyledText { // text for middle line
            id: lyricText
            anchors.fill: parent
            text: lyricLineItem.text
            color: lyricLineItem.highlight ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !lyricLineItem.reallyUseGradient
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
                            color: lyricLineItem.gradientDirection === "top" ? "transparent" : "black" // colShadow makes it look bad
                        }
                        GradientStop { 
                            position: 1.0
                            color: lyricLineItem.gradientDirection === "top" ?  "black" : "transparent"
                        }
                    }
                }
            }

            StyledText { // text with gradient mask
                anchors.fill: parent
                text: lyricLineItem.text
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallie
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

}
