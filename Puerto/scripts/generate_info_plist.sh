#!/bin/bash
# Generate Info.plist for Puerto.app
# Usage: ./generate_info_plist.sh <output_path> <version> <build_number>

set -eu

OUTPUT_PATH="$1"
VERSION="$2"
BUILD_NUMBER="$3"

python3 <<PYEOF > "$OUTPUT_PATH"
import plistlib, sys
plist = {
    "CFBundleName": "Puerto",
    "CFBundleExecutable": "Puerto",
    "CFBundleIdentifier": "com.puerto.Puerto",
    "CFBundlePackageType": "APPL",
    "CFBundleVersion": "${BUILD_NUMBER}",
    "CFBundleShortVersionString": "${VERSION}",
    "CFBundleIconFile": "AppIcon",
    "LSUIElement": True,
}
plistlib.dump(plist, sys.stdout.buffer, fmt=plistlib.FMT_XML)
PYEOF