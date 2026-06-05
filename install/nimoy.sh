#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Install Nimoy from a private GitHub Release asset.

Usage:
  install/nimoy.sh [--version <tag|latest>] [--app-dir <path>] [--repo <owner/repo>]

Environment:
  NIMOY_VERSION   Release tag to install. Default: latest
  NIMOY_APP_DIR   Application install directory. Default: ~/Applications
  NIMOY_REPO      GitHub repository. Default: dungle-scrubs/nimoy

Expected release asset examples:
  Nimoy-v0.1.3-darwin-arm64.zip
  Nimoy-v0.1.3-darwin-x86_64.zip
USAGE
}

repo="${NIMOY_REPO:-dungle-scrubs/nimoy}"
version="${NIMOY_VERSION:-latest}"
app_dir="${NIMOY_APP_DIR:-$HOME/Applications}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      version="${2:-}"
      [ -n "$version" ] || fail "--version requires a value"
      shift 2
      ;;
    --app-dir)
      app_dir="${2:-}"
      [ -n "$app_dir" ] || fail "--app-dir requires a value"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      [ -n "$repo" ] || fail "--repo requires a value"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) fail "unknown argument: $1" ;;
  esac
done

check_github_auth
require_command unzip
require_command ditto

arch="$(detect_arch)"
tag="$(resolve_release_tag "$repo" "$version")"
asset=""
assets="$(list_release_assets "$repo" "$tag")"

while IFS= read -r name; do
  lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *nimoy* ]] || continue
  asset_matches_arch "$name" "$arch" || continue
  [[ "$lower" == *.zip || "$lower" == *.dmg || "$lower" == *.pkg ]] || continue
  asset="$name"
  break
done <<< "$assets"

[ -n "$asset" ] || print_no_asset_help "$repo" "$tag" "Nimoy-${tag}-darwin-${arch}.zip"

tmp="$(mktemp -d)"
mount_dir=""
cleanup() {
  if [ -n "$mount_dir" ] && mount | grep -q " $mount_dir "; then
    hdiutil detach "$mount_dir" -quiet || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT

archive="$(download_release_asset "$repo" "$tag" "$asset" "$tmp")"
extract_dir="$tmp/extract"
mkdir -p "$extract_dir" "$app_dir"

case "$(printf '%s' "$archive" | tr '[:upper:]' '[:lower:]')" in
  *.zip)
    unzip -q "$archive" -d "$extract_dir"
    ;;
  *.dmg)
    mount_dir="$tmp/mount"
    mkdir -p "$mount_dir"
    hdiutil attach "$archive" -mountpoint "$mount_dir" -nobrowse -quiet
    extract_dir="$mount_dir"
    ;;
  *.pkg)
    sudo installer -pkg "$archive" -target /
    printf 'Installed Nimoy %s from package asset %s\n' "$tag" "$asset"
    exit 0
    ;;
  *) fail "unsupported Nimoy asset format: $asset" ;;
esac

app_path="$(find "$extract_dir" -type d -name 'Nimoy.app' | sed -n '1p')"
[ -n "$app_path" ] || fail "asset did not contain Nimoy.app"

target="$app_dir/Nimoy.app"
rm -rf "$target"
ditto "$app_path" "$target"
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
printf 'Installed Nimoy %s to %s\n' "$tag" "$target"
