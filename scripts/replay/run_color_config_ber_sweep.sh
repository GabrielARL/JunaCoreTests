#!/usr/bin/env bash
# Sweep representative color captures across paper configs and SNRs.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

: "${JUNA_REPLAY_BER_SWEEP_CHANNELS:=red1,blue1,yellow1}"
: "${JUNA_REPLAY_BER_SWEEP_CONFIGS:=ownbest,winner,coldbase}"
: "${JUNA_REPLAY_BER_SWEEP_SNRS:=0:5:30}"
: "${JUNA_REPLAY_BER_SWEEP_SEGMENTS:=1}"
: "${JUNA_REPLAY_BER_SWEEP_OUT:=$JUNA_REPLAY_OUTPUT_DIR/color_config_ber_sweep.csv}"
: "${JULIA:=julia}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/run_color_config_ber_sweep.sh [options]

Runs the sibling ReplayCh workbench stage:
  scripts/workbench/sweeps.jl color_config_ber_sweep

Default measurement:
  channels: red1,blue1,yellow1
  configs:  ownbest,winner,coldbase
  SNRs:     0:5:30 dB
  segments: 1 frame per channel/config/SNR

Output CSV columns include BER, PSR, packet counts, config knobs, and decode
timing. Use --channels all for all 12 red/blue/yellow captures.

Options:
  --channels LIST   Channel list, e.g. red1,blue1,yellow1 or all.
  --configs LIST    Config list: ownbest,winner,coldbase.
  --snrs GRID       SNR grid, e.g. 0:5:30 or 0,10,20,30.
  --segments N      Replay segments per decode. Use 0 for full capture.
  --out CSV         Output CSV path. Default: reports/replay/latest/color_config_ber_sweep.csv
USAGE
  usage_common
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channels)
      [[ $# -ge 2 ]] || { echo "--channels needs a list" >&2; exit 2; }
      JUNA_REPLAY_BER_SWEEP_CHANNELS="$2"
      shift 2
      ;;
    --configs)
      [[ $# -ge 2 ]] || { echo "--configs needs a list" >&2; exit 2; }
      JUNA_REPLAY_BER_SWEEP_CONFIGS="$2"
      shift 2
      ;;
    --snrs)
      [[ $# -ge 2 ]] || { echo "--snrs needs a grid" >&2; exit 2; }
      JUNA_REPLAY_BER_SWEEP_SNRS="$2"
      shift 2
      ;;
    --segments)
      [[ $# -ge 2 ]] || { echo "--segments needs a count" >&2; exit 2; }
      JUNA_REPLAY_BER_SWEEP_SEGMENTS="$2"
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || { echo "--out needs a CSV path" >&2; exit 2; }
      JUNA_REPLAY_BER_SWEEP_OUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      consume_common_arg "$@" || consumed=$?
      if [[ "${consumed:-0}" == "0" ]]; then
        echo "unknown option: $1" >&2
        usage
        exit 2
      fi
      shift "$consumed"
      consumed=0
      ;;
  esac
done

require_replay_workspace
if [[ "$DRY_RUN" != "1" && ! -f "$JUNA_REPLAY_WORKSPACE/scripts/workbench/sweeps/functions/color_config_ber_sweep.jl" ]]; then
  echo "workspace lacks color_config_ber_sweep stage: $JUNA_REPLAY_WORKSPACE" >&2
  exit 1
fi

show_replay_context
echo "BER sweep channels: $JUNA_REPLAY_BER_SWEEP_CHANNELS"
echo "BER sweep configs:  $JUNA_REPLAY_BER_SWEEP_CONFIGS"
echo "BER sweep SNRs:     $JUNA_REPLAY_BER_SWEEP_SNRS"
echo "BER sweep segments: $JUNA_REPLAY_BER_SWEEP_SEGMENTS"
echo "BER sweep CSV:      $JUNA_REPLAY_BER_SWEEP_OUT"

run_in_workspace_env \
  SWEEP_CHANNELS="$JUNA_REPLAY_BER_SWEEP_CHANNELS" \
  SWEEP_CONFIGS="$JUNA_REPLAY_BER_SWEEP_CONFIGS" \
  SWEEP_SNRS="$JUNA_REPLAY_BER_SWEEP_SNRS" \
  SWEEP_SEGMENTS="$JUNA_REPLAY_BER_SWEEP_SEGMENTS" \
  SWEEP_OUT="$JUNA_REPLAY_BER_SWEEP_OUT" \
  "$JULIA" --threads=1 --gcthreads=1 --project=. \
  scripts/workbench/sweeps.jl color_config_ber_sweep
