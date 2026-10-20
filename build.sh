#!/bin/zsh
# Builds ScrollFlip.app next to this script (ad-hoc signed).
# The icon is ScrollFlip.icon (Icon Composer), light and dark; compiling it needs Xcode.
set -eu
cd ${0:a:h}
app=ScrollFlip.app
pkill -x ScrollFlip || true
rm -rf $app
mkdir -p $app/Contents/MacOS $app/Contents/Resources
tmp=$(mktemp -d)
xcrun actool ScrollFlip.icon --compile $app/Contents/Resources --platform macosx \
  --minimum-deployment-target 13.0 --app-icon ScrollFlip \
  --output-partial-info-plist $tmp/icon.plist >/dev/null
rm -rf $tmp
cp Resources/* $app/Contents/Resources/
swiftc -O -o $app/Contents/MacOS/ScrollFlip *.swift
cat > $app/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ScrollFlip</string>
  <key>CFBundleIdentifier</key><string>com.raul.scrollflip</string>
  <key>CFBundleExecutable</key><string>ScrollFlip</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>CFBundleIconName</key><string>ScrollFlip</string>
  <key>CFBundleIconFile</key><string>ScrollFlip</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
# Ad-hoc signatures are normally identified by their hash, which changes with every build and makes macOS
# forget the Accessibility permission. Requiring only the bundle identifier keeps the permission across builds.
codesign --force -s - -r='designated => identifier "com.raul.scrollflip"' $app
echo "Built $PWD/$app"
