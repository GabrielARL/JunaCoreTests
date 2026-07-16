#!/usr/bin/env julia
#
# Carrier mapping and modulation - coded bits to BPSK/QPSK carriers, pilots,
# IFFT samples, and cyclic prefix.
#
# Paper claims protected (papers/main.tex):
#   fig:packet-tanner-example (lines 670-679)  The coded bits occupy QPSK data
#                                             tones beside deterministic outer
#                                             pilots in an OFDM block.
#   sec:method (1919-1964)                    The public modem boundary sends
#                                             an OFDM waveform whose length is
#                                             determined by CP + useful symbol.
#
# If this fails: the transmitter may have changed bit-to-symbol polarity, moved
# data onto pilot tones, stopped filling spare tones, or broken the CP/IFFT frame
# that the receiver front end expects.
#
# Run alone:  julia --project=. test/carrier_mapping_and_modulation.jl
# Via runner: julia --project=. test/runtests.jl carrier

using FFTW
using Statistics
using Test
using JunaCore

const CarrierMapJuna = JunaCore.Juna
const CARRIER_MAP_FC = 24_000.0
const CARRIER_MAP_FS = 24_000.0

bit_pattern(n::Integer) = Bool[isodd(count_ones(3i + 1)) for i in 1:n]

local_pm(bit::Bool) = bit ? -1.0 : 1.0
local_bpsk(bit::Bool) = ComplexF64(local_pm(bit), 0.0)

function local_qpsk(codeword::AbstractVector{Bool}, tone::Integer)
    j = 2 * (Int(tone) - 1) + 1
    bI = codeword[j]
    bQ = j + 1 <= length(codeword) ? codeword[j + 1] : false
    ComplexF64(local_pm(bI), local_pm(bQ)) / sqrt(2)
end

function local_carrier_symbol(m, codeword::AbstractVector{Bool}, tone::Integer)
    Int(m.bpc) == 1 ? local_bpsk(codeword[tone]) : local_qpsk(codeword, tone)
end

function expected_carriers(m, layout, codeword)
    carriers = zeros(ComplexF64, Int(m.nc))
    carriers[layout.pilot_idx] .= layout.pilot_syms
    ntones = cld(length(codeword), Int(m.bpc))
    for (i, k) in enumerate(layout.data_idx)
        carriers[k] = i <= ntones ? local_carrier_symbol(m, codeword, i) : one(ComplexF64)
    end
    carriers
end

function expected_block(m, carriers)
    sym = ifft(carriers)
    L = Int(m.np)
    N = Int(m.nc)
    raw = Vector{ComplexF64}(undef, L + N)
    raw[1:L] .= sym[N-L+1:N]
    raw[L+1:end] .= sym
    raw ./ std(raw)
end

function recovered_carriers(m, layout, block)
    L = Int(m.np)
    observed = fft(block[L+1:end])
    pilot = first(layout.pilot_idx)
    scale = layout.pilot_syms[1] / observed[pilot]
    observed .* scale
end

function assert_cp_and_normalization(m, block)
    L = Int(m.np)
    N = Int(m.nc)
    @test block isa Vector{ComplexF64}
    @test length(block) == L + N
    @test all(x -> isfinite(real(x)) && isfinite(imag(x)), block)
    @test std(block) ≈ 1.0 atol=2e-14
    @test block[1:L] ≈ block[N+1:N+L] atol=2e-14
end

function assert_carrier_plan(m, layout, codeword, carriers)
    ntones = cld(length(codeword), Int(m.bpc))
    expected = expected_carriers(m, layout, codeword)
    inactive = setdiff(1:Int(m.nc), layout.active)

    @test carriers[layout.pilot_idx] ≈ layout.pilot_syms atol=2e-12
    @test carriers[layout.data_idx[1:ntones]] ≈ expected[layout.data_idx[1:ntones]] atol=2e-12
    @test carriers[layout.data_idx[ntones+1:end]] ≈ fill(one(ComplexF64), length(layout.data_idx) - ntones) atol=2e-12
    @test carriers[inactive] ≈ zeros(ComplexF64, length(inactive)) atol=2e-12
    @test carriers[1] ≈ 0.0 + 0.0im atol=2e-12
