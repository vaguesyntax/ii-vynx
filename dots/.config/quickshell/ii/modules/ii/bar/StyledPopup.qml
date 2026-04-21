import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property int popupRadius: Appearance.rounding.large
    property bool animate: true

    active: hoverTarget && hoverTarget.containsMouse

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        readonly property real screenWidth: popupWindow.screen?.width ?? 0
        readonly property real screenHeight: popupWindow.screen?.height ?? 0

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.targetWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.targetHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.hoverTarget || !root.QsWindow)
                        return 0;
                    var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                    var centeredX = targetPos.x + (root.hoverTarget.width - popupWindow.implicitWidth) / 2;
                    var minX = 0;
                    var maxX = screenWidth - popupWindow.implicitWidth;
                    return Math.max(minX, Math.min(maxX, centeredX));
                }
                return Appearance.sizes.verticalBarWidth;
            }

            top: {
                if (!Config.options.bar.vertical) {
                    return Appearance.sizes.barHeight;
                }
                if (!root.hoverTarget || !root.QsWindow)
                    return 0;
                var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                var centeredY = targetPos.y + (root.hoverTarget.height - popupWindow.implicitHeight) / 2;
                var minY = 0;
                var maxY = screenHeight - popupWindow.implicitHeight;
                return Math.max(minY, Math.min(maxY, centeredY));
            }

            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        property real animProgress: 0.0
        readonly property Item heroItem: {
            if (!root.contentItem) return null;
            for (let i = 0; i < root.contentItem.children.length; i++) {
                let child = root.contentItem.children[i];
                if (child.visible && child.width > 0) return child;
            }
            return null;
        }
        readonly property real heroHeight: heroItem ? heroItem.implicitHeight : 0
        readonly property real totalContentHeight: root.contentItem ? root.contentItem.implicitHeight : 0

        NumberAnimation on animProgress {
            id: openAnim
            from: 0
            to: 1
            running: true
            duration: Appearance.animation.elementMove.duration 
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            
            readonly property real targetWidth: (root.contentItem?.implicitWidth ?? 0) + margin * 2
            readonly property real targetHeight: (root.contentItem?.implicitHeight ?? 0) + margin * 2

            property bool isVertical: Config.options.bar.vertical
            property bool isBottom: Config.options.bar.bottom
            property int elevation: Appearance.sizes.elevationMargin
            
            anchors {
                top: (!isVertical && !isBottom) ? parent.top : undefined
                bottom: (!isVertical && isBottom) ? parent.bottom : undefined
                left: (isVertical && !isBottom) ? parent.left : undefined
                right: (isVertical && isBottom) ? parent.right : undefined

                topMargin: top ? elevation : undefined
                bottomMargin: bottom ? elevation : undefined
                leftMargin: left ? elevation : undefined
                rightMargin: right ? elevation : undefined

                verticalCenter: isVertical ? parent.verticalCenter : undefined
                horizontalCenter: !isVertical ? parent.horizontalCenter : undefined
            }
            
            width: targetWidth
            height: {
                if (!root.animate || !root.contentItem || !heroItem || targetHeight <= heroHeight + margin * 2) return targetHeight;
                return (heroHeight + margin * 2) + (targetHeight - (heroHeight + margin * 2)) * popupWindow.animProgress;
            }

            color: Appearance.m3colors.m3surfaceContainer
            radius: root.popupRadius
            
            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: popupBackground.margin
                clip: true

                Component.onCompleted: {
                    if (root.contentItem) {
                        root.contentItem.parent = contentContainer;
                        root.contentItem.anchors.centerIn = undefined;
                        root.contentItem.anchors.top = contentContainer.top;
                        root.contentItem.anchors.left = contentContainer.left;
                        root.contentItem.anchors.right = contentContainer.right;

                        for (let i = 0; i < root.contentItem.children.length; i++) {
                            let child = root.contentItem.children[i];

                            child.opacity = Qt.binding(() => {
                                if (!root.animate) return 1.0;
                                let normalizedDelay = child.y / popupBackground.targetHeight;
                                let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                                return Math.max(0, Math.min(1.0, progress));
                            });

                            child.scale = Qt.binding(() => {
                                if (!root.animate) return 1.0;
                                let normalizedDelay = child.y / popupBackground.targetHeight;
                                let progress = (popupWindow.animProgress - normalizedDelay) / (1.0 - normalizedDelay);
                                return 0.85 + (0.15 * Math.max(0, Math.min(1.0, progress)));
                            });
                        }
                    }
                }
            }

            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }
}
