#!/usr/bin/env bash
# Fast paper-pipeline reproduction: all captures, one frame per capture.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/reproduce_juna_tex_proxy.sh [options]

Runs the sibling workbench proxy paper pipeline:
  MODE=proxy bash run_all.sh

This uses all 12 measured color captures but only one frame per capture. It is a
pipeline/logic reproduction for tex/replay channel results juna.tex; the numbers
are throwaway proxies, not the full paper results.
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
run_in_workspace_env MODE=proxy bash run_all.sh
build_args=(--workspace "$JUNA_REPLAY_WORKSPACE" --tex "$JUNA_REPLAY_TEX")
[[ "$DRY_RUN" == "1" ]] && build_args+=(--dry-run)
"$SCRIPT_DIR/build_juna_tex.sh" "${build_args[@]}"
