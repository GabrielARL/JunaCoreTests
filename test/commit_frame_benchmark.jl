#!/usr/bin/env julia

using Test

isdefined(Main, :ReceiverChannelBenchmark) ||
    include(joinpath(@__DIR__, "..", "tools", "receiver_channel_benchmark.jl"))
const FrameCommitBenchmark = Main.ReceiverChannelBenchmark

@testset verbose = true "commit benchmark true frame-wide matrix" begin
    capture = FrameCommitBenchmark.identity_capture(
        fs=19_200.0,
        fc=25_000.0,
        receiver=3,
    )
    coded_bits_by_pilot_and_n = Dict(
        (0.25, 512) => 432,
        (0.25, 1024) => 880,
        (0.25, 2048) => 1776,
        (0.5, 512) => 368,
        (0.5, 1024) => 752,
        (0.5, 2048) => 1520,
        (0.75, 512) => 336,
        (0.75, 1024) => 672,
        (0.75, 2048) => 1360,
    )
    pilot_spacings = (0.25 => 8, 0.5 => 4, 0.75 => 3)
    code_rates = (1 / 16, 1 / 8, 1 / 4, 1 / 2)
    frame_blocks = 10
    expected_profiles = (:standard, :pfft, :lite, :full, :coupled)

    @testset "all 180 cells have a valid ten-block global geometry" begin
        for (pilot_ratio, spacing) in pilot_spacings,
            nfft in (512, 1024, 2048),
            code_rate in code_rates
            coded_bits = coded_bits_by_pilot_and_n[(pilot_ratio, nfft)]
            information_bits = round(Int, code_rate * coded_bits)
            frame_payload = frame_blocks * information_bits -
                            cld(frame_blocks * information_bits, spacing)
            receivers, shared_payload =
                FrameCommitBenchmark._frame_receiver_set(
                    FrameCommitBenchmark.frame_algorithm_descriptors(),
                    capture.fc,
                    capture.fs;
                    frame_blocks=frame_blocks,
                    modem_profile=:default,
                    nfft=nfft,
                    cp=16,
                    code_rate=code_rate,
                    pilot_ratio=pilot_ratio,
                    channel_bandwidth_hz=capture.fs / 2,
                    modem_bw=1.0,
                )

            @test shared_payload == frame_payload
            @test Tuple(item.receiver.frame_receiver for item in receivers) ==
                  expected_profiles
            for item in receivers
                @test Int(item.receiver.nc) == nfft
                @test Int(item.receiver.np) == 16
                @test Int(item.receiver.ldpc_n) == coded_bits
                @test Int(item.receiver.ldpc_k) == information_bits
                @test item.receiver.bw == 0.5
                @test Int(item.receiver.partial_fft_nbands) ==
                      (pilot_ratio == 0.25 && nfft == 512 ? 8 : 16)
                @test FrameCommitBenchmark.Juna._frame_payload_capacity(
                    item.receiver, frame_blocks) == frame_payload
                @test isvalid(item.receiver, capture.fc, capture.fs)
            end
        end
    end

    @testset "one ten-block frame decodes through all five global receivers" begin
        rows = FrameCommitBenchmark.benchmark_frame_capture(
            capture;
            channel_id="identity",
            frames=1,
            frame_blocks=10,
            algorithms=FrameCommitBenchmark.frame_algorithm_descriptors(),
            snr_db=Inf,
            seed=1,
            modem_fs=:capture,
            modem_profile=:default,
            nfft=512,
            cp=16,
            code_rate=1 / 16,
            pilot_ratio=0.75,
            warmup=false,
        )

        @test length(rows) == 5
        @test Set(row.algorithm for row in rows) ==
              Set(descriptor.name for descriptor in
                  FrameCommitBenchmark.frame_algorithm_descriptors())
        for row in rows
            @test row.frames == 1
            @test row.frame_blocks == 10
            @test row.successful_frames == 1
            @test row.psr == 1.0
            @test row.bit_errors == 0
            @test row.ber == 0.0
            @test row.decode_failures == 0
            @test row.mean_decode_seconds_per_frame ==
                  row.total_decode_seconds
            @test row.status == "ok"
        end
    end

    @testset "exact SG-1 Rpchan samples feed all five frame receivers" begin
        recorder = joinpath(
            @__DIR__, "..", "tools",
            "record_sg1_rpchan_five_algorithms.jl")
        @test isfile(recorder)
        config = only(filter(
            item -> item.id === :red1,
            FrameCommitBenchmark.paper_frame_wide_config_descriptors(),
        ))
        rpchan_capture = FrameCommitBenchmark.identity_capture(
            fs=config.capture_fs,
            fc=config.carrier_hz,
            receiver=3,
        )
        adapter_calls = Ref(0)
        rows = FrameCommitBenchmark.benchmark_paper_frame_wide_algorithms(
            rpchan_capture,
            config;
            decoded_packets=10,
            snr_db=Inf,
            seed=51_001,
            warmup=false,
            channel_adapter=(_capture, transmitted; snapshot, modem_fs) -> begin
                adapter_calls[] += 1
                @test snapshot == 1
                @test modem_fs == 9_600.0
                copy(transmitted)
            end,
        )

        @test adapter_calls[] == 1
        @test length(rows) == 5
        @test Tuple(row.algorithm for row in rows) == Tuple(
            item.name for item in
            FrameCommitBenchmark.frame_algorithm_descriptors())
        @test Tuple(Symbol(row.profile) for row in rows) ==
              (:standard, :pfft, :lite, :full, :coupled)
        for row in rows
            @test row.channel == "red1"
            @test row.label == "SG-1"
            @test row.receiver == 3
            @test (row.nfft, row.cp) == (1024, 16)
            @test (row.outer_spacing, row.inner_spacing) == (5, 10)
            @test (row.fec_rate, row.check_degree) == (0.5, 10)
            @test (row.modem_fs, row.capture_fs) == (9_600.0, 19_200.0)
            @test row.frames == 1
            @test row.frame_blocks == 10
            @test row.decoded_packets == 10
            @test row.accepted_packets == 10
            @test row.packet_psr == 1.0
            @test row.successful_frames == 1
            @test row.frame_psr == 1.0
            @test row.payload_bits == config.payload_bits_per_frame
            @test row.bit_errors == 0
            @test row.ber == 0.0
            @test row.decode_failures == 0
            @test row.status == "ok"
            @test isfinite(row.mean_decode_seconds_per_frame)
            @test row.mean_decode_seconds_per_frame >= 0
        end

        mktempdir() do dir
            path = FrameCommitBenchmark.write_paper_algorithm_csv(
                joinpath(dir, "sg1-five.csv"), rows)
            header = split(first(readlines(path)), ',')
            for column in ("algorithm", "profile", "packet_psr",
                           "successful_frames", "frame_psr", "ber",
                           "mean_decode_seconds_per_frame",
                           "effective_rate_bps")
                @test column in header
            end
        end
    end

    @test_throws ArgumentError FrameCommitBenchmark.benchmark_frame_capture(
        capture; frames=1, frame_blocks=0, warmup=false)
    @test_throws ArgumentError FrameCommitBenchmark.benchmark_frame_capture(
        capture; frames=0, frame_blocks=10, warmup=false)
    @test_throws ArgumentError FrameCommitBenchmark.benchmark_frame_capture(
        capture; frames=2, frame_blocks=10, full_capture=true, warmup=false)
end

println("commit frame-wide benchmark checks passed")
