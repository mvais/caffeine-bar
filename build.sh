#!/bin/sh
# Builds Caffeinate.app — a menu bar toggle for /usr/bin/caffeinate
set -e
cd "$(dirname "$0")"

APP=Caffeinate.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

# ponytail: building the ObjC port — installed Swift CLT has a broken SDK/compiler
# mismatch; switch back to `swiftc -O main.swift -o ...` once Apple ships a fixed CLT.
clang -O2 -fobjc-arc -framework AppKit main.m -o "$APP/Contents/MacOS/Caffeinate"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Caffeinate</string>
    <key>CFBundleIdentifier</key><string>local.caffeinate-menubar</string>
    <key>CFBundleName</key><string>Caffeinate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP — run with: open $APP"
