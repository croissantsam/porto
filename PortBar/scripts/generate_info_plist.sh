#!/bin/bash
# Generate Info.plist for Porto.app
# Usage: ./generate_info_plist.sh <output_path> <version> <build_number>

set -eu

OUTPUT_PATH="$1"
VERSION="$2"
BUILD_NUMBER="$3"

python3 <<PYEOF > "$OUTPUT_PATH"
import plistlib, sys
plist = {
    "CFBundleName": "Porto",
    "CFBundleExecutable": "Porto",
    "CFBundleIdentifier": "com.porto.Porto",
    "CFBundlePackageType": "APPL",
    "CFBundleVersion": "${BUILD_NUMBER}",
    "CFBundleShortVersionString": "${VERSION}",
    "LSUIElement": True,
}
plistlib.dump(plist, sys.stdout.buffer, fmt=plistlib.FMT_XML)
PYEOF