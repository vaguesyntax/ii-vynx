# ii-vynx Extension System

Extensions allow third-party QML components to be dynamically loaded into various shell surfaces — the bar, sidebar, background, overlay canvas — and to run background services. Everything is managed live from the Extensions settings page with no shell restart required.

---

## Table of Contents

- [Quick Start](#quick-start)
- [extension.json Schema](#extensionjson-schema)
- [Contribution Points](#contribution-points)
  - [services](#1-services)
  - [barComponents](#2-barcomponents)
  - [sidebarLeftPages](#3-sidebarleftpages)
  - [sidebarRightBottom](#4-sidebarrightbottom)
  - [backgroundWidgets](#5-backgroundwidgets)
  - [overlayWidgets](#6-overlaywidgets)
- [Lifecycle](#lifecycle)
- [Persistence](#persistence)
- [Best Practices](#best-practices)
- [Publishing](#publishing)
---

## Quick Start

Create a directory with an `extension.json` and your QML files:

```
my-extension/
├── extension.json
├── MyOverlay.qml
├── bar/
│   └── MyWidget.qml
└── services/
    └── MyService.qml
```

**Minimal `extension.json`:**

You can also check official and other extensions' `extension.json` to see what `extension.json` looks like when its fully filled.

```json
{
  "name": "My Extension",
  "description": "Does cool things",
  "version": "1.0.0",
  "author": "YourName",
  "contributes": {
    "barComponents": [
      {
        "identifier": "myWidget",
        "title": "My Widget",
        "icon": "widgets",
        "component": "bar/MyWidget.qml"
      }
    ]
  }
}
```

**Test locally:** Open Extensions settings, paste the absolute path to your extension directory, click Install. The extension appears instantly — toggle it on to see your widget in the bar.

---

## extension.json Schema

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | **Yes** | Display name. Also used as extension ID (derived from directory/repo name). |
| `description` | string | No | Short description shown in extension cards. |
| `version` | string | No | Semantic version (e.g. `"1.0.0"`). |
| `author` | string | No | Author display name. |
| `icon` | string | No | [Material Symbols](https://fonts.google.com/icons) icon codepoint name. Default: `"extension"`. |
| `shapeString` | string | No | Shape override for the icon container (e.g. `"RoundedRect"`). Empty = default shape. |
| `configDefaults` | object | No | Default key-value config. Applied on install and reload. See [Persistence](#persistence). |
| `contributes` | object | No | Declares which shell surfaces this extension integrates with. See below. |

### `contributes` object

Each key is a contribution point name. The value is always an **array of contribution descriptors**.

```json
{
  "contributes": {
    "services":           [...],
    "barComponents":      [...],
    "sidebarLeftPages":   [...],
    "sidebarRightBottom": [...],
    "backgroundWidgets":  [...],
    "overlayWidgets":     [...]
  }
}
```

---

## Contribution Points

### 1. `services`

Background processes that run for the lifetime of the extension.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | **Yes** | Unique service identifier within this extension. |
| `qml` | string | **Yes** | Relative path to the QML file. |

**Lifecycle:**

- Loaded when extension is enabled or installed.
- Destroyed when extension is disabled or uninstalled.
- Created with no parent (`createObject(null)`).

**QML contract:**

The root item receives an `extensionId` property injected at runtime:

```qml
// services/MyService.qml
import QtQuick

QtObject {
    id: root
    // Injected automatically:
    // property string extensionId: "..."

    property int randomNumber: 45
    property bool testBool: true
    property var testArray: [1, 2, 3, 4, 5]
    property var testObject: { "key1": "value1", "key2": "value2" }

    Component.onCompleted: {
        console.log("Service started for", extensionId)
    }
}
```

**Example:**

```json
{
  "contributes": {
    "services": [
      {
        "id": "myService",
        "qml": "services/MyService.qml"
      }
    ]
  }
}
```

**Consumer:** `ExtensionManager.qml` → `ExtensionServices.qml`

---

### 2. `barComponents`

Custom widgets that appear alongside built-in bar components.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. Used as cache key. |
| `title` | string | **Yes** | Display name. |
| `icon` | string | **Yes** | Material Symbols icon codepoint name. |
| `component` | string | **Yes** | Relative path to the horizontal-layout QML file. |
| `verticalQml` | string | No | Relative path to the vertical-layout QML file. Defaults to `component` if not set. |

**QML contract:**

The root item receives an `extensionId` property injected at runtime on load. No other special properties are required.

```qml
// bar/MyWidget.qml
import QtQuick
import qs.modules.common

Item {
    id: root
    // Injected automatically:
    // property string extensionId: "..."

    implicitWidth: 200
    implicitHeight: Appearance.sizes.barHeight // It's recommended to use ---.barHeight when setting the height in the horizontal component
                                               // And ---.verticalBarWidth when setting the width in the vertical component

    Text {
        anchors.centerIn: parent
        text: "My Widget"
    }
}
```

**Example:**

```json
{
  "contributes": {
    "barComponents": [
      {
        "identifier": "myBarWidget",
        "title": "My Widget",
        "icon": "widgets",
        "component": "bar/MyWidget.qml",
        "verticalQml": "bar/MyWidgetVert.qml"
      }
    ]
  }
}
```

**Consumer:** `BarComponentRegistry.qml` (caches both horizontal and vertical components) → `BarComponent.qml` (renders via component ID lookup)

---

### 3. `sidebarLeftPages`

Custom pages/tabs in the left (policies) sidebar, alongside AI Chat, Translator, Wallpapers, and Anime tabs.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. |
| `title` | string | **Yes** | Tab label text. |
| `icon` | string | **Yes** | Material Symbols icon codepoint name. |
| `component` | string | **Yes** | Relative path to the QML page file. |

**QML contract:**

The root item receives an `extensionId` property injected at runtime on load.

```qml
// sidebar/MyPage.qml
import QtQuick

Item {
    id: root
    // Use `anchors.fill`
    anchors.fill: parent
    // Injected automatically:
    // property string extensionId: "..."

    Text {
        anchors.centerIn: parent
        text: "My Page"
    }
}
```

**Example:**

```json
{
  "contributes": {
    "sidebarLeftPages": [
      {
        "identifier": "myPage",
        "title": "My Tab",
        "icon": "tab",
        "component": "sidebar/MyPage.qml"
      }
    ]
  }
}
```

**Consumer:** `SidebarPoliciesContent.qml` (renders tab buttons + creates `Loader` per page)

---

### 4. `sidebarRightBottom`

Custom tabs in the bottom panel of the right sidebar, alongside Calendar, To-Do, and Timer.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. |
| `title` | string | **Yes** | Tab name shown as tooltip. |
| `icon` | string | **Yes** | Material Symbols icon codepoint name. |
| `component` | string | **Yes** | Relative path to the QML tab file. |

**QML contract:**

The root item receives an `extensionId` property injected at runtime on load.

```qml
// sidebarBottom/MyTab.qml
import QtQuick

Item {
    // Use `anchors.fill`
    anchors.fill: parent 
    // Injected automatically:
    // property string extensionId: "..."

    Text {
        anchors.centerIn: parent
        text: "My Tab Content"
    }
}
```

**Example:**

```json
{
  "contributes": {
    "sidebarRightBottom": [
      {
        "identifier": "myTab",
        "title": "My Tab",
        "icon": "tab",
        "component": "sidebarBottom/MyTab.qml"
      }
    ]
  }
}
```

**Consumer:** `BottomWidgetGroup.qml` (renders nav buttons + `Loader` for content)

---

### 5. `backgroundWidgets`

Widgets drawn on the wallpaper canvas — useful for clocks, media players, weather, system monitors, etc.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. |
| `title` | string | **Yes** | Display name. |
| `icon` | string | **Yes** | Material Symbols icon codepoint name. |
| `component` | string | **Yes** | Relative path to the QML widget file. |
| `x` | number | No | Default x position (pixels). Default: `100`. |
| `y` | number | No | Default y position (pixels). Default: `100`. |
| `placementStrategy` | string | No | `"free"` (default), `"leastBusy"` (not recommended), or `"mostBusy"` (not recommended). |

**Persistence:** Position (x, y) and enable state are saved per-widget via `extensionWidgetConfigs`. See [Persistence](#persistence).

**QML contract:**

The root item receives these properties injected at runtime:

| Property | Type | Description |
|---|---|---|
| `configEntry` | QtObject | Has `.enable` (bool), `.x` (real), `.y` (real), `.placementStrategy` (string). Changes auto-save. |
| `extensionId` | string | Extension ID. |
| `screenWidth` | real | Wallpaper canvas width. |
| `screenHeight` | real | Wallpaper canvas height. |
| `scaledScreenWidth` | real | Scaled canvas width (accounts for wallpaper scale). |
| `scaledScreenHeight` | real | Scaled canvas height (accounts for wallpaper scale). |
| `wallpaperScale` | real | Current wallpaper scale factor. |

```qml
// bg/MyBgWidget.qml
import QtQuick

// You must use AbstractBackgroundWidget as a root component
AbstractBackgroundWidget {
    // Injected automatically:
    // property QtObject configEntry: ...
    // property string extensionId: "..."
    // property real screenWidth: ...
    // property real screenHeight: ...

    width: 200
    height: 100

    Rectangle {
        anchors.fill: parent
        color: "#88000000"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: "My BG Widget"
            color: "white"
        }
    }
}
```

**Example:**

```json
{
  "contributes": {
    "backgroundWidgets": [
      {
        "identifier": "myBgWidget",
        "title": "My BG Widget",
        "icon": "wallpaper",
        "component": "bg/MyBgWidget.qml",
        "x": 100,
        "y": 100,
        "placementStrategy": "free"
      }
    ]
  }
}
```

**Consumer:** `Background.qml` (creates into `widgetCanvas`)

---

### 6. `overlayWidgets`

Floating, draggable, resizable widgets that sit above all shell surfaces — akin to desktop widgets.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. |
| `title` | string | **Yes** | Display name. |
| `icon` | string | No | Fallback icon. If `materialSymbol` is not set, this is used. |
| `materialSymbol` | string | No | Icon shown in the overlay taskbar. Falls back to `icon`, then `"extension"`. |
| `component` | string | **Yes** | Relative path to the QML widget file. |
| `x` | number | No | Default x position. Default: `100`. |
| `y` | number | No | Default y position. Default: `100`. |
| `width` | number | No | Default width. Default: `300`. |
| `height` | number | No | Default height. Default: `200`. |
| `pinned` | boolean | No | Whether the widget stays open persistently. Default: `false`. |
| `clickthrough` | boolean | No | Whether mouse clicks pass through the widget. Default: `true`. |

**Persistence:** Position, size, pinned, and clickthrough are saved per-widget via `extensionOverlayConfigs`. See [Persistence](#persistence).

**QML contract:**

The root item receives these properties injected at runtime:

| Property | Type | Description |
|---|---|---|
| `configEntry` | QtObject | Has `.pinned` (bool), `.clickthrough` (bool), `.x` (real), `.y` (real), `.width` (real), `.height` (real). Changes auto-save. |
| `extensionId` | string | Extension ID. |

The widget is created as a child of the overlay parent. You do **not** set `width`/`height`/`x`/`y` yourself — the extension system handles positioning via `configEntry`. Instead, bind to these values:

```qml
// overlay/MyOverlay.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.ii.overlay
import qs.modules.common.widgets

// You must use StyledOverlayWidget as a root component
StyledOverlayWidget {
    id: root
    // You can also pass it manually
    property string extensionId: ""

    contentItem: Rectangle {
        color: Appearance.colors.colLayer2
        radius: root.contentRadius
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            StyledText {
                text: "Hello from extension!"
                Layout.alignment: Qt.AlignHCenter
            }
            Button {
                text: "Extension ID: " + root.extensionId
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
```

**Example:**

```json
{
  "contributes": {
    "overlayWidgets": [
      {
        "identifier": "myOverlay",
        "title": "My Overlay Widget",
        "icon": "extension",
        "materialSymbol": "stadia_controller",
        "component": "overlay/MyOverlay.qml",
        "x": 100,
        "y": 100,
        "width": 300,
        "height": 200,
        "pinned": false,
        "clickthrough": true
      }
    ]
  }
}
```

**Consumer:** `OverlayContext.qml` (collects widget list) → `ExtensionOverlayWidgetLoader.qml` (creates each widget) → `OverlayContent.qml` (renders) + `OverlayTaskbar.qml` (taskbar buttons)

---

## Lifecycle

### Installation

1. **GitHub discovery:** Extensions tagged with `ii-vynx-extension` topic appear in Browse Extensions search results. Results are cached for 1 hour.
2. **Custom URL:** Paste any GitHub repo URL → cloned via `git clone --depth 1`.
3. **Local path:** Paste an absolute filesystem path → registered directly without git operations.

On install, the extension's `extension.json` is parsed and stored in `plugins.json`. The extension is initially disabled.

### Enable / Disable

Toggling an extension:
1. Deep-copies the extension entry with the new `enabled` state.
2. Immediately writes to `plugins.json`.
3. If enabling: loads `services` contributions.
4. Emits `extensionToggled(extId)`, which triggers all consumers to refresh.

### Uninstall

1. For git-based extensions: `rm -rf <installedPath>`.
2. For local extensions: only the registry entry is removed (files stay on disk).
3. `services` contributions are unloaded.
4. All config entries (`extensionConfigs`, `extensionWidgetConfigs`, `extensionOverlayConfigs`) for this extension are purged.
5. Emits `extensionRemoved(extId)`.

### Reload (Local Extensions Only)

The Reload button appears only for locally-installed extensions (`isLocal: true`):

1. Re-reads `extension.json` from disk via `cat`.
2. **Disables** the extension (removes all components).
3. Updates the stored entry with new `contributes` and `configDefaults`.
4. **Re-enables** the extension (triggers full re-creation with fresh QML).

### Update (Git Extensions)

1. Disables the extension.
2. Runs `git pull --ff-only` in the extension directory.
3. Re-reads `extension.json` and updates the stored entry.
4. Re-enables the extension.
5. On failure: surfaces the error but still re-enables the extension.

### Signals

Extension-related signals on the singleton `ExtensionManager`:

| Signal | Parameters | When |
|---|---|---|
| `refreshExtensions()` | — | Any extension state change (available, installed, toggled, etc.) |
| `extensionInstalled(extId)` | string | After successful install |
| `extensionRemoved(extId)` | string | After successful uninstall |
| `extensionToggled(extId)` | string | After enable/disable |
| `extensionSearchDone()` | — | After GitHub search completes |
| `extensionJsonReady(repoId)` | int | After fetching extension.json for a browse result |
| `updateCheckDone(extId, available, error)` | string, bool, string | After update check completes |

---

## Persistence

All extension state lives in `~/.config/illogical-impulse/extensions/plugins.json`.

### File Structure

```json
{
  "extensions": {
    "<extId>": { ... full extension entry ... }
  },
  "extensionConfigs": {
    "<extId>": { "key": "value", ... }
  },
  "extensionWidgetConfigs": {
    "<extId>": {
      "<widgetId>": { "enable": true, "x": 100, "y": 200 }
    }
  },
  "extensionOverlayConfigs": {
    "<extId>": {
      "<widgetId>": { "x": 100, "y": 100, "width": 300, "height": 200, "pinned": false, "clickthrough": true }
    }
  },
  "searchCache": {
    "cachedAt": "2025-01-01T00:00:00.000Z",
    "results": [ ... ]
  }
}
```

### Config Stores

| Store | API | Used By |
|---|---|---|
| `extensionConfigs` | `getExtensionConfig(extId, key, default)` / `setExtensionConfig(extId, key, val)` / `resetExtensionConfig(extId)` | General-purpose key-value config per extension. `configDefaults` are applied on install/reload. |
| `extensionWidgetConfigs` | `getExtensionWidgetConfig(extId, widgetId)` / `saveExtensionWidgetConfig(extId, widgetId, { enable, x, y })` | `backgroundWidgets` — position and enable state. |
| `extensionOverlayConfigs` | `getExtensionOverlayConfig(extId, widgetId)` / `saveExtensionOverlayConfig(extId, widgetId, { x, y, width, height, pinned, clickthrough })` | `overlayWidgets` — position, size, pinned, clickthrough. |

### Sync

Every mutation calls `syncPluginsAdapter()` → `extensionsFileView.writeAdapter()`, which writes to disk immediately. The file is also watched — external modifications trigger a reload.

---

## Best Practices

### Naming

- Use kebab-case for directory/repo names (e.g. `my-extension`, `awesome-widgets`). The directory name becomes the extension ID.
- Place `extension.json` at the repository root.

### Testing Locally

1. Create your extension directory anywhere on your filesystem.
2. Open Extensions settings → click "Install from URL" (the toggle at the top).
3. Paste the absolute path to your extension directory.
4. The extension appears in the Installed list. Enable it to test.
5. For rapid iteration: use the Reload button (local extensions only) to pick up changes without reinstalling.

## Publishing

To make your extension discoverable through Browse Extensions:

1. Push your repository to GitHub.
2. Add the topic `ii-vynx-extension` to your repository.
3. Ensure `extension.json` is at the repository root.
4. The system will automatically find you repo via GitHub API.


Report any issue you have faced while developing an extension from [here](https://github.com/vaguesyntax/ii-vynx/issues)