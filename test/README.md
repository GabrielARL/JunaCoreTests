# JunaCore tests — how to run them, and what each one proves

Every suite header states which claims from the paper
([`papers/main.tex`](../papers/main.tex)) it protects, using the paper's
`\label` anchors and line numbers. This file is the maintained map (it
supersedes `docs/test_to_paper_map_slides.tex`).

## How to run

| What | Command |
|---|---|
| Everything | `julia --project=. -e 'using Pkg; Pkg.test()'` |
| Everything via Makefile | `make test` |
| Everything (no Pkg overhead) | `julia --project=. test/runtests.jl` |
| One suite by name | `julia --project=. test/runtests.jl layout` |
| Several suites | `julia --project=. test/runtests.jl pilots sizing` |
| Via Pkg with a filter | `julia --project=. -e 'using Pkg; Pkg.test(test_args=["layout"])'` |
| One file directly | `julia --project=. test/ofdm_layout.jl` |
| Print the test-to-theory map | `julia --project=. test/runtests.jl list` |
| Contract + extended multi-block roundtrip | `julia --project=. test/runtests.jl roundtrip` |
| Same, via the documented env var | `JUNA_INTERFACE_ROUNDTRIP=1 julia --project=. test/interface_contract.jl` |
| Carrier mapping only | `julia --project=. test/runtests.jl carrier` |
| Optional sync waveform only | `julia --project=. test/runtests.jl sync` |
| Sync-assisted frame timing and Doppler correction only | `julia --project=. test/runtests.jl sync-doppler` |
| Rpchan preamble, Doppler search, and payload acquisition only | `julia --project=. test/runtests.jl acquisition` |
| Synthetic multipath/per-path-Doppler channel only | `julia --project=. test/runtests.jl synthetic-channel` |
| Receive front end only | `julia --project=. test/runtests.jl frontend` |
| Pilot equalization only | `julia --project=. test/runtests.jl equalization` |
| Candidate demodulation only | `julia --project=. test/runtests.jl candidate` |
| LDPC belief propagation only | `julia --project=. test/runtests.jl bp` |
| Frame-wide LDPC modem only | `julia --project=. test/runtests.jl frame-wide-ldpc` |
| JUNA-lite refinement only | `julia --project=. test/runtests.jl lite` |
| JUNA-full W,z refinement only | `julia --project=. test/runtests.jl full` |
| JUNA-WCz solver contract only | `julia --project=. test/runtests.jl coupled` |
| JUNA-WCz real initialization only | `julia --project=. test/runtests.jl coupled-init` |
| JUNA-WCz joint optimizer only | `julia --project=. test/runtests.jl coupled-solver` |
| JUNA-WCz block-coordinate optimizer only | `julia --project=. test/runtests.jl coupled-bcd` |
| JUNA-WCz public candidate only | `julia --project=. test/runtests.jl coupled-candidate` |
| JUNA-WCz end-to-end evidence only | `julia --project=. test/runtests.jl coupled-e2e` |
| Seeded-AWGN noise waterfall only | `julia --project=. test/runtests.jl noise` |
| Generate/check the test explorer | `make test-symbol-explorer` |
| The workbench (all lenses, one server, Ctrl-K search) | `make workbench` then http://127.0.0.1:8771 |
| Live test runner UI (explorer + per-suite run pages) | `make test-runner` then http://127.0.0.1:8771 |
| Interactive repo topology map | `make repo-mindmap` (also live at `/map` on the runner) |
| Validate the tutorial walkthroughs | `make walkthrough-check` |
| Behavioral browser checks (390px/1440px, search, focus) | `julia --project=. test/runtests.jl behavior` |
| Run tests + fixed-config bench, update trend dashboard | `make dashboard` |
| Download one measured channel | `make test-download-channel CHANNELS=red_1` |
| Download all color channels (~6 GB) | `make test-download-color-channels` |
| Check a real downloaded MAT schema | `make test-replay-schema CHANNELS=red_1` |
| Decode the fixed JunaCore WCz `red_1` segment | `make test-coupled-replay-segment` |
| Test the receiver-only benchmark and live page | `make test-receiver-benchmark` |
| Open the colored-channel comparison | `make workbench`, then http://127.0.0.1:8771/benchmark |
| Check replay reproduction scripts | `julia --project=. test/runtests.jl replay-scripts` |
| Check staged replay reproduction gates | `julia --project=. test/runtests.jl replay-gates` |
| Real ReplayCh workbench import gate | `make test-replay-workbench` |
| Real replay data integrity gate | `make test-replay-data CHANNELS=red_1` |
| Real smoke/proxy/full replay gates | `make test-replay-smoke`, `make test-replay-proxy`, `make test-replay-full` |
| Representative replay BER/timing sweep | `make replay-color-config-ber` |
| Rpchan concept-to-test audit | [`docs/RPCHAN_WORKBENCH_TEST_AUDIT.md`](../docs/RPCHAN_WORKBENCH_TEST_AUDIT.md) |

