#!/usr/bin/env bash
# Shared helpers for replay-channel paper reproduction scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

: "${JUNA_REPLAY_WORKSPACE:=$HOME/Documents/GitHub/Juna_replay_channel_1ch}"
: "${JUNA_REPLAY_TEX:=replay channel results juna.tex}"
: "${JUNA_REPLAY_OUTPUT_DIR:=$REPO_ROOT/reports/replay/latest}"
: "${DRY_RUN:=0}"

usage_common() {
  cat <<'USAGE'
Common options:
  --workspace DIR   Replay workbench checkout. Default: $HOME/Documents/GitHub/Juna_replay_channel_1ch
  --tex FILE        TeX file under the workbench tex/ directory.
                   Default: replay channel results juna.tex
  --dry-run         Print commands without executing them.
  -h, --help        Show help.

Common environment:
  JUNA_REPLAY_WORKSPACE   Same as --workspace.
  JUNA_REPLAY_TEX         Same as --tex.
  JUNA_REPLAY_OUTPUT_DIR  Where build_juna_tex.sh copies the PDF/data snapshot.
USAGE
}

consume_common_arg() {
  case "${1:-}" in
    --workspace)
      [[ $# -ge 2 ]] || { echo "--workspace needs a directory" >&2; exit 2; }
      JUNA_REPLAY_WORKSPACE="$2"
      return 2
      ;;
    --tex)
      [[ $# -ge 2 ]] || { echo "--tex needs a TeX filename" >&2; exit 2; }
      JUNA_REPLAY_TEX="$2"
      return 2
      ;;
    --dry-run)
      DRY_RUN=1
      return 1
      ;;
  esac
  return 0
}

require_replay_workspace() {
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi

  [[ -d "$JUNA_REPLAY_WORKSPACE" ]] ||
    { echo "missing replay workspace: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/Makefile" ]] ||
    { echo "workspace has no Makefile: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/run_all.sh" ]] ||
    { echo "workspace has no run_all.sh: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/src/ReplayCh.jl" ]] ||
    { echo "workspace has no src/ReplayCh.jl: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/scripts/workbench/sweeps.jl" ]] ||
    { echo "workspace has no scripts/workbench/sweeps.jl: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/scripts/workbench/figures.py" ]] ||
    { echo "workspace has no scripts/workbench/figures.py: $JUNA_REPLAY_WORKSPACE" >&2; exit 1; }
  [[ -f "$JUNA_REPLAY_WORKSPACE/tex/$JUNA_REPLAY_TEX" ]] ||
    { echo "missing TeX target: $JUNA_REPLAY_WORKSPACE/tex/$JUNA_REPLAY_TEX" >&2; exit 1; }
}

show_replay_context() {
  echo "Replay workspace: $JUNA_REPLAY_WORKSPACE"
  echo "TeX target:       tex/$JUNA_REPLAY_TEX"
  echo "Output snapshot:  $JUNA_REPLAY_OUTPUT_DIR"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "Mode:             dry-run"
  fi
}

run_in_workspace() {
  echo "+ cd \"$JUNA_REPLAY_WORKSPACE\" && $*"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  (cd "$JUNA_REPLAY_WORKSPACE" && "$@")
}

run_in_workspace_env() {
  echo "+ cd \"$JUNA_REPLAY_WORKSPACE\" && $*"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  (cd "$JUNA_REPLAY_WORKSPACE" && env "$@")
}

run_in_tex() {
  echo "+ cd \"$JUNA_REPLAY_WORKSPACE/tex\" && $*"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  (cd "$JUNA_REPLAY_WORKSPACE/tex" && "$@")
}

run_in_workspace_optional() {
  echo "+ cd \"$JUNA_REPLAY_WORKSPACE\" && $*  # optional"
  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  (cd "$JUNA_REPLAY_WORKSPACE" && "$@") || echo "optional stage skipped: $*" >&2
}

copy_if_present() {
  local src="$1"
  local dst_dir="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$dst_dir"
    cp "$src" "$dst_dir/"
  fi
}
