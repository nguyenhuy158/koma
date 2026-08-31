#!/bin/bash
# Build Koma and package an unsigned .ipa into build/. Sideloadly does the signing.
set -euo pipefail
cd "$(dirname "$0")"

# Fixed derived-data path: parsing it back out of the log broke on multi-match lines.
xcodebuild -scheme Koma -sdk iphoneos -configuration Release \
  -derivedDataPath build/dd \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build > /tmp/koma-build.log || { grep -E 'error:|BUILD FAILED' /tmp/koma-build.log | head; exit 1; }

APP=build/dd/Build/Products/Release-iphoneos/Koma.app
[ -d "$APP" ] || { echo "Koma.app not found at $APP"; exit 1; }

rm -rf build/Payload && mkdir -p build/Payload
cp -R "$APP" build/Payload/
rm -f build/Koma.ipa
(cd build && zip -qry Koma.ipa Payload && rm -rf Payload)

echo "→ $(pwd)/build/Koma.ipa"
