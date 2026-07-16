#!/usr/bin/env julia
#
# Receive block front end - CP removal and partial-FFT branch observations.
#
# Paper claims protected (papers/main.tex):
#   sec:method (1919-1964)                    The receiver processes whole
#                                             OFDM blocks after CP removal.
#   eq:ofdm5-band-index (885-889)             JUNA observes the received symbol
#                                             through partial-FFT branches before
#                                             pilot fitting and LDPC feedback.
#   tab:hyperparams (2021)                    The profiled receiver uses four
#                                             partial-FFT temporal views.
#
# If this fails: the receive front end may be reading cyclic-prefix samples as
# data, slicing the useful symbol into the wrong temporal windows, or feeding
# later equalizer/JUNA stages branch observations that no longer reconstruct the
# standard FFT view.
#
# Run alone:  julia --project=. test/receive_block_front_end.jl
# Via runner: julia --project=. test/runtests.jl frontend

using FFTW
using Test
using JunaCore

const ReceiveFrontEndJuna = JunaCore.Juna
const ReceiveFrontEndModulations = JunaCore.Modulations
const RECEIVE_FRONT_END_FC = 24_000.0
const RECEIVE_FRONT_END_FS = 24_000.0

front_end_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(7i + 5)) ⊻ iszero(mod(i, 11)) for i in 1:n]

function local_part_bounds(n::Integer, nparts::Integer, p::Integer)
    base = div(Int(n), Int(nparts))
    extra = rem(Int(n), Int(nparts))
    lo = 1 + (Int(p) - 1) * base + min(Int(p) - 1, extra)
    hi = lo + base - 1 + (Int(p) <= extra ? 1 : 0)
    lo, hi
end

function synthetic_block(m)
    N = Int(m.nc)
    L = Int(m.np)
    useful = ComplexF64[
        cispi(0.007 * i) + 0.35 * cispi(-0.019 * i) + ComplexF64(0.001 * i, -0.0007 * i)
        for i in 1:N
    ]
    vcat(useful[N-L+1:N], useful)
end

function expected_time_chunk(m, block, branch::Integer)
    N = Int(m.nc)
    L = Int(m.np)
    lo, hi = local_part_bounds(N, Int(m.partial_fft_parts), branch)
    chunk = zeros(ComplexF64, N)
    chunk[lo:hi] .= block[L+lo:L+hi]
    chunk
end

function expected_branch_observations(m, block)
    P = Int(m.partial_fft_parts)
    N = Int(m.nc)
    expected = Matrix{ComplexF64}(undef, P, N)
    for p in 1:P
        expected[p, :] .= fft(expected_time_chunk(m, block, p))
    end
    expected
end

function assert_branch_front_end(m, block)
    P = Int(m.partial_fft_parts)
    N = Int(m.nc)
    L = Int(m.np)
    yparts = ReceiveFrontEndJuna._branch_observations(m, block)
    expected = expected_branch_observations(m, block)

    @test yparts isa Matrix{ComplexF64}
    @test size(yparts) == (P, N)
    @test all(x -> isfinite(real(x)) && isfinite(imag(x)), yparts)
    @test yparts ≈ expected atol=1e-11

    for p in 1:P
        @test ifft(yparts[p, :]) ≈ expected_time_chunk(m, block, p) atol=1e-11
    end

    @test ReceiveFrontEndJuna._sum_branches(yparts) ≈ fft(block[L+1:L+N]) atol=1e-11
    yparts
end

@testset verbose = true "JUNA receive block front end" begin
    @testset "default four-way front end drops CP and matches independent windowed FFTs" begin
        m = ReceiveFrontEndJuna.LiteModulation()
        block = synthetic_block(m)
        yparts = assert_branch_front_end(m, block)

        @test Int(m.partial_fft_parts) == 4
        @test [last(local_part_bounds(1024, 4, p)) - first(local_part_bounds(1024, 4, p)) + 1
               for p in 1:4] == [256, 256, 256, 256]

        damaged_cp = copy(block)
        damaged_cp[1:Int(m.np)] .= ComplexF64[
            ComplexF64(1000 + 3 * i, -1.5) for i in 1:Int(m.np)
        ]
        @test ReceiveFrontEndJuna._branch_observations(m, damaged_cp) == yparts
    end

    @testset "non-even branch counts still cover the useful symbol exactly once" begin
        m = ReceiveFrontEndJuna.LiteModulation(partial_fft_parts = 3)
        block = synthetic_block(m)
        yparts = assert_branch_front_end(m, block)

        @test [last(local_part_bounds(1024, 3, p)) - first(local_part_bounds(1024, 3, p)) + 1
               for p in 1:3] == [342, 341, 341]
        @test maximum(abs.(sum(ifft(yparts[p, :]) for p in 1:3) .- block[Int(m.np)+1:end])) < 1e-11
    end

    @testset "public multi-block waveform slices feed independent front-end observations" begin
        m = ReceiveFrontEndJuna.LiteModulation()
        bps = ReceiveFrontEndModulations.bitspersymbol(m)
        blocklen = ReceiveFrontEndJuna._blocklen(m)
        bits = front_end_payload_pattern(2 * bps)
        waveform = ReceiveFrontEndModulations.modulate(m, bits, RECEIVE_FRONT_END_FC, RECEIVE_FRONT_END_FS)

        @test length(waveform) == 2 * blocklen

        branch_sums = Vector{Vector{ComplexF64}}(undef, 2)
        for block_id in 1:2
            lo = 1 + (block_id - 1) * blocklen
            hi = block_id * blocklen
            block = @view waveform[lo:hi]
            yparts = assert_branch_front_end(m, block)
            branch_sums[block_id] = ReceiveFrontEndJuna._sum_branches(yparts)
        end

        @test maximum(abs.(branch_sums[1] .- branch_sums[2])) > 1e-6
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA receive block front-end checks passed")
end
