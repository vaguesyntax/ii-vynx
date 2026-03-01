import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

PopupWindow {
    id: previewPopup

    property var  dockRoot:    null
    property var  appTopLevel: null
    property var  dockWindow:  null 

    readonly property bool isVertical: dockRoot?.isVertical ?? false
    readonly property string dockPos:  GlobalStates.dockEffectivePosition

    readonly property bool shouldShow:
        !dockRoot.dragActive &&
        (backgroundHover.hovered || dockRoot.buttonHovered || dockRoot.popupIsResizing) &&
        (appTopLevel?.toplevels?.length > 0)

    property bool show: false

    onShouldShowChanged: {
        if (shouldShow)
            show = true
        else
            hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 150
        onTriggered: previewPopup.show = previewPopup.shouldShow
    }

    visible: show || popupBackground.opacity > 0
    color: "transparent"

    anchor {
        window: dockWindow
        adjustment: PopupAdjustment.None

        rect {
            x: dockPos === "left" ? (dockWindow?.width ?? 0) : 0
            y: dockPos === "bottom" ? 0 : dockPos === "top" ? (dockWindow?.height ?? 0) : 0
        }

        gravity: {
            if (dockPos === "left")  return Edges.Right  | Edges.Bottom
            if (dockPos === "right") return Edges.Left   | Edges.Bottom
            if (dockPos === "top")   return Edges.Bottom | Edges.Right
            return Edges.Top | Edges.Right
        }

        edges: Edges.Top | Edges.Left
    }

    implicitWidth: isVertical
        ? dockRoot.maxWindowPreviewWidth
            + dockRoot.windowControlsHeight
            + popupBackground.padding * 2
            + popupBackground.margins * 2
            - 25
        : dockWindow?.width ?? 0

    implicitHeight: isVertical
        ? dockWindow?.height ?? 0
        : dockRoot.maxWindowPreviewHeight
            + dockRoot.windowControlsHeight
            + popupBackground.padding * 2
            + popupBackground.margins * 2
            + 5

    StyledRectangularShadow {
        target:  popupBackground
        opacity: popupBackground.opacity
        visible: popupBackground.visible
    }

    Rectangle {
        id: popupBackground

        property real margins: 5
        property real padding: 6

        onImplicitWidthChanged:  { dockRoot.popupIsResizing = true; resizeTimer.restart() }
        onImplicitHeightChanged: { dockRoot.popupIsResizing = true; resizeTimer.restart() }

        Timer {
            id: resizeTimer
            interval: 500
            onTriggered: dockRoot.popupIsResizing = false
        }

        x: isVertical
            ? (dockPos === "left"
                ? margins
                : parent.width - implicitWidth - margins)
            : dockRoot.hoveredButtonCenter.x - implicitWidth / 2

        y: isVertical
            ? dockRoot.hoveredButtonCenter.y - implicitHeight / 2
            : (dockPos === "top"
                ? margins
                : parent.height - implicitHeight - margins)

        opacity: previewPopup.show ? 1 : 0
        visible: true
        clip:    true
        color:   Appearance.m3colors.m3surfaceContainer
        radius:  Appearance.rounding.normal
        implicitHeight: previewRowLayout.implicitHeight + padding * 2
        implicitWidth:  previewRowLayout.implicitWidth  + padding * 2

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(previewPopup)
        }

        HoverHandler {
            id: backgroundHover
        }

        GridLayout {
            id: previewRowLayout
            anchors {
                top:        parent.top
                left:       parent.left
                topMargin:  popupBackground.padding
                leftMargin: popupBackground.padding
            }
            flow:          isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            columnSpacing: 6
            rowSpacing:    6

            Repeater {
                model: ScriptModel { values: appTopLevel?.toplevels ?? [] }

                delegate: RippleButton {
                    id: windowButton
                    required property var modelData
                    padding: 0

                    onClicked: {
                        modelData?.activate()
                        dockRoot.buttonHovered     = false
                        dockRoot.lastHoveredButton = null
                    }
                    middleClickAction: () => modelData?.close()

                    contentItem: ColumnLayout {
                        implicitWidth:  screencopyView.implicitWidth
                        implicitHeight: screencopyView.implicitHeight

                        ButtonGroup {
                            contentWidth: parent.width - anchors.margins * 2

                            WrapperRectangle {
                                Layout.fillWidth: true
                                color:   ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                radius:  Appearance.rounding.small
                                margin:  5

                                StyledText {
                                    Layout.fillWidth: true
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    text:  windowButton.modelData?.title ?? ""
                                    elide: Text.ElideRight
                                    color: Appearance.m3colors.m3onSurface
                                }
                            }

                            RippleButton {
                                id: closeButton
                                colBackground:  ColorUtils.transparentize(Appearance.colors.colSurfaceContainer)
                                implicitWidth:  dockRoot.windowControlsHeight
                                implicitHeight: dockRoot.windowControlsHeight
                                buttonRadius:   Appearance.rounding.full

                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text:     "close"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color:    Appearance.m3colors.m3onSurface
                                }
                                onClicked: windowButton.modelData?.close()
                            }
                        }

                        ScreencopyView {
                            id: screencopyView
                            captureSource:  windowButton.modelData
                            live:           true
                            paintCursor:    true
                            constraintSize: Qt.size(
                                dockRoot.maxWindowPreviewWidth,
                                dockRoot.maxWindowPreviewHeight
                            )

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width:  screencopyView.width
                                    height: screencopyView.height
                                    radius: Appearance.rounding.small
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}