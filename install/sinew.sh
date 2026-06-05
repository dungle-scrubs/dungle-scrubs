#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Install sinew from a private GitHub Release asset.

Usage:
  install/sinew.sh [--version <tag|latest>] [--bin-dir <path>] [--repo <owner/repo>]

Environment:
  SINEW_VERSION   Release tag to install. Default: latest
  SINEW_BIN_DIR   Binary install directory. Default: ~/.local/bin
  SINEW_REPO      GitHub repository. Default: dungle-scrubs/sinew

Expected release asset examples:
  sinew-darwin-arm64.tar.gz
  sinew-darwin-x86_64.tar.gz
USAGE
}

repo="${SINEW_REPO:-dungle-scrubs/sinew}"
version="${SINEW_VERSION:-latest}"
bin_dir="${SINEW_BIN_DIR:-$HOME/.local/bin}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      version="${2:-}"
      [ -n "$version" ] || fail "--version requires a value"
      shift 2
      ;;
    --bin-dir)
      bin_dir="${2:-}"
      [ -n "$bin_dir" ] || fail "--bin-dir requires a value"
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
require_command tar
require_command unzip

arch="$(detect_arch)"
tag="$(resolve_release_tag "$repo" "$version")"
asset=""
assets="$(list_release_assets "$repo" "$tag")"

while IFS= read -r name; do
  lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *sinew* ]] || continue
  asset_matches_arch "$name" "$arch" || continue
  [[ "$lower" == *.tar.gz || "$lower" == *.tgz || "$lower" == *.zip ]] || continue
  asset="$name"
  break
done <<< "$assets"

[ -n "$asset" ] || print_no_asset_help "$repo" "$tag" "sinew-darwin-${arch}.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$(download_release_asset "$repo" "$tag" "$asset" "$tmp")"
extract_dir="$tmp/extract"
mkdir -p "$extract_dir" "$bin_dir"

case "$(printf '%s' "$archive" | tr '[:upper:]' '[:lower:]')" in
  *.tar.gz | *.tgz) tar -xzf "$archive" -C "$extract_dir" ;;
  *.zip) unzip -q "$archive" -d "$extract_dir" ;;
  *) fail "unsupported sinew asset format: $asset" ;;
esac

sinew_bin="$(find "$extract_dir" -type f -name sinew | sed -n '1p')"
[ -n "$sinew_bin" ] || fail "asset did not contain a sinew binary"
install -m 0755 "$sinew_bin" "$bin_dir/sinew"

sinew_msg="$(find "$extract_dir" -type f -name sinew-msg | sed -n '1p')"
if [ -n "$sinew_msg" ]; then
  install -m 0755 "$sinew_msg" "$bin_dir/sinew-msg"
fi

printf 'Installed sinew %s to %s\n' "$tag" "$bin_dir"
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
  printf 'Add %s to PATH if this is a new install location.\n' "$bin_dir"
fi
