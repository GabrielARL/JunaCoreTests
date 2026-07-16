#!/usr/bin/env julia
#
# Rpchan-compatible acquisition - QPSK preamble, Doppler-grid resampling,
# normalized payload alignment, and public decode integration.
#
# Reference behavior:
#   Rpchan/src/ReplayCh/OFDM/ModemRuntime/functions/{mk_preamble,dopp_est,
#   tscale_resamp_bang,bb_align,payload_at_lag}.jl
#
# If this fails: a receiver may still decode already-aligned OFDM blocks, but it
# cannot claim compatibility with the measured-replay framing used to produce
# cross_channel_paper.tex.
#
# Run alone:  julia --project=. test/rpchan_acquisition.jl

using Test
using JunaCore
using Random

include(joinpath(@__DIR__, "support", "public_receivers.jl"))

const RpchanAcquisitionJuna = JunaCore.Juna
const RpchanAcquisitionModulations = JunaCore.Modulations
const RPCHAN_ACQUISITION_FC = 24_000.0
const RPCHAN_ACQUISITION_FS = 24_000.0

rpchan_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(11i + 5)) for i in 1:Int(n)]

function rpchan_expected_preamble(n::Integer; seed::Integer = 10_001)
    rng = MersenneTwister(seed)
    alphabet = ComplexF64[
        (1 + 1im) / sqrt(2),
        (1 - 1im) / sqrt(2),
        (-1 + 1im) / sqrt(2),
        (-1 - 1im) / sqrt(2),
    ]
    ComplexF64[alphabet[rand(rng, eachindex(alphabet))] for _ in 1:Int(n)]
end

function rpchan_distort_for_correction(reference, scale, fc, fs)
    carrier_offset_hz = fc * (1 - scale)
    prerotated = ComplexF64[
        reference[n] * cispi(2 * carrier_offset_hz * (n - 1) / fs)
        for n in eachindex(reference)
    ]
    RpchanAcquisitionJuna._rpchan_resample(prerotated, inv(scale))
end

