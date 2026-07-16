#!/usr/bin/env julia
#
# Coarse Doppler correction - sync-peak timing, resampling, and sync=true decode.
#
# Paper claims protected (papers/main.tex):
#   sec:method (1919-1964)                Sync-assisted demodulation removes coarse
#                                        frame timing/Doppler before OFDM blocks
#                                        are handed to the receiver.
#   measured replay captures (1951-1958)  The measured-channel replay path depends
#                                        on sync acquisition before segment decode.
#
# If this fails: sync pre/postambles may still be generated, but the receiver may
# crop the wrong block region, estimate the wrong time scale/CFO, or fail to
# decode a clean sync-wrapped frame.
#
# Run alone:  julia --project=. test/coarse_doppler_correction.jl
# Via runner: julia --project=. test/runtests.jl sync-doppler

using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const SyncDopplerJuna = JunaCore.Juna
const SyncDopplerModulations = JunaCore.Modulations
const SYNC_DOPPLER_FC = 24_000.0
const SYNC_DOPPLER_FS = 24_000.0
const SYNC_DOPPLER_SYNC_LEN = 2048
const SYNC_DOPPLER_SCALE = 17 / 16

sync_doppler_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(7i + 1)) for i in 1:n]

sync_doppler_linear_block(n::Integer) =
    ComplexF64[0.01 + 0.0001i + im * (-0.02 + 0.0002i) for i in 1:Int(n)]

function sync_doppler_scaled_frame(m, blocks, scale::Real; fs::Real = SYNC_DOPPLER_FS)
    sync = SyncDopplerJuna._sync_waveform(m, fs)
    S = SyncDopplerJuna._synclen(m)
    nominal_blocks = length(blocks)
    D0 = S + nominal_blocks
    p1 = 4
    D = round(Int, Float64(scale) * D0)
    p2 = p1 + D
    bstart = p1 + round(Int, Float64(scale) * S)
    bstop = p2 - 1
    stretched = SyncDopplerJuna._resample_to(blocks, bstop - bstart + 1)
    waveform = zeros(ComplexF64, p2 + S - 1 + 3)
    waveform[p1:p1+S-1] .+= sync
    waveform[p2:p2+S-1] .+= sync
    waveform[bstart:bstop] .= stretched
    (waveform = waveform, p1 = p1, p2 = p2, bstart = bstart, bstop = bstop,
     D0 = D0, D = D, expected_cfo = (D / D0 - 1) * SYNC_DOPPLER_FC)
end

