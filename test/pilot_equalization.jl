#!/usr/bin/env julia
#
# Pilot equalization - branch-weight fitting and pilot residual normalization.
#
# Paper claims protected (papers/main.tex):
#   eq:ofdm5-band-index (885-889)             The receiver combines partial-FFT
#                                             branch observations band by band.
#   sec:solver (843)                          Pilot-trained seed equalization
#                                             initializes the decoder/JUNA loop.
#   tab:hyperparams (2021-2033)               Ridge-stabilized least-squares
#                                             fitting is part of the profiled
#                                             JUNA receiver.
#
# If this fails: pilot-trained branch weights may be ignoring their selected
# target rows, pilot residual normalization may no longer remove flat or
# frequency-selective responses, or clean equalized carriers may stop matching
# the transmitter's QPSK carrier plan before LDPC/BP ever sees them.
#
# Run alone:  julia --project=. test/pilot_equalization.jl
# Via runner: julia --project=. test/runtests.jl equalization

using LinearAlgebra
using Test
using JunaCore
using FFTW

const PilotEqJuna = JunaCore.Juna
const PilotEqModulations = JunaCore.Modulations
const PILOT_EQ_FC = 24_000.0
const PILOT_EQ_FS = 24_000.0
const PILOT_EQ_RIDGE = 1e-3

pilot_eq_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(9i + 7)) != iszero(mod(i, 5)) for i in 1:n]

pilot_eq_pm(bit::Bool) = bit ? -1.0 : 1.0

function pilot_eq_carrier_symbol(m, codeword::AbstractVector{Bool}, tone::Integer)
    if Int(m.bpc) == 1
        ComplexF64(pilot_eq_pm(codeword[tone]), 0.0)
    else
        j = 2 * (Int(tone) - 1) + 1
        bI = codeword[j]
        bQ = j + 1 <= length(codeword) ? codeword[j + 1] : false
        ComplexF64(pilot_eq_pm(bI), pilot_eq_pm(bQ)) / sqrt(2)
    end
end

function pilot_eq_expected_carriers(m, layout, codeword)
    carriers = zeros(ComplexF64, Int(m.nc))
    carriers[layout.pilot_idx] .= layout.pilot_syms
    ntones = cld(length(codeword), Int(m.bpc))
    for (i, k) in enumerate(layout.data_idx)
        carriers[k] = i <= ntones ? pilot_eq_carrier_symbol(m, codeword, i) : one(ComplexF64)
    end
    carriers
end

function pilot_eq_fixture(m; channel = 1.25 - 0.45im)
    layout = PilotEqJuna._layout(m, PILOT_EQ_FS)
    code = PilotEqJuna._code(m)
    bits = pilot_eq_payload_pattern(PilotEqModulations.bitspersymbol(m))
    message = PilotEqJuna._build_message(m, code, bits)
    codeword = PilotEqJuna._encode(code, message)
    expected = pilot_eq_expected_carriers(m, layout, codeword)
    block = PilotEqJuna._modulate_block(m, layout, codeword) .* ComplexF64(channel)
    yparts = PilotEqJuna._branch_observations(m, block)
    equalized = PilotEqJuna._equalize_from_targets(m, yparts, layout, layout.pilot_idx, layout.pilot_syms)
    (m = m, layout = layout, codeword = codeword, expected = expected,
     yparts = yparts, equalized = equalized)
end

function pilot_eq_piecewise_branch_fixture(m; gains)
    layout = PilotEqJuna._layout(m, PILOT_EQ_FS)
    code = PilotEqJuna._code(m)
    bits = pilot_eq_payload_pattern(PilotEqModulations.bitspersymbol(m))
    message = PilotEqJuna._build_message(m, code, bits)
    codeword = PilotEqJuna._encode(code, message)
    expected = pilot_eq_expected_carriers(m, layout, codeword)
    block = PilotEqJuna._modulate_block(m, layout, codeword)
    faded = copy(block)
    L = Int(m.np)
    N = Int(m.nc)

    @test length(gains) == Int(m.partial_fft_parts)
    for p in 1:Int(m.partial_fft_parts)
        lo, hi = PilotEqJuna._part_bounds(N, Int(m.partial_fft_parts), p)
        @views faded[L+lo:L+hi] .*= ComplexF64(gains[p])
    end

    yparts = PilotEqJuna._branch_observations(m, faded)
    equalized = PilotEqJuna._equalize_from_targets(
        m, yparts, layout, layout.pilot_idx, layout.pilot_syms)
    uniform = PilotEqJuna._residual_pilot_equalize(m, layout, PilotEqJuna._sum_branches(yparts))
    (m = m, layout = layout, codeword = codeword, expected = expected, block = block,
     faded = faded, yparts = yparts, equalized = equalized, uniform = uniform)
