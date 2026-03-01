import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property string imageSource

    property int animationDuration: 1000

    onImageSourceChanged: {
        fadeTo(root.imageSource)
    }
    Component.onCompleted: {
        imgOld.source = imageSource
    }

    Timer {
        id: revertBackTimer
        interval: root.animationDuration * 1.5
        running: true
        repeat: false
        onTriggered: {
            imgNew.animEnabled = false
            imgOld.animEnabled = false
            
            Qt.callLater(() => {
                imgOld.source = imgNew.source
                imgOld.opacity = 1
                imgNewFixTimer.restart()
            })
        }
    }

    Timer {
        id: imgNewFixTimer
        interval: 50
        onTriggered: {
            imgNew.opacity = 0
            imgNew.source = ""
        }
    }

    function fadeTo(newSrc) {
        imgNew.source = newSrc
        imgNew.opacity = 0
        
        imgNew.animEnabled = true
        imgOld.animEnabled = true

        imgNew.opacity = 1    // animasyonu başlatır
        imgOld.opacity = 0    // animasyonu başlatır

        Qt.callLater(() => {
            revertBackTimer.restart()
        })
    }

    Image {
        id: imgOld
        anchors.fill: parent
        opacity: 1.0
        fillMode: Image.PreserveAspectCrop
        cache: false; antialiasing: true; asynchronous: true
        
        property bool animEnabled: true

        Behavior on opacity {
            enabled: imgNew.animEnabled
            NumberAnimation { duration: root.animationDuration }
        }
    }

    Image {
        id: imgNew
        anchors.fill: parent
        opacity: 0.0
        fillMode: Image.PreserveAspectCrop
        cache: false; antialiasing: true; asynchronous: true

        property bool animEnabled: true

        Behavior on opacity {
            enabled: imgNew.animEnabled
            NumberAnimation { duration: root.animationDuration }
        }
    }
}