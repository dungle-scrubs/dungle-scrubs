#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Install opchain from a private GitHub Release asset.

Usage:
  install/opchain.sh [--version <tag|latest>] [--bin-dir <path>] [--repo <owner/repo>]

Environment:
  OPCHAIN_VERSION   Release tag to install. Default: latest
  OPCHAIN_BIN_DIR   Binary install directory. Default: ~/.local/bin
  OPCHAIN_REPO      GitHub repository. Default: dungle-scrubs/opchain

Expected release asset examples:
  opchain-darwin-arm64.tar.gz
  opchain-darwin-x86_64.tar.gz
USAGE
}

repo="${OPCHAIN_REPO:-dungle-scrubs/opchain}"
version="${OPCHAIN_VERSION:-latest}"
bin_dir="${OPCHAIN_BIN_DIR:-$HOME/.local/bin}"

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
  [[ "$lower" == *opchain* ]] || continue
  asset_matches_arch "$name" "$arch" || continue
  [[ "$lower" == *.tar.gz || "$lower" == *.tgz || "$lower" == *.zip ]] || continue
  asset="$name"
  break
done <<< "$assets"

[ -n "$asset" ] || print_no_asset_help "$repo" "$tag" "opchain-darwin-${arch}.tar.gz"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
archive="$(download_release_asset "$repo" "$tag" "$asset" "$tmp")"
extract_dir="$tmp/extract"
mkdir -p "$extract_dir" "$bin_dir"

case "$(printf '%s' "$archive" | tr '[:upper:]' '[:lower:]')" in
  *.tar.gz | *.tgz) tar -xzf "$archive" -C "$extract_dir" ;;
  *.zip) unzip -q "$archive" -d "$extract_dir" ;;
  *) fail "unsupported opchain asset format: $asset" ;;
esac

opchain_bin="$(find "$extract_dir" -type f -name opchain | sed -n '1p')"
[ -n "$opchain_bin" ] || fail "asset did not contain an opchain binary"
target="$bin_dir/opchain"
if [ -L "$target" ]; then
  rm "$target"
fi
install -m 0755 "$opchain_bin" "$target"

printf 'Installed opchain %s to %s\n' "$tag" "$bin_dir"
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
  printf 'Add %s to PATH if this is a new install location.\n' "$bin_dir"
fi
