#!/bin/sh
# Builds a signed DMG of the app at a version, and with `publish` notarizes it and makes a GitHub release.
# Usage: release.sh build|publish x.y.z
# PUBLIC_KEY and BUILD replace the Keychain update key and the commit count, for a test build.
set -e
stage=$1
version=$2
team=NNK86LQK58
profile=openspot
out=.temp/release
archive=$out/Openspot.xcarchive
dmg=$out/Openspot-$version.dmg
packages=.temp/packages
tools=$packages/artifacts/sparkle/Sparkle/bin
account=openspot
build=${BUILD:-$(git rev-list --count HEAD)}
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
mkdir -p "$out"
(cd app && xcodegen generate >/dev/null)
xcodebuild -resolvePackageDependencies -project app/Openspot.xcodeproj -scheme Openspot \
  -clonedSourcePackagesDirPath "$packages" >"$out/build.log" 2>&1 || fail "Sparkle did not download. See $out/build.log"
public_key=${PUBLIC_KEY:-$("$tools/generate_keys" --account "$account" -p 2>/dev/null)} \
  || fail "Make the update key first, once, and back it up: $tools/generate_keys --account $account"

xcodebuild -project app/Openspot.xcodeproj -scheme Openspot -configuration Release -destination 'generic/platform=macOS' \
  -clonedSourcePackagesDirPath "$packages" -archivePath "$archive" archive \
  MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build" \
  UPDATE_PUBLIC_KEY="$public_key" \
  DEVELOPMENT_TEAM="$team" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS=--timestamp >>"$out/build.log" 2>&1 || fail "The build failed. See $out/build.log"

/usr/libexec/PlistBuddy -c "Add :method string developer-id" \
  -c "Add :teamID string $team" \
  -c "Add :signingStyle string manual" \
  -c "Add :signingCertificate string Developer ID Application" "$out/export.plist" >/dev/null
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out/export" -exportOptionsPlist "$out/export.plist" \
  >>"$out/build.log" 2>&1 || fail "The export failed. See $out/build.log"

sh scripts/dmg.sh "$out/export/Openspot.app" "$dmg"
codesign --sign "Developer ID Application" --timestamp "$dmg"

if [ "$stage" = publish ]; then
  echo "Apple is checking the DMG. This takes some minutes, so keep this terminal open."
  echo "Then the script staples the result and publishes v$version."
  echo "If you stop it, run this to start again: make release V=$version"
  xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
  xcrun stapler staple "$dmg"
  url=https://github.com/celishq/openspot/releases/download/v$version/$(basename "$dmg")
  sh scripts/appcast.sh "$version" "$build" "$url" "$("$tools/sign_update" --account "$account" "$dmg")" >"$out/appcast.xml"
  gh release create "v$version" "$dmg" "$out/appcast.xml" --draft --target "$(git rev-parse HEAD)" --title "$version" --generate-notes
  gh release edit "v$version" --draft=false --latest
fi

echo "$dmg"
