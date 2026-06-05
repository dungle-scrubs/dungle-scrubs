#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Build a sinew GitHub Release asset locally.

No GitHub runners are used. This script builds from a local checkout, writes a
versioned tarball, and optionally uploads it to a GitHub Release.

Usage:
  release/sinew.sh [options]

Options:
  --tag <tag|latest>          Release tag. Default: latest
  --source-dir <path>         Local sinew checkout. Default: ~/dev/sinew
  --repo <owner/repo>         GitHub repo. Default: dungle-scrubs/sinew
  --dist-dir <path>           Output directory. Default: ./dist
  --upload                    Upload asset and .sha256 to the release
  --create-release            Create the release if it does not exist
  --allow-dirty               Build from a dirty checkout
  --allow-ref-mismatch        Do not require HEAD to match the release tag
  -h, --help                  Show help

Output asset:
  sinew-darwin-<arch>.tar.gz
USAGE
}

repo="${SINEW_REPO:-dungle-scrubs/sinew}"
tag_input="${SINEW_VERSION:-latest}"
source_dir="${SINEW_SOURCE_DIR:-$HOME/dev/sinew}"
dist_dir="${SINEW_DIST_DIR:-$PWD/dist}"
upload="0"
create_release="0"
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
require_command cargo
require_command git
require_command shasum
check_github_auth

assert_git_checkout "$source_dir"
tag="$(resolve_release_tag "$repo" "$tag_input")"
arch="$(detect_arch)"
asset_name="sinew-darwin-${arch}.tar.gz"
out_dir="$dist_dir/sinew/$tag"
package_dir="$out_dir/sinew-darwin-${arch}"
asset="$out_dir/$asset_name"

assert_clean_source "$source_dir" "$allow_dirty"
assert_source_ref_matches_tag "$source_dir" "$tag" "$allow_ref_mismatch"

cargo build --manifest-path "$source_dir/Cargo.toml" --release --locked
rm -rf "$package_dir"
mkdir -p "$package_dir" "$out_dir"
install -m 0755 "$source_dir/target/release/sinew" "$package_dir/sinew"
if [ -f "$source_dir/target/release/sinew-msg" ]; then
  install -m 0755 "$source_dir/target/release/sinew-msg" "$package_dir/sinew-msg"
fi

tar -C "$out_dir" -czf "$asset" "$(basename "$package_dir")"
write_sha256 "$asset"

printf 'Built %s\n' "$asset"
printf 'SHA256: %s\n' "$(cut -d ' ' -f 1 "$asset.sha256")"

if [ "$upload" = "1" ]; then
  ensure_release_exists "$repo" "$tag" "$create_release"
  upload_assets "$repo" "$tag" "$asset" "$asset.sha256"
fi
