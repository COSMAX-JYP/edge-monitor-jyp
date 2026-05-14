#!/bin/bash
# Run all unit tests with code signing disabled (workaround for macOS 26 beta CodeSign issue).
# Usage: bash scripts/test.sh
set -e
cd "$(dirname "$0")/.."
xcodebuild test \
  -project EdgeLauncher.xcodeproj \
  -scheme EdgeLauncher \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -quiet \
  "$@" 2>&1 | tail -40
