#!/usr/bin/env julia
#
# Deterministic synthetic underwater channel support. This suite isolates the
# channel equation from every receiver so Lite, Full, and Coupled can later be
# compared on exactly the same multipath, per-path Doppler, and AWGN samples.
#
# Run alone:  julia --project=. test/synthetic_uwa_channel.jl
# Via runner: julia --project=. test/runtests.jl synthetic-channel

using Random
using Statistics
using Test
using JunaCore

include(joinpath(@__DIR__, "support", "synthetic_uwa_channel.jl"))
using .SyntheticUWAChannel

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const SyntheticChannelJuna = JunaCore.Juna
const SyntheticChannelModulations = JunaCore.Modulations
const SYNTHETIC_CHANNEL_FC = 24_000.0
const SYNTHETIC_CHANNEL_FS = 24_000.0

@testset verbose = true "Synthetic underwater channel" begin
    @testset "paper profile preserves six delays and relative tap powers" begin
        profile = paper_channel_profile(24_000.0; seed = 17)
        expected_db = [0.0, -0.9, -4.9, -8.0, -7.8, -23.7]
        expected_delays = [0, 19, 41, 65, 91, 120]

        @test profile.fs == 24_000.0
        @test profile.delay_samples == expected_delays
        @test length(profile.taps) == 121
        @test findall(!iszero, profile.taps) == expected_delays .+ 1
        @test 10 .* log10.(abs2.(profile.taps[expected_delays .+ 1]) ./
                           abs2(profile.taps[1])) ≈ expected_db atol=2e-12
        @test paper_channel_profile(24_000.0; seed = 17).taps == profile.taps
        @test paper_channel_profile(24_000.0; seed = 18).taps != profile.taps
        @test_throws ArgumentError paper_channel_profile(0.0)
    end

    @testset "linear multipath returns the full independently computed convolution" begin
        x = ComplexF64[1 + 2im, -0.5 + 0.25im, 0.75 - 0.1im]
        h = ComplexF64[0.8, 0.0, -0.2 + 0.3im]
        expected = ComplexF64[
            x[1] * h[1],
            x[2] * h[1],
            x[3] * h[1] + x[1] * h[3],
            x[2] * h[3],
            x[3] * h[3],
        ]

        @test apply_multipath(x, h) ≈ expected atol=1e-15
        @test apply_multipath(x, ComplexF64[1]) == x
        @test_throws ArgumentError apply_multipath(ComplexF64[], h)
        @test_throws ArgumentError apply_multipath(x, ComplexF64[])
    end

    @testset "per-path Doppler has identity and analytic carrier-rotation limits" begin
        x = fill(1.0 + 0.0im, 12)
        h = ComplexF64[0.75 - 0.25im]
        identity = apply_per_path_doppler(x, h, [0.0]; fs = 8_000.0, fc = 24_000.0)
        @test identity == h[1] .* x

        scale = 1 / 1000
        rotated = apply_per_path_doppler(x, ComplexF64[1], [scale];
                                         fs = 8_000.0, fc = 2_000.0)
        usable = 1:10
        expected = cis.(2pi * 2_000.0 * scale .* ((usable .- 1) ./ 8_000.0))
        @test rotated[usable] ≈ expected atol=2e-14

        delayed = apply_per_path_doppler(ComplexF64[1, 0, 0],
                                         ComplexF64[0, 2 - im], [0.0, 0.0];
                                         fs = 8_000.0)
        @test delayed == ComplexF64[0, 2 - im, 0, 0]
        @test_throws DimensionMismatch apply_per_path_doppler(x, h, [0.0, 0.1];
                                                               fs = 8_000.0)
        @test_throws ArgumentError apply_per_path_doppler(x, h, [0.0]; fs = -1.0)
    end

    @testset "seeded AWGN is deterministic and calibrated to requested SNR" begin
        x = ComplexF64[cis(0.17k) for k in 0:199_999]
        y1 = add_awgn(x, 12.0; rng = Xoshiro(41))
        y2 = add_awgn(x, 12.0; rng = Xoshiro(41))
        noise = y1 - x
        measured_snr = 10log10(mean(abs2, x) / mean(abs2, noise))

        @test y1 == y2
        @test y1 isa Vector{ComplexF64}
        @test abs(measured_snr - 12.0) < 0.08
        @test all(z -> isfinite(real(z)) && isfinite(imag(z)), y1)
        @test_throws ArgumentError add_awgn(x, Inf; rng = Xoshiro(1))
    end

    @testset "composed channel agrees with its explicit noiseless stages" begin
        profile = paper_channel_profile(2_000.0; seed = 9)
        x = ComplexF64[cis(0.11k) for k in 0:127]
        scales = zeros(length(profile.taps))
        scales[profile.delay_samples .+ 1] .= range(-2e-4, 2e-4;
                                                    length = length(profile.delay_samples))
        expected = apply_per_path_doppler(x, profile.taps, scales;
                                          fs = profile.fs, fc = 4_000.0)
        actual = apply_channel(x, profile; doppler_scales = scales, fc = 4_000.0)

        @test actual == expected
        @test length(actual) == length(x) + length(profile.taps) - 1
        @test_throws DimensionMismatch apply_channel(
            x, profile; doppler_scales = [0.0], fc = 4_000.0,
        )
    end

    @testset "every receiver uses matched FEC on one physical-channel waterfall" begin
        assert_public_receiver_catalog()
        nbits = SyntheticChannelModulations.bitspersymbol(
            SyntheticChannelJuna.LiteModulation())
        profile = paper_channel_profile(SYNTHETIC_CHANNEL_FS; seed = 71)
        scales = zeros(length(profile.taps))
        scales[profile.delay_samples .+ 1] .= range(-8e-5, 8e-5;
                                                    length = length(profile.delay_samples))
        payload_rng = Xoshiro(133)
        payloads = [rand(payload_rng, Bool, nbits) for _ in 1:4]
        snrs = (20.0, 4.0, -2.0)
        @test maximum(abs.(scales)) > 0
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                receiver = public_receiver(descriptor)
                trials = [begin
                    transmitted = SyntheticChannelModulations.modulate(
                        receiver, bits,
                        SYNTHETIC_CHANNEL_FC, SYNTHETIC_CHANNEL_FS,
                    )
                    clean = apply_channel(
                        transmitted, profile;
                        doppler_scales = scales, fc = SYNTHETIC_CHANNEL_FC,
                    )
                    (; bits, transmitted, clean)
                end for bits in payloads]
                received = Dict(snr => [
                    add_awgn(
                        trial.clean, snr;
                        rng = Xoshiro(10_000 + 100snr_id + trial_id),
                    )
                    for (trial_id, trial) in enumerate(trials)
                ] for (snr_id, snr) in enumerate(snrs))

                @test all(length(trial.clean) ==
                          length(trial.transmitted) + length(profile.taps) - 1
                          for trial in trials)
                @test all(
                    trial.clean[1:length(trial.transmitted)] !=
                    trial.transmitted for trial in trials)
                errors = Dict{Float64,Int}()
                for snr in snrs
                    errors[snr] = 0
                    for (trial, waveform) in zip(trials, received[snr])
                        metrics, cfo = SyntheticChannelModulations.demodulate(
                            receiver, nbits, waveform,
                            SYNTHETIC_CHANNEL_FC, SYNTHETIC_CHANNEL_FS,
                        )
                        errors[snr] += count((metrics .> 0) .!= trial.bits)
                        @test isfinite(cfo)
                    end
                end
                @test errors[20.0] == 0
                @test 0 < errors[4.0] < length(trials) * nbits
                @test errors[-2.0] >= errors[4.0]
            end
        end
    end

    @testset "band-tied C discriminates codeword truth under physical model mismatch" begin
        m = SyntheticChannelJuna.CoupledModulation()
        code = SyntheticChannelJuna._code(m)
        layout = SyntheticChannelJuna._layout(m, SYNTHETIC_CHANNEL_FS)
        nbits = SyntheticChannelModulations.bitspersymbol(m)
        bits = Bool[isodd(count_ones(43i + 5)) for i in 1:nbits]
        message = SyntheticChannelJuna._build_message(m, code, bits)
        codeword = SyntheticChannelJuna._encode(code, message)
        transmitted = SyntheticChannelModulations.modulate(
            m, bits, SYNTHETIC_CHANNEL_FC, SYNTHETIC_CHANNEL_FS)
        profile = paper_channel_profile(SYNTHETIC_CHANNEL_FS; seed = 71)
        scales = zeros(length(profile.taps))
        scales[profile.delay_samples .+ 1] .= range(
            -8e-5, 8e-5; length = length(profile.delay_samples))
        received = apply_channel(
            transmitted, profile;
            doppler_scales = scales, fc = SYNTHETIC_CHANNEL_FC)
        block = @view received[1:SyntheticChannelJuna._blocklen(m)]
        yparts = SyntheticChannelJuna._branch_observations(m, block)
        seed = SyntheticChannelJuna._seed_candidate(m, code, layout, yparts)
        problem = SyntheticChannelJuna._coupled_problem_from_receiver(
            m, code, layout, yparts)

        truth_metrics = Float64[bit ? 20.0 : -20.0 for bit in codeword]
        wrong_metrics = -truth_metrics
        truth = SyntheticChannelJuna._initial_coupled_state(
            m, code, layout, problem, merge(seed, (; lpost_metric = truth_metrics)))
        wrong = SyntheticChannelJuna._initial_coupled_state(
            m, code, layout, problem, merge(seed, (; lpost_metric = wrong_metrics)))
        physical_weights = SyntheticChannelJuna._CoupledWeights(
            observation = 1.0, response_regularization = 0.002)
        truth_terms = SyntheticChannelJuna._coupled_objective(
            problem, truth; weights = physical_weights)
        wrong_terms = SyntheticChannelJuna._coupled_objective(
            problem, wrong; weights = physical_weights)

        @test maximum(abs, scales) > 0
        @test problem.spec.response_parameterization == :band_tied
        @test sum(abs2, truth.C[:, [1, 3], :, :]) > 1e-3
        @test truth_terms.total < wrong_terms.total
        @test all(isfinite, (truth_terms.total, wrong_terms.total))
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("Synthetic underwater channel checks passed")
end
