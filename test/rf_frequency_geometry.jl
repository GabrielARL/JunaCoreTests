#!/usr/bin/env julia
#
# RF frequency geometry - every public receiver must transmit on the band its
# bw/dc0 settings declare, and its own demodulator must recover that waveform.
#
# Contract:
#   occupied width = bw * fs
#   RF centre      = fc + dc0 * 1 kHz
#   RF edges       = centre +/- occupied width / 2
#
# FFT-bin quantization and the DC null make the realized edges approximate.
# JUNA-FrameRLS is intentionally pinned to the Rpchan full-band dc0=0 protocol;
# this suite verifies its actual default waveform and its explicit rejection of
# half-band/shifted requests instead of pretending those settings are supported.
#
# Run alone:  julia --project=. test/rf_frequency_geometry.jl
# Via runner: julia --project=. test/runtests.jl frequency-geometry

using Test
using FFTW
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const FrequencyGeometryJuna = JunaCore.Juna
const FrequencyGeometryModulations = JunaCore.Modulations
const FREQUENCY_GEOMETRY_FC = 24_000.0
const FREQUENCY_GEOMETRY_FS = 24_000.0

function frequency_geometry_payload(nbits::Integer)
    Bool[isodd(count_ones(17i + 3)) for i in 1:Int(nbits)]
end

function frequency_geometry_rf_edges(bins, nfft::Integer, fc::Real, fs::Real)
    signed = [(bin - 1) <= nfft ÷ 2 ? bin - 1 : bin - 1 - nfft for bin in bins]
    extrema(Float64(fc) .+ signed .* (Float64(fs) / nfft))
end

function frequency_geometry_payload_start(m, fs)
    if m.sync && m.sync_profile === :rpchan
        return length(FrequencyGeometryJuna._rpchan_preamble(m, fs)) +
               FrequencyGeometryJuna._rpchan_guard_length(m, fs)
    elseif m.sync && m.sync_profile === :lfm
        return FrequencyGeometryJuna._synclen(m)
    end
    0
end

function frequency_geometry_waveform_bins(m, waveform, fs)
    nfft = Int(m.nc)
    first = frequency_geometry_payload_start(m, fs) + Int(m.np) + 1
    last = first + nfft - 1
    spectrum = fft(@view waveform[first:last])
    threshold = maximum(abs, spectrum) * 1e-9
    findall(value -> abs(value) > threshold, spectrum)
end

function assert_frequency_geometry(descriptor; bw, dc0, expected_edges)
    m = public_receiver(descriptor; nc=2048, np=128, bw=bw, dc0=dc0)
    @test isvalid(m, FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)

    payload = frequency_geometry_payload(
        FrequencyGeometryModulations.bitspersymbol(m))
    waveform = FrequencyGeometryModulations.modulate(
        m, payload, FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
    layout = FrequencyGeometryJuna._layout(m, FREQUENCY_GEOMETRY_FS)
    waveform_bins = frequency_geometry_waveform_bins(
        m, waveform, FREQUENCY_GEOMETRY_FS)
    @test waveform_bins == sort(layout.active)

    edges = frequency_geometry_rf_edges(
        waveform_bins, Int(m.nc), FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
    bin_width = FREQUENCY_GEOMETRY_FS / Int(m.nc)
    @test isapprox(edges[1], expected_edges[1]; atol=2bin_width)
    @test isapprox(edges[2], expected_edges[2]; atol=2bin_width)
    @test isapprox(edges[2] - edges[1], bw * FREQUENCY_GEOMETRY_FS;
                   atol=2bin_width)

    metrics, cfo = FrequencyGeometryModulations.demodulate(
        m, length(payload), waveform,
        FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
    @test (metrics .> 0) == payload
    @test cfo == 0.0
end

@testset verbose = true "JUNA RF frequency geometry across public receivers" begin
    @testset "every module's default waveform occupies fc +/- fs/2" begin
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                m = public_receiver(descriptor)
                @test m.bw == 1.0
                @test m.dc0 == 0
                @test isvalid(m, FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)

                payload = frequency_geometry_payload(
                    FrequencyGeometryModulations.bitspersymbol(m))
                waveform = FrequencyGeometryModulations.modulate(
                    m, payload, FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
                bins = frequency_geometry_waveform_bins(
                    m, waveform, FREQUENCY_GEOMETRY_FS)
                layout = FrequencyGeometryJuna._layout(m, FREQUENCY_GEOMETRY_FS)
                # Rpchan stores wrapped carriers negative-frequency first;
                # findall returns numeric FFT-bin order. Occupancy is a set
                # contract, while carrier ordering has its own golden gate.
                @test bins == sort(layout.active)

                edges = frequency_geometry_rf_edges(
                    bins, Int(m.nc), FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
                bin_width = FREQUENCY_GEOMETRY_FS / Int(m.nc)
                @test isapprox(edges[1], 12_000.0; atol=2bin_width)
                @test isapprox(edges[2], 36_000.0; atol=2bin_width)

                metrics, _ = FrequencyGeometryModulations.demodulate(
                    m, length(payload), waveform,
                    FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
                @test (metrics .> 0) == payload
            end
        end
    end

    @testset "every configurable module realizes half-band and +1 kHz waveforms" begin
        configurable = filter(
            descriptor -> descriptor.supports_shifted_band,
            public_receiver_descriptors())
        @test length(configurable) == 6
        for descriptor in configurable
            @testset "$(descriptor.name) / dc0=0" begin
                assert_frequency_geometry(
                    descriptor; bw=0.5, dc0=0,
                    expected_edges=(18_000.0, 30_000.0))
            end
            @testset "$(descriptor.name) / dc0=1 kHz" begin
                assert_frequency_geometry(
                    descriptor; bw=0.5, dc0=1,
                    expected_edges=(19_000.0, 31_000.0))
            end
        end
    end

    @testset "JUNA-FrameRLS rejects frequency geometry outside its pinned protocol" begin
        descriptor = only(filter(
            item -> item.key === :frame_rls,
            public_receiver_descriptors()))
        for kwargs in ((bw=0.5, dc0=0), (bw=1.0, dc0=1))
            m = public_receiver(descriptor; kwargs...)
            @test !isvalid(m, FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
            @test_throws ArgumentError FrequencyGeometryModulations.modulate(
                m, Bool[false], FREQUENCY_GEOMETRY_FC, FREQUENCY_GEOMETRY_FS)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA RF frequency geometry checks passed")
end
