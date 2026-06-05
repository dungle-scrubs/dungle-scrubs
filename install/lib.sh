#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

check_github_auth() {
  require_command gh
  if gh auth status -h github.com >/dev/null 2>&1; then
    return 0
  fi
  if [ -n "${GH_TOKEN:-}" ] || [ -n "${GITHUB_TOKEN:-}" ]; then
    return 0
  fi
  fail "GitHub auth required. Run: gh auth login -h github.com"
}

detect_arch() {
  case "$(uname -m)" in
    arm64 | aarch64) printf 'arm64\n' ;;
    x86_64 | amd64) printf 'x86_64\n' ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
  esac
}

resolve_release_tag() {
  local repo="$1"
  local version="$2"

  if [ "$version" != "latest" ]; then
    printf '%s\n' "$version"
    return 0
  fi

  local tag
  tag="$(gh release list --repo "$repo" --limit 1 --json tagName --jq '.[0].tagName // empty')"
  [ -n "$tag" ] || fail "no releases found for $repo"
  printf '%s\n' "$tag"
}

asset_matches_arch() {
  local name="$1"
  local arch="$2"
  local lower
  lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"

  case "$arch" in
    arm64) [[ "$lower" == *arm64* || "$lower" == *aarch64* ]] ;;
    x86_64) [[ "$lower" == *x86_64* || "$lower" == *amd64* || "$lower" == *x64* ]] ;;
    *) return 1 ;;
  esac
}

list_release_assets() {
  local repo="$1"
  local tag="$2"
  gh release view "$tag" --repo "$repo" --json assets --jq '.assets[].name'
}

print_no_asset_help() {
  local repo="$1"
  local tag="$2"
  local expected="$3"

  printf 'No matching release asset found for %s@%s.\n' "$repo" "$tag" >&2
  printf 'Expected something like: %s\n\n' "$expected" >&2
  printf 'Current assets:\n' >&2
  list_release_assets "$repo" "$tag" >&2 || true
  printf '\nUpload an asset with:\n' >&2
  printf '  gh release upload %q <asset-path> --repo %q\n' "$tag" "$repo" >&2
  exit 1
}

download_release_asset() {
  local repo="$1"
  local tag="$2"
  local asset="$3"
  local dir="$4"

  mkdir -p "$dir"
  gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$dir" --clobber >/dev/null
  printf '%s/%s\n' "$dir" "$asset"
}
