#!/usr/bin/env julia
#
# Real-receiver probe for the tutorial diagrams (run -> explain).
#
# ONE run of the ACTUAL JUNA receiver - modulate a random payload, add seeded
# AWGN at the requested SNR, demodulate - emits everything the interactive
# diagrams can reseed themselves with:
#
#   cloud       pilot-equalized data carriers, labelled by the transmitted
#               coded bits, plus each carrier's hard-decision class
#   partialfft  per-branch RMS energies of _branch_observations on the first
#               received block, plus the branch-sum reconstruction residual
#               (the exact invariant the frontend suite proves)
#   tanner      real syndrome weights: the pilot-equalized seed candidate
#               before JUNA refinement vs the final JUNA candidate, straight
#               from the .syndrome/.valid fields the receiver scores with
#
# The noise convention matches test/noise_roundtrip.jl exactly
# (sigma = sqrt(10^(-snr/10)/2) per complex component, fixed-seed Xoshiro), so
# the probe is the same computation the noise suite asserts on.
#
# Usage:  julia --project=. tools/diag_probe.jl --snr 1.5 --mod QPSK
# Emits one JSON line on stdout.

using JunaCore
using Random
using FFTW

const ProbeJuna = JunaCore.Juna
const ProbeModulations = JunaCore.Modulations
const PROBE_FC = 24_000.0
const PROBE_FS = 24_000.0
const PROBE_SEED = 20_260_710
const MAX_SYMBOLS = 96          # keep the returned cloud small + readable

jnum(x) = string(round(x, digits = 4))

function main()
    snr = 6.0
    modulation = "QPSK"
    args = copy(ARGS)
    i = 1
    while i < length(args)
        args[i] == "--snr" && (snr = parse(Float64, args[i + 1]))
        args[i] == "--mod" && (modulation = uppercase(args[i + 1]))
        i += 2
    end
    modulation in ("QPSK", "BPSK") || error("--mod must be QPSK or BPSK")

    m = modulation == "BPSK" ?
        ProbeJuna.LiteModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680) :
        ProbeJuna.LiteModulation()
    bps = ProbeModulations.bitspersymbol(m)
    rng = Xoshiro(PROBE_SEED)
    sigma = sqrt(10.0^(-snr / 10) / 2)

    bits = rand(rng, Bool, bps)
    w = ProbeModulations.modulate(m, bits, PROBE_FC, PROBE_FS)
    w = w .+ sigma .* (randn(rng, length(w)) .+ im .* randn(rng, length(w)))
    metrics, _ = ProbeModulations.demodulate(m, bps, w, PROBE_FC, PROBE_FS)

    nerr = count((metrics .> 0) .!= bits)
    ber = round(nerr / bps, digits = 4)

    # ---- partial FFT: the real front end on the first received block --------
    N = Int(m.nc); L = Int(m.np)
    block = @view w[1:ProbeJuna._blocklen(m)]
    yparts = ProbeJuna._branch_observations(m, block)
    P = size(yparts, 1)
    rms = [sqrt(sum(abs2, @view yparts[p, :]) / N) for p in 1:P]
    full = FFTW.fft(ComplexF64.(w[L+1:L+N]))             # standard FFT of the useful symbol
    recon = vec(sum(yparts; dims = 1))
    recon_rel = sqrt(sum(abs2, recon .- full)) / max(sqrt(sum(abs2, full)), 1e-12)

    code = ProbeJuna._code(m)
    layout = ProbeJuna._layout(m, PROBE_FS)
    message = ProbeJuna._build_message(m, code, bits)
    codeword = ProbeJuna._encode(code, message)
    equalized = ProbeJuna._equalize_from_targets(
        m, yparts, layout, layout.pilot_idx, layout.pilot_syms)

    # ---- constellation: actual equalized carriers + transmitted labels ------
    # k is the transmitted class, while decision is the quadrant/side where the
    # received carrier landed. A wrong decision therefore has k != decision and
    # is visibly coloured by truth on the wrong side of the decision boundary.
    pts = String[]
    bpc = Int(m.bpc)
    nsym = min(MAX_SYMBOLS, ProbeJuna._ndata_tones(m, length(codeword)))
    symbol_errors = 0
    for tone in 1:nsym
        received = equalized[layout.data_idx[tone]]
        transmitted = ProbeJuna._carrier_symbol(m, codeword, tone)
        truth = bpc == 1 ? (real(transmitted) < 0 ? 1 : 0) :
            (real(transmitted) < 0 ? 1 : 0) + (imag(transmitted) < 0 ? 2 : 0)
        decision = bpc == 1 ? (real(received) < 0 ? 1 : 0) :
            (real(received) < 0 ? 1 : 0) + (imag(received) < 0 ? 2 : 0)
        symbol_errors += truth != decision
        push!(pts, string("{\"x\":", jnum(real(received)),
                          ",\"y\":", jnum(imag(received)),
                          ",\"k\":", truth, ",\"decision\":", decision, "}"))
    end

    # ---- Tanner: real syndrome before vs after JUNA refinement --------------
    seed = ProbeJuna._seed_candidate(m, code, layout, yparts)
    juna = ProbeJuna._juna_candidate(m, code, layout, yparts, seed)
    checks = size(code.H, 1)

    println("{\"snr\":", snr, ",\"mod\":\"", modulation, "\",\"ber\":", ber,
            ",\"evidence\":\"pilot_equalized_carriers\"",
            ",\"labels\":\"transmitted_code_bits\"",
            ",\"symbol_errors\":", symbol_errors,
            ",\"cloud\":[", join(pts, ","), "]",
            ",\"partialfft\":{\"parts\":", P, ",\"nfft\":", N, ",\"cp\":", L,
              ",\"rms\":[", join(jnum.(rms), ","), "]",
              ",\"recon_rel\":", string(round(recon_rel, sigdigits = 2)), "}",
            ",\"tanner\":{\"checks\":", checks, ",\"n\":", code.n,
              ",\"seed_syndrome\":", seed.syndrome,
              ",\"seed_valid\":", seed.valid ? "true" : "false",
              ",\"juna_syndrome\":", juna.syndrome,
              ",\"juna_valid\":", juna.valid ? "true" : "false", "}",
            "}")
end

main()
