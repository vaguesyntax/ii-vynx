import QtQuick
import QtQuick.Layouts

import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: wrapper
    
    required property var modelData
    readonly property var compInfo: BarComponentRegistry.getComponent(modelData.id)

    property bool alternateColor: visualIndex % 2 == 0
    property color colBackground: alternateColor ? Appearance.colors.colLayer3 : Appearance.colors.colLayer2
    property color colHover: alternateColor ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer2Hover
    property color colActive: alternateColor ? Appearance.colors.colLayer3Active : Appearance.colors.colLayer2Active

    property color colTitle: Appearance.colors.colOnLayer0

    property int barSection

    anchors {
        right: parent?.right
        left: parent?.left
    }
    height: content.height
    property int visualIndex: DelegateModel.itemsIndex


    Behavior on y {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    function getOrderedList() {
        var ordered = []

        for (var i = 0; i < visualModel.items.count; i++) {
            var item = visualModel.items.get(i).model
            ordered.push(item.modelData)
        }

        return ordered
    }

    property real bottomRadius: {
        if (listModel.length == 1 || visualIndex == listModel.length - 1) return Appearance.rounding.full
        return Appearance.rounding.verysmall
    }

    property real topRadius: {
        if (listModel.length == 1 || visualIndex == 0) return Appearance.rounding.full
        return Appearance.rounding.verysmall
    }

    Rectangle {
        id: content

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        scale: dragArea.held ? 1.02 : 1
        opacity: dragArea.held ? 0.8 : 1

        Behavior on scale {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        
        topLeftRadius: topRadius
        topRightRadius: topRadius
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius
        
        height: contentRow.implicitHeight + 4

        color: dragArea.held ? colActive : colBackground
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Drag.active: dragArea.held
        Drag.source: dragArea
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        states: State {
            when: dragArea.held

            ParentChange {
                target: content
                parent: root
            }
            AnchorChanges {
                target: content
                anchors {
                    left: undefined
                    right: undefined
                    verticalCenter: undefined
                }
            }
        }

        RowLayout {
            id: contentRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                margins: 20
            }
            spacing: 10

            MaterialSymbol {
                id: dragIndicatorIcon
                text: "drag_indicator"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOutline
            }
            
            MaterialSymbol {
                id: icon
                Layout.leftMargin: 10
                text: wrapper.compInfo?.icon ?? ""
                iconSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colPrimary
                fill: 1
            }

            StyledText {
                id: title
                text: wrapper.compInfo?.title ?? modelData.id
                color: wrapper.colTitle

                Layout.leftMargin: 10
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.normal
                }
            }
            
            Item {
                height: 40
                Layout.fillWidth: true
            }

            Loader {
                active: modelData.id in page.componentMap
                sourceComponent: EntryButton {
                    iconText: "settings"
                    tooltip: Translation.tr("Settings")

                    onClicked: {
                        page.scrollTo(modelData.id)
                    }
                }
            }
            
            
            Loader {
                active: barSection == 1 // only showing it on center layout
                sourceComponent: EntryButton {
                    iconText: "adjust"
                    iconFill: modelData.centered
                    tooltip: Translation.tr("Center")

                    onClicked: {
                        root.toggleCenter(wrapper.visualIndex, wrapper.getOrderedList())
                    }
                }
            }
            

            EntryButton {
                id: removeButton
                iconText: "close"
                tooltip: Translation.tr("Remove")

                onClicked: {
                    let arr = wrapper.getOrderedList()
                    arr.splice(visualIndex, 1)
                    root.updated(arr)
                }
            }
        }

        
    }
    
    DropArea {
        id: dropArea
        anchors {
            fill: parent
            margins: 20
        }

        onEntered: (drag) => {
            let fromIndex = drag.source.parent.visualIndex
            let toIndex = wrapper.visualIndex
            
            visualModel.items.move(fromIndex, toIndex)
        }
    }

    MouseArea {
        id: dragArea

        property bool held: false
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: -6
        }
        width: 50

        pressAndHoldInterval: 200

        drag.target: held ? content : undefined
        drag.axis: Drag.YAxis
        drag.minimumY: 0
        drag.maximumY: root.listModel.length * 40 + (root.listModel.length - 1) * 4

        onPressAndHold: {
            root.dragging = true
            held = true
        }
        onReleased: {
            root.updated(wrapper.getOrderedList())
            held = false
            root.dragging = false
        }
    }

    component EntryButton: RippleButton {
        id: button
        implicitWidth: implicitHeight

        property string iconText: ""
        property bool iconFill: false
        property string tooltip: ""

        MaterialSymbol {
            text: button.iconText
            anchors.centerIn: parent
            color: Appearance.colors.colPrimary
            iconSize: Appearance.font.pixelSize.huge
            fill: button.iconFill ? 1 : 0
        }

        StyledToolTip {
            text: button.tooltip
        }
    }
}
    