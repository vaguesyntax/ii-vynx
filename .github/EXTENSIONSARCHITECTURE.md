# ii-vynx Extension System — Internal Architecture

This document describes how the extension system works under the hood. It is intended for developers contributing to the shell itself, not extension authors. For the extension developer API, see [EXTENSIONS.md](./EXTENSIONS.md).

---

## Service Architecture

The extension system is split across four singleton services in `services/`, all available through `import qs.services`:

| Service | Role |
|---|---|
| `ExtensionManager` | Core: install/uninstall/toggle, config storage, persistence layer, contribution point collection, update management, QML component loading |
| `ExtensionSearch` | GitHub discovery: search repos by topic, fetch `extension.json` metadata per repo, search cache |
| `ExtensionAudit` | Security: fetch extension-database.json, evaluate blocked/trusted/recommended states |
| `ExtensionServices` | QML runtime: create and destroy extension service components, inject `extensionId` |

### Dependency Flow

```
ExtensionAudit (security data)
       ↓
ExtensionSearch (filters results by blockedIds)
       ↓
ExtensionManager (orchestrates everything)
       ↓
ExtensionServices (loads service QML at runtime)
```

---

## State Management

### Owned by ExtensionManager

| Property | Type | Description |
|---|---|---|
| `installedExtensions` | `{extId: entry}` | All installed extensions with full metadata |
| `extensionConfigs` | `{extId: {key: val}}` | Per-extension key-value config |
| `extensionWidgetConfigs` | `{extId: {widgetId: {enable, x, y}}}` | Background widget positions and enable state |
| `extensionOverlayConfigs` | `{extId: {widgetId: {x, y, w, h, pinned, clickthrough}}}` | Overlay widget geometry and behavior |
| `updateStates` | `{extId: {checking, localHash, remoteHash, updateAvailable, error}}` | Per-extension update check results |
| `loading` | bool | Combined loading state (search + install + update) |
| `error` | string | Last error message |
| `ready` | bool | True after plugins.json has been loaded at least once |

### Owned by ExtensionSearch

| Property | Type | Description |
|---|---|---|
| `availableExtensions` | `[repo]` | GitHub search results, filtered by `ExtensionAudit.blockedIds` |
| `extensionJsonLoading` | bool | Whether an extension.json fetch is in progress |
| `loading` | bool | Whether a GitHub search is in progress (synced to `ExtensionManager.loading`) |

### Owned by ExtensionAudit

| Property | Type | Description |
|---|---|---|
| `auditDatabaseReady` | bool | True after extension-database.json has been fetched and parsed |
| `blockedIds` | `{extId: reason}` | Blocked extensions with optional reason string |
| `trustedMap` | `{extId: {trustedCommit}}` | Trusted extensions and their audited commits |
| `recommendedIds` | `{extId: true}` | Extensions recommended by the maintainer |
| `auditDbVersion` | int | Incremented on each audit database fetch (used as binding trigger in UI) |

---

## File Persistence

### Single File, Multiple Adapters

All extension state lives in `~/.config/illogical-impulse/extensions/plugins.json`.

The file is managed by a `FileView` + `JsonAdapter` inside `ExtensionManager`:

```
extensionsFileView (FileView)
  path: Directories.pluginsJsonPath
  adapter: extensionsAdapter (JsonAdapter)
    extensions          ←→  ExtensionManager.installedExtensions
    extensionConfigs    ←→  ExtensionManager.extensionConfigs
    extensionWidgetConfigs ←→  ExtensionManager.extensionWidgetConfigs
    extensionOverlayConfigs ←→ ExtensionManager.extensionOverlayConfigs
    searchCache         ←→  ExtensionSearch (via loadFromCache / saveSearchCache)
```

### File Structure

```json
{
  "extensions": { ... },
  "extensionConfigs": { ... },
  "extensionWidgetConfigs": { ... },
  "extensionOverlayConfigs": { ... },
  "searchCache": {
    "cachedAt": "2025-01-01T00:00:00.000Z",
    "results": [ ... ]
  }
}
```

### Write Pattern

Every mutation follows this sequence:

1. Mutate the in-memory property (shallow clone via `Object.assign({}, ...)` to trigger QML bindings)
2. Copy data into `extensionsAdapter.*`
3. Call `extensionsFileView.writeAdapter()` to flush to disk

### Read / Init Flow

```
Component.onCompleted → mkdir -p cache + installed dirs
       ↓
extensionsFileView.onLoaded:
  1. Restore installedExtensions, extensionWidgetConfigs, etc. from adapter
  2. Call ExtensionSearch.loadFromCache(adapter.searchCache)
  3. Call ExtensionAudit.fetchAuditDatabase()
  4. Set ready = true
  5. Apply configDefaults for each installed extension
  6. Load services for enabled extensions
```

