#!/bin/bash
# Builds RemoveMacAI.app from the same binary as the command-line tool.
#
#   tools/build-app.sh            -> .build/RemoveMacAI.app
#
# Opened from Finder the binary shows the app; with arguments it is the CLI.
set -euo pipefail
cd "$(dirname "$0")/.."

# Build arch: arm64 by default; REMOVEMACAI_ARCH=x86_64 for an Intel Ventura Mac.
arch="${REMOVEMACAI_ARCH:-arm64}"

swift build -c release --arch "$arch"
bin="$(swift build -c release --arch "$arch" --show-bin-path)/removemacai"
version="$("$bin" --version)"

app=".build/RemoveMacAI.app"
rm -rf "$app" .build/AppIcon.iconset
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/RemoveMacAI"
cp LICENSE THIRD-PARTY-NOTICES.md "$app/Contents/Resources/"

# Translations: Localization/<language>.lproj. English is the source language, so
# it needs no folder; the keys are the English strings in the code.
cp -R Localization/*.lproj "$app/Contents/Resources/"
languages="<string>en</string>"
for dir in Localization/*.lproj; do languages+="<string>$(basename "$dir" .lproj)</string>"; done

mkdir -p .build/AppIcon.iconset
for size in 16 32 128 256 512; do
  sips -z $size $size tools/AppIcon.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) tools/AppIcon.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array>$languages</array>
  <key>CFBundleExecutable</key><string>RemoveMacAI</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.omlahore.removemacai.app</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>RemoveMacAI</string>
  <key>CFBundleDisplayName</key><string>RemoveMacAI</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>$version</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License. Apple Intelligence removal builds on pared by 4evy.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "$app ($version)"
