#!/usr/bin/env julia
#
# Public input robustness - malformed samples fail loudly while benign changes
# that do not alter OFDM information preserve the decoded payload.
#
# This suite separates three contracts that are easy to conflate:
#   * malformed API arguments are rejected before receiver-specific processing;
#   * finite extra samples are allowed because demodulate consumes the requested
#     whole blocks from the front of a stream;
#   * finite gain and a constant time-domain offset do not change the useful
#     normalized, DC-nulled OFDM payload.
#
# A parity-valid LDPC output is not packet-integrity evidence, so this suite does
# not invent a silence/noise validity promise. That needs framing with a CRC.
#
# Run alone:  julia --project=. test/public_input_robustness.jl
# Via runner: julia --project=. test/runtests.jl input-robustness

using Random
using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const InputRobustnessJuna = JunaCore.Juna
const InputRobustnessModulations = JunaCore.Modulations
const INPUT_ROBUSTNESS_FC = 24_000.0
const INPUT_ROBUSTNESS_FS = 24_000.0

input_robustness_payload(n::Integer) =
    Bool[isodd(count_ones(43i + 5)) for i in 1:Int(n)]

function compact_frame_rls_robustness_receiver(; kwargs...)
    defaults = (
        nc=128,
        np=16,
        ldpc_k=24,
        ldpc_n=48,
        ldpc_npc=2,
        partial_fft_parts=1,
        partial_fft_nbands=2,
        pilot_ratio=1 / 4,
        inner_pilot_ratio=1 / 3,
        rpchan_guard_s=0.0,
        rpchan_doppler_steps=1,
        rpchan_sync_max_lag=0,
    )
    JunaCore.JunaFrameRLS.Modulation(; merge(defaults, (; kwargs...))...)
end

function captured_exception(f)
    try
        f()
        nothing
    catch err
        err
    end
end

