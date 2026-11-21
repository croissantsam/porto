#!/bin/sh
# Builds Porto and assembles a double-clickable Porto.app bundle.

set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/Porto.app"

swift build --package-path "$root" -c release

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Porto</string>
    <key>CFBundleExecutable</key><string>Porto</string>
    <key>CFBundleIdentifier</key><string>com.porto.Porto</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

cp "$root/.build/release/Porto" "$app/Contents/MacOS/Porto"
chmod +x "$app/Contents/MacOS/Porto"

plutil -lint "$app/Contents/Info.plist"

echo "Built $app"
open "$app"