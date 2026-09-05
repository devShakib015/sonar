#!/bin/bash
# Builds Sonar.app (release, ad-hoc signed) and packages Sonar.dmg for distribution.
set -e
cd "$(dirname "$0")"

echo "▸ Building release binary…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Sonar"

APP="Sonar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Sonar"
[ -f Sonar.icns ] && cp Sonar.icns "$APP/Contents/Resources/Sonar.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Sonar</string>
  <key>CFBundleDisplayName</key><string>Sonar</string>
  <key>CFBundleIdentifier</key><string>com.shakib.sonar</string>
  <key>CFBundleVersion</key><string>2.0.0</string>
  <key>CFBundleShortVersionString</key><string>2.0.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>Sonar</string>
  <key>CFBundleIconFile</key><string>Sonar</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Sonar lists the devices connected to your local network and the services they expose.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Sonar uses your location only to read the Wi-Fi network name and scan for nearby access points, which macOS requires for Wi-Fi details.</string>
  <key>NSAppTransportSecurity</key>
  <dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict>
</plist>
PLIST

echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP" 2>/dev/null || echo "  (codesign skipped)"

echo "▸ Building DMG…"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f Sonar.dmg
hdiutil create -volname "Sonar" -srcfolder "$STAGE" -ov -format UDZO Sonar.dmg >/dev/null
rm -rf "$STAGE"

echo "✓ Built $APP and Sonar.dmg"