@testset verbose = true "JUNA sync-assisted frame timing and Doppler correction" begin
    @testset "_resample_to returns ComplexF64 linear interpolation with stable endpoints" begin
        x = ComplexF32[1 + 1im, 3 + 5im, 5 + 9im]
        y = SyncDopplerJuna._resample_to(x, 5)

        @test y isa Vector{ComplexF64}
        @test y ≈ ComplexF64[1 + 1im, 2 + 3im, 3 + 5im, 4 + 7im, 5 + 9im] atol=1e-12
        @test SyncDopplerJuna._resample_to(x, 3) == ComplexF64.(x)
        @test SyncDopplerJuna._resample_to(x, 1) == ComplexF64[1 + 1im]
        @test SyncDopplerJuna._resample_to(x, 0) == ComplexF64[]
        @test SyncDopplerJuna._resample_to(ComplexF64[], 3) == ComplexF64[]
    end

    @testset "_coarse_doppler extracts clean sync-wrapped OFDM blocks with zero CFO" begin
        m = SyncDopplerJuna.LiteModulation(sync = true)
        nbits = SyncDopplerModulations.bitspersymbol(m)
        bits = sync_doppler_payload_pattern(nbits)
        waveform = SyncDopplerModulations.modulate(m, bits, SYNC_DOPPLER_FC, SYNC_DOPPLER_FS)
        S = SyncDopplerJuna._synclen(m)
        blocklen = SyncDopplerJuna._blocklen(m)
        payload_blocks = waveform[S+1:end-S]
        corrected, cfo = SyncDopplerJuna._coarse_doppler(m, waveform, SYNC_DOPPLER_FC,
                                                         SYNC_DOPPLER_FS, 1)

        @test S == SYNC_DOPPLER_SYNC_LEN
        @test length(payload_blocks) == blocklen
        @test corrected isa Vector{ComplexF64}
        @test length(corrected) == blocklen
        @test corrected == payload_blocks
        @test cfo == 0.0
    end

    @testset "_coarse_doppler estimates controlled time scale and resamples block region" begin
        m = SyncDopplerJuna.LiteModulation(sync = true)
        blocklen = SyncDopplerJuna._blocklen(m)
        blocks = sync_doppler_linear_block(blocklen)
        frame = sync_doppler_scaled_frame(m, blocks, SYNC_DOPPLER_SCALE)
        sync = SyncDopplerJuna._sync_waveform(m, SYNC_DOPPLER_FS)
        corr = SyncDopplerJuna._matched_corr(frame.waveform, sync)
        half = div(length(corr), 2)
        front_peak = argmax(@view corr[1:half])
        back_peak = half + argmax(@view corr[half+1:end])
        corrected, cfo = SyncDopplerJuna._coarse_doppler(m, frame.waveform,
                                                         SYNC_DOPPLER_FC,
                                                         SYNC_DOPPLER_FS, 1)

        @test front_peak == frame.p1
        @test back_peak == frame.p2
        @test frame.D / frame.D0 == SYNC_DOPPLER_SCALE
        @test frame.bstart > frame.p1 + SYNC_DOPPLER_SYNC_LEN - 1
        @test length(corrected) == blocklen
        @test cfo ≈ frame.expected_cfo atol=1e-12
        @test cfo ≈ 1500.0 atol=1e-12
        @test maximum(abs.(corrected .- blocks)) < 1e-12
    end

    @testset "sample rate sets sync time while carrier frequency scales reported CFO" begin
        m = SyncDopplerJuna.LiteModulation(sync = true)
        blocks = sync_doppler_linear_block(SyncDopplerJuna._blocklen(m))
        sample_rates = (12_000.0, 24_000.0, 48_000.0)
        carrier_frequencies = (12_000.0, 24_000.0, 48_000.0)
        reference_sync = SyncDopplerJuna._sync_waveform(m, first(sample_rates))

        for fs in sample_rates
            sync = SyncDopplerJuna._sync_waveform(m, fs)
            frame = sync_doppler_scaled_frame(m, blocks, SYNC_DOPPLER_SCALE; fs = fs)

            @test length(sync) / fs ≈ SYNC_DOPPLER_SYNC_LEN / fs atol=1e-15
            @test sync ≈ reference_sync atol=2e-14
            for fc in carrier_frequencies
                corrected, cfo = SyncDopplerJuna._coarse_doppler(
                    m, frame.waveform, fc, fs, 1)
                @test cfo ≈ (SYNC_DOPPLER_SCALE - 1) * fc atol=1e-12
                @test maximum(abs.(corrected .- blocks)) < 1e-12
            end
        end
    end

    @testset "public sync=true demodulate roundtrip recovers padded multi-block payload" begin
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                m = public_receiver(descriptor; sync = true)
                nbits = SyncDopplerModulations.bitspersymbol(m) + 1
                bits = sync_doppler_payload_pattern(nbits)
                waveform = SyncDopplerModulations.modulate(
                    m, bits, SYNC_DOPPLER_FC, SYNC_DOPPLER_FS)
                metrics, cfo = SyncDopplerModulations.demodulate(
                    m, nbits, waveform, SYNC_DOPPLER_FC, SYNC_DOPPLER_FS)

                @test length(waveform) == SyncDopplerModulations.signallength(
                    m, nbits, SYNC_DOPPLER_FC, SYNC_DOPPLER_FS)
                @test metrics isa Vector{Float64}
                @test length(metrics) == nbits
                @test all(isfinite, metrics)
                @test (metrics .> 0) == bits
                @test cfo == 0.0
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA coarse Doppler correction checks passed")
end
