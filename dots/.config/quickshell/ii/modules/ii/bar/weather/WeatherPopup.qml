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

    property bool compactMode: Config.options.bar.tooltips.compactPopups
    property int cardMargins: 14

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
        const padding = Math.max(2, (max - min) * 0.2);
        return {
            min: min - padding,
            max: max + padding
        };
    }

    Component.onCompleted: fetchForecast()

    contentItem: ColumnLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 12

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
            margins: 20
            iconSize: 100
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

        HourlyForecast {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 6
            shapeString: "Clover4Leaf"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer
            showDivider: false
            title: Translation.tr("Hourly")
            icon: "schedule"
            headerExtraText: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh || "--").slice(0, 20)
        }

        MetricsGrid {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            uniformCellWidths: true
        }

        InDayForecast {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 8
            shapeString: "Cookie6Sided"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer
            showDivider: false
            title: Translation.tr("Forecast")
            icon: "calendar_month"
        }
    }
}
