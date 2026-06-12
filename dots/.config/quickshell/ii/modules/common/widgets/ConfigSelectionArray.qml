import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flow {
    id: root
    Layout.fillWidth: true

    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    spacing: 2
    property list<var> options: [
        {
            "displayName": "Option 1",
            "icon": "check",
            "shape": "Arch",
            "symbol": "google-gemini-symbolic",
            "color": "red",
            "value": 1
        },
        {
            "displayName": "Option 2",
            "icon": "close",
            "shape": "Circle",
            "symbol": "mistral-symbolic",
            "color": "blue",
            "value": 2
        },
    ]
    property var currentValue: null

    signal selected(var newValue)

    Repeater {
        model: root.options
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index
            onYChanged: {
                if (index === 0) {
                    paletteButton.leftmost = true
                } else {
                    var prev = root.children[index - 1]
                    var thisIsOnNewLine = prev && prev.y !== paletteButton.y
                    paletteButton.leftmost = thisIsOnNewLine
                    prev.rightmost = thisIsOnNewLine
                }
            }
            leftmost: index === 0
            rightmost: index === root.options.length - 1
            buttonIcon: modelData.icon || ""
            buttonShape: modelData.shape || ""
            buttonSymbol: modelData.symbol || ""
            buttonColor: modelData.color || ""
            buttonText: modelData.displayName ?? modelData
            enabled: modelData.enabled !== undefined ? modelData.enabled : true
            opacity: enabled ? 1.0 : 0.5
            toggled: root.currentValue == (modelData.value ?? modelData)
            releaseAction: modelData.releaseAction || ""

            colBackground: root.colBackground
            colBackgroundHover: root.colBackgroundHover
            colBackgroundActive: root.colBackgroundActive

            onClicked: {
                root.selected(modelData.value ?? modelData);
            }
        }
    }
}