@testset verbose = true "JUNA Rpchan-compatible preamble Doppler and payload acquisition" begin
    @testset "Rpchan preamble and guard reproduce the reference frame constants" begin
        m = RpchanAcquisitionJuna.LiteModulation(
            sync = true,
            sync_profile = :rpchan,
        )
        preamble = RpchanAcquisitionJuna._rpchan_preamble(m, RPCHAN_ACQUISITION_FS)

        @test length(preamble) == 4_800
        @test preamble == rpchan_expected_preamble(length(preamble))
        @test maximum(abs.(abs2.(preamble) .- 1.0)) < 3e-16
        @test RpchanAcquisitionJuna._rpchan_guard_length(
            m, RPCHAN_ACQUISITION_FS,
        ) == 480
        @test m.rpchan_guard_s == 0.02
        @test m.rpchan_doppler_ppm == 5_000.0
        @test m.rpchan_doppler_steps == 81
        @test m.rpchan_sync_max_lag == 400
        @test RpchanAcquisitionJuna._rpchan_doppler_grid() ==
              collect(range(0.995, 1.005; length = 81))
        @test RpchanAcquisitionJuna._rpchan_doppler_grid(5_000.0, 1) == [1.0]

        workbench_seed = 61_001
        exported = RpchanAcquisitionJuna.LiteModulation(
            sync = true,
            sync_profile = :rpchan,
            rpchan_preamble_seed = workbench_seed,
        )
        exported_preamble = RpchanAcquisitionJuna._rpchan_preamble(
            exported, RPCHAN_ACQUISITION_FS,
        )
        @test exported_preamble == rpchan_expected_preamble(
            length(exported_preamble); seed = workbench_seed,
        )
        @test exported_preamble != preamble
    end

    @testset "normalized correlation finds the preamble and rejects short input" begin
        m = RpchanAcquisitionJuna.LiteModulation(
            sync = true,
            sync_profile = :rpchan,
        )
        preamble = RpchanAcquisitionJuna._rpchan_preamble(m, RPCHAN_ACQUISITION_FS)
        received = vcat(zeros(ComplexF64, 17), preamble, zeros(ComplexF64, 23))
        aligned = RpchanAcquisitionJuna._rpchan_align(
            received, preamble; max_lag = 40,
        )

        @test aligned.lag == 17
        @test aligned.score ≈ 1.0 atol = 2e-15
        @test aligned.scores[aligned.lag + 1] == maximum(aligned.scores)
        @test_throws ArgumentError RpchanAcquisitionJuna._rpchan_align(
            preamble[1:end-1], preamble; max_lag = 0,
        )
    end

    @testset "polyphase resampling and derotation invert a controlled Doppler scale" begin
        m = RpchanAcquisitionJuna.LiteModulation(
            sync = true,
            sync_profile = :rpchan,
        )
        preamble = RpchanAcquisitionJuna._rpchan_preamble(m, RPCHAN_ACQUISITION_FS)
        scale = 1.0025
        received = vcat(
            zeros(ComplexF64, 9),
            rpchan_distort_for_correction(
                preamble, scale, RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS,
            ),
            zeros(ComplexF64, 500),
        )
        estimate = RpchanAcquisitionJuna._rpchan_estimate_doppler(
            received, preamble, RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS,
        )

        @test RpchanAcquisitionJuna._rpchan_resample(preamble, 1.0) == preamble
        @test estimate.scale ≈ scale atol = 0.000125
        @test estimate.ppm ≈ 2_500.0 atol = 125.0
        @test estimate.lag in 8:10
        @test estimate.score > 0.95
        @test_throws ArgumentError RpchanAcquisitionJuna._rpchan_resample(
            preamble, 0.0,
        )
    end

    @testset "public modulation extracts and decodes a lagged Rpchan frame" begin
        assert_public_receiver_catalog()
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                m = public_receiver(
                    descriptor; sync = true, sync_profile = :rpchan,
                )
                payload_per_block = RpchanAcquisitionModulations.bitspersymbol(m)
                bits = rpchan_payload_pattern(2 * payload_per_block)
                waveform = RpchanAcquisitionModulations.modulate(
                    m, bits, RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS,
                )
                preamble = RpchanAcquisitionJuna._rpchan_preamble(
                    m, RPCHAN_ACQUISITION_FS,
                )
                guard_length = RpchanAcquisitionJuna._rpchan_guard_length(
                    m, RPCHAN_ACQUISITION_FS,
                )
                block_length = RpchanAcquisitionJuna._blocklen(m)

                @test length(waveform) ==
                      length(preamble) + guard_length + 2 * block_length
                @test waveform[1:length(preamble)] == preamble
                @test all(iszero,
                          waveform[length(preamble)+1:length(preamble)+guard_length])

                received = vcat(
                    zeros(ComplexF64, 31), waveform, zeros(ComplexF64, 64),
                )
                metrics, cfo = RpchanAcquisitionModulations.demodulate(
                    m, length(bits), received,
                    RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS,
                )
                @test (metrics .> 0) == bits
                @test cfo == 0.0
            end
        end
    end

    @testset "unsupported sync profiles are rejected at the public boundary" begin
        invalid = RpchanAcquisitionJuna.LiteModulation(
            sync = true,
            sync_profile = :unknown,
        )
        @test !isvalid(invalid, RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS)
        @test_throws ArgumentError RpchanAcquisitionModulations.modulate(
            invalid, Bool[true], RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS,
        )
        for malformed in (
            RpchanAcquisitionJuna.LiteModulation(rpchan_guard_s = -0.01),
            RpchanAcquisitionJuna.LiteModulation(rpchan_guard_s = NaN),
            RpchanAcquisitionJuna.LiteModulation(rpchan_doppler_ppm = -1.0),
            RpchanAcquisitionJuna.LiteModulation(rpchan_doppler_steps = 0),
            RpchanAcquisitionJuna.LiteModulation(rpchan_sync_max_lag = -1),
            RpchanAcquisitionJuna.LiteModulation(rpchan_preamble_seed = -1),
        )
            @test !isvalid(malformed, RPCHAN_ACQUISITION_FC, RPCHAN_ACQUISITION_FS)
        end
        @test_throws ArgumentError RpchanAcquisitionJuna._rpchan_doppler_grid(-1.0, 81)
        @test_throws ArgumentError RpchanAcquisitionJuna._rpchan_doppler_grid(5_000.0, 0)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA Rpchan-compatible acquisition checks passed")
end
