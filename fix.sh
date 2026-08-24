#!/bin/bash

set -e

BASE="$HOME/.cache/dots-hyprland/sdata/dist-arch/illogical-impulse-microtex-git/src/MicroTeX"
FILE="$BASE/src/platform/cairo/graphic_cairo.cpp"

echo "[1/3] Aplicar patch definitivo (Fontconfig moderno)..."

cp "$FILE" "$FILE.bak"

# remove função antiga inteira
awk '
/void tex::Font_cairo::loadFont/ {flag=1}
flag && /}/ {flag=0; next}
!flag {print}
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

# adiciona versão compatível no fim do ficheiro
cat >> "$FILE" << 'EOF'

void tex::Font_cairo::loadFont(const std::string& name)
{
    // Fontconfig moderno - sem FcFreeTypeQuery
    FcPattern *pattern = FcNameParse((const FcChar8*)name.c_str());
    if (!pattern) return;

    FcConfigSubstitute(nullptr, pattern, FcMatchPattern);
    FcDefaultSubstitute(pattern);

    FcResult result;
    FcPattern *match = FcFontMatch(nullptr, pattern, &result);

    if (!match) {
        FcPatternDestroy(pattern);
        return;
    }

    FcPatternDestroy(pattern);
    FcPatternDestroy(match);
}
EOF

echo "[2/3] Limpar build..."
rm -rf "$BASE/build"

echo "[3/3] Compilar..."
cd "$HOME/.cache/dots-hyprland/sdata/dist-arch/illogical-impulse-microtex-git"
makepkg -Afsi --noconfirm
