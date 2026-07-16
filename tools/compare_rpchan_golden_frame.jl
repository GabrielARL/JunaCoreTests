#!/usr/bin/env julia
#
# Consume a ReplayCh golden MAT artifact with JunaCore and report the first
# stage whose normalized numerical output differs.
#
#   julia --project=. tools/compare_rpchan_golden_frame.jl frame.mat report.tsv

using JunaCore
using MAT
using SignalAnalysis
using Statistics

include(joinpath(@__DIR__, "rpchan_golden_comparison.jl"))
using .RpchanGoldenComparison

const JunaImpl = JunaCore.Juna

length(ARGS) >= 1 || error("usage: compare_rpchan_golden_frame.jl GOLDEN.mat [REPORT.tsv]")
const GOLDEN_PATH = abspath(ARGS[1])
const REPORT_PATH = length(ARGS) >= 2 ? abspath(ARGS[2]) :
    joinpath(dirname(GOLDEN_PATH), "sg1_first_divergence.tsv")

function scalar(data, key, ::Type{T}) where T
    haskey(data, key) || error("golden artifact is missing $key")
    value = data[key]
    value = value isa AbstractArray ? only(vec(value)) : value
    convert(T, value)
end

function vector_of(data, key, ::Type{T}) where T
    haskey(data, key) || error("golden artifact is missing $key")
    T.(vec(data[key]))
end

function array_of(data, key, ::Type{T}) where T
    haskey(data, key) || error("golden artifact is missing $key")
    T.(data[key])
end

utf8_string(data, key) = String(UInt8.(vec(data[key])))

function load_reference(data)
    GoldenTrace(
        source=utf8_string(data, "source_utf8"),
        passband=vector_of(data, "passband", Float64),
        acquisition_lag=scalar(data, "acquisition_lag", Int),
        active_bins=vector_of(data, "active_bins", Int),
        partial_fft=array_of(data, "partial_fft", ComplexF64),
        seed_equalized=array_of(data, "seed_equalized_symbols", ComplexF64),
        seed_llrs=vector_of(data, "seed_channel_llrs", Float64),
        seed_ldpc_output=Bool.(vector_of(data, "seed_ldpc_output", Int)),
        equalized=array_of(data, "equalized_symbols", ComplexF64),
        llrs=vector_of(data, "channel_llrs", Float64),
        ldpc_output=Bool.(vector_of(data, "ldpc_output", Int)),
        fft_size=scalar(data, "nfft", Int),
        metadata=Dict{String,Any}(
            "ldpc_n" => scalar(data, "fec_n", Int),
            "ldpc_blocks" => 1,
            "ldpc_block_n" => scalar(data, "fec_n", Int),
            "ldpc_block_k" => scalar(data, "fec_k", Int),
            "equalizer_contract" => "ReplayCh symbol-sequential band RLS, forgetting=0.98, delta=0.01, then pilot-linear residual calibration",
        ),
    )
end

function downconvert_passband(data, passband)
    oversample = scalar(data, "passband_oversample", Int)
    carrier_hz = scalar(data, "carrier_hz", Float64)
    passband_rate = scalar(data, "passband_sample_rate_hz", Float64)
    rolloff = scalar(data, "interpolation_rolloff", Float64)
    pulse = SignalAnalysis.rrcosfir(rolloff, oversample)
    signal = SignalAnalysis.signal(passband, passband_rate)
    recovered = SignalAnalysis.downconvert(signal, oversample, carrier_hz, pulse)
    ComplexF64.(vec(SignalAnalysis.samples(recovered)))
end

function juna_modulation(data)
    symbols = scalar(data, "nofdm_symbols", Int)
    fec_n = scalar(data, "fec_n", Int)
    fec_k = scalar(data, "fec_k", Int)
    fec_d_c = scalar(data, "fec_d_c", Int)
    fec_n % symbols == 0 || error("ReplayCh fec_n is not divisible by OFDM symbols")
    fec_k % symbols == 0 || error("ReplayCh fec_k is not divisible by OFDM symbols")
    preamble_seed = scalar(data, "preamble_seed", Int)
    JunaImpl.FrameWideLDPCModulation(
        nc=UInt16(scalar(data, "nfft", Int)),
        np=UInt16(scalar(data, "cp", Int)),
        bw=1.0,
        bpc=2,
        pilot_ratio=1 / scalar(data, "pilot_spacing", Int),
        inner_pilot_ratio=1 / scalar(data, "inner_pilot_spacing", Int),
        sync=true,
        sync_profile=:rpchan,
        compatibility_profile=:rpchan,
        rpchan_preamble_seed=preamble_seed,
        rpchan_guard_s=scalar(data, "preamble_guard_s", Float64),
        rpchan_doppler_ppm=scalar(data, "doppler_search_ppm", Float64),
        rpchan_doppler_steps=scalar(data, "doppler_search_steps", Int),
        rpchan_sync_max_lag=scalar(data, "sync_max_lag_samples", Int),
        ldpc_k=div(fec_k, symbols),
        ldpc_n=div(fec_n, symbols),
        ldpc_npc=fec_d_c,
        ldpc_seed=preamble_seed - 10_000,
        partial_fft_parts=scalar(data, "partial_fft_parts", Int),
        partial_fft_nbands=scalar(data, "partial_fft_nbands", Int),
    )
end

