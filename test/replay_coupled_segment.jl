#!/usr/bin/env julia
#
# Coupled measured replay segment: apply one stored time-varying baseband
# channel segment to a known JUNA-WCz block, align it to the known transmit
# reference, decode it, and report BER/syndrome/objective/timing diagnostics.
#
# Default checks use independent tiny arrays. The real 183 MB red_1 capture is
# explicit because it is external data:
#   JUNA_REPLAY_SEGMENT=1 julia --project=. test/runtests.jl replay-segment
# Optional path override:
#   JUNA_REPLAY_SEGMENT_PATH=/path/red_1.mat

using Test
using JunaCore

const ReplaySegmentRoot = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ReplaySegmentRoot, "tools", "replay_coupled_segment.jl"))
const Segment = ReplayCoupledSegment

segment_payload(n::Integer=170) =
    Bool[isodd(count_ones(43i + 17)) for i in 1:Int(n)]

function real_red1_path()
    override = get(ENV, "JUNA_REPLAY_SEGMENT_PATH", "")
    candidates = filter(!isempty, [
        override,
        joinpath(ReplaySegmentRoot, "data", "red_1.mat"),
        joinpath(ReplaySegmentRoot, "..", "..", "red_1.mat"),
        joinpath(homedir(), "Documents", "GitHub", "Rpchan", "data", "red_1.mat"),
    ])
    index = findfirst(path -> isfile(path) && filesize(path) > 1_000_000, candidates)
    isnothing(index) ? "" : abspath(candidates[index])
end

