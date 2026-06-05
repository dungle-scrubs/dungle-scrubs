#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=release/lib.sh
source "$script_dir/lib.sh"

usage() {
  cat <<'USAGE'
Build an opchain GitHub Release asset locally.

No GitHub runners are used. This script builds from a local source checkout when
`src/index.ts` exists, or packages an existing local `opchain` binary from older
release checkouts.

Usage:
  release/opchain.sh [options]

Options:
  --tag <tag|latest>          Release tag. Default: latest
  --source-dir <path>         Local opchain checkout. Default: ~/dev/opchain
  --repo <owner/repo>         GitHub repo. Default: dungle-scrubs/opchain
  --dist-dir <path>           Output directory. Default: ./dist
  --upload                    Upload asset and .sha256 to the release
  --create-release            Create the release if it does not exist
  --allow-dirty               Build from a dirty checkout
  --allow-ref-mismatch        Do not require HEAD to match the release tag
  -h, --help                  Show help

Output asset:
  opchain-darwin-<arch>.tar.gz
USAGE
}

repo="${OPCHAIN_REPO:-dungle-scrubs/opchain}"
tag_input="${OPCHAIN_VERSION:-latest}"
source_dir="${OPCHAIN_SOURCE_DIR:-$HOME/dev/opchain}"
dist_dir="${OPCHAIN_DIST_DIR:-$PWD/dist}"
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
require_command git
require_command shasum
check_github_auth

assert_git_checkout "$source_dir"
if [ ! -f "$source_dir/src/index.ts" ] && [ ! -x "$source_dir/opchain" ]; then
  fail "missing src/index.ts and executable opchain binary in $source_dir"
fi
tag="$(resolve_release_tag "$repo" "$tag_input")"
arch="$(detect_arch)"
asset_name="opchain-darwin-${arch}.tar.gz"
out_dir="$dist_dir/opchain/$tag"
package_dir="$out_dir/opchain-darwin-${arch}"
asset="$out_dir/$asset_name"

assert_clean_source "$source_dir" "$allow_dirty"
assert_source_ref_matches_tag "$source_dir" "$tag" "$allow_ref_mismatch"

rm -rf "$package_dir"
mkdir -p "$package_dir" "$out_dir"
if [ -f "$source_dir/src/index.ts" ]; then
  require_command bun
  (
    cd "$source_dir"
    bun install --frozen-lockfile
    bun build src/index.ts --compile --outfile "$package_dir/opchain"
  )
else
  install -m 0755 "$source_dir/opchain" "$package_dir/opchain"
fi
chmod 0755 "$package_dir/opchain"

tar -C "$out_dir" -czf "$asset" "$(basename "$package_dir")"
write_sha256 "$asset"

printf 'Built %s\n' "$asset"
printf 'SHA256: %s\n' "$(cut -d ' ' -f 1 "$asset.sha256")"

if [ "$upload" = "1" ]; then
  ensure_release_exists "$repo" "$tag" "$create_release"
  upload_assets "$repo" "$tag" "$asset" "$asset.sha256"
fi
