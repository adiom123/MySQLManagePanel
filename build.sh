#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

PANE="build/MySQL.prefPane"
rm -rf build
mkdir -p "$PANE/Contents/MacOS" "$PANE/Contents/Resources"

clang -bundle -fobjc-arc -fobjc-arc-exceptions \
    -mmacosx-version-min=13.0 \
    -arch arm64 -arch x86_64 \
    -framework Cocoa -framework PreferencePanes \
    -o "$PANE/Contents/MacOS/MySQL" \
    src/MySQLPref.m

cp Info.plist "$PANE/Contents/Info.plist"
cp Resources/mysqlPref.tiff Resources/mysql_logo.png "$PANE/Contents/Resources/"

codesign --force --deep --sign - "$PANE"

echo "构建完成：$PANE"