Selectors are case-insensitive substrings of a suite key, file name, or title.
An unknown selector fails with the list of valid keys. Suites print per-testset
results (`verbose = true`), so a failure names the claim that broke, not just a
line number.

## Test-to-theory map

Anchors are `\label` names in `papers/main.tex`; numbers in parentheses are
line numbers there.

| Suite key | File | Paper claim it protects |
|---|---|---|
| `packaging` | `source_layout.jl` | JUNA-lite, JUNA-Wz, constrained JUNA-WCz, and frame-wide LDPC exist as distinct loaded paths; the package exposes named facades for each public modem. |
| `config` | `receiver_configuration.jl` | `:lite`, `:full`, `:coupled`, and `:frame_wide_ldpc` select distinct modems, while `:robust` aliases `:full`; `init()` resets to the benchmark geometry while preserving mode and sync selection. |
| `interface` | `public_modem_interface.jl` | One shared modulate/demodulate boundary covers all six public modem modules. Receiver-only modes can consume the same coded waveform; Frame-wide LDPC uses its own matched transmit framing for multi-block tests. Geometry, polarity, payload rate, and clean roundtrip remain executable contracts. |
| `input-robustness` | `public_input_robustness.jl` | All six public modem modules reject malformed arguments, invalid geometry, and non-finite samples deliberately; benign finite transformations remain payload-exact. |
| `sizing` | `payload_block_sizing.jl` | Payload accounting excludes inner-pilot bits (`eq:goodput`, 1938): 170 unknown of k=340 (fig caption, 674); one block = 1024+256 = 1280 samples; positive block count = ceil(nbits/170), while zero payload size is rejected. All expectations are paper literals, not recomputed formulas. |
| `pilots` | `pilot_ratio_handling.jl` | Outer pilots are subcarrier comb pilots and inner pilots live inside the LDPC message row (523–524). In addition to pinning the paper's p3/ip2 default (1966–1971, 674), a dense numeric sweep checks nearest-1/k snapping, p2–p16 outer combs are recovered from the physical OFDM waveform, inner-off/ip2–ip16 positions survive framing and extraction, and every public receiver passes the pairwise clean-loopback matrix for every valid default-code spacing. |
| `layout` | `ofdm_layout.jl` | DC-nulled carrier plan: 341 comb pilots (agrees with fig caption, 672) + data tones partition the active set; deterministic ±1 pilot signs (golden prefix); contiguous near-even band partition (`eq:ofdm5-band-index`, 885–889); dc0 shifts the band circularly and keeps DC nulled. Its opening walkthrough renders the benchmark packet across time-domain, physical OFDM, and logical LDPC layers, with schema-checked counts. |
| `ldpc` | `ldpc_code_construction.jl` | LDPC helper binaries resolve from `tools/ldpc`; the default code is k=340, n=1360, `evencol`, `ldpc_npc=3`; generated `H`, generator rows, Tanner graph adjacency, cache invalidation, and `H·codeword == 0 mod 2` are checked before BP/JUNA consume the graph. Impossible dimensions/degrees fail before invoking a helper, and helper-process failures are translated into contextual `ArgumentError`s at the modem boundary. |
| `framing` | `message_framing_and_encoding.jl` | Framing builds a fixed-length LDPC message row from unknown payload bits, deterministic known inner-pilot anchors, and zero fill for a short final block. Paper-literal ip2/ip3 checks remain, while a general matrix covers k/n = 340/1360 and 170/680; inner pilots off and ip2/ip3/ip5/ip8/ip16; payload lengths 0, 1, half, exact capacity, and rejected capacity+1. Extraction skips the same anchors through `code.invperm`; systematic encoding and every parity check are verified for each matrix cell. |
| `carrier` | `carrier_mapping_and_modulation.jl` | Coded bits become BPSK/QPSK data carriers beside deterministic pilots; spare data tones are filled, inactive bins stay zero, the IFFT output is CP-prefixed and normalized, and the BPSK capacity gate prevents silent truncation. |
| `sync` | `sync_waveform.jl` | Optional sync is deterministic and isolated from coarse Doppler: `sync=false` is a no-op, `sync=true` emits a 2048-sample unit-magnitude LFM waveform, matched correlation peaks at the embedded lag, and every public receiver wraps OFDM blocks as `[sync][blocks][sync]`. |
| `sync-doppler` | `coarse_doppler_correction.jl` | Sync-assisted frame timing and Doppler correction consumes the sync pre/postamble: `_resample_to` has pinned ComplexF64 interpolation, clean sync-wrapped frames crop to the exact OFDM block with zero CFO, a controlled 17/16 time-scale estimates 1500 Hz and resamples back, and every public receiver's `sync=true` demodulation recovers a padded multi-block payload. |
| `acquisition` | `rpchan_acquisition.jl` | Rpchan-compatible frame acquisition uses a configurable QPSK preamble seed (default 10001; real workbench frames export `frame_seed + 10000`), optional guard, normalized lag correlation, an 81-point +/-5000 ppm Doppler grid, 64-phase windowed-sinc resampling, carrier derotation, and payload alignment. Controlled scale/lag fixtures and every public receiver's two-block public roundtrip are exact. The separately named `rpchan_winner` benchmark profile pins the paper run's zero guard and one-point Doppler grid. |
| `synthetic-channel` | `synthetic_uwa_channel.jl` | A deterministic six-tap/per-path-Doppler channel and calibrated seeded AWGN drive a one-block sample-identical waterfall through all six modules. A separate fixture checks coupled-state discrimination under physical model mismatch. |
| `frontend` | `receive_block_front_end.jl` | Receive block observations are isolated before equalization: CP samples are ignored, useful samples are split into partial-FFT windows, non-even branch counts still cover the useful symbol once, and summed branches reconstruct the standard FFT view for each public waveform block. |
| `equalization` | `pilot_equalization.jl` | The diagonal CP-OFDM equation is checked by direct FIR convolution with sufficient and insufficient CP. Pilot-trained equalization is then isolated before decoder candidates: `_fit_branch_weights!` solves both ordinary and confidence-weighted ridge normal equations, `_residual_pilot_equalize` removes flat and interpolated frequency-selective pilot responses, `_equalize_from_targets` recovers clean QPSK/filler carriers, a piecewise time-varying branch-channel fixture proves branch weights matter, and the global-pilot fallback stays finite when local bands have too few pilots. |
| `candidate` | `candidate_demodulation.jl` | Equalized carriers become decoder candidates with the right polarity and score fields: QPSK metrics clip to ±20 with positive = bit 1, explicit softer metrics stay finite and valid, pilot residuals flow into `pilot_mse`, and the posterior tie MSE matches the paper's confidence-weighted formula and floor for QPSK and BPSK. |
| `bp` | `ldpc_belief_propagation.jl` | LDPC belief propagation turns candidate metrics into posterior codeword decisions: the exact sum-product tanh/atanh update is an executable reference path, normalized min-sum remains the profiled default and has pinned signs/magnitudes, degree-one checks saturate to finite forced-zero evidence, inner pilots clamp known bits, clean codewords decode valid, modest corruptions correct, and heavy corruptions report invalid syndrome. |
| `frame-wide-ldpc` | `frame_wide_ldpc.jl` | `JunaFrameWideLDPC.Modulation()` preserves one OFDM carrier map per block, carries band-RLS weights and inverse covariances across blocks, converts global BP posteriors into soft QPSK anchors, and selects the best of four frame-level refits. The suite pins a hand-computed two-step RLS recurrence, proves inherited state differs from a reset fit, checks Rpchan pilot and realized-`d_c` contracts, and retains the global parity/clean/error/Lite-non-regression checks. |
| `lite` | `juna_lite_refinement.jl` | JUNA-lite refinement is forced past the valid-seed early return: posterior metrics become QPSK/BPSK soft anchors and confidence values, threshold/cap selection retains every outer pilot and ranks eligible data anchors, pilot rows receive unit weight while virtual data rows receive posterior-confidence weight, `_juna_step` refits an invalid seed into a finite valid candidate, `_juna_lite` recovers payload bits, and valid seeds are preserved. |
| `full` | `juna_full_refinement.jl` | JUNA-full / W,z refinement is tested below the public roundtrip: `_gradient_symbol_grid!` maps z to QPSK latents, the parity surrogate gradient is pinned, `_wz_loss_and_grad!` returns finite nonzero gradients and matches centered finite differences for selected W real/imag and z coordinates, `_gradient_candidate` and `_juna_wz_gradient_solve` decode valid candidates, `_juna_wz` recovers payload bits, and `_juna_wz_candidate` keeps the best candidate. |
| `coupled` | `juna_coupled_specification.jl` | The paper's ideal per-carrier C/W objective now has executable state dimensions, all seven finite loss families, and sampled C/W finite-difference checks. The public profile remains QPSK, one-symbol, K=1, band-tied C/W and additionally proves discrimination against diagonal-only C and corrupted z. A misleading-W fixture pins the deployed runtime policy (`observation=1.0`, `tie=0.1`) and requires physical fit to overrule the wrong tie minimum. The suite also checks independent profiled-C stationarity and parity direction, exhaustively compares all 38 real C/W/z coordinates, and requires quadratic joint Taylor convergence. |
| `coupled-init` | `juna_coupled_initialization.jl` | Step 7 maps a real Partial-FFT/LDPC block into `_CoupledProblem`, maps systematic inner pilots through `code.invperm`, and deterministically initializes pilot-trained W, ridge-profiled K=1 C, and BP-seeded hard-clamped z. |
| `coupled-solver` | `juna_coupled_optimization.jl` | Step 8 runs bounded joint Adam on the hand-derived C/W/z gradients, preserves hard inner-pilot clamps, records finite losses, recovers a controlled ICI fixture, and returns the best finite objective checkpoint. |
| `coupled-bcd` | `juna_coupled_block_coordinate.jl` | A second optimizer alternates W, C, and z on exactly the same frozen QPSK/K=1/band-tied objective and initialization as joint Adam. Every block uses a fresh analytic gradient and backtracking rollback; complete-cycle loss must be finite and monotone, hard inner-pilot logits remain fixed, and a shared fixture proves both solvers start from the identical scalar objective. |
| `coupled-candidate` | `juna_coupled_candidate.jl` | Step 9 converts optimized W,z into equalized carriers and correctly polarized decoder metrics, passes them through normalized min-sum BP, preserves a better seed, and exposes `CoupledModulation` / `JunaCoupled.Modulation` with capability `:coupled_cwz`. |
| `coupled-e2e` | `juna_coupled_end_to_end.jl` | Step 10 requires exact clean three-block recovery, then uses a fixed 0.08-subcarrier residual offset plus seeded AWGN to prove public Coupled dispatch differs from and beats Lite/Seed at 0 dB. At 1.5 dB it requires the accepted candidate to reduce syndrome while bounding any truth-error increase to four bits. Warmed decode time is logged but is not a machine-dependent correctness gate. |
| `noise` | `noise_roundtrip.jl` | Lite, Wz, and WCz consume the exact same 12 seeded payloads, clean waveforms, and unit complex-noise vectors. Each is bracketed at BER == 0 at 4 dB, 0 < BER < 0.30 at 1.5 dB, BER > 0.05 at 0 dB, with monotone BER in SNR. Assertions remain portable bands while the fixture-equality test proves the receiver comparison is sample-for-sample fair. |
| `replay-download` | `replay_channel_download.jl` | Optional measured-channel fixture gate inspired by `Juna_replay_channel_1ch`: validates red/blue/yellow channel naming, git-LFS `data/<channel>.mat` paths, MAT v5/HDF5 signature plus size checks, and explicit opt-in download before any replay-segment decode test; the real download reports skipped/broken until enabled. |
| `replay-schema` | `replay_mat_schema.jl` | Acceptance item 2 for replay segment decode: downloaded MAT files expose `h_hat`, `phi_hat`/`theta_hat`, and `params.fs_delay`/`fc`/`fs_time` in the shape the sibling measured-channel reader consumes; the real MAT inspection reports skipped/broken until enabled. |
| `replay-segment` | `replay_coupled_segment.jl` | A test-local ReplayCh-compatible adapter validates tap order and time-varying FIR interpolation against an independent two-tap example, validates known-reference alignment, and bridges the Rpchan `basebandHz = fs_delay / 2` profile onto the capture delay grid. A second identity fixture exercises the reference 12x real-passband path: RRC interpolation, upconversion, analytic downmix, capture-grid replay, remodulation, matched downconversion, and public acquisition. The opt-in real gate pins `red_1` at 9.6 kHz baseband on its declared 19.2 kHz delay grid, receiver 3, snapshot 1, and requires an exact 170-bit WCz decode, zero syndrome, a lower coupled objective, preservation of the already-valid seed, deterministic non-timing diagnostics, and a BER/objective/timing CSV row. |
| `golden-diff` | `rpchan_golden_comparison.jl` | The synthetic contract proves exact-input comparison, active-bin/`1/sqrt(N)` Partial-FFT normalization, seed/final stage separation, first-divergence short-circuiting, and explicit LDPC structural mismatch reporting. With `JUNA_RPCHAN_GOLDEN=1`, ReplayCh exports one deterministic SG-1 receiver-3 frame at 20 dB and JunaCore consumes the exact 152706 passband samples. Passband, lag 21, Partial-FFT carriers, seed RLS symbols/LLRs/LDPC bits, final JUNA symbols/LLRs/LDPC bits all pass; the largest observed symbol delta is below `1e-13`. |
| `receiver-benchmark` | `receiver_channel_benchmark.jl` | The common `/benchmark` page compares the five receiver-only profiles on identical per-symbol-coded samples across all 12 captures. Frame-wide LDPC remains N/A in that table because it changes transmit FEC framing. Its separate matched-transmitter lane pins all twelve paper configurations and native rates, uses the Rpchan-compatible preamble, carrier order, global systematic LDPC code, and re-encoded per-packet acceptance rule, and writes measured-versus-paper PSR/BER/timing CSV rows through `tools/reproduce_paper_frame_wide.jl`. |
| `commit-rate-benchmark` | `commit_code_rate_benchmark.jl` | The commit-history benchmark holds SG-1, 20 dB, seed 1, and CP=16 fixed while sweeping N=512/1024/2048 and LDPC rates 1/16, 1/8, 1/4, and 1/2 across Standard, Partial FFT, Lite, Wz, and WCz. The clean identity contract proves all 60 geometries are valid and payload-exact, including capacity-fitted coded lengths 672/1360/2720. The measured recorder then maps sequential complete blocks over more than 99% of the full 47.7917-second SG-1 capture, rejects dirty JunaCore source, and records block PSR, aggregate mean BER, mean decode time per block, and successful-block effective data rate under the exact source commit. |
| `replay-scripts` | `replay_reproduction_scripts.jl` | Keeps the measured-channel `replay channel results juna.tex` reproduction path executable: bootstrap data, sanity decode, representative BER/timing sweep, proxy pipeline, full pipeline, and TeX rebuild wrappers expose dry-run contracts, and a fake real-mode workbench proves the shared context helper reaches the requested command. |
| `replay-gates` | `replay_reproduction_gates.jl` | The staged reproduction ladder for the replay paper: repo boundary, ReplayCh workbench shape, data integrity, ReplayCh import, smoke run, sanity decode, figure artifact parse, TeX build, proxy run, single-segment sanity, table spot-check, and full-capture reproduction. Cheap structural gates run by default; disabled real workbench stages report as skipped/broken, and become assertions only when their `JUNA_REPLAY_*` env vars / Make targets are enabled. |
| `test-explorer` | `test_symbol_explorer_contract.jl` | The generated `docs/test_symbol_explorer.html` view renders each registered suite as a browsable node with claim, command, testsets, direct source-symbol references, and replay gate status. |
| `runner` | `test_runner_server_contract.jl` | The live runner streams validated suite subsets and serves run pages, progress, repo-restricted source, and commit-stamped history. Its bounded `/api/probe` path runs the actual receiver in QPSK or compact BPSK mode and returns pilot-equalized carriers labelled by transmitted code bits, separate hard-decision classes, branch reconstruction evidence, and seed/JUNA syndromes. |
| `mindmap` | `repo_mindmap_contract.jl` | `REPO_MINDMAP.md` (the curated repo map) renders as `docs/repo_mindmap.html`: start-here goal cards, a collapsible per-area topology tree with live file facts (exists, line counts, covering suite), and the receiver-pipeline ribbon whose stages deep-link to `/run/<key>`. The contract keeps the map truthful: generation fails the suite if the md names a file that no longer exists. |
| `workbench` | `workbench_contract.jl` | The unifying frame: `tools/workbench_data.py` builds ONE graph over files, symbols, suites, testsets, pipeline stages, curated `annotations.json` cards, and full-suite run history, with reverse indices (file → symbols defined, symbol → referencing suites/testsets, file → covering suites); `--check` fails on any dangling edge. The server provides Home, Tests, Bench, Map, and History destinations, `/symbol/<name>` (definition + annotation + coverage with run links), `/api/searchindex`, and a shared Search palette and first-run task tour. Subset runs never become suite verdicts, stale runs are labeled against the current checkout, and embedded runner pages omit duplicated workbench chrome. |
| `walkthrough` | `walkthrough_contract.jl` | The tutorial overlay behind the runner. Clicking the "Now testing" code pane (or `explain`) blacks out the page and steps through the testset's code full-screen, with annotated pop-ups, paper anchors, live source-symbol links, and an animated diagram per step from `docs/test_walkthroughs.json` (authored by the `gen-walkthroughs` / `gen-test-diagrams` Workflows; structural fallback for un-authored testsets). Authored kinds include `seq`, `flow`, `packet`, exact toy `tanner` graphs, `partialfft` window anatomy, and BPSK/QPSK `constellation` geometry, plus an auto-derived module map. `tools/walkthrough_data.py --check` keeps every step's line range, diagram schema, equation citation, and source symbol honest, so code or test drift forces its explanation to be refreshed. |
| `dashboard` | `dashboard_contract.jl` | `make dashboard` appends one record per run (test pass counts + fixed-config decode benchmark) to `bench/history.jsonl` keyed by commit, and renders `docs/test_dashboard.html` with trend charts. Fixed config: default `LiteModulation()`/`FullModulation()` (paper geometry `n1024_cp256_sym1_p3_r0p25_ip2`), seeded AWGN (`Xoshiro(42)`, 40 packets) at 1.5 dB (mid-waterfall, lite BER ≈ 5e-2 — maximally regression-sensitive) and 2.5 dB (near-clean sentinel), plus a noiseless decode-time point. Fixed seed makes BER/PSR bit-deterministic: any movement is a code change. Decode time is tracked here as a benchmark, deliberately NOT a hard-timed CI assertion (wall-clock tests on shared machines are flaky). |
| `behavior` | `browser_behavior.jl` | Headless Chrome drives the served lenses like a user (via `docs/behavior_harness.html`, same-origin iframes): the Find card opens a POPULATED palette, multi-word queries match (tokenized AND), map filtering dims non-matching pipeline stages and reports a per-category breakdown, no lens scrolls sideways at 390px or 1440px, the home page separates "Last verified" from "Current checkout", and dialog focus lands inside the tour. Skips (recorded as broken) when no Chrome/Chromium is on PATH. |
| `contract` | `interface_contract.jl` | The shared catalog must exactly equal runtime profiles. Every modem has an executable capability, including `:frame_wide_ldpc`; all six named modules pass clean interface loopback, and the opt-in strict gate exercises multi-block framing. |

