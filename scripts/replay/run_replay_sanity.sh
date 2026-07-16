#!/usr/bin/env bash
# Decode one short segment of every measured color capture.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/run_replay_sanity.sh [options]

Runs the sibling workbench sanity decode:
  make sanity

That decodes about one second of all 12 red/blue/yellow captures at 20 dB
using each channel's known-good JUNA configuration. It proves the downloaded
data and decoder entry point work before a longer paper run.
USAGE
  usage_common
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) consume_common_arg "$@" || consumed=$?
       if [[ "${consumed:-0}" == "0" ]]; then echo "unknown option: $1" >&2; usage; exit 2; fi
       shift "$consumed"; consumed=0; continue ;;
  esac
done

require_replay_workspace
show_replay_context
run_in_workspace make sanity
