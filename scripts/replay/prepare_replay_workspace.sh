#!/usr/bin/env bash
# Clone/update measured replay data and instantiate the canonical workbench.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/prepare_replay_workspace.sh [options]

Runs the sibling workbench bootstrap:
  make bootstrap

This clones the replaychan Git-LFS data and wires the measured red/blue/yellow
captures expected by the replay-channel paper workflow.
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
run_in_workspace make bootstrap

cat <<'DONE'

Prepared replay workspace.
Next:
  scripts/replay/run_replay_sanity.sh
  scripts/replay/reproduce_juna_tex_proxy.sh
DONE
