#!/usr/bin/env bash
# Build, sign and (optionally) upload the iOS app to TestFlight.
#
# Usage:
#   scripts/ios_testflight.sh            # archive + export IPA to build/ios/testflight/ipa
#   scripts/ios_testflight.sh --upload   # ... and upload the IPA to App Store Connect
#
# Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_TEAM_ID from .env.appstore (gitignored).
# The API key lives outside the repo: ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8
# The shared app token is read from .app_token.txt (gitignored).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROD_URL="https://study-buddy-server-pudn.onrender.com"
OUT_DIR="$ROOT/build/ios/testflight"
ARCHIVE="$OUT_DIR/Runner.xcarchive"
IPA_DIR="$OUT_DIR/ipa"

UPLOAD=0
case "${1:-}" in
  "") ;;
  --upload) UPLOAD=1 ;;
  *) echo "usage: $0 [--upload]" >&2; exit 2 ;;
esac

if [[ ! -f .env.appstore ]]; then
  echo "missing .env.appstore (need ASC_KEY_ID, ASC_ISSUER_ID, ASC_TEAM_ID)" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. ./.env.appstore
set +a
: "${ASC_KEY_ID:?set ASC_KEY_ID in .env.appstore}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID in .env.appstore}"
: "${ASC_TEAM_ID:?set ASC_TEAM_ID in .env.appstore}"

KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
if [[ ! -f "$KEY_PATH" ]]; then
  echo "missing API key file: $KEY_PATH" >&2
  exit 1
fi
if [[ ! -s .app_token.txt ]]; then
  echo "missing or empty .app_token.txt" >&2
  exit 1
fi
APP_TOKEN="$(tr -d '[:space:]' < .app_token.txt)"

# Monotonic, deterministic build number. TestFlight rejects a repeated number per version.
BUILD_NUMBER="$(git rev-list --count HEAD)"
echo "build number: $BUILD_NUMBER"

AUTH_ARGS=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

EXPORT_PLIST="$OUT_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${ASC_TEAM_ID}</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
plutil -lint "$EXPORT_PLIST" >/dev/null

# Writes ios/Flutter/Generated.xcconfig (version, build number, DART_DEFINES) without building.
flutter build ios --config-only --release \
  --build-number="$BUILD_NUMBER" \
  --dart-define=BACKEND_BASE_URL="$PROD_URL" \
  --dart-define=APP_TOKEN="$APP_TOKEN"

xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$ASC_TEAM_ID" \
  "${AUTH_ARGS[@]}"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$IPA_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  "${AUTH_ARGS[@]}"

IPA="$(find "$IPA_DIR" -maxdepth 1 -name '*.ipa' | head -n 1)"
if [[ -z "$IPA" ]]; then
  echo "export produced no .ipa in $IPA_DIR" >&2
  exit 1
fi
echo "IPA: $IPA"

if [[ "$UPLOAD" -eq 1 ]]; then
  xcrun altool --upload-app -f "$IPA" \
    --api-key "$ASC_KEY_ID" \
    --api-issuer "$ASC_ISSUER_ID" \
    --show-progress
else
  echo "skipping upload (pass --upload to send to App Store Connect)"
fi
