#!/usr/bin/env bash
# Builds, signs (Developer ID), notarizes, staples and publishes a GitHub Release.
#
# Usage: scripts/release.sh <version>      e.g. scripts/release.sh 0.1.0
#
# One-time setup:
#   - A "Developer ID Application" certificate in the login keychain.
#   - A notarytool keychain profile named "notarytool":
#       xcrun notarytool store-credentials notarytool --apple-id <apple-id> --team-id <team-id>
#   - gh CLI authenticated (gh auth status).
set -euo pipefail

VERSION="${1:-}"
[[ -n "$VERSION" ]] || { echo "usage: $0 <version>  (e.g. 0.1.0)"; exit 1; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 1.2.3"; exit 1; }

APP_NAME="NotchPrompter"
SCHEME="NotchPrompter"
TAG="v$VERSION"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
BUILD="$DIST/build"
APP="$BUILD/Build/Products/Release/$APP_NAME.app"
ZIP="$DIST/$APP_NAME-$VERSION.zip"

cd "$ROOT"

# --- Preflight -------------------------------------------------------------
[[ -z "$(git status --porcelain)" ]] || { echo "working tree is not clean"; exit 1; }
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "tag $TAG already exists"; exit 1; }

IDENTITY="$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')"
[[ -n "$IDENTITY" ]] || { echo "no Developer ID Application certificate found"; exit 1; }
TEAM_ID="$(echo "$IDENTITY" | sed -E 's/.*\(([A-Z0-9]+)\)$/\1/')"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || { echo "notarytool profile '$NOTARY_PROFILE' not found; run: xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <apple-id> --team-id $TEAM_ID"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated"; exit 1; }

echo "==> Releasing $APP_NAME $VERSION as $IDENTITY"
rm -rf "$DIST"
mkdir -p "$DIST"

# --- Build + sign ------------------------------------------------------------
xcodegen generate >/dev/null
xcodebuild build \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES \
  ENABLE_TESTABILITY=NO \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
  | grep -E "error:|warning: |BUILD (SUCCEEDED|FAILED)" || true
[[ -d "$APP" ]] || { echo "build failed: $APP not found"; exit 1; }

codesign --verify --deep --strict --verbose=2 "$APP"
if codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "get-task-allow"; then
  echo "binary carries com.apple.security.get-task-allow; notarization would reject it"; exit 1
fi

# --- Notarize + staple -------------------------------------------------------
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> Submitting to notarization (this can take a few minutes)"
SUBMIT_OUTPUT="$(xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee /dev/stderr)"
if ! grep -q "status: Accepted" <<<"$SUBMIT_OUTPUT"; then
  SUBMISSION_ID="$(grep -m1 -E '^\s*id:' <<<"$SUBMIT_OUTPUT" | awk '{print $2}')"
  echo "notarization failed; details: xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE"
  exit 1
fi
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Gatekeeper assessment"
spctl --assess --type execute --verbose=2 "$APP"

# --- Tag + GitHub Release ----------------------------------------------------
git tag -a "$TAG" -m "$APP_NAME $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$ZIP" \
  --title "$APP_NAME $VERSION" \
  --generate-notes

echo "==> Done: $ZIP"