@testset verbose = true "JUNA public input robustness" begin
    @testset "JUNA-FrameRLS facade rejects malformed public inputs" begin
        m = compact_frame_rls_robustness_receiver()
        fs = 9_600.0
        blocks = 2
        bits = input_robustness_payload(
            InputRobustnessJuna._frame_payload_capacity(m, blocks))
        waveform = InputRobustnessModulations.modulate(
            m, bits, INPUT_ROBUSTNESS_FC, fs)

        @test_throws ArgumentError InputRobustnessModulations.signallength(
            m, length(bits), INPUT_ROBUSTNESS_FC, 0.0)
        @test_throws ArgumentError InputRobustnessModulations.modulate(
            m, bits, NaN, fs)
        @test_throws ArgumentError InputRobustnessModulations.demodulate(
            m, length(bits), @view(waveform[1:end-1]),
            INPUT_ROBUSTNESS_FC, fs)

        damaged = copy(waveform)
        damaged[end] = ComplexF64(NaN, 0)
        err = captured_exception() do
            InputRobustnessModulations.demodulate(
                m, length(bits), damaged, INPUT_ROBUSTNESS_FC, fs)
        end
        @test err isa ArgumentError
        @test occursin("finite", lowercase(sprint(showerror, err)))

        invalid = compact_frame_rls_robustness_receiver(nc=1000)
        @test !isvalid(invalid, INPUT_ROBUSTNESS_FC, fs)
        @test_throws ArgumentError InputRobustnessModulations.modulate(
            invalid, bits, INPUT_ROBUSTNESS_FC, fs)
    end

    @testset "frequency and payload-size arguments fail at the public boundary" begin
        bits = input_robustness_payload(170)
        tx = InputRobustnessJuna.LiteModulation()
        waveform = InputRobustnessModulations.modulate(
            tx, bits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        invalid_frequencies = (
            (fc = NaN, fs = INPUT_ROBUSTNESS_FS),
            (fc = Inf, fs = INPUT_ROBUSTNESS_FS),
            (fc = INPUT_ROBUSTNESS_FC, fs = NaN),
            (fc = INPUT_ROBUSTNESS_FC, fs = Inf),
            (fc = INPUT_ROBUSTNESS_FC, fs = 0.0),
            (fc = INPUT_ROBUSTNESS_FC, fs = -1.0),
        )

        for descriptor in public_receiver_descriptors()
            m = public_receiver(descriptor)
            for args in invalid_frequencies
                @test !isvalid(m, args.fc, args.fs)
                @test_throws ArgumentError InputRobustnessModulations.signallength(
                    m, length(bits), args.fc, args.fs)
                @test_throws ArgumentError InputRobustnessModulations.modulate(
                    m, bits, args.fc, args.fs)
                @test_throws ArgumentError InputRobustnessModulations.demodulate(
                    m, length(bits), waveform, args.fc, args.fs)
            end

            @test_throws ArgumentError InputRobustnessModulations.modulate(
                m, Bool[], INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            for nbits in (-1, 0, 1.5)
                @test_throws ArgumentError InputRobustnessModulations.signallength(
                    m, nbits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                @test_throws ArgumentError InputRobustnessModulations.demodulate(
                    m, nbits, waveform,
                    INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            end
        end
    end

    @testset "every receiver rejects short waveforms and invalid geometry" begin
        bits = input_robustness_payload(170)
        tx = InputRobustnessJuna.LiteModulation()
        waveform = InputRobustnessModulations.modulate(
            tx, bits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        short_waveform = waveform[1:end-1]

        for descriptor in public_receiver_descriptors()
            m = public_receiver(descriptor)
            @test_throws ArgumentError InputRobustnessModulations.demodulate(
                m, length(bits), short_waveform,
                INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            @test_throws ArgumentError InputRobustnessJuna.demodulate_methods(
                m, length(bits), short_waveform,
                INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)

            invalid = public_receiver(descriptor; nc = 1000)
            @test !isvalid(invalid, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            @test_throws ArgumentError InputRobustnessModulations.modulate(
                invalid, bits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            @test_throws ArgumentError InputRobustnessModulations.demodulate(
                invalid, length(bits), waveform,
                INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            @test_throws ArgumentError InputRobustnessJuna.demodulate_methods(
                invalid, length(bits), waveform,
                INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        end
    end

    @testset "every receiver rejects non-finite samples before decoding" begin
        tx = InputRobustnessJuna.LiteModulation()
        bits = input_robustness_payload(170)
        waveform = InputRobustnessModulations.modulate(
            tx, bits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        corruptions = (
            (name = "NaN in cyclic prefix", index = 1, value = ComplexF64(NaN, 0)),
            (name = "Inf in useful symbol", index = Int(tx.np) + 1,
             value = ComplexF64(Inf, 0)),
            (name = "imaginary Inf in useful symbol", index = Int(tx.np) + 2,
             value = ComplexF64(0, Inf)),
            (name = "NaN in trailing sample", index = length(waveform) + 1,
             value = ComplexF64(NaN, 0)),
        )

        for descriptor in public_receiver_descriptors()
            for corruption in corruptions
                @testset "$(descriptor.name): $(corruption.name)" begin
                    damaged = corruption.index <= length(waveform) ? copy(waveform) :
                              vcat(waveform, corruption.value)
                    corruption.index <= length(waveform) &&
                        (damaged[corruption.index] = corruption.value)
                    err = captured_exception() do
                        InputRobustnessModulations.demodulate(
                            public_receiver(descriptor), length(bits), damaged,
                            INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                    end

                    @test err isa ArgumentError
                    @test occursin("finite", lowercase(sprint(showerror, err)))
                end
            end
        end

        for descriptor in public_receiver_descriptors()
            damaged = copy(waveform)
            damaged[Int(tx.np) + 1] = ComplexF64(NaN, 0)
            err = captured_exception() do
                InputRobustnessJuna.demodulate_methods(
                    public_receiver(descriptor), length(bits), damaged,
                    INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            end
            @test err isa ArgumentError
            @test occursin("finite", lowercase(sprint(showerror, err)))
        end
    end

    @testset "gain, DC offset, and finite trailing samples preserve payload" begin
        bits = input_robustness_payload(127)
        for descriptor in public_receiver_descriptors()
            receiver = public_receiver(descriptor)
            waveform = InputRobustnessModulations.modulate(
                receiver, bits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            variants = (
                (name = "gain 1e-6", waveform = 1e-6 .* waveform),
                (name = "gain 1e6", waveform = 1e6 .* waveform),
                (name = "constant DC offset",
                 waveform = waveform .+ ComplexF64(0.2, -0.1)),
                (name = "finite trailing samples",
                 waveform = vcat(
                     waveform, ComplexF64[3 + 4im, -2 + 0.5im])),
            )
            for variant in variants
                @testset "$(descriptor.name): $(variant.name)" begin
                    metrics, cfo = InputRobustnessModulations.demodulate(
                        receiver, length(bits), variant.waveform,
                        INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                    @test all(isfinite, metrics)
                    @test (metrics .> 0) == bits
                    @test cfo == 0.0
                end
            end
        end
    end

    @testset "unsupported pilot LDPC bandwidth and Partial-FFT bounds fail early" begin
        payload = input_robustness_payload(170)
        reference = InputRobustnessJuna.LiteModulation()
        waveform = InputRobustnessModulations.modulate(
            reference, payload, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        invalid_configs = (
            (name = "one pilot cannot train four branches", kwargs = (pilot_ratio = 1e-6,)),
            (name = "pilot comb leaves fewer rows than branches",
             kwargs = (pilot_ratio = 1 / 17, partial_fft_nbands = 16)),
            (name = "column degree exceeds parity rows",
             kwargs = (ldpc_k = 679, ldpc_n = 680, ldpc_npc = 3)),
            (name = "zero LDPC column degree", kwargs = (ldpc_npc = 0,)),
            (name = "too many Partial-FFT views", kwargs = (partial_fft_parts = 17,)),
            (name = "more views than FFT samples", kwargs = (partial_fft_parts = 2048,)),
            (name = "bandwidth above Nyquist occupancy", kwargs = (bw = 1.5,)),
            (name = "positive dc0 kHz shift exceeds Nyquist",
             kwargs = (nc = 2048, np = 128, bw = 0.5, dc0 = 13)),
            (name = "negative dc0 kHz shift exceeds Nyquist",
             kwargs = (nc = 2048, np = 128, bw = 0.5, dc0 = -13)),
        )

        for descriptor in public_receiver_descriptors(), config in invalid_configs
            @testset "$(descriptor.name): $(config.name)" begin
                m = public_receiver(descriptor; config.kwargs...)
                @test !isvalid(m, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                @test_throws ArgumentError InputRobustnessModulations.signallength(
                    m, length(payload), INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                @test_throws ArgumentError InputRobustnessModulations.modulate(
                    m, payload, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                @test_throws ArgumentError InputRobustnessModulations.demodulate(
                    m, length(payload), waveform,
                    INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            end
        end

        for descriptor in public_receiver_descriptors()
            @test isvalid(public_receiver(descriptor; pilot_ratio = 1 / 16),
                          INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
            @test isvalid(public_receiver(descriptor; partial_fft_parts = 16),
                          INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
        end
    end

    @testset "silence and pure noise have deterministic public outcomes" begin
        nbits = 127
        for (receiver_id, descriptor) in enumerate(public_receiver_descriptors())
            @testset "$(descriptor.name)" begin
                m = public_receiver(descriptor)
                nsamples = InputRobustnessModulations.signallength(
                    m, nbits, INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                rng = Xoshiro(4_200 + receiver_id)
                waveforms = (
                    silence = zeros(ComplexF64, nsamples),
                    noise = ComplexF64.(randn(rng, nsamples), randn(rng, nsamples)),
                )

                for (name, waveform) in pairs(waveforms)
                    @testset "$name" begin
                        if descriptor.mode === :frame_rls && name === :noise
                            first_error = captured_exception() do
                                InputRobustnessModulations.demodulate(
                                    m, nbits, waveform,
                                    INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                            end
                            second_error = captured_exception() do
                                InputRobustnessModulations.demodulate(
                                    m, nbits, waveform,
                                    INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                            end
                            @test first_error isa ArgumentError
                            @test typeof(second_error) === typeof(first_error)
                            @test sprint(showerror, second_error) ==
                                  sprint(showerror, first_error)
                            @test occursin(
                                "preamble alignment",
                                lowercase(sprint(showerror, first_error)),
                            )
                            continue
                        end
                        first_metrics, first_cfo = InputRobustnessModulations.demodulate(
                            m, nbits, waveform,
                            INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)
                        second_metrics, second_cfo = InputRobustnessModulations.demodulate(
                            m, nbits, waveform,
                            INPUT_ROBUSTNESS_FC, INPUT_ROBUSTNESS_FS)

                        @test length(first_metrics) == nbits
                        @test all(isfinite, first_metrics)
                        @test first_metrics == second_metrics
                        @test isfinite(first_cfo)
                        @test first_cfo == second_cfo
                    end
                end
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA public input robustness checks passed")
end