## How to tell the tests test the right thing

Three rules used throughout (from the 2026-07 test audit):

1. **Expected values are literals derived from the paper**, never recomputed
   with the implementation's own formula. Example: `bitspersymbol == 170`
   (k=340 minus 170 ip2 anchors, main.tex:674) instead of
   `ldpc_k - cld(ldpc_k, 2)`, which would pass even with a wrong `ldpc_k`.
2. **Decode correctness is asserted by default.** The noiseless loopback with an
   alternating bit pattern runs unconditionally in `interface` and `contract`;
   it fails on polarity flips and bit reordering that an all-zeros payload (the
   old, env-gated check) could never detect.
3. **Package defaults and ReplayCh experiment profiles are kept separate.**
   The paper now labels both evidence layers explicitly; tests pin executable
   JunaCore behavior without pretending that a package unit test regenerates a
   measured ReplayCh table.

### Package defaults versus measured-workbench profiles

| Quantity | JunaCore reference implementation | Separate ReplayCh profile | Where pinned |
|---|---|---|---|
| Active / pilot / data tones (`N=1024`) | 1023 / 341 / 682 | Profile-dependent | `ofdm_layout.jl`, paper `tab:junacore-defaults` |
| Coded bits per block | `n=1360`; 680 QPSK tones plus two fillers | Profile-dependent | `ofdm_layout.jl`, `ldpc_code_construction.jl` |
| Combiner bands | 16 (`_PARTIAL_FFT_NBANDS`) | 4 in the reported profile | `ofdm_layout.jl`, paper `tab:hyperparams` |
| LDPC construction | `evencol`, `ldpc_npc=3`, fixed seed | `dc4` workbench configuration | `receiver_configuration.jl`, `ldpc_code_construction.jl` |
| Lite update | Confidence-weighted batch ridge-LS, two passes | Recursive RLS, four-pass cap | `juna_lite_refinement.jl` |
| BP / Wz steps | 20 BP / 20 Adam | 8 fast or 24 BP cap / 30 Adam | `ldpc_belief_propagation.jl`, `juna_full_refinement.jl` |
| Sync (LFM) length | 2048 samples at each end | Capture/profile-dependent | `payload_block_sizing.jl`, `sync_waveform.jl` |

