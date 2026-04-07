import QtQuick
import QtQuick.Layouts

import qs.services
import qs.modules.common
import qs.modules.common.widgets

SectionCard {
    id: hourlyForecastCard
    property int hourlyChartHeight: 145

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: hourlyForecastCard.hourlyChartHeight
        visible: !root.forecastLoading && root.filteredHourlyData.length > 0

        property var tempRange: root.getHourlyTempRange()
        property real tempSpan: Math.max(tempRange.max - tempRange.min, 1)

        RowLayout {
            anchors.fill: parent
            spacing: 6

            Repeater {
                model: root.filteredHourlyData

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    required property var modelData
                    required property int index

                    property int hourValue: Math.floor(parseInt(modelData.time) / 100)
                    property bool isCurrentHour: index === 0
                    property real temp: Weather.useUSCS ? parseInt(modelData.tempF) : parseInt(modelData.tempC)
                    property var parentTempRange: root.getHourlyTempRange()
                    property real parentTempSpan: Math.max(parentTempRange.max - parentTempRange.min, 1)
                    property real normalized: (temp - parentTempRange.min) / parentTempSpan
                    // Bar height: 45% min to 100% max for better visual contrast
                    property real availableBarSpace: parent.height - timeLabel.height + 10
                    property real barHeight: availableBarSpace * (0.45 + normalized * 0.55)

                    StyledText {
                        id: timeLabel
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.formatHour(modelData.time)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: isCurrentHour ? Font.Bold : Font.Normal
                        color: isCurrentHour ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    }

                    Rectangle {
                        anchors.bottom: timeLabel.top
                        anchors.bottomMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: barHeight
                        radius: Appearance.rounding.normal
                        color: isCurrentHour ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer

                        ColumnLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 8
                            spacing: 2

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: Icons.getWeatherIcon(modelData.code)
                                iconSize: Appearance.font.pixelSize.large
                                color: isCurrentHour ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: temp + "°"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: isCurrentHour ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
                            }
                        }

                        Rectangle {
                            visible: isCurrentHour
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            width: 20
                            height: 20
                            radius: 10
                            color: Appearance.colors.colPrimary

                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }
        }
    }

    LoadingPlaceholder {
        Layout.preferredHeight: hourlyForecastCard.hourlyChartHeight
        visible: root.forecastLoading || root.filteredHourlyData.length === 0
        loading: root.forecastLoading
        loadingText: Translation.tr("Loading forecast...")
        emptyText: Translation.tr("No forecast data")
    }
}