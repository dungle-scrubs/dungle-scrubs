#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Install private dungle-scrubs tools from GitHub Releases.

Usage:
  install/all.sh [--opchain-version <tag|latest>] [--sinew-version <tag|latest>] [--nimoy-version <tag|latest>]

Defaults install the latest release of each tool.
USAGE
}

opchain_version="${OPCHAIN_VERSION:-latest}"
sinew_version="${SINEW_VERSION:-latest}"
nimoy_version="${NIMOY_VERSION:-latest}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --opchain-version)
      opchain_version="${2:-}"
      [ -n "$opchain_version" ] || { printf 'error: --opchain-version requires a value\n' >&2; exit 1; }
      shift 2
      ;;
    --sinew-version)
      sinew_version="${2:-}"
      [ -n "$sinew_version" ] || { printf 'error: --sinew-version requires a value\n' >&2; exit 1; }
      shift 2
      ;;
    --nimoy-version)
      nimoy_version="${2:-}"
      [ -n "$nimoy_version" ] || { printf 'error: --nimoy-version requires a value\n' >&2; exit 1; }
      shift 2
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

"$script_dir/opchain.sh" --version "$opchain_version"
"$script_dir/sinew.sh" --version "$sinew_version"
"$script_dir/nimoy.sh" --version "$nimoy_version"
