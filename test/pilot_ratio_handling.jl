#!/usr/bin/env julia
#
# Pilot and ratio handling — how pilot densities become the paper's comb spacings.
#
# Paper claims protected (papers/main.tex):
#   ssec:packet-tanner-example        Two distinct pilot kinds: outer pilots are
#   (lines 523-527; also fig          frequency-domain comb pilots on known
#   caption 674-675)                  subcarriers; inner pilots are known positions
#                                     inside the LDPC message row (ordinary data
#                                     tones carry them — they are NOT extra OFDM
#                                     pilot tones).
#   sec:method (lines 1966-1971)      Benchmark config p3 / ip2: outer pilot every
#                                     3rd active tone, inner pilot every 2nd
#                                     message bit; with k=340 that means 170 inner
#                                     anchors (fig caption, line 674).
#
# The package expresses both as ratios and snaps them to the nearest 1/k comb;
# outer combs require k >= 2 (a pilot on every tone leaves no data), inner allow
# k = 1 (every message bit pinned — valid spacing, invalid modulation).
#
# If this fails: pilot densities drift from the paper's p3/ip2 geometry, or the
# ratio->spacing snapping changes, silently changing every equalizer's training set.
#
# Run alone:  julia --project=. test/pilot_ratio_handling.jl
# Via runner: julia --project=. test/runtests.jl pilots

using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const PilotRatioJuna = JunaCore.Juna

const PILOT_RATIO_FC = 24_000.0
const PILOT_RATIO_FS = 24_000.0

@testset verbose = true "JUNA pilot and ratio handling" begin
    @testset "ratio -> spacing snapping truth table (nearest 1/k, floor kmin)" begin
        @test PilotRatioJuna._ratio_spacing(-0.1, 2) == 0   # non-positive: off
        @test PilotRatioJuna._ratio_spacing(0.0, 2) == 0
        @test PilotRatioJuna._ratio_spacing(1 / 3, 2) == 3
        @test PilotRatioJuna._ratio_spacing(0.30, 2) == 3   # |0.30-1/3| < |0.30-1/4|
        @test PilotRatioJuna._ratio_spacing(0.40, 2) == 3   # |0.40-1/3| < |0.40-1/2|
        @test PilotRatioJuna._ratio_spacing(0.45, 2) == 2   # |0.45-1/2| < |0.45-1/3|
        @test PilotRatioJuna._ratio_spacing(1.0, 2) == 2    # kmin floor for outer combs
        @test PilotRatioJuna._ratio_spacing(1.0, 1) == 1    # inner pilots may pin every bit
    end

    @testset "defaults realize the paper's p3 / ip2 config (main.tex:1966-1971)" begin
        default = PilotRatioJuna.LiteModulation()
        @test PilotRatioJuna._pilot_spacing(default) == 3       # outer: every 3rd active tone
        @test PilotRatioJuna._inner_pilot_spacing(default) == 2 # inner: every 2nd message bit
        @test PilotRatioJuna._n_inner(default, 340) == 170      # 170 anchors in k=340 (line 674)
    end

    @testset "inner-pilot density: off and every-3rd variants" begin
        no_inner = PilotRatioJuna.LiteModulation(inner_pilot_ratio = 0.0)
        @test PilotRatioJuna._inner_pilot_spacing(no_inner) == 0
        @test PilotRatioJuna._n_inner(no_inner, 340) == 0

        every_third_inner = PilotRatioJuna.LiteModulation(inner_pilot_ratio = 1 / 3)
        @test PilotRatioJuna._inner_pilot_spacing(every_third_inner) == 3
        @test PilotRatioJuna._n_inner(every_third_inner, 340) == 114  # ceil(340/3)
    end

    @testset "field-level snapping and the outer/inner kmin asymmetry" begin
        snapped_outer = PilotRatioJuna.LiteModulation(pilot_ratio = 0.30)
        snapped_inner = PilotRatioJuna.LiteModulation(inner_pilot_ratio = 0.40)
        @test PilotRatioJuna._pilot_spacing(snapped_outer) == 3
        @test PilotRatioJuna._inner_pilot_spacing(snapped_inner) == 3

        dense_outer = PilotRatioJuna.LiteModulation(pilot_ratio = 1.0)
        dense_inner = PilotRatioJuna.LiteModulation(inner_pilot_ratio = 0.75)
        @test PilotRatioJuna._pilot_spacing(dense_outer) == 2   # outer floor: k >= 2
        # 0.75 is exactly midway between 1/1 and 1/2; this pins the snapper's
        # tie-break, which resolves toward the smaller spacing (denser comb).
        @test PilotRatioJuna._inner_pilot_spacing(dense_inner) == 1
    end

    @testset "isvalid gates pilot ratios to (0,1] outer, [0,1] inner, payload > 0" begin
        default = PilotRatioJuna.LiteModulation()
        @test isvalid(default, PILOT_RATIO_FC, PILOT_RATIO_FS)
        @test !isvalid(PilotRatioJuna.LiteModulation(pilot_ratio = 0.0),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)   # no outer pilots: nothing to train on
        @test !isvalid(PilotRatioJuna.LiteModulation(pilot_ratio = -0.1),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)
        @test !isvalid(PilotRatioJuna.LiteModulation(pilot_ratio = 1.1),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)
        @test !isvalid(PilotRatioJuna.LiteModulation(inner_pilot_ratio = -0.1),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)
        @test !isvalid(PilotRatioJuna.LiteModulation(inner_pilot_ratio = 1.1),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)
        # 0.75 ties toward spacing 1 (see above) -> every message bit is an inner
        # pilot -> zero payload -> invalid
        @test !isvalid(PilotRatioJuna.LiteModulation(inner_pilot_ratio = 0.75),
                       PILOT_RATIO_FC, PILOT_RATIO_FS)
    end
