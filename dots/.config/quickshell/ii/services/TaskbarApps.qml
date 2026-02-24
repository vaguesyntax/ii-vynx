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

    // NUOVO: riordina le app pinnate tramite drag & drop
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
        var map = new Map();
        const pinnedApps = Config.options?.dock.pinnedApps ?? [];
        for (const appId of pinnedApps) {
            if (!map.has(appId.toLowerCase())) map.set(appId.toLowerCase(), ({
                pinned: true,
                toplevels: []
            }));
        }
        if (pinnedApps.length > 0) {
            map.set("SEPARATOR", { pinned: false, toplevels: [] });
        }
        const ignoredRegexStrings = Config.options?.dock.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));
        for (const toplevel of ToplevelManager.toplevels.values) {
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            if (!map.has(toplevel.appId.toLowerCase())) map.set(toplevel.appId.toLowerCase(), ({
                pinned: false,
                toplevels: []
            }));
            map.get(toplevel.appId.toLowerCase()).toplevels.push(toplevel);
        }
        var values = [];
        for (const [key, value] of map) {
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