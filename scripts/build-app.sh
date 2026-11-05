#!/usr/bin/env bash
# Builds "MacOS Storage Optimiser.app" into dist/.
# Ad-hoc signed: fine for local use and GitHub releases (users may need to
# right-click > Open the first time because it is not notarized).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacOS Storage Optimiser"
EXECUTABLE="MacOSStorageOptimiser"
BUNDLE_ID="com.merajc.MacOSStorageOptimiser"
VERSION="1.0.0"
DIST="${ROOT}/dist"
APP="${DIST}/${APP_NAME}.app"
ICON="${ROOT}/app/Resources/AppIcon.icns"

echo "▸ Building release binary…"
swift build -c release --package-path "${ROOT}/app"

echo "▸ Assembling ${APP_NAME}.app…"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "${ROOT}/app/.build/release/${EXECUTABLE}" "${APP}/Contents/MacOS/${EXECUTABLE}"
install -m 755 "${ROOT}/bin/macos-system-data" "${APP}/Contents/Resources/macos-system-data"

if [[ ! -f "${ICON}" ]]; then
    echo "▸ Generating app icon…"
    mkdir -p "${ROOT}/app/Resources"
    TMP_ICONSET="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "${TMP_ICONSET}"
    MASTER="$(mktemp -d)/icon_1024.png"
    swift "${ROOT}/scripts/make-icon.swift" "${MASTER}" >/dev/null
    ICONSET_SPECS=(
        "16:16:" "32:16:@2x" "32:32:" "64:32:@2x" "128:128:"
        "256:128:@2x" "256:256:" "512:256:@2x" "512:512:" "1024:512:@2x"
    )
    for spec in "${ICONSET_SPECS[@]}"; do
        IFS=':' read -r actual logical suffix <<< "${spec}"
        sips -z "${actual}" "${actual}" "${MASTER}" \
            --out "${TMP_ICONSET}/icon_${logical}x${logical}${suffix}.png" >/dev/null 2>&1
    done
    iconutil -c icns "${TMP_ICONSET}" -o "${ICON}"
fi
cp "${ICON}" "${APP}/Contents/Resources/AppIcon.icns"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License · macos-system-data</string>
</dict>
</plist>
PLIST

echo "▸ Signing (ad-hoc)…"
codesign --force --deep --sign - "${APP}" >/dev/null 2>&1

echo ""
echo "✔ Built: ${APP}"
echo "  Run with: open \"${APP}\""
echo "  Size:     $(du -sh "${APP}" | awk '{print $1}')"
