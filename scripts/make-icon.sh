#!/usr/bin/env bash
# Regenerates the app icon and the menu bar icon from the SVGs in Design/.
#
# Usage: scripts/make-icon.sh
#
# Requires rsvg-convert: brew install librsvg
# Run this after editing the SVG, then commit both the SVG and the PNGs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/NotchPrompter/Resources/Assets.xcassets"
SVG="$ROOT/Design/AppIcon.svg"
SET="$ASSETS/AppIcon.appiconset"
MENU_SVG="$ROOT/Design/MenuBarIcon.svg"
MENU_SET="$ASSETS/MenuBarIcon.imageset"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found; brew install librsvg"; exit 1; }
for f in "$SVG" "$MENU_SVG"; do [[ -f "$f" ]] || { echo "missing $f"; exit 1; }; done

mkdir -p "$SET"
rm -f "$SET"/*.png

# macOS wants each size at 1x and 2x; the 2x of one size is the 1x pixel count
# of the next, so ten files cover 16pt through 512pt.
for size in 16 32 128 256 512; do
  rsvg-convert -w "$size" -h "$size" "$SVG" -o "$SET/icon_${size}x${size}.png"
  rsvg-convert -w "$((size * 2))" -h "$((size * 2))" "$SVG" -o "$SET/icon_${size}x${size}@2x.png"
done

cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16", "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16", "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32", "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32", "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

echo "wrote $(ls "$SET"/*.png | wc -l | tr -d ' ') PNGs to $SET"

# --- Menu bar icon -----------------------------------------------------------
# 18pt at 1x and 2x, rendered as a template image so macOS recolors it for the
# light bar, the dark bar and the highlighted state.
mkdir -p "$MENU_SET"
rm -f "$MENU_SET"/*.png
rsvg-convert -w 18 -h 18 "$MENU_SVG" -o "$MENU_SET/menubar_18.png"
rsvg-convert -w 36 -h 36 "$MENU_SVG" -o "$MENU_SET/menubar_36.png"

cat > "$MENU_SET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "universal", "scale" : "1x", "filename" : "menubar_18.png" },
    { "idiom" : "universal", "scale" : "2x", "filename" : "menubar_36.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "template-rendering-intent" : "template" }
}
JSON

echo "wrote 2 PNGs to $MENU_SET"