end

function deterministic_base_carriers(layout, N::Integer)
    carriers = zeros(ComplexF64, Int(N))
    carriers[layout.pilot_idx] .= layout.pilot_syms
    for (i, k) in enumerate(layout.data_idx)
        carriers[k] = ComplexF64(isodd(i) ? 1.0 : -1.0, iszero(mod(i, 3)) ? -1.0 : 1.0) / sqrt(2)
    end
    carriers
end

function pilot_eq_frequency_response(layout, k::Integer)
    pfirst = first(layout.pilot_idx)
    plast = last(layout.pilot_idx)
    kk = min(max(Int(k), pfirst), plast)
    ComplexF64(0.85 + 0.00021kk, -0.32 + 0.00017kk)
end

function local_ridge_weights(yparts, target_idx, targets, positions, P::Integer)
    Y = Matrix{ComplexF64}(undef, length(positions), Int(P))
    t = Vector{ComplexF64}(undef, length(positions))
    for (r, row) in enumerate(positions)
        k = target_idx[row]
        t[r] = ComplexF64(targets[row])
        for p in 1:Int(P)
            Y[r, p] = yparts[p, k]
        end
    end
    (Y' * Y + PILOT_EQ_RIDGE * I) \ (Y' * t)
end

function pilot_eq_linear_convolution(x, h)
    y = zeros(ComplexF64, length(x) + length(h) - 1)
    for i in eachindex(x), j in eachindex(h)
        y[i + j - 1] += x[i] * h[j]
    end
    y
end

function assert_equalized_matches_expected(m, layout, equalized, expected, codeword; data_atol)
    ntones = PilotEqJuna._ndata_tones(m, length(codeword))
    inactive = setdiff(1:Int(m.nc), layout.active)

    @test equalized isa Vector{ComplexF64}
    @test length(equalized) == Int(m.nc)
    @test all(x -> isfinite(real(x)) && isfinite(imag(x)), equalized)
    @test maximum(abs.(equalized[layout.pilot_idx] .- layout.pilot_syms)) < 2e-12
    @test maximum(abs.(equalized[layout.data_idx[1:ntones]] .- expected[layout.data_idx[1:ntones]])) < data_atol
    @test maximum(abs.(equalized[layout.data_idx[ntones+1:end]] .- expected[layout.data_idx[ntones+1:end]])) < data_atol
    @test maximum(abs.(equalized[inactive])) < 2e-12
end

