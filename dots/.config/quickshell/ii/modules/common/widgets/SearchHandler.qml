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
                let targetY = p.y - 100
                
                let maxContentY = Math.max(0, page.contentHeight - page.height)
                
                page.contentY = Math.max(0, Math.min(targetY, maxContentY))

                highlightOverlay.startAnimation()
            })
            SearchRegistry.currentSearch = ""
        }
    } 
}