# ii-vynx Extensions

Extensions allow third-party QML components to be dynamically loaded into various shell surfaces — the bar, sidebar, background, overlay canvas — and to run background services. Everything is managed live from the Extensions settings page with no shell restart required.

> [!WARNING]  
> By submitting or developing an extension for ii-vynx Hyprland shell, you grant the shell developer the right to use, modify, redistribute, and integrate the extension, in whole or in part, for any purpose without restriction.

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

For rapid iteration, use the **Reload** button (local extensions only) to pick up changes without reinstalling.

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

Long-running background processes that live for the lifetime of the extension.

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

The root item receives an `extensionId` property injected at runtime on load. Use `Appearance.sizes.barHeight` for height and `Appearance.sizes.verticalBarWidth` for width:

```qml
// bar/MyWidget.qml
import QtQuick
import qs.modules.common

Item {
    id: root
    // Injected automatically:
    // property string extensionId: "..."

    implicitWidth: 200
    implicitHeight: Appearance.sizes.barHeight

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

Use `anchors.fill: parent` to fill the available space:

```qml
// sidebar/MyPage.qml
import QtQuick

Item {
    id: root
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

Use `anchors.fill: parent` to fill the available space:

```qml
// sidebarBottom/MyTab.qml
import QtQuick

Item {
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

**Persistence:** Position (x, y) and enable state are saved per-widget. Changes propagate automatically.

**QML contract:**

Your root component **must** extend `AbstractBackgroundWidget`. Injected properties:

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
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
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

---

### 6. `overlayWidgets`

Floating, draggable, resizable widgets that sit above all shell surfaces — akin to desktop widgets.

**Descriptor fields:**

| Field | Type | Required | Description |
|---|---|---|---|
| `identifier` | string | **Yes** | Unique ID within this extension. |
| `title` | string | **Yes** | Display name. |
| `icon` | string | No | Fallback icon. |
| `materialSymbol` | string | No | Icon shown in the overlay taskbar. Falls back to `icon`, then `"extension"`. |
| `component` | string | **Yes** | Relative path to the QML widget file. |
| `x` | number | No | Default x position. Default: `100`. |
| `y` | number | No | Default y position. Default: `100`. |
| `width` | number | No | Default width. Default: `300`. |
| `height` | number | No | Default height. Default: `200`. |
| `pinned` | boolean | No | Whether the widget stays open persistently. Default: `false`. |
| `clickthrough` | boolean | No | Whether mouse clicks pass through the widget. Default: `true`. |

**Persistence:** Position, size, pinned, and clickthrough are saved per-widget. Changes propagate automatically.

**QML contract:**

Your root component **must** extend `StyledOverlayWidget`. Do **not** set `width`/`height`/`x`/`y` yourself — the extension system handles positioning via `configEntry`. Bind to these values instead.

| Property | Type | Description |
|---|---|---|
| `configEntry` | QtObject | Has `.pinned` (bool), `.clickthrough` (bool), `.x` (real), `.y` (real), `.width` (real), `.height` (real). Changes auto-save. |
| `extensionId` | string | Extension ID. |

```qml
// overlay/MyOverlay.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.ii.overlay
import qs.modules.common.widgets

StyledOverlayWidget {
    id: root
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

---

## Best Practices

### Importing QML files

You can directly use qml files in the file if they are in the folder as the main qml file. If not, you can use `import "./folderName"` to import a folder and use the files in that folder. 

You can check official plugin to see an example for it from [here](https://github.com/vaguesyntax/vynx-wallpaper-browser/blob/main/src/WallpaperBrowserUI.qml).

### Naming

- Use kebab-case for directory/repo names (e.g. `my-extension`, `awesome-widgets`). The directory name becomes the extension ID.
- Place `extension.json` at the repository root.

### Testing Locally

1. Create your extension directory anywhere on your filesystem.
2. Open Extensions settings → click the link icon at the top to reveal the URL/path input.
3. Paste the absolute path to your extension directory.
4. The extension appears in the Installed list. Enable it to test.
5. For rapid iteration: use the **Reload** button (local extensions only) to pick up changes without reinstalling.

### Config Defaults

Use `configDefaults` to provide initial values for your extension's config. These are applied automatically on install and reload:

```json
{
  "configDefaults": {
    "refreshInterval": 30,
    "theme": "dark",
    "maxItems": 10
  }
}
```

Users can change these from an extension settings UI (if you provide one) and they persist in `plugins.json`.

### Config Schema

Use `configSchema` to define a typed settings UI that is automatically rendered in the extension's card. Each key maps to a control:

```json
{
  "configSchema": {
    "refreshInterval": {
      "type": "int",
      "label": "Refresh Interval",
      "default": 30,
      "min": 5,
      "max": 120
    },
    "theme": {
      "type": "enum",
      "label": "Theme",
      "default": "dark",
      "values": ["light", "dark", "system"]
    },
    "showBadges": {
      "type": "bool",
      "label": "Show Badges",
      "default": true
    },
    "opacity": {
      "type": "slider",
      "label": "Opacity",
      "default": 0.8,
      "min": 0.1,
      "max": 1.0
    },
    "apiKey": {
      "type": "string",
      "label": "API Key",
      "default": ""
    }
  }
}
```

| Type     | Control              | Extra properties       |
|----------|----------------------|------------------------|
| `bool`   | Switch               | —                      |
| `int`    | SpinBox              | `min`, `max`           |
| `slider` | Slider (float)       | `min`, `max`           |
| `float`  | SpinBox (decimal)    | `min`, `max`           |
| `enum`   | Dropdown             | `values` (string[])    |
| `string` | Text field           | —                      |

Values are stored per-extension in `plugins.json` and accessible at runtime via `ExtensionManager.getExtensionConfig(extId, key, defaultValue)`.

---

## Publishing

To make your extension discoverable through Browse Extensions:

1. Push your repository to GitHub.
2. Add the topic `ii-vynx-extension` to your repository.
3. Ensure `extension.json` is at the repository root.
4. The system will automatically find your repo via the GitHub API.

Report any issues you faced while developing an extension [here](https://github.com/vaguesyntax/ii-vynx/issues).