`walkthrough_contract.jl` reads live package constants and requires
`papers/main.tex` to state these JunaCore defaults and the separate ReplayCh
provenance. Changing either side without updating the other therefore fails the
walkthrough suite.

## What is deliberately NOT covered yet

Honest gaps (each is a good next test, roughly in value order):

- **Blind measured-waveform replay and paper-table reproduction** — the receiver
  benchmark now computes BER, PSR with Wilson intervals, failures, and
  mean/median/p95 timing for the five receiver-only profiles
  across all 12 channel estimates, with optional seeded AWGN and multiple channel
  snapshots. Its strict preflight covers every capture and receiver-only profile at 0/30 dB,
  and the report target sweeps `0:5:30` dB. It still uses the known transmit waveform for oracle alignment and
  applies the measured `h_hat`/phase tracks to generated packets; it does not decode
  raw recorded packets, perform blind acquisition, or reproduce the paper tables.
- **Exact ReplayCh receiver equivalence beyond one golden frame** — frame-wide
  LDPC is correctly N/A in the identical-waveform receiver table and has a
  separate matched-transmitter measured-channel lane. The SG-1 golden frame now
  matches every exported numerical stage through final LDPC output. The twelve
  full-capture rows remain the statistical reproduction gate; a one-frame match
  does not by itself prove every channel result.
- **BP behavior under realistic noisy channels** — `ldpc_belief_propagation.jl`
  now covers the exact sum-product reference, profiled normalized min-sum,
  clamps, clean/corrupted outcomes, and syndrome reporting, but not
  BER-vs-SNR or replay-channel BP convergence.
- **BPSK under impairment** — the public configuration matrix now proves a
  clean `bpc=1` encode/decode roundtrip, but noisy and replay decode still use
  QPSK.
- **Receiver superiority under independent raw captures** — synthetic and measured
  channel-estimate comparisons now exercise all public modes, but they report the
  outcome rather than asserting that one receiver must win. A superiority claim
  still needs an independently specified raw-capture protocol and uncertainty bounds.
- **`isvalid` edge branches** — np bounds, `bpc ∉ {1,2}`, `k ≥ n`, the
  dc0-Nyquist-fit rule.
