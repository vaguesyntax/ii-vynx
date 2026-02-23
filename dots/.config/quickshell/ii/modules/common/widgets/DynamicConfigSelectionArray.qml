pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: layout.height
    clip: true

    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    property list<var> options: []
    property var currentValue: null
    property var register: false

    signal selected(var newValue)

    property int loadedCount: 0
    property int batchSize: 4
    property bool loading: root.loadedCount < root.options.length

    ListModel {
        id: selectionModel
    }

    function startLoading() {
        root.loadedCount = 0;
        selectionModel.clear();
        loadTimer.restart();
    }

    Component.onCompleted: root.startLoading()

    onOptionsChanged: root.startLoading()

    Timer {
        id: loadTimer
        interval: 16
        running: root.loading
        repeat: true
        onTriggered: {
            let end = Math.min(root.loadedCount + root.batchSize, root.options.length);
            for (let i = root.loadedCount; i < end; i++) {
                selectionModel.append(root.options[i]);
            }
            root.loadedCount = end;
        }
    }

    Flow {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2

        Repeater {
            model: selectionModel
            delegate: SelectionGroupButton {
                id: paletteButton
                required property var modelData
                required property int index

                onYChanged: {
                    if (paletteButton.index === 0) {
                        paletteButton.leftmost = true;
                    } else {
                        var prev = layout.children[paletteButton.index - 1];
                        var thisIsOnNewLine = prev && prev.y !== paletteButton.y;
                        paletteButton.leftmost = thisIsOnNewLine;
                        if (prev)
                            prev.rightmost = thisIsOnNewLine;
                    }
                }

                leftmost: paletteButton.index === 0
                rightmost: paletteButton.index === selectionModel.count - 1
                buttonIcon: paletteButton.modelData.icon || ""
                buttonShape: paletteButton.modelData.shape || ""
                buttonSymbol: paletteButton.modelData.symbol || ""
                buttonText: paletteButton.modelData.displayName
                toggled: root.currentValue == paletteButton.modelData.value
                releaseAction: paletteButton.modelData.releaseAction || ""

                colBackground: root.colBackground
                colBackgroundHover: root.colBackgroundHover
                colBackgroundActive: root.colBackgroundActive

                onClicked: {
                    root.selected(paletteButton.modelData.value);
                }

                opacity: 0
                scale: 0.95
                Component.onCompleted: {
                    paletteButton.opacity = 1;
                    paletteButton.scale = 1;
                }

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on scale {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }
        }
    }

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }

    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: Appearance.m3colors.m3surfaceContainerLow
        opacity: root.loading ? 1 : 0
        visible: loadingOverlay.opacity > 0
        z: 10

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
