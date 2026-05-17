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
ENTITLEMENTS_PATH="$APP_NAME/$APP_NAME.entitlements"

# 버전 자동 증가 (patch +1). `--no-bump` 옵션으로 스킵 가능.
BUMP=1
for arg in "$@"; do
  case "$arg" in
    --no-bump|--keep-version) BUMP=0 ;;
  esac
done

echo "[1/6] 버전 자동 증가..."
PROJ_FILE="$APP_NAME.xcodeproj/project.pbxproj"
CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJ_FILE" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')
if [ "$BUMP" -eq 1 ] && [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
  NEW_PATCH=$((PATCH + 1))
  NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
  sed -i '' -E "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $NEW_VERSION;/g" "$PROJ_FILE"
  echo "  → $CURRENT_VERSION → $NEW_VERSION"
elif [ "$BUMP" -eq 0 ]; then
  echo "  → --no-bump 지정: 버전 유지 ($CURRENT_VERSION)"
else
  echo "  → 현재 버전 ($CURRENT_VERSION) 형식 인식 실패, 스킵"
fi

echo "[2/6] Release 빌드 (캐시 활용, 첫 빌드는 수 분 소요)..."
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

echo "[3/6] 실행 중인 기존 앱 종료..."
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
pkill -f "Applications/$APP_NAME.app" 2>/dev/null || true
sleep 1

echo "[4/6] 기존 설치 제거..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_PATH"

echo "[5/6] $INSTALL_PATH 에 복사..."
cp -R "$PRODUCT_PATH" "$INSTALL_PATH"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

# Apple Development 인증서로 안정적 서명 → 매번 리빌드해도 TCC(Input Monitoring/Accessibility) 유지.
DEV_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')
if [ -n "$DEV_IDENTITY" ]; then
  echo "  → Apple Development 인증서로 서명: $DEV_IDENTITY"
  codesign --force --deep --sign "$DEV_IDENTITY" --options=runtime --entitlements "$ENTITLEMENTS_PATH" "$INSTALL_PATH" 2>&1 | tail -3 || true
else
  echo "  → Apple Development 인증서 없음, ad-hoc 서명 유지"
fi

echo "[6/6] 실행..."
open "$INSTALL_PATH"

FINAL_VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJ_FILE" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')
echo ""
echo "완료: $INSTALL_PATH (v$FINAL_VERSION)"
