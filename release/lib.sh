#!/usr/bin/env bash
set -euo pipefail

release_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$release_dir/../install/lib.sh"

assert_macos() {
  [ "$(uname -s)" = "Darwin" ] || fail "local asset builds require macOS"
}

assert_git_checkout() {
  local source_dir="$1"
  git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "not a git checkout: $source_dir"
}

assert_clean_source() {
  local source_dir="$1"
  local allow_dirty="$2"

  if [ "$allow_dirty" = "1" ]; then
    return 0
  fi

  if [ -n "$(git -C "$source_dir" status --porcelain)" ]; then
    git -C "$source_dir" status --short >&2
    fail "source checkout is dirty; pass --allow-dirty only if this is intentional"
  fi
}

assert_source_ref_matches_tag() {
  local source_dir="$1"
  local tag="$2"
  local allow_ref_mismatch="$3"

  if [ "$allow_ref_mismatch" = "1" ]; then
    return 0
  fi

  git -C "$source_dir" rev-parse --verify "$tag^{commit}" >/dev/null 2>&1 || {
    printf 'warning: tag %s is not present in %s; skipping ref match check\n' "$tag" "$source_dir" >&2
    return 0
  }

  local head_commit tag_commit
  head_commit="$(git -C "$source_dir" rev-parse HEAD)"
  tag_commit="$(git -C "$source_dir" rev-parse "$tag^{commit}")"
  [ "$head_commit" = "$tag_commit" ] || fail "source HEAD does not match $tag; checkout the tag or pass --allow-ref-mismatch"
}

ensure_release_exists() {
  local repo="$1"
  local tag="$2"
  local create_release="$3"

  if gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
    return 0
  fi

  [ "$create_release" = "1" ] || fail "release $tag does not exist in $repo; pass --create-release to create it"
  gh release create "$tag" --repo "$repo" --title "$tag" --notes "Local asset build for $tag" >/dev/null
}

write_sha256() {
  local asset="$1"
  shasum -a 256 "$asset" > "$asset.sha256"
}

upload_assets() {
  local repo="$1"
  local tag="$2"
  shift 2

  gh release upload "$tag" "$@" --repo "$repo" --clobber
}
