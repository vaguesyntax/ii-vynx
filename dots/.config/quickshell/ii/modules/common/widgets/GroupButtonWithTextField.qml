import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

GroupButton {
    id: button

    signal textChanged(string text)
    signal accepted()

    property string buttonIcon: ""
    property string buttonText: ""
    property string textFieldText: ""

    baseHeight: 44
    baseWidth: content.implicitWidth + 280
    clickedWidth: baseWidth + 44

    readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : baseHeight / 2
    buttonRadius: fullRadius
    buttonRadiusPressed: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colBackgroundActive: Appearance.colors.colLayer2Active
    property color colText: toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1

    contentItem: Item {
        id: content
        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight
        
        RowLayout {
            id: contentRowLayout
            anchors.fill: parent
            spacing: 8

            MaterialSymbol {
                Layout.leftMargin: parent.spacing * 2
                text: button.buttonIcon
                iconSize: Appearance.font.pixelSize.huge
            }

            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.fillHeight: true

                placeholderText: button.buttonText
                placeholderTextColor: Appearance.colors.colSubtext
                color: Appearance.colors.colOnLayer1

                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.small
                    hintingPreference: Font.PreferFullHinting
                    variableAxes: Appearance.font.variableAxes.main
                }

                renderType: Text.NativeRendering
                selectedTextColor: Appearance.colors.colOnSecondaryContainer
                selectionColor: Appearance.colors.colSecondaryContainer
                background: null
                verticalAlignment: Text.AlignVCenter

                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0

                onTextChanged: {
                    button.textFieldText = searchField.text
                    button.textChanged(searchField.text)
                }
                onAccepted: {
                    button.accepted()
                }
            }
        }        
    }
}