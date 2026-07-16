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
    expected_payload_bits = (
        1 / 16 => 42,
        1 / 8 => 85,
        1 / 4 => 170,
        1 / 2 => 340,
    )

    for (code_rate, payload_bits) in expected_payload_bits
        @testset "rate $code_rate" begin
            rows = CodeRateBenchmark.benchmark_capture(
                capture;
                channel_id="identity",
                packets=1,
                algorithms=CodeRateBenchmark.algorithm_descriptors(),
                snr_db=Inf,
                seed=1,
                modem_fs=:capture,
                modem_profile=:default,
                code_rate=code_rate,
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
end

println("commit code-rate benchmark checks passed")
