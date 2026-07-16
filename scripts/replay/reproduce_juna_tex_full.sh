#!/usr/bin/env bash
# Full replay-channel paper reproduction. This can take hours.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/reproduce_juna_tex_full.sh [options]

Runs the full sibling workbench paper pipeline:
  MODE=full bash run_all.sh

This is the hours-scale full-capture run used to regenerate the measured-channel
results, figure_data files, and final tex/replay channel results juna.tex PDF.
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
run_in_workspace_env MODE=full bash run_all.sh
build_args=(--workspace "$JUNA_REPLAY_WORKSPACE" --tex "$JUNA_REPLAY_TEX")
[[ "$DRY_RUN" == "1" ]] && build_args+=(--dry-run)
"$SCRIPT_DIR/build_juna_tex.sh" "${build_args[@]}"
