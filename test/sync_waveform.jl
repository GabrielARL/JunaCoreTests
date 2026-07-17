#!/usr/bin/env julia
#
# Optional sync waveform - deterministic LFM pre/postamble and matched correlation.
#
# Paper claims protected (papers/main.tex):
#   sec:method (1919-1964)                    A transmitted frame may carry a
#                                             measured-replay sync pre/postamble
#                                             around the OFDM payload region.
#   measured replay captures (1951-1958)      Sync is an explicit acquisition
#                                             aid before replay/channel decode.
#
# If this fails: sync=false may no longer be a no-op, sync=true may no longer
# create the expected LFM acquisition waveform, or the transmitter may have
# stopped wrapping OFDM blocks with the pre/postamble expected by coarse Doppler.
#
# Run alone:  julia --project=. test/sync_waveform.jl
# Via runner: julia --project=. test/runtests.jl sync

using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const SyncWaveformJuna = JunaCore.Juna
const SyncWaveformModulations = JunaCore.Modulations
const SYNC_WAVEFORM_FC = 24_000.0
const SYNC_WAVEFORM_FS = 24_000.0
const SYNC_WAVEFORM_LEN = 2048
const SYNC_WAVEFORM_BW = 0.9

sync_payload_pattern(n::Integer) = Bool[isodd(count_ones(5i + 3)) for i in 1:n]

function expected_sync_sample(index::Integer, S::Integer, fs::Real)
    n = Int(index) - 1
    T = S / fs
    k = clamp(SYNC_WAVEFORM_BW, 0.05, 1.0) * fs / T
    ComplexF64(cispi(k * (n / fs - T / 2)^2))
end

@testset verbose = true "JUNA optional sync waveform" begin
    @testset "sync=false is a true no-op for sync helpers" begin
        m = SyncWaveformJuna.LiteModulation(sync = false)

        @test SyncWaveformJuna._synclen(m) == 0
        @test SyncWaveformJuna._sync_waveform(m, SYNC_WAVEFORM_FS) == ComplexF64[]
    end

    @testset "sync=true creates a deterministic unit-magnitude LFM waveform" begin
        m = SyncWaveformJuna.LiteModulation(sync = true)
        sync = SyncWaveformJuna._sync_waveform(m, SYNC_WAVEFORM_FS)
        again = SyncWaveformJuna._sync_waveform(m, SYNC_WAVEFORM_FS)

        @test SyncWaveformJuna._synclen(m) == SYNC_WAVEFORM_LEN
        @test sync isa Vector{ComplexF64}
        @test length(sync) == SYNC_WAVEFORM_LEN
        @test sync == again
        @test all(x -> isfinite(real(x)) && isfinite(imag(x)), sync)
        @test maximum(abs.(abs.(sync) .- 1.0)) < 2e-15

        @test sync[1] ≈ expected_sync_sample(1, SYNC_WAVEFORM_LEN, SYNC_WAVEFORM_FS) atol=2e-15
        @test sync[SYNC_WAVEFORM_LEN ÷ 2 + 1] ≈
              expected_sync_sample(SYNC_WAVEFORM_LEN ÷ 2 + 1, SYNC_WAVEFORM_LEN, SYNC_WAVEFORM_FS) atol=2e-15
        @test sync[end] ≈ expected_sync_sample(SYNC_WAVEFORM_LEN, SYNC_WAVEFORM_LEN, SYNC_WAVEFORM_FS) atol=2e-15
    end

    @testset "matched correlation identifies a single embedded sync lag" begin
        m = SyncWaveformJuna.LiteModulation(sync = true)
        sync = SyncWaveformJuna._sync_waveform(m, SYNC_WAVEFORM_FS)
        rx = vcat(zeros(ComplexF64, 3), sync, zeros(ComplexF64, 5))
        corr = SyncWaveformJuna._matched_corr(rx, sync)

        @test corr isa Vector{Float64}
        @test length(corr) == 9
        @test argmax(corr) == 4
        @test corr[4] ≈ SYNC_WAVEFORM_LEN atol=1e-8
        @test corr[4] == maximum(corr)
        @test all(isfinite, corr)
        @test isempty(SyncWaveformJuna._matched_corr(sync[1:end-1], sync))
    end

    @testset "public modulate wraps OFDM blocks with front and back sync" begin
        lfm_receivers = filter(
            descriptor -> descriptor.supports_lfm,
            public_receiver_descriptors(),
        )
        @test length(lfm_receivers) == 6
        @test only(filter(
            descriptor -> !descriptor.supports_lfm,
            public_receiver_descriptors(),
        )).mode === :frame_rls
        for descriptor in lfm_receivers
            @testset "$(descriptor.name)" begin
                m = public_receiver(descriptor; sync = true)
                nbits = SyncWaveformModulations.bitspersymbol(m)
                bits = sync_payload_pattern(nbits)
                sync = SyncWaveformJuna._sync_waveform(m, SYNC_WAVEFORM_FS)
                waveform = SyncWaveformModulations.modulate(
                    m, bits, SYNC_WAVEFORM_FC, SYNC_WAVEFORM_FS)
                blocklen = SyncWaveformJuna._blocklen(m)

                @test waveform isa Vector{ComplexF64}
                @test length(waveform) == SyncWaveformModulations.signallength(
                    m, nbits, SYNC_WAVEFORM_FC, SYNC_WAVEFORM_FS)
                @test length(waveform) == 2 * SYNC_WAVEFORM_LEN + blocklen
                @test waveform[1:SYNC_WAVEFORM_LEN] == sync
                @test waveform[end-SYNC_WAVEFORM_LEN+1:end] == sync

                blocks = waveform[SYNC_WAVEFORM_LEN+1:end-SYNC_WAVEFORM_LEN]
                @test length(blocks) == blocklen
                @test all(x -> isfinite(real(x)) && isfinite(imag(x)), blocks)

                corr = SyncWaveformJuna._matched_corr(waveform, sync)
                front_lag = 1
                back_lag = SYNC_WAVEFORM_LEN + blocklen + 1
                @test corr[front_lag] ≈ SYNC_WAVEFORM_LEN atol=1e-8
                @test corr[back_lag] ≈ SYNC_WAVEFORM_LEN atol=1e-8
                @test maximum(corr) ≈ SYNC_WAVEFORM_LEN atol=1e-8
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA optional sync waveform checks passed")
end
