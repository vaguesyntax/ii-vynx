import QtQuick
import QtQuick.Layouts

import qs.services
import qs.modules.common
import qs.modules.common.widgets

GridLayout {

    MetricCard {
        title: Translation.tr("UV Index")
        symbol: "wb_sunny"
        value: Weather.data.uv
        accentColor: Appearance.colors.colTertiaryContainer
        symbolColor: Appearance.colors.colOnTertiaryContainer
        compact: root.compactMode
    }
    MetricCard {
        title: Translation.tr("Wind")
        symbol: "air"
        value: `(${Weather.data.windDir}) ${Weather.data.wind}`
        accentColor: Appearance.colors.colSecondaryContainer
        symbolColor: Appearance.colors.colOnSecondaryContainer
        compact: root.compactMode
    }
    MetricCard {
        title: Translation.tr("Precipitation")
        symbol: "rainy_light"
        value: Weather.data.precip
        accentColor: Appearance.colors.colPrimaryContainer
        symbolColor: Appearance.colors.colOnPrimaryContainer
        compact: root.compactMode
    }
    MetricCard {
        title: Translation.tr("Humidity")
        symbol: "humidity_low"
        value: Weather.data.humidity
        accentColor: Appearance.colors.colTertiaryContainer
        symbolColor: Appearance.colors.colOnTertiaryContainer
        compact: root.compactMode
    }
}