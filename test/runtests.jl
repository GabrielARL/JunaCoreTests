#!/usr/bin/env julia
#
# JunaCore test runner.
#
# Usage:
#   julia --project=. -e 'using Pkg; Pkg.test()'          # all suites
#   julia --project=. test/runtests.jl                    # all suites
#   julia --project=. test/runtests.jl layout pilots      # only matching suites
#   julia --project=. test/runtests.jl list               # print the test-to-theory map, run nothing
#   julia --project=. test/runtests.jl roundtrip          # contract suite + extended multi-block roundtrip
#   julia --project=. -e 'using Pkg; Pkg.test(test_args=["layout"])'
#
# A selector matches a suite key, file name, or title (case-insensitive
# substring). Every test file is also runnable on its own, e.g.
# `julia --project=. test/ofdm_layout.jl`.
#
# Each suite header and test/README.md state which papers/main.tex claims the
# suite protects (anchors are \label names; line numbers refer to main.tex).

using Test

const SUITES = [
    (key = "packaging", file = "source_layout.jl",
     title = "Source layout and solver loading",
     claim = "the wrapper loads shared common code plus public Lite, Full, Coupled, and Frame-wide LDPC modules from dedicated solver files",
     paper = "sec:solver (main.tex:843), ssec:junalite (1522), ssec:gradient-juna (1622), eq:juna-total (791-823)"),
    (key = "config", file = "receiver_configuration.jl",
     title = "Receiver selection and init defaults",
     claim = ":lite, :full, :coupled, and :frame_wide_ldpc select distinct modems (:robust aliases :full); init() resets to the n1024_cp256_sym1_p3_r0p25_..._ip2 benchmark geometry",
     paper = "sec:solver (843), config string (1966-1971), tab:hyperparams (2011-2033)"),
    (key = "interface", file = "public_modem_interface.jl",
     title = "Public modulate/demodulate boundary",
     claim = "every registered receiver crosses the m-sequence, 3x3 fc/fs, Standard/Partial/JUNA, named geometry, waveform-length, metric-polarity, payload-rate, and error contracts; supported p16/P16 boundaries and a non-default rate/pilot geometry recover clean payloads, while unsupported BPSK refinements reject explicitly",
     paper = "sec:method (1919-1964), eq:goodput (1934-1939)"),
    (key = "input-robustness", file = "public_input_robustness.jl",
     title = "Public input integrity and benign waveform transformations",
     claim = "all receivers reject invalid frequency/payload arguments, non-finite samples, untrainable pilot combs, impossible LDPC codes, excessive Partial-FFT views, and invalid bandwidths before decoding; finite gain/DC/trailing samples preserve payload, while silence and seeded noise return finite deterministic diagnostics",
     paper = "sec:method (1919-1964), shared Modulations interface contract"),
    (key = "sizing", file = "payload_block_sizing.jl",
     title = "Payload bits and block sizing",
     claim = "positive payload sizes exclude inner pilots (170 unknown of k=340), reject zero, and count 1280-sample blocks (N=1024 + CP 256)",
     paper = "config string (1966-1971), fig:packet-tanner-example caption (670-679), eq:goodput (1934-1939)"),
    (key = "pilots", file = "pilot_ratio_handling.jl",
     title = "Pilot ratio snapping, placement, and roundtrip matrix",
     claim = "dense ratios snap to the nearest 1/k comb; p2-p16 outer FFT placement and inner-off/ip2-ip16 message placement are verified, and every registered receiver passes every valid p3-p16 public roundtrip",
     paper = "outer vs inner pilots (523-524), config string (1966-1971)"),
    (key = "layout", file = "ofdm_layout.jl",
     title = "OFDM tone layout and band partition",
     claim = "DC-nulled active set splits into 341 comb pilots + data tones; contiguous near-even band partition for the bandwise combiner",
     paper = "fig:packet-tanner-example (670-679), eq:ofdm5-band-index (885-889)"),
    (key = "ldpc", file = "ldpc_code_construction.jl",
     title = "LDPC code construction and cache",
     claim = "LDPC helper tools, H/G dimensions, Tanner graph adjacency, GF(2) parity, and code-cache invalidation are sane before BP/JUNA use them; impossible dimensions and helper failures surface as deliberate ArgumentErrors",
     paper = "fig:packet-tanner-example (670-679), sec:solver (843), config string (1966-1971)"),
    (key = "framing", file = "message_framing_and_encoding.jl",
     title = "Message framing and LDPC encoding",
     claim = "payload bits, zero fill, and deterministic inner pilots form general LDPC message rows across code sizes/spacings; extraction, systematic encoding, and parity preserve the contract",
     paper = "outer vs inner pilots (523-524), fig:packet-tanner-example (670-679), eq:goodput (1934-1939)"),
    (key = "carrier", file = "carrier_mapping_and_modulation.jl",
     title = "Carrier mapping and OFDM modulation",
     claim = "coded bits map to BPSK/QPSK data carriers with deterministic pilots, filler tones, IFFT samples, CP prefix, and normalized block power",
     paper = "fig:packet-tanner-example (670-679), sec:method (1919-1964)"),
    (key = "sync", file = "sync_waveform.jl",
     title = "LFM sync and matched correlation",
     claim = "sync=true produces a deterministic unit-magnitude LFM pre/postamble and matched-correlation peak, and every registered receiver's public modulate wraps OFDM blocks with it",
     paper = "sec:method (1919-1964), measured replay captures (1951-1958)"),
    (key = "sync-doppler", file = "coarse_doppler_correction.jl",
     title = "Sync-assisted frame timing and Doppler correction",
     claim = "sync peaks drive coarse time-scale/CFO estimation and block-region resampling, and every registered receiver's sync=true public demodulation recovers a padded multi-block payload",
     paper = "sec:method (1919-1964), measured replay captures (1951-1958)"),
    (key = "acquisition", file = "rpchan_acquisition.jl",
     title = "Rpchan preamble Doppler and payload acquisition",
     claim = "the deterministic Rpchan QPSK preamble, normalized lag correlation, polyphase time-scale resampling, carrier derotation, and payload extraction recover lagged multi-block frames through every public receiver",
     paper = "Rpchan cross-channel protocol: mk_preamble, dopp_est, tscale_resamp_bang, bb_align, and payload_at_lag"),
    (key = "synthetic-channel", file = "synthetic_uwa_channel.jl",
     title = "Synthetic underwater multipath and per-path Doppler",
     claim = "the six-tap paper PDP, full linear convolution, per-path time scale and carrier Doppler, calibrated seeded AWGN, and a sample-identical one-block six-module waterfall form a replay-data-free physical channel gate; a second fixture proves band-tied C still favors the true codeword under physical model mismatch",
     paper = "measured replay captures (1951-1958), sec:method (1919-1964)"),
    (key = "frontend", file = "receive_block_front_end.jl",
     title = "Partial-FFT receive front end",
     claim = "received OFDM blocks drop CP, split useful samples into partial-FFT branches, and branch sums reconstruct the standard FFT view",
     paper = "sec:method (1919-1964), eq:ofdm5-band-index (885-889), tab:hyperparams (2021)"),
    (key = "equalization", file = "pilot_equalization.jl",
     title = "Pilot-trained ridge LS equalization",
     claim = "pilot-trained branch weights solve ordinary and confidence-weighted ridge LS systems, residual pilot normalization removes flat/interpolated responses, and time-varying branch channels require the combiner before LDPC/BP",
     paper = "eq:ofdm5-band-index (885-889), sec:solver (843), tab:hyperparams (2021-2033)"),
    (key = "candidate", file = "candidate_demodulation.jl",
     title = "Soft-metric candidate demodulation",
     claim = "equalized carriers become correctly signed soft metrics; candidate ties use the paper's confidence-weighted posterior MSE for QPSK and BPSK; clean candidates return finite valid payload bits",
     paper = "sec:solver (843), eq:candidate-score, sec:method (1919-1964)"),
    (key = "bp", file = "ldpc_belief_propagation.jl",
     title = "Exact and normalized-min-sum belief propagation",
     claim = "the exact tanh/atanh sum-product reference and the profiled normalized min-sum decoder use public metric polarity, finite degree-one saturation, inner-pilot clamps, matching scratch buffers, and valid/invalid syndrome status",
     paper = "sec:solver (843), eq:bp-check/eq:bp-var, inner pilots (523-524, 670-679)"),
    (key = "frame-wide-ldpc", file = "frame_wide_ldpc.jl",
     title = "Frame-stateful band-RLS/JUNA and frame-wide LDPC",
     claim = "one receiver carries Rpchan-compatible band-RLS state across B OFDM blocks, refits from global BP posteriors, and decodes one (Bk,Bn) graph; existing receivers retain per-symbol fitting and codes",
     paper = "implementation-derived ReplayCh receiver-equivalence and FEC-scope experiment"),
    (key = "lite", file = "juna_lite_refinement.jl",
     title = "JUNA-lite soft-anchor refinement",
     claim = "posterior metrics become confidence-weighted soft data anchors, JUNA-lite refits an invalid seed into a finite valid candidate, and valid seeds are preserved",
     paper = "ssec:junalite (1522), sec:solver (843)"),
    (key = "full", file = "juna_full_refinement.jl",
     title = "JUNA-Wz reduced-gradient refinement",
     claim = "the reduced-gradient W,z objective has finite and finite-difference-checked gradients, returns valid decoded candidates, and keeps the best full-receiver candidate",
     paper = "ssec:gradient-juna (1622), sec:solver (843)"),
    (key = "coupled", file = "juna_coupled_specification.jl",
     title = "JUNA-WCz ideal and deployed objective specification",
     claim = "the paper's per-carrier C/W objective and the deployed band-tied seven-term objective have checked shapes and gradients; the fixed runtime weights make observation physics overrule a deliberately misleading W-z tie, and the profiled path has independent C stationarity, exhaustive finite differences, and joint quadratic Taylor convergence",
     paper = "eq:juna-wcz, eq:juna-total, ssec:juna-wcz"),
    (key = "coupled-init", file = "juna_coupled_initialization.jl",
     title = "JUNA-WCz real problem and initialization",
     claim = "one real Partial-FFT/LDPC block maps exactly into the constrained problem and deterministically initializes finite pilot-trained W, profiled K=1 C, and BP-seeded clamp-safe z",
     paper = "eq:juna-wcz, eq:juna-total, ssec:juna-wcz"),
    (key = "coupled-solver", file = "juna_coupled_optimization.jl",
     title = "JUNA-WCz bounded joint optimizer",
     claim = "bounded joint Adam consumes the hand-derived C/W/z gradient, preserves hard clamps, records finite loss history, recovers a controlled ICI fixture, and returns the best finite checkpoint",
     paper = "eq:juna-wcz, eq:juna-total, ssec:juna-wcz"),
    (key = "coupled-bcd", file = "juna_coupled_block_coordinate.jl",
     title = "JUNA-WCz safeguarded block-coordinate optimizer",
     claim = "alternating W, C, and z updates use the same frozen objective and hand-derived gradients as joint Adam; per-block backtracking keeps every complete cycle finite and monotonically non-increasing",
     paper = "eq:juna-wcz, eq:juna-total, ssec:juna-wcz"),
    (key = "coupled-candidate", file = "juna_coupled_candidate.jl",
     title = "JUNA-WCz candidate and public receiver",
     claim = "the optimized W,z state becomes a finite LDPC candidate, best-candidate selection cannot regress its seed, and public CoupledModulation declares and executes :coupled_cwz through the shared modem interface",
     paper = "eq:juna-wcz, eq:juna-total, ssec:juna-wcz"),
    (key = "coupled-e2e", file = "juna_coupled_end_to_end.jl",
     title = "JUNA-WCz clean and impaired end-to-end",
     claim = "public CoupledModulation decodes clean and mismatched channels, dispatches to the coupled solver, beats Seed and Lite at fixed 0 dB, and bounds the proxy-versus-truth tradeoff at 1.5 dB",
     paper = "eq:juna-wcz, eq:juna-total, sec:method, acceptance rule, tab:wcz-ici"),
    (key = "pfft", file = "partial_fft_receiver.jl",
     title = "Baseline receivers: standard OFDM and partial FFT",
     claim = "the paper's OFDM+FEC and Partial FFT+FEC benchmark branches are public receiver modes pinned to their demodulate_methods columns, per-band combining survives the within-symbol channel one-tap cannot, lite never loses to its own seed, and both baselines roundtrip BPSK",
     paper = "eq:pfft-ls, eq:ofdm5-band-index, sec:method"),
    (key = "noise", file = "noise_roundtrip.jl",
     title = "Seeded-AWGN waterfall roundtrip",
     claim = "every catalogued receiver decodes the exact same seeded payload/waveform/noise fixtures: clean at 4 dB, erroring at 1.5 dB, channel-limited at 0 dB, and monotone in SNR",
     paper = "sec:method (1919-1964), acceptance rule (1928-1932)"),
    (key = "replay-download", file = "replay_channel_download.jl",
     title = "Replay: channel capture download",
     claim = "measured-channel color captures can be named, URL-resolved, MAT-signature-gated, and explicitly downloaded before replay decode tests",
     paper = "measured replay captures (1951-1958), transfer channels (2205-2219)"),
    (key = "replay-schema", file = "replay_mat_schema.jl",
     title = "Replay: MAT file schema",
     claim = "downloaded replay-channel MAT files expose h_hat, phase estimates, and params in the shape consumed by the measured-channel reader",
     paper = "measured replay captures (1951-1958), replay evaluation protocol (1920-1958)"),
    (key = "replay-segment", file = "replay_coupled_segment.jl",
     title = "Replay: coupled measured segment decode",
     claim = "ReplayCh-compatible 9.6 kHz baseband on the red_1 19.2 kHz delay grid decodes receiver 3 snapshot 1 exactly with JUNA-WCz, preserves the already-valid seed while the optimizer lowers its objective, and records BER, syndrome, iteration, alignment, and decode time",
     paper = "measured replay captures, eq:juna-wcz, eq:juna-total, acceptance rule"),
    (key = "golden-diff", file = "rpchan_golden_comparison.jl",
     title = "Replay: one-frame stage-by-stage golden comparison",
     claim = "one immutable SG-1 passband frame is compared across ReplayCh and JunaCore at lag, Partial-FFT carriers, seed RLS symbols/LLRs/LDPC output, and final JUNA symbols/LLRs/LDPC output; downstream stages block after the first divergence",
     paper = "measured replay protocol; implementation differential rather than a paper-performance claim"),
    (key = "receiver-benchmark", file = "receiver_channel_benchmark.jl",
     title = "Replay: colored-channel and matched frame-wide benchmark",
     claim = "the common page compares five receiver-only profiles on identical per-symbol-coded samples; a separate matched-transmitter lane pins all twelve paper configurations and applies Rpchan's re-encoded packet-success rule to JUNA Frame-wide LDPC without pretending it consumed the shared waveform",
     paper = "measured replay captures (1951-1958), replay evaluation protocol (1920-1958), transfer study (2205-2248)"),
    (key = "replay-scripts", file = "replay_reproduction_scripts.jl",
     title = "Replay: paper reproduction scripts",
     claim = "scripted smoke/proxy/full workflows reproduce the measured-channel juna.tex pipeline without hiding the 6 GB data and hours-scale full run",
     paper = "replay evaluation protocol (1920-1958), transfer study (2205-2248)"),
    (key = "replay-gates", file = "replay_reproduction_gates.jl",
     title = "Replay: staged reproduction gates",
     claim = "repo boundary, ReplayCh workbench shape, data integrity, import, smoke, sanity, figure, TeX, proxy, spot-check, and full reproduction gates are explicit, opt-in by cost, and skipped when disabled",
     paper = "replay evaluation protocol (1920-1958), measured replay captures (1951-1958), transfer study (2205-2248)"),
    (key = "contract", file = "interface_contract.jl",
     title = "Modem interface and refinement capability contract",
     claim = "the shared receiver descriptor catalog exactly covers the runtime profile registry; every path satisfies Modulations, executes its declared objective, and decodes a noiseless loopback payload-exactly",
     paper = "sec:method (1919-1964), eq:juna-total, eq:gradient-rescue, acceptance rule (1928-1932, 2029)"),
]

