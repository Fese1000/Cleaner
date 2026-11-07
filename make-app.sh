#!/bin/bash
# Baut Cleaner.app (nativ, SwiftUI) und packt sie als DMG.
# Aufruf: ./make-app.sh [arm64|x86_64|all]   (Standard: Architektur dieses Macs)
# Ergebnis: dist/Cleaner-AppleSilicon.dmg und/oder dist/Cleaner-Intel.dmg
# Nötig: Xcode Command Line Tools (swiftc). Echte Signatur: CODESIGN_ID="Developer ID Application: ..."
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DIST="$SRC/dist"
VERSION="$(tr -d '[:space:]' < "$SRC/VERSION")"
mkdir -p "$DIST"

build() {  # $1 = arm64|x86_64
  local arch="$1" label; [ "$arch" = arm64 ] && label=AppleSilicon || label=Intel
  local stage="$SRC/build/$label" app="$SRC/build/$label/Cleaner.app"
  rm -rf "$stage"; mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$SRC/assets/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos13" \
    "$SRC"/Sources/Cleaner/*.swift -o "$app/Contents/MacOS/Cleaner"
  cat > "$app/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Cleaner</string>
<key>CFBundleDisplayName</key><string>Cleaner</string>
<key>CFBundleIdentifier</key><string>de.felix.cleaner</string>
<key>CFBundleExecutable</key><string>Cleaner</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSDesktopFolderUsageDescription</key><string>Cleaner durchsucht den Schreibtisch nach großen und veralteten Dateien.</string>
<key>NSDocumentsFolderUsageDescription</key><string>Cleaner durchsucht Dokumente nach großen, veralteten und doppelten Dateien.</string>
<key>NSDownloadsFolderUsageDescription</key><string>Cleaner zeigt dir, was im Downloads-Ordner Platz belegt.</string>
<key>NSRemovableVolumesUsageDescription</key><string>Cleaner kann externe Volumes im Explorer anzeigen.</string>
</dict></plist>
PL
  # Ad-hoc-Signatur (nötig für Apple Silicon); echte Signatur über CODESIGN_ID
  codesign --force --deep --sign "${CODESIGN_ID:--}" "$app"
  ln -s /Applications "$stage/Applications"
  rm -f "$DIST/Cleaner-$label.dmg"
  hdiutil create -quiet -volname Cleaner -srcfolder "$stage" -ov -format UDZO "$DIST/Cleaner-$label.dmg"
  echo "Fertig: $DIST/Cleaner-$label.dmg"
}

case "${1:-$(uname -m)}" in
  arm64)  build arm64 ;;
  x86_64) build x86_64 ;;
  all)    build arm64; build x86_64 ;;
  *) echo "Aufruf: $0 [arm64|x86_64|all]"; exit 1 ;;
esac
