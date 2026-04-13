#!/usr/bin/env bash
# Build the ASCII Chart app and wrap it in a proper .app bundle,
# including a generated AppIcon.icns.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ASCII Chart"
EXE_NAME="AsciiChartApp"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

# --- 1) Generate AppIcon.icns ------------------------------------------------
echo "==> Generating app icon"
swift generate-icon.swift

ICONSET_DIR="build/AppIcon.iconset"
ICNS_PATH="build/AppIcon.icns"
rm -rf "${ICONSET_DIR}" "${ICNS_PATH}"
mkdir -p "${ICONSET_DIR}"

# Required sizes per Apple's iconset convention.
# Each entry: "<dest-filename>:<pixels>"
SIZES=(
    "icon_16x16.png:16"
    "icon_16x16@2x.png:32"
    "icon_32x32.png:32"
    "icon_32x32@2x.png:64"
    "icon_128x128.png:128"
    "icon_128x128@2x.png:256"
    "icon_256x256.png:256"
    "icon_256x256@2x.png:512"
    "icon_512x512.png:512"
    "icon_512x512@2x.png:1024"
)
for entry in "${SIZES[@]}"; do
    name="${entry%%:*}"
    px="${entry##*:}"
    sips -z "${px}" "${px}" icon-1024.png --out "${ICONSET_DIR}/${name}" \
        >/dev/null 2>&1
done
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"

# --- 2) Build release executable --------------------------------------------
echo "==> Building release executable"
swift build -c release

# --- 3) Assemble the .app bundle --------------------------------------------
echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${EXE_NAME}" "${APP_DIR}/Contents/MacOS/${EXE_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"
cp "${ICNS_PATH}" "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Ad-hoc codesign so Gatekeeper / quarantine is happier when launched locally.
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

# Touch the bundle so Finder notices the new icon immediately.
touch "${APP_DIR}"

echo "==> Done. App is at: ${APP_DIR}"
echo "    Run it with:    open \"${APP_DIR}\""
echo "    Or move it to:  /Applications/"
