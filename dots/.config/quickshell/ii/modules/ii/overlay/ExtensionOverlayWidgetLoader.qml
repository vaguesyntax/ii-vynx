pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Item {
    id: root
    required property var modelData

    property bool _active: true
    property var _widget: null
    property var _configEntry: null

    Component.onCompleted: loadWidget()
    Component.onDestruction: cleanupWidget()

    function loadWidget() {
        let entry = root.modelData
        let extId = entry.extensionId
        let wid = entry.identifier
        let url = "file://" + entry.fullPath

        let saved = ExtensionManager.getExtensionOverlayConfig(extId, wid)
        let savedX = saved?.x ?? entry.x ?? 100
        let savedY = saved?.y ?? entry.y ?? 100
        let savedW = saved?.width ?? entry.width ?? 300
        let savedH = saved?.height ?? entry.height ?? 200
        let savedPinned = saved?.pinned ?? entry.pinned ?? false
        let savedClickthrough = saved?.clickthrough ?? entry.clickthrough ?? true

        let cfgQml = 'import QtQml; QtObject { property bool pinned: ' + savedPinned + '; property bool clickthrough: ' + savedClickthrough + '; property real x: ' + savedX + '; property real y: ' + savedY + '; property real width: ' + savedW + '; property real height: ' + savedH + ' }'
        let cfg = Qt.createQmlObject(cfgQml, root)
        root._configEntry = cfg

        let comp = Qt.createComponent(url)

        let createWidget = (comp) => {
            if (!root._active) return
            let widget = comp.createObject(root.parent, {
                configEntry: cfg,
                modelData: entry
            })

            if (widget && extId) {
                if ("extensionId" in widget) {
                    widget.extensionId = extId
                } else {
                    Object.defineProperty(widget, "extensionId", {
                        value: extId,
                        writable: true,
                        configurable: true,
                        enumerable: true
                    })
                }

                root._widget = widget

                let saveCfg = () => {
                    ExtensionManager.saveExtensionOverlayConfig(extId, wid, {
                        x: cfg.x, y: cfg.y,
                        width: cfg.width, height: cfg.height,
                        pinned: cfg.pinned, clickthrough: cfg.clickthrough
                    })
                }
                cfg.xChanged.connect(saveCfg)
                cfg.yChanged.connect(saveCfg)
                cfg.widthChanged.connect(saveCfg)
                cfg.heightChanged.connect(saveCfg)
                cfg.pinnedChanged.connect(saveCfg)
                cfg.clickthroughChanged.connect(saveCfg)
            }
        }

        if (comp.status === Component.Ready) {
            createWidget(comp)
        } else if (comp.status === Component.Error) {
            console.log("Extension overlay widget error:", comp.errorString())
        } else {
            comp.statusChanged.connect(() => {
                if (!root._active) return
                if (comp.status === Component.Ready) {
                    createWidget(comp)
                } else if (comp.status === Component.Error) {
                    console.log("Extension overlay widget error:", comp.errorString())
                }
            })
        }
    }

    function cleanupWidget() {
        root._active = false
        if (root._widget) {
            root._widget.destroy()
            root._widget = null
        }
        if (root._configEntry) {
            root._configEntry.destroy()
            root._configEntry = null
        }
    }
}
