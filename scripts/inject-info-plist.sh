#!/bin/bash
# Inject CFBundleURLTypes + LSApplicationQueriesSchemes into the generated Info.plist.
# Runs as an Xcode Build Phase after Process Info.plist, before codesign.
# Required env vars: TARGET_BUILD_DIR, INFOPLIST_PATH, PRODUCT_BUNDLE_IDENTIFIER.

set -e

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST" ]; then
    echo "warning: inject-info-plist.sh: Info.plist not found at $PLIST"
    exit 0
fi

PB="/usr/libexec/PlistBuddy"
URL_NAME="${PRODUCT_BUNDLE_IDENTIFIER}.msal"
URL_SCHEME="msauth.${PRODUCT_BUNDLE_IDENTIFIER}"

$PB -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLName string ${URL_NAME}" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string ${URL_SCHEME}" "$PLIST"

$PB -c "Delete :LSApplicationQueriesSchemes" "$PLIST" 2>/dev/null || true
$PB -c "Add :LSApplicationQueriesSchemes array" "$PLIST"
$PB -c "Add :LSApplicationQueriesSchemes:0 string msauthv2" "$PLIST"
$PB -c "Add :LSApplicationQueriesSchemes:1 string msauthv3" "$PLIST"

echo "inject-info-plist.sh: injected MSAL URL scheme ${URL_SCHEME} into $PLIST"
