pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

Singleton {
    id: root

    property var loaded: ({})

    function ensure(extId, serviceId, qmlPath) {
        let key = extId + "." + serviceId
        if (root.loaded[key]) return root.loaded[key]

        let url = (qmlPath.startsWith("file://") ? qmlPath : "file://" + qmlPath) + "?_t=" + Date.now()
        let comp = Qt.createComponent(url)
        if (comp.status === Component.Error) {
            console.warn("ExtensionServices: failed to create component for", key, ":", comp.errorString())
            return null
        }
        if (comp.status === Component.Ready) {
            return root._instantiate(comp, key)
        }
        comp.statusChanged.connect(() => {
            if (comp.status === Component.Ready) {
                root._instantiate(comp, key)
            } else if (comp.status === Component.Error) {
                console.warn("ExtensionServices: async component error for", key, ":", comp.errorString())
            }
        })
        return null
    }

    function _instantiate(comp, key) {
        let extId = key.split(".")[0]
        let instance = comp.createObject(null)
        if (instance) {
            if ("extensionId" in instance) {
                instance.extensionId = extId
            } else {
                Object.defineProperty(instance, "extensionId", {
                    value: extId,
                    writable: true,
                    configurable: true,
                    enumerable: true
                })
            }
            let updated = Object.assign({}, root.loaded)
            updated[key] = instance
            root.loaded = updated
        }
        return instance
    }

    function unload(extId, serviceId) {
        let key = extId + "." + serviceId
        if (root.loaded[key]) {
            root.loaded[key].destroy()
        }
        let updated = Object.assign({}, root.loaded)
        delete updated[key]
        root.loaded = updated
    }

    function unloadExtension(extId) {
        let prefix = extId + "."
        let updated = Object.assign({}, root.loaded)
        for (let key in root.loaded) {
            if (key.startsWith(prefix)) {
                if (updated[key]) updated[key].destroy()
                delete updated[key]
            }
        }
        root.loaded = updated
    }

    function get(extId, serviceId) {
        return root.loaded[extId + "." + serviceId] || null
    }
}