function channel_metrics(m, code, layout, equalized)
    pilot_mse = mean(abs2,
        equalized[index] - symbol
        for (index, symbol) in zip(layout.pilot_idx, layout.pilot_syms)
    )
    beta = max(pilot_mse, JunaImpl._BETA_FLOOR)
    metrics = Vector{Float64}(undef, code.n)
    tones = cld(code.n, 2)
    for tone in 1:tones
        symbol = equalized[layout.data_idx[tone]]
        metrics[2tone - 1] = clamp(
            -2real(symbol) / beta, -JunaImpl._LLR_CLIP, JunaImpl._LLR_CLIP)
        2tone <= code.n && (metrics[2tone] = clamp(
            -2imag(symbol) / beta, -JunaImpl._LLR_CLIP, JunaImpl._LLR_CLIP))
    end
    metrics
end

function juna_lite_equalized(m, code, layout, observations)
    seed_symbols = JunaImpl._equalize_from_targets(
        m, observations, layout, layout.pilot_idx, layout.pilot_syms)
    seed = JunaImpl._candidate_from_equalized(m, code, layout, seed_symbols)
    seed.valid && return seed_symbols, seed

    current = seed
    best = seed
    best_symbols = seed_symbols
    for _ in 1:JunaImpl._JUNA_ITERS
        anchors = JunaImpl._juna_anchor_targets(m, layout, current.lpost_metric)
        symbols = JunaImpl._equalize_from_targets(
            m,
            observations,
            layout,
            anchors.target_idx,
            anchors.targets;
            target_weights=anchors.target_weights,
        )
        candidate = JunaImpl._candidate_from_equalized(
            m, code, layout, symbols)
        if JunaImpl._juna_better(best, candidate)
            best = candidate
            best_symbols = symbols
        end
        step_improves = JunaImpl._juna_better(current, candidate)
        current = candidate
        candidate.valid && break
        step_improves || break
    end
    best_symbols, best
end

function run_juna(data, reference)
    m = juna_modulation(data)
    fs = scalar(data, "baseband_sample_rate_hz", Float64)
    fc = scalar(data, "carrier_hz", Float64)
    nblocks = scalar(data, "nofdm_symbols", Int)
    baseband = downconvert_passband(data, reference.passband)
    exported_baseband = vector_of(data, "coarse_baseband", ComplexF64)
    baseband_delta = length(baseband) == length(exported_baseband) ?
        maximum(abs, baseband .- exported_baseband) : Inf
    println("passband handoff: exact samples; downconversion max_abs=", baseband_delta)

    acquired = JunaImpl._rpchan_acquire(m, baseband, fc, fs, nblocks)
    println("acquisition: ReplayCh lag=", reference.acquisition_lag,
            ", JunaCore lag=", acquired.lag,
            ", JunaCore ppm=", acquired.ppm,
            ", score=", acquired.score)
    nfft = Int(m.nc)
    block_length = nfft + Int(m.np)
    yparts = Array{ComplexF64}(undef, m.partial_fft_parts, nfft, nblocks)
    equalized = Matrix{ComplexF64}(undef, nfft, nblocks)
    code = JunaImpl._frame_code(m, nblocks)
    layout = JunaImpl._layout(m, fs)
    replay_pilot_mask = Bool.(vector_of(data, "pilot_mask", Int))
    replay_pilot_bins = Set(reference.active_bins[replay_pilot_mask])
    juna_pilot_bins = Set(layout.pilot_idx)
    pilot_overlap = length(intersect(replay_pilot_bins, juna_pilot_bins))

    for block_index in 1:nblocks
        lo = 1 + (block_index - 1) * block_length
        hi = block_index * block_length
        block = @view acquired.payload[lo:hi]
        observations = JunaImpl._branch_observations(m, block)
        yparts[:, :, block_index] .= observations
    end
    refinement = JunaImpl._frame_juna_refine(m, code, layout, yparts)
    equalized .= refinement.best_equalized
    seed_llrs = -refinement.seed.channel_metrics
    llrs = -refinement.best.channel_metrics
    seed_decoded = refinement.seed.bits
    decoded = refinement.best.bits

    GoldenTrace(
        source="JunaCore consuming $(basename(GOLDEN_PATH))",
        passband=reference.passband,
        acquisition_lag=acquired.lag,
        active_bins=reference.active_bins,
        partial_fft=yparts,
        seed_equalized=refinement.seed_equalized,
        seed_llrs=seed_llrs,
        seed_ldpc_output=seed_decoded,
        equalized=equalized,
        llrs=llrs,
        ldpc_output=decoded,
        fft_size=nfft,
        partial_fft_representation=:juna_full_unscaled,
        equalized_representation=:juna_full_bins,
        metadata=Dict{String,Any}(
            "ldpc_n" => code.n,
            "ldpc_blocks" => 1,
            "ldpc_block_n" => code.n,
            "ldpc_block_k" => code.k,
            "baseband_handoff_max_abs" => baseband_delta,
            "doppler_scale" => acquired.scale,
            "doppler_ppm" => acquired.ppm,
            "equalizer_contract" => "JunaCore frame-stateful band RLS, forgetting=0.98, delta=0.01, then pilot-linear residual calibration; pilot-bin overlap=$(pilot_overlap)/$(length(replay_pilot_bins)) ReplayCh and $(length(juna_pilot_bins)) JunaCore",
        ),
    )
end

data = MAT.matread(GOLDEN_PATH)
scalar(data, "schema_version", Int) == 1 || error("unsupported golden schema")
reference = load_reference(data)
actual = run_juna(data, reference)
report = compare_traces(reference, actual; atol=1e-9, rtol=1e-8)
print_report(report)
write_report(REPORT_PATH, report)
println("report: ", REPORT_PATH)
println("first numerical divergence: ", something(report.first_divergence, "none"))