function print_map(suites)
    println()
    println("JunaCore test-to-theory map (details: test/README.md)")
    println("=" ^ 78)
    key_width = max(11, maximum(length(s.key) for s in suites) + 2)
    for s in suites
        println(rpad(s.key, key_width), "test/", s.file)
        println(" " ^ key_width, "claim: ", s.claim)
        println(" " ^ key_width, "paper: ", s.paper)
    end
    println("=" ^ 78)
    println()
end

function select_suites(args)
    isempty(args) && return SUITES
    selected = empty(SUITES)
    for arg in args
        pat = lowercase(arg)
        # an exact suite key wins; otherwise substring-match key/file/title
        matches = filter(s -> s.key == pat, SUITES)
        if isempty(matches)
            matches = filter(SUITES) do s
                occursin(pat, s.key) || occursin(pat, lowercase(s.file)) ||
                    occursin(pat, lowercase(s.title))
            end
        end
        if isempty(matches)
            keys = join((s.key for s in SUITES), ", ")
            error("no test suite matches '$arg'; available suites: $keys " *
                  "(plus 'list' and 'roundtrip')")
        end
        append!(selected, matches)
    end
    unique(s -> s.key, selected)
end

args = copy(ARGS)

if "list" in args
    print_map(SUITES)
else
    # 'roundtrip' = run the interface contract with the extended multi-block
    # loopback enabled (same switch as JUNA_INTERFACE_ROUNDTRIP=1). It always
    # adds the contract suite, also when combined with other selectors.
    if "roundtrip" in args
        ENV["JUNA_INTERFACE_ROUNDTRIP"] = "1"
        args = filter(!=("roundtrip"), args)
        push!(args, "contract")
    end

    suites = select_suites(args)
    print_map(suites)

    @testset verbose = true "JunaCore" begin
        for s in suites
            include(s.file)
        end
    end
end
