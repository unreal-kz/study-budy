#!/usr/bin/env bash
# Regenerate platform icon sets from design/brand/png/ via flutter_launcher_icons.
#
# flutter_launcher_icons 0.14.4 rewrites
#   ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES
# to "= AppIcon;" in ios/Runner.xcodeproj/project.pbxproj (an invalid boolean;
# the real APPICON_NAME setting is already correct). Save the file and put it
# back after the run so that unrelated pbxproj edits are never lost.
set -euo pipefail

cd "$(dirname "$0")/../.."
PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
BACKUP="$(mktemp)"
trap 'rm -f "$BACKUP"' EXIT

cp "$PBXPROJ" "$BACKUP"
dart run flutter_launcher_icons
cp "$BACKUP" "$PBXPROJ"
echo "restored $PBXPROJ (plugin edit discarded)"

# The plugin also rewrites web/manifest.json without its trailing newline.
if [[ -n "$(tail -c1 web/manifest.json)" ]]; then
  echo >> web/manifest.json
fi
