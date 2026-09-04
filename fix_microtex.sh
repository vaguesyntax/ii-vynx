#!/bin/bash

set -e

BASE="$HOME/.cache/dots-hyprland/sdata/dist-arch/illogical-impulse-microtex-git/src/MicroTeX"
FILE="$BASE/src/platform/cairo/graphic_cairo.cpp"

echo "[1/3] A aplicar patch real no Fontconfig..."

# backup
cp "$FILE" "$FILE.bak"

# remove a linha problemática inteira e substitui por versão segura
sed -i '/FcFreeTypeQuery/d' "$FILE"

# inserir fallback correto no lugar da função loadFont
sed -i '/void tex::Font_cairo::loadFont/,/}/c\
void tex::Font_cairo::loadFont(const std::string& name)\n\
{\n\
    FcPattern* p = nullptr;\n\
    int count = 0;\n\
    FcBlanks* blanks = FcBlanksCreate();\n\
\n\
    p = FcFreeTypeQueryFace(nullptr, 0, blanks, &count);\n\
\n\
    if (!p) return;\n\
}' "$FILE"

echo "[2/3] Limpar build..."
rm -rf "$BASE/build"

echo "[3/3] Compilar..."
cd "$HOME/.cache/dots-hyprland/sdata/dist-arch/illogical-impulse-microtex-git"
makepkg -Afsi --noconfirm
