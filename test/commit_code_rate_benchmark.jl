#!/usr/bin/env julia

using Test

isdefined(Main, :ReceiverChannelBenchmark) ||
    include(joinpath(@__DIR__, "..", "tools", "receiver_channel_benchmark.jl"))
const CodeRateBenchmark = Main.ReceiverChannelBenchmark

@testset verbose = true "commit benchmark code-rate matrix" begin
    capture = CodeRateBenchmark.identity_capture(
        fs=19_200.0,
        fc=25_000.0,
        receiver=3,
    )
    coded_bits_by_pilot_and_n = Dict(
        (0.25, 512) => 880,
        (0.25, 1024) => 1776,
        (0.25, 2048) => 3568,
        (0.5, 512) => 752,
        (0.5, 1024) => 1520,
        (0.5, 2048) => 3056,
        (0.75, 512) => 672,
        (0.75, 1024) => 1360,
        (0.75, 2048) => 2720,
    )
    pilot_spacings = (0.25 => 8, 0.5 => 4, 0.75 => 3)
    fft_sizes = (512, 1024, 2048)
    code_rates = (1 / 16, 1 / 8, 1 / 4, 1 / 2)

    for (pilot_ratio, spacing) in pilot_spacings,
        nfft in fft_sizes,
        code_rate in code_rates
        @testset "pilots=$pilot_ratio N=$nfft rate=$code_rate" begin
            coded_bits = coded_bits_by_pilot_and_n[(pilot_ratio, nfft)]
            information_bits = round(Int, code_rate * coded_bits)
            payload_bits = information_bits - cld(information_bits, spacing)
            geometry = CodeRateBenchmark._pilot_budget_geometry(pilot_ratio)
            @test geometry.requested == pilot_ratio
            @test geometry.per_domain == pilot_ratio / 2
            @test geometry.outer_spacing == spacing
            @test geometry.inner_spacing == spacing
            @test geometry.outer_density == 1 / spacing
            @test geometry.inner_density == 1 / spacing

            receivers, shared_payload = CodeRateBenchmark._receiver_set(
                CodeRateBenchmark.algorithm_descriptors(),
                capture.fc,
                capture.fs;
                modem_profile=:default,
                nfft=nfft,
                cp=16,
                code_rate=code_rate,
                pilot_ratio=pilot_ratio,
            )
            @test shared_payload == payload_bits
            for item in receivers
                @test Int(item.receiver.nc) == nfft
                @test Int(item.receiver.np) == 16
                @test Int(item.receiver.ldpc_n) == coded_bits
                @test Int(item.receiver.ldpc_k) == information_bits
                @test item.receiver.pilot_ratio == pilot_ratio / 2
                @test item.receiver.inner_pilot_ratio == pilot_ratio / 2
                @test CodeRateBenchmark.Juna._pilot_spacing(item.receiver) == spacing
                @test CodeRateBenchmark.Juna._inner_pilot_spacing(item.receiver) == spacing

                layout = CodeRateBenchmark.Juna._layout(item.receiver, capture.fs)
                expected_pilots = [
                    carrier for carrier in layout.active
                    if (carrier - 2) % spacing == 0
                ]
                @test layout.pilot_idx == expected_pilots
                @test isempty(intersect(layout.pilot_idx, layout.data_idx))
                @test sort(vcat(layout.pilot_idx, layout.data_idx)) ==
                      sort(layout.active)
            end

            rows = CodeRateBenchmark.benchmark_capture(
                capture;
                channel_id="identity",
                packets=1,
                algorithms=CodeRateBenchmark.algorithm_descriptors(),
                snr_db=Inf,
                seed=1,
                modem_fs=:capture,
                modem_profile=:default,
                nfft=nfft,
                cp=16,
                code_rate=code_rate,
                pilot_ratio=pilot_ratio,
                warmup=false,
            )

            @test length(rows) == 5
            @test Set(row.algorithm for row in rows) ==
                  Set(descriptor.name for descriptor in
                      CodeRateBenchmark.algorithm_descriptors())
            for row in rows
                @test row.packets == 1
                @test row.payload_bits == payload_bits
                @test row.successful_packets == 1
                @test row.psr == 1.0
                @test row.bit_errors == 0
                @test row.ber == 0.0
                @test row.decode_failures == 0
                @test row.mean_decode_seconds == row.total_decode_seconds
                @test row.status == "ok"
            end
        end
    end

    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, code_rate=0.0, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, code_rate=1 / 7, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, pilot_ratio=0.0, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, pilot_ratio=1.01, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, pilot_ratio=Inf, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, pilot_ratio="0.5", warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, nfft=1000, cp=16, code_rate=1 / 4, warmup=false)
    @test_throws ArgumentError CodeRateBenchmark.benchmark_capture(
        capture; packets=1, nfft=512, cp=512, code_rate=1 / 4, warmup=false)

    @testset "full-capture positions and block accounting" begin
        segment = CodeRateBenchmark.ReplayCoupledSegment
        positioned = segment.ReplayCapture(
            ones(ComplexF64, 2, 100),
            zeros(2_000),
            1_000.0,
            25_000.0,
            10,
            1,
            "positions",
        )
        @test CodeRateBenchmark._full_capture_positions(
            positioned, 100, 1_000.0) == collect(1:10:81)

        short = segment.ReplayCapture(
            ones(ComplexF64, 1, 15),
            zeros(3_000),
            19_200.0,
            25_000.0,
            100,
            3,
            "short-full",
        )
        positions = CodeRateBenchmark._full_capture_positions(short, 528, 19_200.0)
        @test positions == [1, 6]
        rows = CodeRateBenchmark.benchmark_capture(
            short;
            channel_id="short-full",
            packets=1,
            algorithms=CodeRateBenchmark.algorithm_descriptors(),
            snr_db=Inf,
            seed=1,
            modem_fs=:capture,
            modem_profile=:default,
            nfft=512,
            cp=16,
            code_rate=1 / 16,
            pilot_ratio=0.25,
            full_capture=true,
            warmup=false,
        )
        @test length(rows) == 5
        for row in rows
            @test row.packets == length(positions)
            @test row.successful_packets == length(positions)
            @test row.psr == 1.0
            @test row.ber == 0.0
            @test row.mean_decode_seconds ==
                  row.total_decode_seconds / length(positions)
        end

        @test CodeRateBenchmark._effective_data_rate(3, 42, 10.0) == 12.6
        @test_throws ArgumentError CodeRateBenchmark._effective_data_rate(
            -1, 42, 10.0)
        @test_throws ArgumentError CodeRateBenchmark._effective_data_rate(
            1, 42, 0.0)
    end
end

println("commit code-rate benchmark checks passed")
