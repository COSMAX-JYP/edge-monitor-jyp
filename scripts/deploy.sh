#!/bin/bash
# EdgeLauncher 빌드 + 재설치 + 실행 한 번에.
# Usage: bash scripts/deploy.sh

set -e
cd "$(dirname "$0")/.."

APP_NAME="EdgeLauncher"
INSTALL_DIR="$HOME/Applications"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME.app"
BUILD_DIR="build"
PRODUCT_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

echo "[1/5] Release 빌드 (캐시 활용, 첫 빌드는 수 분 소요)..."
xcodebuild -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [ ! -d "$PRODUCT_PATH" ]; then
  echo "Error: 빌드 산출물을 찾을 수 없음 ($PRODUCT_PATH)" >&2
  exit 1
fi

echo "[2/5] 실행 중인 기존 앱 종료..."
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
pkill -f "Applications/$APP_NAME.app" 2>/dev/null || true
sleep 1

echo "[3/5] 기존 설치 제거..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_PATH"

echo "[4/5] $INSTALL_PATH 에 복사..."
cp -R "$PRODUCT_PATH" "$INSTALL_PATH"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "[5/5] 실행..."
open "$INSTALL_PATH"

echo ""
echo "완료: $INSTALL_PATH"
