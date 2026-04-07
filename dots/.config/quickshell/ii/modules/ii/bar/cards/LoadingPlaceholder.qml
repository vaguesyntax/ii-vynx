import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: loadingColumn.implicitHeight + 16
    color: "transparent"

    property bool loading: false
    property string loadingText: ""
    property string emptyText: ""

    Layout.preferredHeight: implicitHeight

    ColumnLayout {
        id: loadingColumn
        anchors.centerIn: parent
        spacing: 8

        MaterialLoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            loading: root.loading
            visible: root.loading
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.loading ? root.loadingText : root.emptyText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}
