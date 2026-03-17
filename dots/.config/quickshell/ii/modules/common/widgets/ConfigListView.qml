pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQml.Models

import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true
    
    // short version of -> height: listModel.length * 40 + (listModel.length - 1) * 4 + listModel.length * 4 + 20 (component height + space between them + component margin + listView padding)
    implicitHeight: listModel.length * 48 + componentSelector.height + 16 + 6

    color: "transparent"
    radius: Appearance.rounding.large

    property int barSection // 0: left, 1: center, 2: right
    property var listModel
    property int selectedCompIndex

    property bool dragging: false

    // Compute available components from registry based on what's already used
    readonly property var usedIds: {
        let ids = []
        let allLists = [
            Config.options.bar.layouts.left,
            Config.options.bar.layouts.center,
            Config.options.bar.layouts.right
        ]
        for (let list of allLists) {
            for (let item of list) {
                ids.push(item.id)
            }
        }
        return ids
    }
    readonly property var availableComps: BarComponentRegistry.getAvailableComponents(usedIds)

    signal updated(var newList)

    Component.onCompleted: {
        initilizateLayout(listModel)
    }


    /*
     * We have to initilize the layout because we don't define the default values in Config.qml file
    */
    function initilizateLayout(list) {
        let initilizatedLayout = list.map(comp => initilizateComponent(comp))
        root.updated(initilizatedLayout)
    }

    function initilizateComponent(comp) {
        return {
            id: comp.id,
            centered: comp.centered !== undefined ? comp.centered : false,
            visible: comp.visible !== undefined ? comp.visible : true
        }
    }

    function toggleCenter(idx, currentList) {
        if (currentList[idx].centered) {
            currentList[idx].centered = false
            root.updated(currentList)
            return
        }
        for (let i = 0; i < currentList.length; i++) {
            currentList[i].centered = (i === idx);
        }

        root.updated(currentList)
    }

    DelegateModel {
        id: visualModel

        model: {
            values: root.listModel
        }
        delegate: ConfigListViewEntry {
            barSection: root.barSection
        }
    }

    StyledListView {
        id: view

        interactive: false
        anchors {
            fill: parent
            margins: 10
        }

        add: null

        model: visualModel

        spacing: 4
        cacheBuffer: 50
        
    }
    
    RowLayout {
        id: componentSelectRow
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }

        spacing: 4

        StyledComboBox {
            id: componentSelector
            
            topRightRadius: Appearance.rounding.verysmall
            bottomRightRadius: Appearance.rounding.verysmall

            buttonIcon: "box"
            textRole: "title"
            model: root.availableComps
            enabled: root.availableComps.length >= 1

            onActivated: index => {
                root.selectedCompIndex = index;
            }
        }

        RippleButton {
            id: addComponentButton
            implicitHeight: componentSelector.implicitHeight

            topLeftRadius: Appearance.rounding.verysmall
            bottomLeftRadius: Appearance.rounding.verysmall
            topRightRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full

            buttonText: Translation.tr("Add component")
            enabled: root.availableComps.length >= 1

            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            rippleColor: Appearance.colors.colSecondaryContainerActive
            
            onClicked: {
                let available = root.availableComps
                if (available[root.selectedCompIndex] == null) return

                let newComp = initilizateComponent(available[root.selectedCompIndex]);
                listModel.push(newComp);

                root.updated(listModel);
            }
        }
    }
    
    
} 