# AGENTS.md - ii-vynx

Hyprland dotfiles based on illogical-impulse, built with Quickshell (QtQuick/QML).

## Commands

- **Restart shell (dev):** `pkill qs; qs -c ii`
- **Run settings app:** `qs -c ii settings.qml` (separate QApplication)
- **Setup/update:** `./setup-ii-vynx.sh` or `vynx update` (CLI)
- **Legacy setup router:** `./setup <subcommand>` (install, uninstall, exp-update, etc.)
- **LSP setup:** `touch ~/.config/quickshell/ii/.qmlls.ini` — gitignored, create manually

## QML Architecture

### Entry Points

| File | Role |
|---|---|
| `dots/.config/quickshell/ii/shell.qml` | Main shell entry (`qs -c ii`). Uses `ShellRoot` |
| `dots/.config/quickshell/ii/settings.qml` | Settings app. Uses `ApplicationWindow` (separate process) |

### Panel Families (`panelFamilies/`)

Two mutually exclusive UI styles loaded via `LazyLoader`. Switch with `Super+Ctrl+R` or IPC call `panelFamily cycle`.
But focus on the ii (Illogical-Impulse) panel family when making any changes unless otherwise stated.

- **`IllogicalImpulseFamily.qml`** — original ii style (bar, sidebars, dock, etc.)
- **`WaffleFamily.qml`** — Windows 11-like (action center, start menu, task view)
- Shared components (cheatsheet, OSK, overlay, screen translator, wallpaper selector) are imported in both

### Core Singletons (`modules/common/`)

- **`Config.qml`** — All shell options. Backed by `FileView` + `JsonAdapter` at `~/.config/illogical-impulse/config.json`. Has `readWriteDelay` (default 75ms) to batch writes. Check `Config.ready` before accessing options.
- **`GlobalStates.qml`** — Centralized UI state booleans (`sidebarLeftOpen`, `sidebarRightOpen`, `overlayOpen`, `overviewOpen`, etc.). Also has `effectiveLeftOpen`/`effectiveRightOpen` computed properties that respect `Config.options.sidebar.position`.
- **`Directories.qml`** — XDG paths and internal config paths. All paths use `file://` protocol except noted "without file://" ones. Use `FileUtils.trimFileProtocol()` to strip.
- **`Appearance.qml`** — Colors, fonts, rounding, animation curves
- **`Icons.qml`**, **`Images.qml`** — Icon/image resources

### Module Layout

```
modules/
  common/       # Shared utilities, Config, Appearance, widgets
    widgets/    # Common widgets used accross the repo to maintain Material 3 style
  ii/           # Illogical-impulse panel components
  waffle/       # Waffle panel components
  settings/     # Settings app pages (QuickConfig, BarConfig, etc.)
services/       # Backend services (Ai, Audio, Battery, Network, MprisController, etc.)
```

### Loader Pattern

`PanelLoader.qml` wraps `LazyLoader`. Always check `Config.ready`:
```qml
PanelLoader { extraCondition: Config.options.dock.enable; component: Dock {} }
```

**Important:** When using `Loader`/`LazyLoader`, declare `anchors` and positioning on the Loader itself, not the `sourceComponent`. For fade animations, use `FadeLoader` with `shown` prop.

### Import Conventions

- `qs.modules.common` → `modules/common/`
- `qs.modules.common.widgets` → `modules/common/widgets`
- `qs.modules.ii.*` → `modules/ii/*/`
- `qs.modules.waffle.*` → `modules/waffle/*/`
- `qs.services` → `services/`
- `qs.modules.common.functions as CF` → utility functions

## Config Schema

Config lives in `Config.qml` as nested `JsonObject` properties. Key top-level groups:
- `panelFamily` — "ii" or "waffle"
- `appearance` — theme, fonts, transparency, wallpaper theming, `fakeScreenRounding` (0-3)
- `bar` — layout, workspaces, layouts (left/center/right component arrays), vertical mode
- `sidebar` — position ("default"/"inverted"/"left"/"right"), quickToggles, quickSliders
- `background` — wallpaper, widgets (clock/media/weather), media mode, parallax
- `lock` — lock screen, blur, `useHyprlock`
- `waffles` — Waffle-specific tweaks (bar, actionCenter toggles)
- `ai` — system prompt, models, tools
- `policies` — feature flags (ai, weeb, wallpapers, translator)

Access via `Config.options.bar.vertical`, `Config.options.appearance.sharpMode`, etc.

## QML Style

- **Indent:** 4 spaces, no tabs (`.qmlformat.ini`)
- **Spacing:** Space between text and operators: `if (condition) { ... }`
- **Blank lines:** Group related properties/children, no 2+ consecutive blanks
- **Components:** Use `component` keyword for in-file reusable components
- **Early return:** Prefer `if (!condition) return; doStuff()` over deep nesting
- **Conditional loading:** Use `Loader`/`LazyLoader` for anything guarded by config options

## Extension System

The details of the extension system are in the file named `EXTENSIONS.md` located at `.github/EXTENSIONS.md`

## Git Setup

- **Must clone with `--recurse-submodules`** — submodule at `modules/common/widgets/shapes` (rounded-polygon-qmljs)
- `.qmlls.ini` is gitignored — agents must create it manually for LSP