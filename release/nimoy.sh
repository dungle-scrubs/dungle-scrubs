#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Build a Nimoy GitHub Release asset locally.

No GitHub runners are used. This script builds from a local Xcode checkout,
writes a versioned zip, and optionally uploads it to a GitHub Release.

Usage:
  release/nimoy.sh [options]

Options:
  --tag <tag|latest>          Release tag. Default: latest
  --source-dir <path>         Local Nimoy checkout. Default: ~/dev/nimoy
  --repo <owner/repo>         GitHub repo. Default: dungle-scrubs/nimoy
  --scheme <name>             Xcode scheme. Default: Nimoy
  --dist-dir <path>           Output directory. Default: ./dist
  --upload                    Upload asset and .sha256 to the release
  --create-release            Create the release if it does not exist
  --adhoc-sign                Ad-hoc sign the app before zipping
  --allow-dirty               Build from a dirty checkout
  --allow-ref-mismatch        Do not require HEAD to match the release tag
  -h, --help                  Show help

Output asset:
  Nimoy-<tag>-darwin-<arch>.zip
USAGE
}

repo="${NIMOY_REPO:-dungle-scrubs/nimoy}"
tag_input="${NIMOY_VERSION:-latest}"
source_dir="${NIMOY_SOURCE_DIR:-$HOME/dev/nimoy}"
scheme="${NIMOY_SCHEME:-Nimoy}"
dist_dir="${NIMOY_DIST_DIR:-$PWD/dist}"
upload="0"
create_release="0"
adhoc_sign="0"
allow_dirty="0"
allow_ref_mismatch="0"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag | --version)
      tag_input="${2:-}"
      [ -n "$tag_input" ] || fail "$1 requires a value"
      shift 2
      ;;
    --source-dir)
      source_dir="${2:-}"
      [ -n "$source_dir" ] || fail "--source-dir requires a value"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      [ -n "$repo" ] || fail "--repo requires a value"
      shift 2
      ;;
    --scheme)
      scheme="${2:-}"
      [ -n "$scheme" ] || fail "--scheme requires a value"
      shift 2
      ;;
    --dist-dir)
      dist_dir="${2:-}"
      [ -n "$dist_dir" ] || fail "--dist-dir requires a value"
      shift 2
      ;;
    --upload)
      upload="1"
      shift
      ;;
    --create-release)
      create_release="1"
      shift
      ;;
    --adhoc-sign)
      adhoc_sign="1"
      shift
      ;;
    --allow-dirty)
      allow_dirty="1"
      shift
      ;;
    --allow-ref-mismatch)
      allow_ref_mismatch="1"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

assert_macos
require_command ditto
require_command git
require_command shasum
require_command xcodebuild
check_github_auth

assert_git_checkout "$source_dir"
[ -d "$source_dir/Nimoy.xcodeproj" ] || fail "missing Nimoy.xcodeproj in $source_dir"
tag="$(resolve_release_tag "$repo" "$tag_input")"
arch="$(detect_arch)"
asset_name="Nimoy-${tag}-darwin-${arch}.zip"
out_dir="$dist_dir/nimoy/$tag"
derived_data="$out_dir/DerivedData"
asset="$out_dir/$asset_name"

assert_clean_source "$source_dir" "$allow_dirty"
assert_source_ref_matches_tag "$source_dir" "$tag" "$allow_ref_mismatch"
rm -rf "$derived_data"
mkdir -p "$out_dir"

xcodebuild \
  -project "$source_dir/Nimoy.xcodeproj" \
  -scheme "$scheme" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

app_path="$derived_data/Build/Products/Release/Nimoy.app"
[ -d "$app_path" ] || fail "build did not produce $app_path"

if [ "$adhoc_sign" = "1" ]; then
  codesign --force --deep --sign - "$app_path"
fi

rm -f "$asset"
ditto -c -k --keepParent "$app_path" "$asset"
write_sha256 "$asset"

printf 'Built %s\n' "$asset"
printf 'SHA256: %s\n' "$(cut -d ' ' -f 1 "$asset.sha256")"

if [ "$upload" = "1" ]; then
  ensure_release_exists "$repo" "$tag" "$create_release"
  upload_assets "$repo" "$tag" "$asset" "$asset.sha256"
fi
