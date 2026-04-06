import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../cards"

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.ii.bar

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    // Adaptive layout properties based on screen height
    property real availableHeight: Screen.height
    property bool semiCompactMode: availableHeight < 1000
    property bool compactMode: availableHeight < 900
    property bool veryCompactMode: availableHeight < 750

    // Adaptive spacing and margins
    property int mainSpacing: veryCompactMode ? 8 : (compactMode ? 10 : (semiCompactMode ? 12 : 16))
    property int heroMargins: veryCompactMode ? 12 : (compactMode ? 16 : (semiCompactMode ? 20 : 24))
    property int heroIconSize: veryCompactMode ? 80 : (compactMode ? 90 : (semiCompactMode ? 100 : 110))
    property int hourlyChartHeight: veryCompactMode ? 120 : (compactMode ? 130 : (semiCompactMode ? 145 : 160))
    property int hourlyBarMin: veryCompactMode ? 35 : (compactMode ? 40 : (semiCompactMode ? 45 : 50))
    property int hourlyBarMax: veryCompactMode ? 85 : (compactMode ? 100 : (semiCompactMode ? 120 : 140))
    property int forecastCardHeight: veryCompactMode ? 100 : (compactMode ? 120 : (semiCompactMode ? 125 : 140))
    property int forecastIconSize: veryCompactMode ? 40 : (compactMode ? 44 : (semiCompactMode ? 48 : 52))
    property int cardMargins: veryCompactMode ? 10 : (compactMode ? 12 : (semiCompactMode ? 14 : 16))

    // Forecast data model
    property var forecastData: []
    property var hourlyData: []
    property bool forecastLoading: true
    property int maxHourlyBars: 5

    property var filteredHourlyData: {
        const now = new Date();
        const currentHr = now.getHours();
        // Round down to nearest 3-hour slot (API intervals: 0, 3, 6, 9, 12, 15, 18, 21)
        const currentSlot = Math.floor(currentHr / 3) * 3;
        let futureHours = [];
        let passedMidnight = false;

        for (let i = 0; i < hourlyData.length; i++) {
            const item = hourlyData[i];
            const itemHour = Math.floor(parseInt(item.time) / 100);

            if (i > 0 && itemHour < Math.floor(parseInt(hourlyData[i - 1].time) / 100)) {
                passedMidnight = true;
            }

            if (passedMidnight || itemHour >= currentSlot) {
                futureHours.push(item);
            }
        }
        return futureHours.slice(0, maxHourlyBars);
    }

    function fetchForecast() {
        forecastLoading = true;
        let city = Config.options.bar.weather.city || "auto";
        city = city.trim().split(/\s+/).join('+');
        forecastFetcher.command[2] = `curl -s "wttr.in/${city}?format=j1" | jq '{daily: [.weather[] | {date: .date, maxC: .maxtempC, minC: .mintempC, maxF: .maxtempF, minF: .mintempF, code: .hourly[4].weatherCode}], hourly: [.weather[0].hourly[], .weather[1].hourly[] | {time: .time, tempC: .tempC, tempF: .tempF, code: .weatherCode}]}'`;
        forecastFetcher.running = true;
    }

    function getDayName(dateStr, index) {
        if (index === 0)
            return Translation.tr("Today");
        if (index === 1)
            return Translation.tr("Tomorrow");
        const date = new Date(dateStr);
        const days = [Translation.tr("Sun"), Translation.tr("Mon"), Translation.tr("Tue"), Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat")];
        return days[date.getDay()];
    }

    function formatHour(timeStr) {
        const hour = Math.floor(parseInt(timeStr) / 100);
        return hour.toString().padStart(2, '0') + ":00";
    }

    function getHourlyTempRange() {
        const data = filteredHourlyData.length > 0 ? filteredHourlyData : hourlyData;
        if (data.length === 0)
            return {
                min: 0,
                max: 100
            };
        const temps = data.map(h => Weather.useUSCS ? parseInt(h.tempF) : parseInt(h.tempC));
        const min = Math.min(...temps);
        const max = Math.max(...temps);
        // Add 20% padding (minimum 2°) to make small differences more visible
        // e.g., temps 20-21 become range 18-23, making 1° difference span ~20% of bar height
        const padding = Math.max(2, (max - min) * 0.2);
        return {
            min: min - padding,
            max: max + padding
        };
    }

    Component.onCompleted: fetchForecast()

    ColumnLayout {
        anchors.centerIn: parent
        spacing: root.mainSpacing

        Process {
            id: forecastFetcher
            command: ["bash", "-c", ""]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.length === 0) {
                        root.forecastLoading = false;
                        return;
                    }
                    try {
                        const data = JSON.parse(text);
                        root.forecastData = data.daily || [];
                        root.hourlyData = data.hourly || [];
                    } catch (e) {
                        console.error(`[WeatherPopup] Forecast parse error: ${e.message}`);
                    }
                    root.forecastLoading = false;
                }
            }
        }

        HeroCard {
            id: weatherHero
            Layout.minimumWidth: 320
            margins: root.heroMargins
            iconSize: root.heroIconSize
            icon: Icons.getWeatherIcon(Weather.data.wCode)
            pillText: Weather.data.city || "--"
            pillIcon: Weather.data.city ? "location_on" : ""
            
            title: Weather.data.temp
            subtitle: Weather.data.wDesc
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: Appearance.colors.colSurfaceContainerHighest
            radius: 1
        }

        SectionCard {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 6
            shapeString: "Clover4Leaf"
            shapeColor: Appearance.colors.colSecondaryContainer
            showDivider: false
            title: Translation.tr("Hourly")

            shapeContent: MaterialSymbol {
                anchors.centerIn: parent
                text: "schedule"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSecondaryContainer
            }

            headerExtra: StyledText {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh || "--").slice(0, 20)
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hourlyChartHeight
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.hourlyChartHeight
                visible: root.forecastLoading || root.filteredHourlyData.length === 0
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        loading: root.forecastLoading
                        visible: root.forecastLoading
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.forecastLoading ? Translation.tr("Loading forecast...") : Translation.tr("No forecast data")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }

        // Metrics grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: root.semiCompactMode ? 8 : 12
            columnSpacing: root.semiCompactMode ? 8 : 12
            uniformCellWidths: true

            MetricCard {
                title: Translation.tr("UV Index")
                symbol: "wb_sunny"
                value: Weather.data.uv
                accentColor: Appearance.colors.colTertiaryContainer
                onAccentColor: Appearance.colors.colOnTertiaryContainer
                compact: root.semiCompactMode
            }
            MetricCard {
                title: Translation.tr("Wind")
                symbol: "air"
                value: `(${Weather.data.windDir}) ${Weather.data.wind}`
                accentColor: Appearance.colors.colSecondaryContainer
                onAccentColor: Appearance.colors.colOnSecondaryContainer
                compact: root.semiCompactMode
            }
            MetricCard {
                title: Translation.tr("Precipitation")
                symbol: "rainy_light"
                value: Weather.data.precip
                accentColor: Appearance.colors.colPrimaryContainer
                onAccentColor: Appearance.colors.colOnPrimaryContainer
                compact: root.semiCompactMode
            }
            MetricCard {
                title: Translation.tr("Humidity")
                symbol: "humidity_low"
                value: Weather.data.humidity
                accentColor: Appearance.colors.colTertiaryContainer
                onAccentColor: Appearance.colors.colOnTertiaryContainer
                compact: root.semiCompactMode
            }
        }

        SectionCard {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: root.semiCompactMode ? 8 : 12
            shapeString: "Cookie6Sided"
            shapeColor: Appearance.colors.colSecondaryContainer
            showDivider: false
            title: Translation.tr("Forecast")

            shapeContent: MaterialSymbol {
                anchors.centerIn: parent
                text: "calendar_month"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSecondaryContainer
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: !root.forecastLoading && root.forecastData.length > 0

                Repeater {
                    model: root.forecastData

                    Rectangle {
                        id: dayCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.forecastCardHeight
                        radius: Appearance.rounding.normal

                        // tried a gradient-like effect, but dont know if i should switch secondary and tertiary colors
                        color: {
                            const colors = [Appearance.colors.colPrimaryContainer, Appearance.colors.colSecondaryContainer, Appearance.colors.colTertiaryContainer];
                            return colors[index % 3];
                        }

                        property color textColor: {
                            const colors = [Appearance.colors.colOnPrimaryContainer, Appearance.colors.colOnSecondaryContainer, Appearance.colors.colOnTertiaryContainer];
                            return colors[index % 3];
                        }

                        ColumnLayout {
                            id: dayColumn
                            anchors.fill: parent
                            anchors.margins: root.semiCompactMode ? 8 : 12
                            spacing: root.semiCompactMode ? 4 : 8

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.getDayName(modelData.date, index)
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Bold
                                color: dayCard.textColor
                            }

                            // Weather shape
                            MaterialShape {
                                Layout.alignment: Qt.AlignHCenter
                                shapeString: index === 0 ? "Cookie9Sided" : (index === 1 ? "Flower" : "Clover4Leaf")
                                implicitSize: root.forecastIconSize
                                color: Qt.rgba(dayCard.textColor.r, dayCard.textColor.g, dayCard.textColor.b, 0.15)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: Icons.getWeatherIcon(modelData.code)
                                    iconSize: root.semiCompactMode ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.large * 1.2
                                    color: dayCard.textColor
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 0

                                // Max temp
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Weather.useUSCS ? modelData.maxF + "°" : modelData.maxC + "°"
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: dayCard.textColor
                                }

                                // Min temp
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Weather.useUSCS ? modelData.minF + "°" : modelData.minC + "°"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.DemiBold
                                    color: Qt.rgba(dayCard.textColor.r, dayCard.textColor.g, dayCard.textColor.b, 0.7)
                                }
                            }
                        }
                    }
                }
            }

            // Loading placeholder
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.forecastCardHeight
                visible: root.forecastLoading || root.forecastData.length === 0
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        loading: root.forecastLoading
                        visible: root.forecastLoading
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.forecastLoading ? Translation.tr("Loading forecast...") : Translation.tr("No forecast data")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }
}
