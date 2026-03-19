#!/bin/bash
set -e

VERSION="${1:-1.0.5}"
APP_NAME="CodeStation"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT="${REPO_ROOT}/CodeStation.xcodeproj"
SCHEME="CodeStation"
BUILD_DIR="${REPO_ROOT}/build"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "Building ${APP_NAME} ${VERSION}..."

# Clean build dir
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build Release
XCODEBUILD_ARGS=(
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -configuration Release
  -derivedDataPath "${BUILD_DIR}/derived"
  CODE_SIGN_IDENTITY="-"
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGNING_ALLOWED=NO
  build
)

if command -v xcpretty &>/dev/null; then
  xcodebuild "${XCODEBUILD_ARGS[@]}" | xcpretty
else
  xcodebuild "${XCODEBUILD_ARGS[@]}"
fi

APP_PATH="${BUILD_DIR}/derived/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
  echo "Error: app not found at ${APP_PATH}"
  exit 1
fi

echo "App built at ${APP_PATH}"

# Create DMG staging folder
STAGING="${BUILD_DIR}/dmg_staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -r "${APP_PATH}" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"

# Create the DMG
DMG_TEMP="${BUILD_DIR}/${APP_NAME}_tmp.dmg"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}"

hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "${STAGING}" \
  -ov \
  -format UDRW \
  "${DMG_TEMP}"

# Convert to compressed read-only DMG
hdiutil convert "${DMG_TEMP}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${DMG_FINAL}"

rm -f "${DMG_TEMP}"
rm -rf "${STAGING}"

echo ""
echo "Done: ${BUILD_DIR}/${DMG_NAME}"
ls -lh "${DMG_FINAL}"
