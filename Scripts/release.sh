#!/bin/bash
# Publishes a release: builds the universal app, creates the GitHub release, and
# updates Casks/barmod.rb in Jasurito/homebrew-tap.
#
# Runs on this Mac because releases must be signed with the identity in
# .signing/, which keeps users' Accessibility grant across upgrades.
#
# Usage: Scripts/release.sh 1.2.0
set -euo pipefail

VERSION="${1:?usage: Scripts/release.sh VERSION}"
TAG="v$VERSION"
REPO=Jasurito/BarMod
TAP=Jasurito/homebrew-tap
CASK_PATH=Casks/barmod.rb
TAP_MESSAGE="${TAP_COMMIT_MESSAGE:-barmod $VERSION}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit your changes first." >&2
  exit 1
fi

VERSION="$VERSION" ARCHS="arm64 x86_64" "$ROOT/Scripts/build.sh"

ZIP="BarMod-$VERSION.zip"
(cd build && rm -f "$ZIP" && ditto -c -k --norsrc --noextattr --noacl --keepParent BarMod.app "$ZIP")
SHA256="$(shasum -a 256 "build/$ZIP" | cut -d' ' -f1)"

git tag "$TAG"
git push origin main "$TAG"
gh release create "$TAG" "build/$ZIP" --repo "$REPO" --title "BarMod $VERSION" --generate-notes --verify-tag

CASK="$(sed -e '/^# /d' -e "s/@VERSION@/$VERSION/" -e "s/@SHA256@/$SHA256/" packaging/barmod.rb)"
CURRENT_SHA="$(gh api "repos/$TAP/contents/$CASK_PATH" --jq .sha 2>/dev/null || true)"
gh api -X PUT "repos/$TAP/contents/$CASK_PATH" \
  -f message="$TAP_MESSAGE" \
  -f content="$(printf '%s\n' "$CASK" | base64)" \
  ${CURRENT_SHA:+-f sha="$CURRENT_SHA"} \
  --silent

echo "Released $VERSION: brew install --cask jasurito/tap/barmod"
