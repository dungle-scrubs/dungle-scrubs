#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Build private release assets locally.

No GitHub runners are used. Assets are built from local checkouts and can be
uploaded to private GitHub Releases.

Usage:
  release/all.sh [options]

Options:
  --opchain-tag <tag|latest>  opchain release tag. Default: latest
  --sinew-tag <tag|latest>    sinew release tag. Default: latest
  --nimoy-tag <tag|latest>    Nimoy release tag. Default: latest
  --upload                    Upload all built assets
  --create-release            Create missing releases before uploading
  --allow-dirty               Build from dirty checkouts
  --allow-ref-mismatch        Do not require HEAD to match release tags
  -h, --help                  Show help
USAGE
}

opchain_tag="${OPCHAIN_VERSION:-latest}"
sinew_tag="${SINEW_VERSION:-latest}"
nimoy_tag="${NIMOY_VERSION:-latest}"
upload_args=()
shared_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --opchain-tag | --opchain-version)
      opchain_tag="${2:-}"
      [ -n "$opchain_tag" ] || { printf 'error: %s requires a value\n' "$1" >&2; exit 1; }
      shift 2
      ;;
    --sinew-tag | --sinew-version)
      sinew_tag="${2:-}"
      [ -n "$sinew_tag" ] || { printf 'error: %s requires a value\n' "$1" >&2; exit 1; }
      shift 2
      ;;
    --nimoy-tag | --nimoy-version)
      nimoy_tag="${2:-}"
      [ -n "$nimoy_tag" ] || { printf 'error: %s requires a value\n' "$1" >&2; exit 1; }
      shift 2
      ;;
    --upload)
      upload_args+=(--upload)
      shift
      ;;
    --create-release)
      upload_args+=(--create-release)
      shift
      ;;
    --allow-dirty)
      shared_args+=(--allow-dirty)
      shift
      ;;
    --allow-ref-mismatch)
      shared_args+=(--allow-ref-mismatch)
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

"$script_dir/opchain.sh" --tag "$opchain_tag" "${shared_args[@]}" "${upload_args[@]}"
"$script_dir/sinew.sh" --tag "$sinew_tag" "${shared_args[@]}" "${upload_args[@]}"
"$script_dir/nimoy.sh" --tag "$nimoy_tag" "${shared_args[@]}" "${upload_args[@]}"
