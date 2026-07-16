#!/usr/bin/env bash
# Regenerate figure-data from existing replay results and build juna.tex.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

EXTRACT=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/replay/build_juna_tex.sh [--extract] [options]

Builds the replay-channel TeX target with two pdflatex passes:
  tex/replay channel results juna.tex

With --extract, first regenerates the figure_data files used by that TeX file
from existing results/ CSVs using the sibling workbench extractors.
USAGE
  usage_common
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extract) EXTRACT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) consume_common_arg "$@" || consumed=$?
       if [[ "${consumed:-0}" == "0" ]]; then echo "unknown option: $1" >&2; usage; exit 2; fi
       shift "$consumed"; consumed=0; continue ;;
  esac
done

require_replay_workspace
show_replay_context

if [[ "$EXTRACT" == "1" ]]; then
  run_in_workspace_optional python3 scripts/workbench/figures.py copy_cir_figs
  run_in_workspace_optional python3 scripts/workbench/figures.py aggregate_oat_determinants
  run_in_workspace python3 scripts/workbench/figures.py extract_all_channels
  run_in_workspace python3 scripts/workbench/figures.py extract_robustness
  run_in_workspace python3 scripts/workbench/figures.py extract_fixed_config
  run_in_workspace python3 scripts/workbench/figures.py extract_three_method
  run_in_workspace_optional python3 scripts/workbench/figures.py extract_site_analysis
  run_in_workspace python3 scripts/workbench/figures.py gen_data_rate
  run_in_workspace python3 scripts/workbench/figures.py gen_tables
fi

run_in_tex pdflatex -interaction=nonstopmode -halt-on-error "$JUNA_REPLAY_TEX"
run_in_tex pdflatex -interaction=nonstopmode -halt-on-error "$JUNA_REPLAY_TEX"

PDF_NAME="${JUNA_REPLAY_TEX%.tex}.pdf"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "+ copy \"$JUNA_REPLAY_WORKSPACE/tex/$PDF_NAME\" and selected figure_data files to \"$JUNA_REPLAY_OUTPUT_DIR\""
  exit 0
fi

mkdir -p "$JUNA_REPLAY_OUTPUT_DIR/figure_data"
cp "$JUNA_REPLAY_WORKSPACE/tex/$PDF_NAME" "$JUNA_REPLAY_OUTPUT_DIR/"

for rel in \
  figure_data/tab_best.tex \
  figure_data/tab_oat.tex \
  figure_data/fixedcfg_psr20.dat \
  figure_data/threemethod_winner20.dat \
  figure_data/threemethod_red1_snr.dat \
  figure_data/threemethod_blue1_snr.dat \
  figure_data/interact_red1_n_cp.dat \
  figure_data/interact_blue3_n_cp.dat \
  figure_data/cir_SG1_heatmap.png \
  figure_data/cir_NA1_heatmap.png \
  figure_data/cir_HW1_heatmap.png
do
  copy_if_present "$JUNA_REPLAY_WORKSPACE/tex/$rel" "$JUNA_REPLAY_OUTPUT_DIR/$(dirname "$rel")"
done

cat >"$JUNA_REPLAY_OUTPUT_DIR/manifest.txt" <<MANIFEST
Generated from: $JUNA_REPLAY_WORKSPACE
TeX target: tex/$JUNA_REPLAY_TEX
PDF: $PDF_NAME
Created: $(date -Is)
MANIFEST

echo "Built $JUNA_REPLAY_OUTPUT_DIR/$PDF_NAME"
