# Reproducing `replay channel results juna.tex`

The scripts in this repository drive the canonical ReplayCh workbench in
`~/Documents/GitHub/Juna_replay_channel_1ch`. The workbench remains the owner of
the measured data, ReplayCh engine, generated paper tables, and TeX artifact.
JunaCore tests are prerequisites and differential checks; they are not by
themselves a paper reproduction.

## Scripts

```bash
scripts/replay/prepare_replay_workspace.sh
scripts/replay/run_replay_sanity.sh
scripts/replay/run_color_config_ber_sweep.sh
scripts/replay/reproduce_juna_tex_proxy.sh
scripts/replay/reproduce_juna_tex_full.sh
scripts/replay/build_juna_tex.sh --extract
```

The default target is `tex/replay channel results juna.tex`. Override the
workbench location when needed:

```bash
JUNA_REPLAY_WORKSPACE=/path/to/Juna_replay_channel_1ch \
scripts/replay/reproduce_juna_tex_proxy.sh
```

All wrappers support `--dry-run`. Proxy mode checks the complete pipeline with
throwaway one-frame statistics. Full mode performs the expensive full-capture
reproduction.

## Gate Sequence

Run the structural gate list with:

```bash
julia --project=. test/runtests.jl replay-gates
```

| Gate | Purpose |
|---|---|
| 1. Repository boundary | Confirms JunaCore tests do not claim ReplayCh paper reproduction. |
| 2. Workbench presence | Checks the sibling ReplayCh engine and scripts. |
| 3. Data integrity | Rejects missing captures and Git-LFS pointer files. |
| 4. ReplayCh load | Imports the paper's actual engine. |
| 5. Smoke pipeline | Runs a one-frame red-channel plumbing check. |
| 6. Sanity decode | Produces measured-channel decode metrics. |
| 7. Figure artifacts | Parses the data consumed by the paper. |
| 8. TeX artifact | Builds the paper from current figure data. |
| 9. Proxy reproduction | Runs all captures with one frame each. |
| 10. Single-segment result | Requires real decode fields, not only script success. |
| 11. Table spot-check | Checks selected PSR values and ordering. |
| 12. Full reproduction | Regenerates full-capture artifacts and PDF. |

Real stages are opt-in through the `JUNA_REPLAY_*` environment variables named
by `test/replay_reproduction_gates.jl`. Disabled expensive stages are reported
as skipped/broken, never as passing reproduction evidence.
