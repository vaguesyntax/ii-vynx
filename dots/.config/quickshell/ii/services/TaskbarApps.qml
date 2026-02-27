pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

Singleton {
    id: root

    function isPinned(appId) {
        return Config.options.dock.pinnedApps.indexOf(appId) !== -1;
    }

    function togglePin(appId) {
        if (root.isPinned(appId)) {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.filter(id => id !== appId)
        } else {
            Config.options.dock.pinnedApps = Config.options.dock.pinnedApps.concat([appId])
        }
    }

    function reorderPinnedApp(fromAppId, toAppId) {
        if (fromAppId === toAppId) return
        const pinned = Array.from(Config.options.dock.pinnedApps)
        const fromIdx = pinned.indexOf(fromAppId)
        const toIdx = pinned.indexOf(toAppId)
        if (fromIdx === -1 || toIdx === -1) return
        pinned.splice(fromIdx, 1)
        pinned.splice(toIdx, 0, fromAppId)
        Config.options.dock.pinnedApps = pinned
    }

    property list<var> apps: {
        const pinnedMap = new Map();
        const unpinnedMap = new Map();
        
        const pinnedApps = Config.options?.dock.pinnedApps ?? [];
        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));

        for (const appId of pinnedApps) {
            pinnedMap.set(appId.toLowerCase(), { pinned: true, toplevels: [] });
        }
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            const id = toplevel.appId.toLowerCase();           
            if (pinnedMap.has(id)) {
                pinnedMap.get(id).toplevels.push(toplevel);
            } 
            else {
                if (!unpinnedMap.has(id)) {
                    unpinnedMap.set(id, { pinned: false, toplevels: [] });
                }
                unpinnedMap.get(id).toplevels.push(toplevel);
            }
        }

        var values = [];
        for (const [key, value] of pinnedMap) {
            values.push(appEntryComp.createObject(null, { appId: key, toplevels: value.toplevels, pinned: value.pinned }));
        }
        if (pinnedMap.size > 0 && unpinnedMap.size > 0) {
            values.push(appEntryComp.createObject(null, { appId: "SEPARATOR", toplevels: [], pinned: false }));
        }
        for (const [key, value] of unpinnedMap) {
            values.push(appEntryComp.createObject(null, { appId: key, toplevels: value.toplevels, pinned: value.pinned }));
        }

        return values;
    }

    component TaskbarAppEntry: QtObject {
        required property string appId
        required property list<var> toplevels
        required property bool pinned
    }

    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}