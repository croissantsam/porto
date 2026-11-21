#!/bin/sh
# Builds Puerto and assembles a double-clickable Puerto.app bundle.

set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/Puerto.app"

# Version must match the CI workflow, otherwise the in-app update check
# compares against the wrong version (a hardcoded "1.0" always looks newer
# than every 0.0.x release, so updates would never be detected).
cd "$root"
if git describe --tags --exact-match 2>/dev/null | grep -q '^v'; then
  VERSION=$(git describe --tags --exact-match | sed 's/^v//')
else
  VERSION="0.0.$(git rev-list --count HEAD)-$(git rev-parse --short HEAD)"
fi
BUILD_NUMBER=$(git rev-list --count HEAD)

swift build --package-path "$root" -c release

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Puerto</string>
    <key>CFBundleExecutable</key><string>Puerto</string>
    <key>CFBundleIdentifier</key><string>com.puerto.Puerto</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp "$root/.build/release/Puerto" "$app/Contents/MacOS/Puerto"
chmod +x "$app/Contents/MacOS/Puerto"

plutil -lint "$app/Contents/Info.plist"

echo "Built $app"
open "$app"