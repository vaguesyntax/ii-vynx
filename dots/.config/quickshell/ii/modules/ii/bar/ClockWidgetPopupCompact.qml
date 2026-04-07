import qs.services
import qs.modules.common.widgets
import "./cards"

StyledPopup {
    contentItem: HeroCard {
        id: clockHero
        anchors.centerIn: parent
        margins: 20
        iconSize: 100
        icon: "schedule"
        title: DateTime.time
        subtitle: Qt.locale().toString(DateTime.clock.date, "MMMM dd, dddd")
    }
}