#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ReadArc"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/dist/releases"
REPO="Zanetach/ReadArc"
VERSION=""
TAG=""
TITLE=""
NOTARY_PROFILE="${READARC_NOTARY_PROFILE:-readarc-notary}"
CODESIGN_IDENTITY="${READARC_CODESIGN_IDENTITY:-}"
FORMAT="${READARC_RELEASE_FORMAT:-dmg}"
ARCH_NAME="${READARC_RELEASE_ARCH:-$(uname -m)}"
PUBLISH=0
DRAFT=1
AD_HOC=0
SKIP_NOTARY=0

usage() {
  cat <<USAGE
usage: $0 --version VERSION [options]

Options:
  --version VERSION       Release version, for example 0.1.0
  --tag TAG               Git tag. Default: vVERSION
  --title TITLE           Release title. Default: ReadArc VERSION
  --repo OWNER/REPO       GitHub repository. Default: $REPO
  --format FORMAT         Artifact format: dmg, zip, or both. Default: $FORMAT
  --identity NAME         codesign identity. Default: READARC_CODESIGN_IDENTITY or first Developer ID Application identity
  --notary-profile NAME   notarytool keychain profile. Default: $NOTARY_PROFILE
  --publish              Create or update a GitHub Release and upload artifacts
  --ready                Publish as a non-draft release. Default is draft
  --ad-hoc               Build a local test artifact with ad-hoc signing
  --skip-notary          Skip notarization. Only allowed with --ad-hoc
  --help                 Show this help

Formal public releases should not use --ad-hoc or --skip-notary.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:?missing --version value}"
      shift 2
      ;;
    --tag)
      TAG="${2:?missing --tag value}"
      shift 2
      ;;
    --title)
      TITLE="${2:?missing --title value}"
      shift 2
      ;;
    --repo)
      REPO="${2:?missing --repo value}"
      shift 2
      ;;
    --format)
      FORMAT="${2:?missing --format value}"
      shift 2
      ;;
    --identity)
      CODESIGN_IDENTITY="${2:?missing --identity value}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:?missing --notary-profile value}"
      shift 2
      ;;
    --publish)
      PUBLISH=1
      shift
      ;;
    --ready)
      DRAFT=0
      shift
      ;;
    --ad-hoc)
      AD_HOC=1
      shift
      ;;
    --skip-notary)
      SKIP_NOTARY=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "--version is required" >&2
  usage >&2
  exit 2
fi

if [[ "$VERSION" =~ ^v ]]; then
  echo "--version should not include a leading v; use --tag for a custom tag" >&2
  exit 2
fi

if [[ "$AD_HOC" -eq 0 && "$SKIP_NOTARY" -eq 1 ]]; then
  echo "--skip-notary is only allowed together with --ad-hoc for local test artifacts" >&2
  exit 2
fi

case "$FORMAT" in
  dmg|zip|both) ;;
  *)
    echo "--format must be dmg, zip, or both" >&2
    exit 2
    ;;
esac

TAG="${TAG:-v$VERSION}"
TITLE="${TITLE:-ReadArc $VERSION}"
FINAL_DMG="$RELEASE_DIR/$APP_NAME-$VERSION-macOS-$ARCH_NAME.dmg"
FINAL_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-macOS-$ARCH_NAME.zip"
NOTARY_ZIP="$RELEASE_DIR/$APP_NAME-$VERSION-notary.zip"
ASSETS=()

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

detect_developer_id_identity() {
  security find-identity -p codesigning -v 2>/dev/null \
    | awk -F '"' '/Developer ID Application/ { print $2; exit }'
}

sign_app() {
  if [[ "$AD_HOC" -eq 1 ]]; then
    /usr/bin/codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
    return
  fi

  if [[ -z "$CODESIGN_IDENTITY" ]]; then
    CODESIGN_IDENTITY="$(detect_developer_id_identity)"
  fi

  if [[ -z "$CODESIGN_IDENTITY" ]]; then
    echo "missing Developer ID Application signing identity" >&2
    echo "Install an Apple Developer certificate or pass --identity." >&2
    exit 1
  fi

  /usr/bin/codesign --force --deep --options runtime --timestamp \
    --sign "$CODESIGN_IDENTITY" \
    "$APP_BUNDLE"
}

notarize_app() {
  if [[ "$SKIP_NOTARY" -eq 1 ]]; then
    return
  fi

  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
  xcrun notarytool submit "$NOTARY_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$APP_BUNDLE"
}

write_checksum() {
  local artifact_path="$1"
  /usr/bin/shasum -a 256 "$artifact_path" >"$artifact_path.sha256"
}

package_final_zip() {
  rm -f "$FINAL_ZIP" "$FINAL_ZIP.sha256"
  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$FINAL_ZIP"
  write_checksum "$FINAL_ZIP"
  ASSETS+=("$FINAL_ZIP" "$FINAL_ZIP.sha256")
}

render_dmg_background() {
  local output_path="$1"

  if ! /usr/bin/sips -s format png "$DMG_BACKGROUND_SVG" --out "$output_path" >/dev/null; then
    echo "failed to render DMG background with sips" >&2
    exit 1
  fi
}

