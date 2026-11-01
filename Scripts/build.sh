#!/bin/bash
# Builds, bundles and signs build/BarMod.app.
# VERSION stamps the bundle. ARCHS picks architectures, for example "arm64 x86_64".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
"$ROOT/Scripts/make-signing-identity.sh"

VERSION="${VERSION:-0.0.0-dev}"
ARCHS="${ARCHS:-$(uname -m)}"

BINARIES=()
for arch in $ARCHS; do
  triple="$arch-apple-macosx14.0"
  swift build -c release --product BarMod --triple "$triple"
  BINARIES+=("$(swift build -c release --triple "$triple" --show-bin-path)/BarMod")
done

APP="$ROOT/build/BarMod.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/BarMod"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleShortVersionString $VERSION" \
  -c "Set :CFBundleVersion $VERSION" \
  "$APP/Contents/Info.plist"

KEYCHAIN="$ROOT/.signing/barmod-signing.keychain-db"
security unlock-keychain -p "$(cat "$ROOT/.signing/keychain-password")" "$KEYCHAIN"
IDENTITY="$(security find-certificate -c 'BarMod Local Signing' -Z "$KEYCHAIN" | awk '/SHA-1/ {print $NF}')"

# codesign only finds a self-signed identity on the search list, so add the
# private keychain just while signing.
SEARCH_LIST=()
while IFS= read -r line; do
  line="${line//\"/}"
  SEARCH_LIST+=("${line#"${line%%[![:space:]]*}"}")
done < <(security list-keychains -d user)
trap 'security list-keychains -d user -s "${SEARCH_LIST[@]}"' EXIT
security list-keychains -d user -s "$KEYCHAIN" "${SEARCH_LIST[@]}"

codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
echo "Built $APP"