end

@testset verbose = true "JUNA carrier mapping and modulation" begin
    @testset "carrier-symbol truth tables: QPSK bit pairs and odd final bit" begin
        m = CarrierMapJuna.LiteModulation()
        codeword = Bool[
            false, false,  # +I +Q
            true, false,   # -I +Q
            false, true,   # +I -Q
            true, true,    # -I -Q
            true,          # odd final Q bit pads to false => +Q
        ]

        invsqrt2 = 1 / sqrt(2)
        @test CarrierMapJuna._carrier_symbol(m, codeword, 1) ≈ ComplexF64( 1,  1) * invsqrt2
        @test CarrierMapJuna._carrier_symbol(m, codeword, 2) ≈ ComplexF64(-1,  1) * invsqrt2
        @test CarrierMapJuna._carrier_symbol(m, codeword, 3) ≈ ComplexF64( 1, -1) * invsqrt2
        @test CarrierMapJuna._carrier_symbol(m, codeword, 4) ≈ ComplexF64(-1, -1) * invsqrt2
        @test CarrierMapJuna._carrier_symbol(m, codeword, 5) ≈ ComplexF64(-1,  1) * invsqrt2
    end

    @testset "carrier-symbol truth table: BPSK one bit per tone" begin
        m = CarrierMapJuna.LiteModulation(bpc = 1)
        codeword = Bool[false, true, false]

        @test CarrierMapJuna._carrier_symbol(m, codeword, 1) == ComplexF64(1.0, 0.0)
        @test CarrierMapJuna._carrier_symbol(m, codeword, 2) == ComplexF64(-1.0, 0.0)
        @test CarrierMapJuna._carrier_symbol(m, codeword, 3) == ComplexF64(1.0, 0.0)
    end

    @testset "QPSK block: pilots, data symbols, filler tones, IFFT, and CP" begin
        m = CarrierMapJuna.LiteModulation()
        layout = CarrierMapJuna._layout(m, CARRIER_MAP_FS)
        codeword = bit_pattern(1360)

        @test CarrierMapJuna._ndata_tones(m, length(codeword)) == 680
        @test length(layout.data_idx) == 682

        block = CarrierMapJuna._modulate_block(m, layout, codeword)
        expected = expected_block(m, expected_carriers(m, layout, codeword))
        assert_cp_and_normalization(m, block)
        @test block ≈ expected atol=2e-14

        carriers = recovered_carriers(m, layout, block)
        assert_carrier_plan(m, layout, codeword, carriers)
    end

    @testset "BPSK block: one bit per data tone and unused tones filled" begin
        m = CarrierMapJuna.LiteModulation(bpc = 1)
        layout = CarrierMapJuna._layout(m, CARRIER_MAP_FS)
        codeword = Bool[false, true, true, false, false, true]

        @test CarrierMapJuna._ndata_tones(m, length(codeword)) == length(codeword)

        block = CarrierMapJuna._modulate_block(m, layout, codeword)
        expected = expected_block(m, expected_carriers(m, layout, codeword))
        assert_cp_and_normalization(m, block)
        @test block ≈ expected atol=2e-14

        carriers = recovered_carriers(m, layout, block)
        assert_carrier_plan(m, layout, codeword, carriers)
        @test carriers[layout.data_idx[1:6]] ≈ ComplexF64[
            1 + 0im, -1 + 0im, -1 + 0im, 1 + 0im, 1 + 0im, -1 + 0im
        ] atol=2e-12
    end

    @testset "BPSK capacity gate prevents full-code truncation" begin
        default_bpsk = CarrierMapJuna.LiteModulation(bpc = 1)
        fit_bpsk = CarrierMapJuna.LiteModulation(bpc = 1, ldpc_k = UInt16(170), ldpc_n = UInt16(680))

        @test length(CarrierMapJuna._layout(default_bpsk, CARRIER_MAP_FS).data_idx) == 682
        @test !isvalid(default_bpsk, CARRIER_MAP_FC, CARRIER_MAP_FS)
        @test isvalid(fit_bpsk, CARRIER_MAP_FC, CARRIER_MAP_FS)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA carrier mapping and modulation checks passed")
end
