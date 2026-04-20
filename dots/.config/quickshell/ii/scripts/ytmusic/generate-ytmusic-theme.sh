#!/usr/bin/env bash
# Generates Material You theme for YouTube Music Desktop via matugen native template

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG="$XDG_CONFIG_HOME/illogical-impulse/config.json"
YTM_DIR="$XDG_CONFIG_HOME/YouTube Music"
TEMPLATE="$SCRIPT_DIR/ytmusic.css"
OUTPUT="$YTM_DIR/style.css"

# Only run if YouTube Music Desktop is installed
if [ ! -d "$YTM_DIR" ]; then
    exit 0
fi

# Determine wallpaper
if [ -n "${1:-}" ] && [ -f "$1" ]; then
    WALLPAPER="$1"
elif [ -f "$SHELL_CONFIG" ]; then
    WALLPAPER=$(jq -r '.background.wallpaperPath' "$SHELL_CONFIG" 2>/dev/null || echo "")
fi

if [ -z "${WALLPAPER:-}" ] || [ ! -f "$WALLPAPER" ]; then
    echo "[generate-ytmusic-theme] Error: wallpaper not found or not specified. Usage: $0 [wallpaper_path]" >&2
    exit 1
fi

MODE_RAW=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
if [[ "$MODE_RAW" == *"light"* ]]; then
    MODE_FLAG="light"
else
    MODE_FLAG="dark"
fi

if [ -f "$SHELL_CONFIG" ]; then
    PALETTE_TYPE=$(jq -r '.appearance.palette.type' "$SHELL_CONFIG" 2>/dev/null || echo "scheme-tonal-spot")
else
    PALETTE_TYPE="scheme-tonal-spot"
fi

case "$PALETTE_TYPE" in
    scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|\
    scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
        ;;
    *)
        PALETTE_TYPE="scheme-tonal-spot"
        ;;
esac

# Create a temporary matugen config pointing only to the ytmuisc template.
tmpfile=$(mktemp /tmp/matugen-ytmusic-XXXXXX.toml)
trap 'rm -f "$tmpfile"' EXIT

cat > "$tmpfile" <<TOML
[config]
version_check = false

[templates.ytmusic]
input_path = '$TEMPLATE'
output_path = '$OUTPUT'
TOML

matugen \
    --config "$tmpfile" \
    --mode "$MODE_FLAG" \
    --type "$PALETTE_TYPE" \
    --quiet \
    image "$WALLPAPER"

echo "[generate-ytmusic-theme] Done. Theme written to: $OUTPUT"
