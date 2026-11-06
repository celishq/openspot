#!/bin/sh
# Builds a signed DMG of the app at a version, and with `publish` notarizes it and makes a GitHub release.
# Usage: release.sh build|publish x.y.z
set -e
stage=$1
version=$2
team=NNK86LQK58
profile=openspot
out=.temp/release
archive=$out/Openspot.xcarchive
dmg=$out/Openspot-$version.dmg
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

fail() {
  echo "$1" >&2
  exit 1
}

echo "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "Give a version: make release V=1.2.3"

if [ "$stage" = publish ]; then
  [ -z "$(git status --porcelain)" ] || fail "Commit or remove your changes first."
  [ "$(git branch --show-current)" = main ] || fail "Release from main."
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || fail "Make main match origin/main first."
  ! gh release view "v$version" >/dev/null 2>&1 || fail "Release v$version already exists."
  xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1 \
    || fail "Store your notary login first: xcrun notarytool store-credentials $profile --team-id $team --apple-id <your Apple ID>"
  make verify
fi

rm -rf "$out"
mkdir -p "$out/disk"
(cd app && xcodegen generate >/dev/null)

xcodebuild -project app/Openspot.xcodeproj -scheme Openspot -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$archive" archive \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
  DEVELOPMENT_TEAM="$team" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS=--timestamp >"$out/build.log" 2>&1 || fail "The build failed. See $out/build.log"

/usr/libexec/PlistBuddy -c "Add :method string developer-id" \
  -c "Add :teamID string $team" \
  -c "Add :signingStyle string manual" \
  -c "Add :signingCertificate string Developer ID Application" "$out/export.plist" >/dev/null
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$out/export.plist" \
  >>"$out/build.log" 2>&1 || fail "The export failed. See $out/build.log"

ditto "$out/export/Openspot.app" "$out/disk/Openspot.app"
ln -s /Applications "$out/disk/Applications"
hdiutil create -quiet -volname Openspot -srcfolder "$out/disk" -fs APFS -format ULFO "$dmg"
codesign --sign "Developer ID Application" --timestamp "$dmg"

if [ "$stage" = publish ]; then
  echo "Apple is checking the DMG. This takes some minutes, so keep this terminal open."
  echo "Then the script staples the result and publishes v$version."
  echo "If you stop it, run this to start again: make release V=$version"
  xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
  xcrun stapler staple "$dmg"
  gh release create "v$version" "$dmg" --draft --target "$(git rev-parse HEAD)" --title "$version" --generate-notes
  gh release edit "v$version" --draft=false --latest
fi

echo "$dmg"