If the file does not exist (`FileViewError.FileNotFound`), the adapter is written immediately to create it.

---

## Lifecycle Flows

### Installation

```
installExtension(repoUrl, extId, branch, htmlUrl, isCustomUrl)
  ↓
git clone --depth 1 <repoUrl> <installedPath>
  ↓ (on exit)
installReader (FileView) re-reads extension.json
  ↓
registerInstalled(extId, dest, ...)
  1. Check ExtensionAudit.blockedIds → reject if blocked
  2. Parse extension.json into entry object
  3. Add to installedExtensions (shallow clone to trigger bindings)
  4. syncPluginsAdapter() → write to disk
  5. Emit extensionInstalled(extId)
  6. loadExtensionServices(extId) — create service QML components
  7. applyExtensionConfigDefaults(extId) — merge defaults
  8. reloadFromFile() — reload plugins.json to ensure consistency
```

For local path installs, the flow is identical except:
- No `git clone` — the `localReader` FileView reads `extension.json` directly from the filesystem path
- The entry is marked `isLocal: true`

### Enable / Disable

```
toggleExtension(extId, enabled)
  1. Deep-copy the entry with new enabled state
  2. Replace in installedExtensions (new object to trigger bindings)
  3. syncPluginsAdapter() → write to disk
  4. If enabling: loadExtensionServices(extId) → ExtensionServices.ensure()
  5. If disabling: unloadExtensionServices(extId) → ExtensionServices.unloadExtension()
  6. Emit extensionToggled(extId)
```

### Uninstall

```
uninstallExtension(extId)
  ↓
if isLocal → finalizeUninstall (keep files on disk)
if git     → rm -rf <installedPath>, then on exit → finalizeUninstall
       ↓
finalizeUninstall(extId)
  1. unloadExtensionServices(extId)
  2. Remove entry from installedExtensions
  3. Purge extensionConfigs[extId], extensionWidgetConfigs[extId], extensionOverlayConfigs[extId]
  4. syncPluginsAdapter() → write to disk
  5. Emit extensionRemoved(extId)
  6. reloadFromFile()
```

### Update

```
updateExtension(extId)
  1. toggleExtension(extId, false) — disable first
  2. git pull --ff-only in extension directory
  3. On exit → if non-zero: re-enable, surface error
  4. If success: updateReader re-reads extension.json
  5. reRegisterUpdated(extId, jsonText):
     a. Update entry with new contributes and metadata
     b. syncPluginsAdapter() + applyExtensionConfigDefaults()
     c. Clear updateStates entry
     d. toggleExtension(extId, true) — re-enable
```

### Check Update

```
checkUpdate(extId)
  ↓
git rev-parse HEAD + git ls-remote → compare hashes
  ↓
processUpdateCheck: set updateStates[extId] = { updateAvailable: bool }
  ↓
Queue: checkAllUpdates() populates _updateCheckQueue, processes one at a time
```

---

## Contribution Points

### Collection

`getContributionPoint(pointName)` in ExtensionManager:

1. Iterates all enabled entries in `installedExtensions`
2. For each extension, looks up `ext.contributes[pointName]`
3. Returns an array of resolved descriptors with `fullPath` (absolute path = `installedPath + "/" + component`)
4. For `overlayWidgets`, reads persisted `extensionOverlayConfigs` and overlays saved geometry

### Consumer Mapping

| Contribution Point | Consumer | How It Renders |
|---|---|---|
| `services` | `ExtensionManager` → `ExtensionServices` | `Qt.createComponent()` → `createObject(null)` |
| `barComponents` | `BarComponentRegistry` → `BarComponent` | Cached by ID, loaded via `loadExtensionQmlComponent()` |
| `sidebarLeftPages` | `SidebarPoliciesContent` | Tab buttons + `Loader` per page |
| `sidebarRightBottom` | `BottomWidgetGroup` | Nav buttons + `Loader` per tab |
| `backgroundWidgets` | `Background` → `widgetCanvas` | `loadExtensionQmlComponent()` + position from config |
| `overlayWidgets` | `OverlayContext` → `ExtensionOverlayWidgetLoader` | `loadExtensionQmlComponent()` + geometry from config |

### QML Component Loading

`loadExtensionQmlComponent(fullPath)` bypasses the QML engine cache by appending a unique query parameter:

```qml
Qt.createComponent("file://" + fullPath + "?_t=" + Date.now())
```

