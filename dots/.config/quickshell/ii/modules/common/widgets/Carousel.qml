import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/*
 * As close to as possible recreation of Material 3 Expressive Carousel. 
 * See https://m3.material.io/components/carousel/overview
 * NOTE: Use bigger sourceSize and thumbnailSizeName in ThumbnailImage for better resolution (512x512)
*/

Item {
    id: root

    property var model: []
    property Component delegate: null
    property real itemSpacing: 8
    property real topPadding: 8
    property real bottomPadding: 8
    property real leftPadding: 16
    property real rightPadding: 16
    property bool snapEnabled: true
    property bool showBadges: false

    property int currentIndex: 0
    property list<real> sizeRatios: [6, 3, 1] // Must be a list with a size of 3
    readonly property real itemHeight: height - topPadding - bottomPadding
    readonly property bool expanded: width > 400

    signal pressedAny()
    signal itemClicked(int index, var modelData)

    clip: true

    readonly property real _totalRatio: sizeRatios[0] + sizeRatios[1] + sizeRatios[2]
    readonly property real _itemAreaWidth: Math.max(0, width - leftPadding - rightPadding - 2 * itemSpacing)
    readonly property real _unitWidth: _itemAreaWidth / _totalRatio

    property real _largeW: sizeRatios[0] > 0 ? Math.max(40, _unitWidth * sizeRatios[0]) : 0
    property real _mediumW: sizeRatios[1] > 0 ? Math.max(30, _unitWidth * sizeRatios[1]) : 0
    property real _smallW: sizeRatios[2] > 0 ? Math.max(20, _unitWidth * sizeRatios[2]) : 0
    readonly property real _stepSize: _largeW + itemSpacing

    readonly property var _slotX: [
        root.leftPadding - root.itemSpacing,
        root.leftPadding,
        root.leftPadding + _largeW + itemSpacing,
        root.leftPadding + _largeW + itemSpacing + _mediumW + itemSpacing,
        root.leftPadding + _largeW + itemSpacing + _mediumW + itemSpacing + _smallW + itemSpacing
    ]
    readonly property var _slotWidth: [0, _largeW, _mediumW, _smallW, 0]

    function snapToIndex(index) {
        if (index < 0 || index >= repeater.count) return
        const target = index * _stepSize
        const maxX = Math.max(0, (repeater.count - 1) * _stepSize)
        snapAnim.from = flickable.contentX
        snapAnim.to = Math.min(target, maxX)
        snapAnim.start()
    }

    StyledFlickable {
        id: flickable
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root.topPadding
            bottomMargin: root.bottomPadding
        }
        height: root.itemHeight
        contentHeight: height
        contentWidth: Math.max(width, (repeater.count - 1) * root._stepSize + width)
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        interactive: repeater.count > 1

        Repeater {
            id: repeater
            model: root.model

            delegate: Item {
                id: itemContainer
                required property var modelData
                required property int index

                readonly property real slotDist: index - (flickable.contentX / root._stepSize)
                readonly property real arrayIdx: slotDist + 1
                readonly property int slotFloor: Math.max(0, Math.min(Math.floor(arrayIdx), 4))
                readonly property real slotFrac: arrayIdx - slotFloor
                readonly property int slotCeil: Math.min(slotFloor + 1, 4)

                readonly property real targetWidth: Math.max(0, root._slotWidth[slotFloor] + (root._slotWidth[slotCeil] - root._slotWidth[slotFloor]) * slotFrac)
                readonly property real targetViewportX: root._slotX[slotFloor] + (root._slotX[slotCeil] - root._slotX[slotFloor]) * slotFrac
                readonly property real cornerRadius: Appearance.rounding.large
                readonly property bool isFocal: root.currentIndex === index

                width: targetWidth
                height: flickable.height
                x: flickable.contentX + targetViewportX
                visible: width > 0.5

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: itemContainer.width
                        height: itemContainer.height
                        radius: itemContainer.cornerRadius
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colSurfaceContainerHighest
                    radius: itemContainer.cornerRadius

                    Item {
                        id: delegateContainer
                        anchors.fill: parent
                    }
                }

                Rectangle {
                    id: stateOverlay
                    anchors.fill: parent
                    radius: itemContainer.cornerRadius
                    color: "transparent"

                    property color hoverColor: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)
                    property color pressedColor: ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.8)

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                        margins: 10
                    }

                    visible: root.showBadges
                    implicitWidth: Math.min(fileLabel.implicitWidth + 20, parent.width - 20)
                    implicitHeight: fileLabel.implicitHeight + 5
                    color: Appearance.colors.colPrimary
                    radius: Appearance.rounding.full

                    opacity: itemContainer.width >= root._largeW ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.BezierSpline
                        }
                    }

                    StyledText {
                        id: fileLabel
                        anchors {
                            verticalCenter: parent.verticalCenter
                            horizontalCenter: parent.horizontalCenter
                            horizontalCenterOffset: 4
                        }
                        property string fileName: modelData.filePath.split("/")[modelData.filePath.split("/").length - 1]
                        text: fileName
                        color: Appearance.colors.colOnPrimary
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideMiddle
                        width: parent.implicitWidth - 10
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.itemClicked(itemContainer.index, itemContainer.modelData)
                    hoverEnabled: true

                    onWheel: event => {
                        root.pressedAny()
                        if (event.angleDelta.y < 0) {
                            flickable.flick(-900,0)
                        } else if (event.angleDelta.y > 0) {
                            flickable.flick(900,0)
                        }
                    }

                    onPressed: {
                        root.pressedAny()
                    }
                    onContainsMouseChanged: {
                        stateOverlay.color = containsMouse ? stateOverlay.hoverColor : "transparent"
                    }
                    onPressedChanged: {
                        stateOverlay.color = pressed ? stateOverlay.pressedColor : (containsMouse ? stateOverlay.hoverColor : "transparent")
                    }
                }

                Component.onCompleted: {
                    if (root.delegate) {
                        var obj = root.delegate.createObject(delegateContainer, {
                            modelData: itemContainer.modelData,
                            index: itemContainer.index,
                            width: itemContainer.width,
                            height: itemContainer.height
                        })
                        if (obj) {
                            obj.width = Qt.binding(function() { return itemContainer.width })
                            obj.height = Qt.binding(function() { return itemContainer.height })
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: snapAnim
        target: flickable
        property: "contentX"
        duration: 400
        easing.type: Easing.BezierSpline
        onFinished: {
            updateCurrentIndex()
        }
    }

    PropertyAnimation {
        id: expandAnimation
        target: root
        property: "height"
        duration: 300
        easing.type: Easing.BezierSpline
    }

    function updateCurrentIndex() {
        if (repeater.count === 0) {
            currentIndex = -1
            return
        }
        const rawIndex = flickable.contentX / _stepSize
        const clamped = Math.max(0, Math.min(repeater.count - 1, Math.round(rawIndex)))
        if (clamped !== currentIndex) {
            currentIndex = clamped
            currentIndexChanged()
        }
    }

    onWidthChanged: updateCurrentIndex()

    Connections {
        target: flickable
        function onContentXChanged() {
            if (!snapAnim.running) {
                updateCurrentIndex()
            }
        }
        function onMovementEnded() {
            if (root.snapEnabled && !snapAnim.running) {
                snapToIndex(root.currentIndex)
            }
        }
    }
}