package_final_dmg() {
  local staging_dir
  local rw_dmg
  local mount_dir
  local device
  local volume_name="$APP_NAME $VERSION"

  staging_dir="$(mktemp -d "$RELEASE_DIR/dmg-staging.XXXXXX")"
  mount_dir="$(mktemp -d "$RELEASE_DIR/dmg-mount.XXXXXX")"
  rw_dmg="$RELEASE_DIR/$APP_NAME-$VERSION-rw.dmg"

  rm -f "$FINAL_DMG" "$FINAL_DMG.sha256" "$rw_dmg"
  mkdir -p "$staging_dir/.fseventsd"
  : >"$staging_dir/.fseventsd/no_log"
  cp -R "$APP_BUNDLE" "$staging_dir/"
  ln -s /Applications "$staging_dir/Applications"

  /usr/bin/hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -fs HFS+ \
    -format UDRW \
    -size 96m \
    "$rw_dmg" >/dev/null

  device="$(/usr/bin/hdiutil attach "$rw_dmg" -mountpoint "$mount_dir" -readwrite -noverify -noautoopen | /usr/bin/awk '/\/dev\// { print $1; exit }')"

  if ! /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$mount_dir" as alias
  open dmgFolder
  delay 1
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set bounds of container window of dmgFolder to {100, 100, 725, 500}
  set viewOptions to icon view options of container window of dmgFolder
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 112
  set position of item "$APP_NAME.app" of dmgFolder to {185, 210}
  set position of item "Applications" of dmgFolder to {465, 210}
  if exists item ".fseventsd" of dmgFolder then
    set position of item ".fseventsd" of dmgFolder to {900, 900}
  end if
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
APPLESCRIPT
  then
    /usr/bin/hdiutil detach "$device" >/dev/null 2>&1 || true
    rm -rf "$staging_dir" "$mount_dir" "$rw_dmg"
    exit 1
  fi

  sync
  /usr/bin/hdiutil detach "$device" >/dev/null
  rmdir "$mount_dir"

  /usr/bin/hdiutil convert "$rw_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$FINAL_DMG" >/dev/null

  rm -rf "$staging_dir" "$rw_dmg"

  if [[ "$AD_HOC" -eq 0 ]]; then
    /usr/bin/codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$FINAL_DMG"
  fi

  if [[ "$SKIP_NOTARY" -eq 0 ]]; then
    xcrun notarytool submit "$FINAL_DMG" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
    xcrun stapler staple "$FINAL_DMG"
  fi

  write_checksum "$FINAL_DMG"
  ASSETS+=("$FINAL_DMG" "$FINAL_DMG.sha256")
}

package_artifacts() {
  case "$FORMAT" in
    dmg)
      package_final_dmg
      ;;
    zip)
      package_final_zip
      ;;
    both)
      package_final_dmg
      package_final_zip
      ;;
  esac
}

validate_release_readiness() {
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

  if [[ "$AD_HOC" -eq 0 ]]; then
    /usr/sbin/spctl -a -vv --type execute "$APP_BUNDLE"
    if [[ -f "$FINAL_DMG" ]]; then
      /usr/sbin/spctl -a -vv --type open "$FINAL_DMG"
    fi
  fi

  if [[ "$PUBLISH" -eq 1 ]]; then
    require_command gh
    gh auth status --active -h github.com >/dev/null

    local default_branch
    default_branch="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name // ""')"
    if [[ -z "$default_branch" ]]; then
      echo "GitHub repo $REPO has no default branch yet. Push the source code first, then create a release." >&2
      exit 1
    fi
  fi
}

publish_release() {
  [[ "$PUBLISH" -eq 1 ]] || return 0

  local draft_flag=(--draft)
  if [[ "$DRAFT" -eq 0 ]]; then
    draft_flag=()
  fi

  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
  else
    local release_notes
    release_notes="ReadArc $VERSION for macOS Apple Silicon ($ARCH_NAME)."
    if [[ "$AD_HOC" -eq 1 || "$SKIP_NOTARY" -eq 1 ]]; then
      release_notes="$release_notes"$'\n\n'"Note: this artifact is ad-hoc signed and not notarized because no Developer ID certificate/notary profile is configured on the build machine."
    fi

    gh release create "$TAG" "${ASSETS[@]}" \
      --repo "$REPO" \
      --title "$TITLE" \
      --notes "$release_notes" \
      "${draft_flag[@]}"
  fi
}

require_command swift
require_command codesign
require_command ditto
require_command hdiutil
require_command osascript
require_command shasum
mkdir -p "$RELEASE_DIR"

READARC_BUILD_CONFIGURATION=release READARC_VERSION="$VERSION" "$ROOT_DIR/script/build_and_run.sh" --package >/dev/null
sign_app
notarize_app
package_artifacts
validate_release_readiness
publish_release

printf 'Release artifacts:\n'
printf '  %s\n' "${ASSETS[@]}"
if [[ "$PUBLISH" -eq 1 ]]; then
  echo "GitHub Release: https://github.com/$REPO/releases/tag/$TAG"
else
  echo "Dry run only. Add --publish to create or update the GitHub Release."
fi
