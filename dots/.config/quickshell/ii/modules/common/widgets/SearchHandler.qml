import qs.services
import QtQuick

Item {
    id: searchHandler
    readonly property string currentSearch: SearchRegistry.currentSearch
    property string searchString

    onCurrentSearchChanged: {
        if (SearchRegistry.currentSearch.toLowerCase() === searchHandler.searchString.toLowerCase()) {
            Qt.callLater (() => {
                let p = page.contentItem.mapFromItem(root, 0, 0)
                page.contentY = p.y - 100

                highlightOverlay.startAnimation()
            })
            SearchRegistry.currentSearch = ""
        }
    } 
}