This ensures that reloaded/updated extensions always get a fresh compile, even if the QML engine would otherwise return a cached version.

---

## Search & Discovery

### Flow

```
refreshAvailableExtensions()
  ↓
curl GitHub search API (topic: ii-vynx-extension, per_page: 50)
  ↓
processSearchResults(jsonText)
  1. Parse response into repo array
  2. saveSearchCache(repos) → write to ExtensionManager's searchCache adapter
  3. Filter repos by ExtensionAudit.blockedIds
  4. Set availableExtensions
  5. Emit extensionSearchDone
  6. startExtensionJsonFetchAll() — queue all repos for metadata fetch
```

### Cache

- Search results are cached for **1 hour** (`isCacheValid()` check)
- On startup, `ExtensionSearch.loadFromCache()` restores cached results if still valid
- Cache is stored in `plugins.json` under `searchCache`

### Extension Metadata Queue

After a search completes, each repo's `extension.json` is fetched from `raw.githubusercontent.com` in sequence:

1. `startExtensionJsonFetchAll()` populates `_extensionJsonQueue`
2. `_processExtensionJsonQueue()` processes one at a time
3. If a fetch is in progress, a 500ms timer retries
4. As each response arrives, `updateExtensionJsonInList()` patches the repo entry with metadata (name, icon, version, contributes stub)

---

## Audit System

### Fetch

- `ExtensionAudit.fetchAuditDatabase()` curl's `extension-database.json` from the `vaguesyntax/vynx-extension-audit` repo
- Called on:
  - `extensionsFileView.onLoaded()` — every shell startup
  - `extensionsFileView.onLoadFailed()` — first run

### Processing

The JSON has three lists:

```json
{
  "blocked-extensions": [{ "extension-id": "bad-extension", "reason": "Malware detected" }],
  "trusted-extensions": [{ "extension-id": "safe-ext", "trustedCommit": "abc123" }],
  "recommended-extensions": ["good-ext"]
}
```

`_processAuditDatabase()` converts these into lookup maps:

| Internal Map | Source | Used By |
|---|---|---|
| `blockedIds` | blocked-extensions | `registerInstalled()` — blocks installation, `processSearchResults()` — filters search results |
| `trustedMap` | trusted-extensions | `getExtensionAuditState()` — shows "verified" badge in UI |
| `recommendedIds` | recommended-extensions | `isExtensionRecommended()` — highlights recommended repos in browse view |

### Integration Points

- `ExtensionSearch.processSearchResults()` filters `availableExtensions` through `ExtensionAudit.blockedIds` before exposing results
- `ExtensionManager.registerInstalled()` checks `ExtensionAudit.blockedIds` before allowing install
- UI components (`ExtensionCard`, `InstalledExtensionCard`) bind to `ExtensionAudit.auditDbVersion` to re-evaluate audit states when the database updates

---

## Signal Flow

```
ExtensionManager.refreshExtensions()
  ↑ (aggregated from)
  ├── ExtensionManager.installedExtensionsChanged
  ├── ExtensionManager.readyChanged
  ├── ExtensionManager.updateStatesChanged
  ├── ExtensionManager.extensionWidgetConfigsChanged
  ├── ExtensionManager.extensionOverlayConfigsChanged
  └── ExtensionManager.extensionConfigsChanged
       ↓
  Consumers re-evaluate contribution points (SidebarPoliciesContent,
  BottomWidgetGroup, OverlayContext, Background, BarComponentRegistry)
```

```
ExtensionSearch.extensionSearchDone
  ↓
ExtensionsConfig page re-filters the extension list

ExtensionSearch.extensionJsonReady(repoId)
  ↓
ExtensionCard metadata updates in place
```

```
ExtensionManager.extensionInstalled(extId)
ExtensionManager.extensionRemoved(extId)
ExtensionManager.extensionToggled(extId)
  ↓
All consumers re-evaluate contribution points
```

---

## Queue Mechanisms

### Extension.json Fetch Queue

- **Purpose:** Fetch metadata for each search result sequentially without overwhelming the network
- **Implementation:** `_extensionJsonQueue` array, processed one item at a time
- **Backoff:** If a fetch is already in progress, a 500ms `Timer` retries
- **Save trigger:** When the queue empties, `saveSearchCache()` is called with updated metadata

### Update Check Queue

- **Purpose:** Run `checkUpdate()` for every installed extension without spawning parallel git processes
- **Implementation:** `_updateCheckQueue` array, `_updateCheckRunning` guard
- **Advance:** Each check completion calls `_advanceUpdateCheckQueue()` which processes the next item via `Qt.callLater()`
