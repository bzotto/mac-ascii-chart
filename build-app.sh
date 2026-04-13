#!/usr/bin/env bash
# Build the ASCII Chart app and wrap it in a proper .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ASCII Chart"
EXE_NAME="AsciiChartApp"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

echo "==> Building release executable"
swift build -c release

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${EXE_NAME}" "${APP_DIR}/Contents/MacOS/${EXE_NAME}"
cp Info.plist "${APP_DIR}/Contents/Info.plist"

# Ad-hoc codesign so Gatekeeper / quarantine is happier when launched locally.
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "==> Done. App is at: ${APP_DIR}"
echo "    Run it with:    open \"${APP_DIR}\""
echo "    Or move it to:  /Applications/"