@testset verbose = true "JUNA pilot equalization" begin
    @testset "a sufficient CP turns an FIR channel into diagonal one-tap FFT bins" begin
        N = 64
        cp = 12
        X = ComplexF64[
            cis(0.17k) * (iszero(k % 5) ? 0.5 : 1.0) for k in 0:N-1
        ]
        h = ComplexF64[0.8 + 0.1im, -0.2 + 0.3im, 0.12 - 0.08im,
                       0.04 + 0.02im, -0.03im]
        x = ifft(X)
        with_cp = vcat(x[end-cp+1:end], x)
        received = pilot_eq_linear_convolution(with_cp, h)
        Y = fft(received[cp+1:cp+N])
        H = fft(vcat(h, zeros(ComplexF64, N - length(h))))

        @test length(h) - 1 <= cp
        @test Y ≈ H .* X atol=2e-14 rtol=2e-14

        short_cp = length(h) - 2
        short_block = vcat(x[end-short_cp+1:end], x)
        short_received = pilot_eq_linear_convolution(short_block, h)
        short_Y = fft(short_received[short_cp+1:short_cp+N])
        @test maximum(abs.(short_Y .- H .* X)) > 1e-4
    end

    @testset "_fit_branch_weights! solves the ridge normal equations" begin
        m = PilotEqJuna.LiteModulation(partial_fft_parts = 3)
        P = Int(m.partial_fft_parts)
        target_idx = [2, 4, 6, 8, 9]
        positions = collect(eachindex(target_idx))
        yparts = zeros(ComplexF64, P, 10)
        for k in target_idx
            yparts[:, k] = ComplexF64[
                1 + 0.07k,
                -0.4 + 0.11k * im,
                (-1)^k * 0.6 + 0.03k - 0.2im,
            ]
        end
        true_weights = ComplexF64[0.7 + 0.2im, -0.3 + 0.1im, 0.2 - 0.4im]
        targets = ComplexF64[
            sum(yparts[p, k] * true_weights[p] for p in 1:P)
            for k in target_idx
        ]
        weights = Vector{ComplexF64}(undef, P)
        A = Matrix{ComplexF64}(undef, P, P)
        b = Vector{ComplexF64}(undef, P)

        PilotEqJuna._fit_branch_weights!(weights, A, b, m, yparts, target_idx, targets, positions)
        expected = local_ridge_weights(yparts, target_idx, targets, positions, P)

        @test all(x -> isfinite(real(x)) && isfinite(imag(x)), weights)
        @test weights ≈ expected atol=2e-12
        @test maximum(abs.(weights .- true_weights)) < 5e-3

        subset_positions = [1, 3, 5]
        poisoned_targets = copy(targets)
        poisoned_targets[[2, 4]] .= ComplexF64[9.0 - 3.0im, -7.5 + 4.0im]
        PilotEqJuna._fit_branch_weights!(weights, A, b, m, yparts, target_idx,
                                         poisoned_targets, subset_positions)
        expected_subset = local_ridge_weights(
            yparts, target_idx, poisoned_targets, subset_positions, P)
        expected_all_poisoned = local_ridge_weights(
            yparts, target_idx, poisoned_targets, collect(eachindex(target_idx)), P)

        @test weights ≈ expected_subset atol=2e-12
        @test norm(weights - expected_all_poisoned) > 1.0
    end

    @testset "_residual_pilot_equalize removes a flat scalar channel" begin
        m = PilotEqJuna.LiteModulation()
        layout = PilotEqJuna._layout(m, PILOT_EQ_FS)
        base = deterministic_base_carriers(layout, Int(m.nc))
        channel = 1.7 - 0.35im
        observed = base .* channel

        equalized = PilotEqJuna._residual_pilot_equalize(m, layout, observed)
        @test equalized === observed
        @test maximum(abs.(equalized[layout.active] .- base[layout.active])) < 2e-14

        observed32 = ComplexF32.(base .* channel)
        equalized32 = PilotEqJuna._residual_pilot_equalize(m, layout, observed32)
        @test equalized32 isa Vector{ComplexF64}
        @test maximum(abs.(equalized32[layout.active] .- base[layout.active])) < 5e-7
    end

    @testset "_residual_pilot_equalize removes an interpolated frequency-selective response" begin
        m = PilotEqJuna.LiteModulation()
        layout = PilotEqJuna._layout(m, PILOT_EQ_FS)
        base = deterministic_base_carriers(layout, Int(m.nc))
        observed = copy(base)
        for k in layout.active
            observed[k] *= pilot_eq_frequency_response(layout, k)
        end

        equalized = PilotEqJuna._residual_pilot_equalize(m, layout, observed)
        between = layout.data_idx[findfirst(k -> layout.pilot_idx[1] < k < layout.pilot_idx[2],
                                            layout.data_idx)]
        above_last = layout.data_idx[findfirst(k -> k > last(layout.pilot_idx),
                                               layout.data_idx)]

        @test pilot_eq_frequency_response(layout, first(layout.pilot_idx)) !=
              pilot_eq_frequency_response(layout, last(layout.pilot_idx))
        @test PilotEqJuna._interp_response([10, 20], ComplexF64[2 + 0im, 4 + 2im], 5) == 2 + 0im
        @test PilotEqJuna._interp_response([10, 20], ComplexF64[2 + 0im, 4 + 2im], 25) == 4 + 2im
        @test PilotEqJuna._interp_response([10, 20], ComplexF64[2 + 0im, 4 + 2im], 15) ≈ 3 + 1im
        @test between > first(layout.pilot_idx)
        @test above_last > last(layout.pilot_idx)
        @test equalized === observed
        @test maximum(abs.(equalized[layout.active] .- base[layout.active])) < 2e-12
        @test maximum(abs.(equalized[setdiff(1:Int(m.nc), layout.active)])) < 2e-12
    end

    @testset "_equalize_from_targets recovers clean flat-channel carriers" begin
        m = PilotEqJuna.LiteModulation()
        fixture = pilot_eq_fixture(m; channel = 1.25 - 0.45im)

        @test size(fixture.yparts) == (Int(m.partial_fft_parts), Int(m.nc))
        assert_equalized_matches_expected(
            m, fixture.layout, fixture.equalized, fixture.expected, fixture.codeword;
            data_atol = 2e-6,
        )
    end

    @testset "_equalize_from_targets uses branch weights on a piecewise time-varying channel" begin
        m = PilotEqJuna.LiteModulation(partial_fft_parts = 4)
        gains = ComplexF64[1.45 - 0.35im, 0.62 + 0.75im, -0.35 + 1.2im, 1.05 + 0.18im]
        fixture = pilot_eq_piecewise_branch_fixture(m; gains = gains)
        ntones = PilotEqJuna._ndata_tones(m, length(fixture.codeword))
        data_idx = fixture.layout.data_idx[1:ntones]

        @test length(unique(round.(abs.(gains); digits=6))) > 1
        @test size(fixture.yparts) == (Int(m.partial_fft_parts), Int(m.nc))
        @test maximum(abs.(fixture.equalized[data_idx] .- fixture.expected[data_idx])) < 2e-6
        @test maximum(abs.(fixture.uniform[data_idx] .- fixture.expected[data_idx])) > 1e-2
        assert_equalized_matches_expected(
            m, fixture.layout, fixture.equalized, fixture.expected, fixture.codeword;
            data_atol = 2e-6,
        )
    end

    @testset "pilot fallback stays finite when a local band has too few pilots" begin
        m = PilotEqJuna.LiteModulation(partial_fft_parts = 24)
        fixture = pilot_eq_fixture(m; channel = 0.9 + 0.6im)
        pilot_set = Set(fixture.layout.pilot_idx)
        pilots_per_band = [count(k -> k in pilot_set, band) for band in fixture.layout.bands]

        @test minimum(pilots_per_band) == 21
        @test Int(m.partial_fft_parts) > minimum(pilots_per_band)
        assert_equalized_matches_expected(
            m, fixture.layout, fixture.equalized, fixture.expected, fixture.codeword;
            data_atol = 1e-3,
        )
    end

    @testset "confidence weights scale virtual-pilot rows in the ridge system" begin
        m = PilotEqJuna.LiteModulation(partial_fft_parts = 2)
        target_idx = [2, 4, 6, 8]
        targets = ComplexF64[1.0, -0.4 + 0.7im, 0.2 - 0.9im, -1.0]
        yparts = zeros(ComplexF64, 2, 10)
        yparts[:, target_idx] .= ComplexF64[
            1.0  0.8+0.2im  -0.4+0.7im  0.3-0.6im;
            0.2-0.4im  -0.5+0.3im  1.2+0.1im  -0.8-0.2im
        ]
        positions = collect(eachindex(target_idx))
        row_weights = [1.0, 0.05, 0.8, 1.0]
        weights = zeros(ComplexF64, 2)
        A = zeros(ComplexF64, 2, 2)
        b = zeros(ComplexF64, 2)

        PilotEqJuna._fit_branch_weights!(
            weights, A, b, m, yparts, target_idx, targets, positions;
            target_weights = row_weights,
        )
        Y = permutedims(yparts[:, target_idx])
        D = Diagonal(row_weights)
        expected = (Y' * D * Y + PILOT_EQ_RIDGE * I) \ (Y' * D * targets)
        unweighted = local_ridge_weights(yparts, target_idx, targets, positions, 2)

        @test weights ≈ expected atol=2e-12
        @test norm(weights - unweighted) > 1e-2

        PilotEqJuna._fit_branch_weights!(
            weights, A, b, m, yparts, target_idx, targets, positions;
            target_weights = ones(length(target_idx)),
        )
        @test weights ≈ unweighted atol=2e-12
        @test_throws DimensionMismatch PilotEqJuna._fit_branch_weights!(
            weights, A, b, m, yparts, target_idx, targets, positions;
            target_weights = [1.0],
        )
        @test_throws ArgumentError PilotEqJuna._fit_branch_weights!(
            weights, A, b, m, yparts, target_idx, targets, positions;
            target_weights = [1.0, -0.1, 0.5, 1.0],
        )
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA pilot equalization checks passed")
end