end

using FFTW: fft

const GENERAL_PILOT_SPACINGS = 2:16

function brute_force_spacing(ratio::Real, kmin::Int)
    ratio <= 0 && return 0
    candidates = collect(kmin:max(kmin + 1, ceil(Int, 1 / ratio) + 1))
    errors = abs.(Float64(ratio) .- 1.0 ./ candidates)
    candidates[argmin(errors)]
end

function general_pilot_bits(n::Integer)
    Bool[isodd(count_ones(5i + 3)) for i in 1:n]
end

@testset verbose = true "JUNA generalized inner and outer pilot-ratio matrix" begin
    @testset "dense numeric ratio sweep agrees with an independent nearest-1/k search" begin
        ratios = unique(vcat(collect(range(0.01, 1.0; length = 100)),
                             [0.013, 0.027, 0.073, 0.149, 0.301, 0.449, 0.749, 0.999]))

        @test PilotRatioJuna._ratio_spacing(0.0, 1) == 0
        @test PilotRatioJuna._ratio_spacing(0.0, 2) == 0
        for ratio in ratios
            @test PilotRatioJuna._ratio_spacing(ratio, 2) ==
                  brute_force_spacing(ratio, 2)
            @test PilotRatioJuna._ratio_spacing(ratio, 1) ==
                  brute_force_spacing(ratio, 1)
        end
    end

    @testset "p2 through p16 outer combs occupy exactly the expected FFT bins" begin
        for spacing in GENERAL_PILOT_SPACINGS
            m = PilotRatioJuna.LiteModulation(pilot_ratio = 1 / spacing)
            layout = PilotRatioJuna._layout(m, PILOT_RATIO_FS)
            expected_pilots = [k for k in layout.active if mod(k - 2, spacing) == 0]
            expected_data = [k for k in layout.active if mod(k - 2, spacing) != 0]

            @test PilotRatioJuna._pilot_spacing(m) == spacing
            @test layout.pilot_idx == expected_pilots
            @test layout.data_idx == expected_data
            @test isempty(intersect(layout.pilot_idx, layout.data_idx))
            @test sort(vcat(layout.pilot_idx, layout.data_idx)) == layout.active

            # Recover the actual transmitted carriers after IFFT, normalization,
            # cyclic-prefix insertion, CP removal, and FFT. This proves that the
            # pilot locations are present in the waveform, not only in metadata.
            ncoded = min(Int(m.ldpc_n), Int(m.bpc) * length(layout.data_idx))
            codeword = general_pilot_bits(ncoded)
            block = PilotRatioJuna._modulate_block(m, layout, codeword)
            observed = fft(block[Int(m.np) + 1:end])
            scale = layout.pilot_syms[1] / observed[layout.pilot_idx[1]]
            recovered = observed .* scale

            @test recovered[expected_pilots] ≈ layout.pilot_syms atol=2e-12
            @test recovered[setdiff(1:Int(m.nc), layout.active)] ≈
                  zeros(ComplexF64, Int(m.nc) - length(layout.active)) atol=2e-12
        end
    end

    @testset "inner pilots off and ip2 through ip16 occupy exact message positions" begin
        code = PilotRatioJuna._code(PilotRatioJuna.LiteModulation())
        for spacing in vcat(0, collect(GENERAL_PILOT_SPACINGS))
            ratio = spacing == 0 ? 0.0 : 1 / spacing
            m = PilotRatioJuna.LiteModulation(inner_pilot_ratio = ratio)
            inner_positions = spacing == 0 ? Int[] : collect(1:spacing:code.k)
            data_positions = setdiff(1:code.k, inner_positions)
            payload = general_pilot_bits(length(data_positions))
            message = PilotRatioJuna._build_message(m, code, payload)

            @test PilotRatioJuna._inner_pilot_spacing(m) == spacing
            @test PilotRatioJuna._n_inner(m, code.k) == length(inner_positions)
            @test JunaCore.Modulations.bitspersymbol(m) == length(data_positions)
            @test message[inner_positions] == PilotRatioJuna._inner_bit.(inner_positions)
            @test message[data_positions] == payload

            metrics = fill(-20.0, code.n)
            nparity = code.n - code.k
            for p in 1:code.k
                metrics[code.invperm[nparity + p]] = message[p] ? 20.0 : -20.0
            end
            @test PilotRatioJuna._payload_from_metrics(m, code, metrics) == payload
        end

        all_inner = PilotRatioJuna.LiteModulation(inner_pilot_ratio = 1.0)
        @test PilotRatioJuna._inner_pilot_spacing(all_inner) == 1
        @test JunaCore.Modulations.bitspersymbol(all_inner) == 0
        @test !isvalid(all_inner, PILOT_RATIO_FC, PILOT_RATIO_FS)
    end

    @testset "every valid p3-p16 and ip-off/ip2-ip16 spacing gets a public clean roundtrip" begin
        boundary_pairs = [(3, 0), (3, 2), (3, 16),
                          (16, 0), (16, 2), (16, 16)]
        coverage_pairs = [(outer, outer - 1) for outer in 4:15]
        spacing_pairs = unique(vcat(boundary_pairs, coverage_pairs, [(8, 15)]))
        @test sort(unique(first.(spacing_pairs))) == collect(3:16)
        @test sort(unique(last.(spacing_pairs))) == vcat(0, collect(2:16))

        payload = general_pilot_bits(63)
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                m = public_receiver(descriptor)
                for (outer_spacing, inner_spacing) in spacing_pairs
                    m.pilot_ratio = 1 / outer_spacing
                    m.inner_pilot_ratio = inner_spacing == 0 ? 0.0 : 1 / inner_spacing

                    @test isvalid(m, PILOT_RATIO_FC, PILOT_RATIO_FS)
                    waveform = JunaCore.Modulations.modulate(
                        m, payload, PILOT_RATIO_FC, PILOT_RATIO_FS)
                    metrics, cfo = JunaCore.Modulations.demodulate(
                        m, length(payload), waveform, PILOT_RATIO_FC, PILOT_RATIO_FS)

                    @test length(waveform) == Int(m.nc) + Int(m.np)
                    @test all(isfinite, metrics)
                    @test (metrics .> 0) == payload
                    @test cfo == 0.0
                end
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA pilot and ratio handling checks passed")
end