@testset verbose = true "JUNA-WCz measured replay segment" begin
    @testset "capture validates shapes and applies a hand-calculated two-tap channel" begin
        # The MAT file stores zero-delay first; ReplayCh reverses that axis.
        h_hat = reshape(
            repeat(ComplexF64[1, 0.5], 3), 2, 1, 3,
        )
        capture = Segment.capture_from_dict(Dict(
            "h_hat" => h_hat,
            "phi_hat" => fill(pi / 2, 1, 32),
            "params" => Dict(
                "fs_delay" => 19_200.0,
                "fc" => 25_000.0,
                "fs_time" => 9_600.0,
            ),
        ); receiver=1, name="two_tap")
        replayed = Segment.apply_capture(capture, ComplexF64[1, 2, 3]; snapshot=1)

        @test replayed ≈ im .* ComplexF64[1, 2.5, 4, 1.5]
        @test capture.h[:, 1] == ComplexF64[0.5, 1]
        @test capture.fs == 19_200.0
        @test capture.fc == 25_000.0
        @test capture.step == 2
        @test_throws ArgumentError Segment.ReplayCapture(
            zeros(ComplexF64, 0, 2), zeros(8), 1.0, 1.0, 1, 1, "bad",
        )
        @test_throws ArgumentError Segment.apply_capture(
            capture, ComplexF64[1]; snapshot=4,
        )
        @test_throws ArgumentError Segment.capture_from_dict(
            Dict("params" => Dict(), "phi_hat" => zeros(1, 1)),
        )
    end

    @testset "known-reference alignment recovers lag and complex gain" begin
        reference = ComplexF64[1 + im, -0.5 + 0.25im, 2 - im]
        received = vcat(zeros(ComplexF64, 3), (2 - im) .* reference,
                        zeros(ComplexF64, 2))
        aligned = Segment.align_to_reference(received, reference; max_lag=5)

        @test aligned.lag == 3
        @test aligned.score ≈ 1.0
        @test aligned.waveform ≈ reference
    end

    @testset "identity replay produces exact payload and complete diagnostics" begin
        capture = Segment.ReplayCapture(
            ones(ComplexF64, 1, 8), zeros(10_000), 19_200.0, 25_000.0,
            200, 1, "identity",
        )
        bits = segment_payload()
        config = JunaCore.Juna._CoupledOptimizerConfig(steps=2)
        first = Segment.decode_segment(capture, bits; snapshot=1, config=config)
        second = Segment.decode_segment(capture, bits; snapshot=1, config=config)

        @test first.channel == "identity"
        @test first.modem_fs == capture.fs
        @test first.capture_fs == capture.fs
        @test first.payload_bits == 170
        @test first.bit_errors == 0
        @test first.ber == 0.0
        @test first.valid
        @test first.syndrome == 0
        @test isfinite(first.objective_initial)
        @test isfinite(first.objective_best)
        @test first.objective_best <= first.objective_initial
        @test first.objective_reduction >= 0.0
        @test first.selected_iteration in 0:config.steps
        @test isfinite(first.decode_seconds) && first.decode_seconds >= 0.0
        @test first.alignment_lag == 0
        @test first.alignment_score ≈ 1.0
        @test Segment.deterministic_signature(first) == Segment.deterministic_signature(second)

        mktempdir() do dir
            csv = joinpath(dir, "red1_segment.csv")
            Segment.write_result_csv(csv, first)
            lines = readlines(csv)
            @test length(lines) == 2
            @test split(lines[1], ',') == collect(Segment.RESULT_COLUMNS)
            values = split(lines[2], ',')
            @test values[1:7] == ["identity", "1", "1", "19200", "19200", "170", "0"]
            @test parse(Float64, values[8]) == 0.0
        end
        @test_throws ArgumentError Segment.write_result_csv("", first)
        @test_throws ArgumentError Segment.decode_segment(
            capture, bits; modem_fs=0.0, config=config,
        )
    end

    @testset "modem and capture sample rates are bridged without changing payload" begin
        capture = Segment.ReplayCapture(
            ones(ComplexF64, 1, 40), zeros(20_000), 10_000.0, 25_000.0,
            100, 1, "rate_bridge",
        )
        bits = segment_payload()
        result = Segment.decode_segment(
            capture, bits; modem_fs=5_000.0,
            config=JunaCore.Juna._CoupledOptimizerConfig(steps=2),
        )

        @test result.modem_fs == 5_000.0
        @test result.capture_fs == 10_000.0
        @test result.bit_errors == 0
        @test result.valid
        @test result.syndrome == 0
        @test result.objective_best <= result.objective_initial
    end

    @testset "Rpchan passband adapter preserves an identity public frame" begin
        capture = Segment.ReplayCapture(
            ones(ComplexF64, 1, 256), zeros(100_000), 19_200.0, 25_000.0,
            200, 1, "passband_identity",
        )
        modulation = JunaCore.Juna.LiteModulation(
            sync=true, sync_profile=:rpchan,
            rpchan_guard_s=0.0, rpchan_doppler_ppm=0.0,
            rpchan_doppler_steps=1,
        )
        bits = segment_payload(JunaCore.Modulations.bitspersymbol(modulation))
        transmitted = JunaCore.Modulations.modulate(
            modulation, bits, capture.fc, capture.fs / 2,
        )
        received = Segment.replay_passband_at_modem_rate(
            capture, transmitted; snapshot=1, modem_fs=capture.fs / 2,
            passband_oversample=12,
        )
        metrics, cfo = JunaCore.Modulations.demodulate(
            modulation, length(bits), received, capture.fc, capture.fs / 2,
        )

        @test (metrics .> 0) == bits
        @test cfo == 0.0
        @test length(received) >= length(transmitted)
        @test_throws ArgumentError Segment.replay_passband_at_modem_rate(
            capture, transmitted; modem_fs=capture.fs / 2,
            passband_oversample=0,
        )
    end

    @testset "optional real red_1 segment is deterministic and recorded" begin
        if get(ENV, "JUNA_REPLAY_SEGMENT", "0") == "1"
            path = real_red1_path()
            @test !isempty(path)
            capture = Segment.load_capture(path; receiver=3)
            bits = segment_payload()
            config = JunaCore.Juna._CoupledOptimizerConfig(steps=8)
            rpchan_fs = capture.fs / 2
            first = Segment.decode_segment(
                capture, bits; snapshot=1, modem_fs=rpchan_fs, config=config,
            )
            second = Segment.decode_segment(
                capture, bits; snapshot=1, modem_fs=rpchan_fs, config=config,
            )

            @test first.channel == "red_1"
            @test first.receiver == 3
            @test first.snapshot == 1
            @test first.modem_fs == 9_600.0
            @test first.capture_fs == 19_200.0
            @test first.payload_bits == length(bits)
            @test first.bit_errors == 0
            @test first.ber == 0.0
            @test first.valid
            @test first.syndrome == 0
            @test isfinite(first.objective_initial)
            @test isfinite(first.objective_best)
            @test first.objective_best < first.objective_initial
            @test first.objective_reduction > 0.0
            @test first.selected_iteration in 1:config.steps
            @test first.selected_candidate == "seed"
            @test first.alignment_score > 0.5
            @test Segment.deterministic_signature(first) == Segment.deterministic_signature(second)

            output = get(ENV, "JUNA_REPLAY_SEGMENT_CSV",
                         joinpath(ReplaySegmentRoot, "reports", "red_1_coupled_segment.csv"))
            Segment.write_result_csv(output, first)
            @test isfile(output)
            @info "real red_1 coupled segment" result=first csv=output
        else
            @info "real replay segment disabled; set JUNA_REPLAY_SEGMENT=1"
            @test_skip true
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA-WCz measured replay segment checks passed")
end
