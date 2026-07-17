#!/usr/bin/env julia
#
# Colored replay receiver benchmark - one fair comparison across every public
# JUNA receiver. The deterministic identity fixture protects the BER/PSR/time
# accounting without requiring multi-gigabyte measured captures in CI; the
# browser/API contract protects the page that launches the real replay runs.
#
# Run alone:  julia --project=. test/receiver_channel_benchmark.jl
# Via runner: julia --project=. test/runtests.jl receiver-benchmark

using Test
using JunaCore
import SignalAnalysis

const BenchmarkRoot = normpath(joinpath(@__DIR__, ".."))
const BenchmarkExplorerRoot = get(ENV, "JUNA_EXPLORER_ROOT",
    normpath(joinpath(BenchmarkRoot, "..", "JunaCoreExplorer")))
const BenchmarkTool = joinpath(BenchmarkRoot, "tools", "receiver_channel_benchmark.jl")
const FrameWidePaperTool = joinpath(BenchmarkRoot, "tools", "reproduce_paper_frame_wide.jl")
const BenchmarkPage = joinpath(BenchmarkExplorerRoot, "tools", "receiver_benchmark_page.py")
const BenchmarkServer = joinpath(BenchmarkExplorerRoot, "tools", "test_runner_server.py")

function benchmark_curl(args...)
    read(`curl -sS --max-time 10 $(collect(args))`, String)
end

@testset verbose = true "JUNA colored-channel receiver benchmark" begin
    @testset "benchmark tools and workbench routes exist" begin
        @test isfile(BenchmarkTool)
        @test isfile(FrameWidePaperTool)
        @test isfile(BenchmarkPage)
        server = read(BenchmarkServer, String)
        @test occursin("\"/benchmark\"", server)
        @test occursin("\"/api/benchmark\"", server)
        @test occursin("\"/api/benchmark/stream/\"", server)
        @test occursin("\"/api/benchmark/csv/\"", server)
        @test occursin("\"--strict\", \"true\"", server)

        makefile = read(joinpath(BenchmarkRoot, "Makefile"), String)
        @test occursin("record-frame-benchmark:", makefile)
        @test occursin("record-sg1-rpchan-baseline:", makefile)

        nav = read(joinpath(BenchmarkExplorerRoot, "tools", "workbench_data.py"), String)
        @test occursin("data-dest=\"benchmark\"", nav)
    end

    if isfile(BenchmarkTool)
        include(BenchmarkTool)
        benchmark = Main.ReceiverChannelBenchmark

        @testset "catalog covers receiver-only profiles and every colored capture" begin
            algorithms = benchmark.algorithm_descriptors()
            receiver_only_profiles = Tuple(filter(
                profile -> profile !== :frame_wide_ldpc,
                JunaCore.Juna._RECEIVER_PROFILES,
            ))
            @test Tuple(entry.profile for entry in algorithms) ==
                  receiver_only_profiles
            @test Tuple(setdiff(JunaCore.Juna._RECEIVER_PROFILES,
                                receiver_only_profiles)) == (:frame_wide_ldpc,)
            @test Tuple(entry.id for entry in algorithms) ==
                  (:standard, :pfft, :lite, :wz, :wcz)
            @test length(unique(entry.id for entry in algorithms)) == length(algorithms)

            channels = benchmark.channel_descriptors()
            @test length(channels) == 12
            @test count(entry -> entry.color == :red, channels) == 3
            @test count(entry -> entry.color == :blue, channels) == 3
            @test count(entry -> entry.color == :yellow, channels) == 6
            @test all(endswith(entry.filename, ".mat") for entry in channels)
            @test all(entry -> entry.capture_fs == 19_200.0,
                      filter(entry -> entry.color == :red, channels))
            @test all(entry -> entry.capture_fs == 9_765.625,
                      filter(entry -> entry.color == :blue, channels))
            @test all(entry -> entry.capture_fs == 12_500.0,
                      filter(entry -> entry.color == :yellow, channels))
            @test_throws ArgumentError benchmark.select_algorithms(["unknown"])
            @test_throws ArgumentError benchmark.select_channels(["orange1"])
        end

        @testset "Red replay bandwidth uses the smaller channel or modem width" begin
            capture = benchmark.identity_capture(fs=19_200.0, fc=25_000.0)

            channel_limited = benchmark._effective_bandwidth_geometry(
                capture, 19_200.0, 1.0,
            )
            @test channel_limited.channel_bandwidth_hz == 9_600.0
            @test channel_limited.requested_modem_bandwidth_hz == 19_200.0
            @test channel_limited.effective_bandwidth_hz == 9_600.0
            @test channel_limited.normalized_bw == 0.5

            modem_limited = benchmark._effective_bandwidth_geometry(
                capture, 9_600.0, 0.5,
            )
            @test modem_limited.channel_bandwidth_hz == 9_600.0
            @test modem_limited.requested_modem_bandwidth_hz == 4_800.0
            @test modem_limited.effective_bandwidth_hz == 4_800.0
            @test modem_limited.normalized_bw == 0.5

            rpchan_equal = benchmark._effective_bandwidth_geometry(
                capture, 9_600.0, 1.0,
            )
            @test rpchan_equal.effective_bandwidth_hz == 9_600.0
            @test rpchan_equal.normalized_bw == 1.0

            receivers, _ = benchmark._receiver_set(
                benchmark.algorithm_descriptors(), 25_000.0, 19_200.0;
                channel_bandwidth_hz=channel_limited.channel_bandwidth_hz,
                modem_bw=1.0,
            )
            @test length(receivers) == 5
            @test all(item -> item.receiver.bw == 0.5, receivers)
            @test all(item -> JunaCore.Modulations.isvalid(
                item.receiver, 25_000.0, 19_200.0), receivers)

            sparse_pilot_receivers, _ = benchmark._receiver_set(
                benchmark.algorithm_descriptors(), 25_000.0, 19_200.0;
                nfft=512, cp=16, code_rate=1 / 16, pilot_ratio=0.25,
                channel_bandwidth_hz=9_600.0, modem_bw=1.0,
            )
            @test all(item -> item.receiver.partial_fft_nbands == 8,
                      sparse_pilot_receivers)
            @test all(item -> JunaCore.Juna._pilot_training_sufficient(
                item.receiver,
                JunaCore.Juna._layout(item.receiver, 19_200.0),
            ), sparse_pilot_receivers)

            @test_throws ArgumentError benchmark._effective_bandwidth_geometry(
                capture, 19_200.0, 0.0,
            )
            @test_throws ArgumentError benchmark._effective_bandwidth_geometry(
                capture, 19_200.0, 1.01,
            )
        end

        @testset "paper frame-wide catalog pins all twelve measured configurations" begin
            configs = benchmark.paper_frame_wide_config_descriptors()
            @test length(configs) == 12
            @test Tuple(config.id for config in configs) ==
                  Tuple(channel.id for channel in benchmark.channel_descriptors())

            expected = Dict(
                :red1    => (1024, 16, 5, 10, 0.5, 10, 1634, 7353, 360, 360, 1.000, 0.0, 5540),
                :red2    => (1024, 64, 5, 10, 0.5, 10, 1634, 7353, 350, 200, 0.571, 0.06162, 3078),
                :red3    => (1024, 64, 5, 10, 0.5, 10, 1634, 7353, 149, 85, 0.570, 0.03585, 1308),
                :blue1   => (1024, 0,  5, 5,  0.5, 8,  1634, 6536, 220, 220, 1.000, 0.0, 2751),
                :blue2   => (512,  0,  5, 10, 0.5, 6,  816,  3672, 166, 113, 0.681, 0.01159, 793),
                :blue3   => (512,  32, 5, 10, 0.5, 10, 816,  3672, 163, 61,  0.374, 0.08388, 428),
                :yellow1 => (2048, 64, 4, 4,  0.25, 8, 3068, 5752, 140, 140, 1.000, 0.0, 1565),
                :yellow2 => (1024, 16, 7, 10, 0.5, 8,  1752, 7884, 270, 260, 0.963, 0.008475, 3985),
                :yellow3 => (512,  32, 7, 10, 0.5, 8,  874,  3933, 460, 430, 0.935, 0.01466, 3303),
                :yellow4 => (2048, 64, 4, 4,  0.25, 8, 3068, 5752, 140, 140, 1.000, 0.0, 1546),
                :yellow5 => (512,  0,  5, 7,  0.5, 10, 816,  3497, 490, 330, 0.673, 0.09853, 2254),
                :yellow6 => (512,  16, 7, 7,  0.5, 8,  874,  3745, 480, 280, 0.583, 0.09667, 2024),
            )

            for config in configs
                values = expected[config.id]
                @test (config.nfft, config.cp, config.outer_spacing,
                       config.inner_spacing, config.fec_rate, config.dc,
                       config.coded_bits_per_packet, config.payload_bits_per_frame,
                       config.target_decoded_packets, config.target_accepted_packets,
                       config.target_psr, config.target_ber, config.target_rate_bps) == values

                channel = only(filter(item -> item.id === config.id,
                                      benchmark.channel_descriptors()))
                @test config.capture_fs == channel.capture_fs
                @test config.modem_fs == channel.capture_fs / 2

                modem = benchmark._paper_frame_wide_modem(
                    config, config.carrier_hz, config.modem_fs)
                @test modem.mode === :frame_wide_ldpc
                @test modem.compatibility_profile === :rpchan
                @test (Int(modem.nc), Int(modem.np)) == (config.nfft, config.cp)
                @test JunaCore.Juna._pilot_spacing(modem) == config.outer_spacing
                @test JunaCore.Juna._inner_pilot_spacing(modem) == config.inner_spacing
                @test (modem.ldpc_k, modem.ldpc_n, modem.ldpc_npc) ==
                      (round(Int, config.fec_rate * config.coded_bits_per_packet),
                       config.coded_bits_per_packet, config.dc)
                @test JunaCore.Juna._frame_payload_capacity(modem, 10) ==
                      config.payload_bits_per_frame
            end
        end

        @testset "frame-wide reproduction uses Rpchan packet acceptance accounting" begin
            config = (
                id=:identity, label="Identity", nfft=128, cp=16,
                outer_spacing=4, inner_spacing=10, fec_rate=0.5, dc=6,
                coded_bits_per_packet=188, payload_bits_per_frame=846,
                capture_fs=19_200.0, modem_fs=9_600.0,
                carrier_hz=25_000.0, target_decoded_packets=10,
                target_accepted_packets=10, target_psr=1.0,
                target_ber=0.0, target_rate_bps=0,
            )
            capture = benchmark.identity_capture(
                fs=config.capture_fs, fc=config.carrier_hz, receiver=3,
            )
            row = benchmark.benchmark_paper_frame_wide_capture(
                capture, config; decoded_packets=10, snr_db=Inf, seed=37,
                channel_adapter=(_capture, transmitted; snapshot, modem_fs) ->
                    copy(transmitted),
            )

            @test row.channel == "identity"
            @test row.algorithm == "JUNA Frame-wide LDPC"
            @test row.receiver == 3
            @test row.frames == 1
            @test row.decoded_packets == 10
            @test row.accepted_packets == 10
            @test row.psr == 1.0
            @test row.payload_bits == config.payload_bits_per_frame
            @test row.bit_errors == 0
            @test row.ber == 0.0
            @test row.decode_failures == 0
            @test row.status == "ok"
            @test isfinite(row.total_decode_seconds)
            @test row.total_decode_seconds >= 0
            @test row.target_psr == 1.0
            @test row.psr_delta == 0.0

            mktempdir() do dir
                path = benchmark.write_paper_frame_wide_csv(
                    joinpath(dir, "frame-wide.csv"), [row],
                )
                lines = readlines(path)
                @test length(lines) == 2
                header = split(first(lines), ',')
                for column in ("channel", "decoded_packets", "accepted_packets",
                               "psr", "ber", "total_decode_seconds",
                               "target_psr", "psr_delta", "status")
                    @test column in header
                end
            end
        end

        @testset "PSR uncertainty and robust timing summaries are reportable" begin
            @test collect(benchmark._wilson_interval(0, 10)) ≈
                  [0.0, 0.2775327998628892] atol=1e-12
            @test collect(benchmark._wilson_interval(5, 10)) ≈
                  [0.236593090512564, 0.7634069094874361] atol=1e-12
            @test collect(benchmark._wilson_interval(10, 10)) ≈
                  [0.7224672001371107, 1.0] atol=1e-12
            @test_throws ArgumentError benchmark._wilson_interval(-1, 10)
            @test_throws ArgumentError benchmark._wilson_interval(11, 10)
            @test_throws ArgumentError benchmark._wilson_interval(0, 0)

            timing = benchmark._timing_summary([0.001, 0.004, 0.002, 0.003])
            @test timing.total == 0.01
            @test timing.mean == 0.0025
            @test timing.median == 0.0025
            @test timing.p95 ≈ 0.00385 atol=1e-15
            @test_throws ArgumentError benchmark._timing_summary(Float64[])
            @test_throws ArgumentError benchmark._timing_summary([0.1, NaN])
        end

        @testset "packet snapshots are distinct distributed and capture-bounded" begin
            segment = benchmark.ReplayCoupledSegment
            capture = segment.ReplayCapture(
                ones(ComplexF64, 2, 100), zeros(2_000),
                1_000.0, 25_000.0, 10, 1, "positions",
            )
            positions = benchmark._snapshot_positions(capture, 4, 100, 1_000.0)
            @test positions == [1, 30, 60, 89]
            @test issorted(positions)
            @test allunique(positions)
            @test first(positions) == 1
            @test last(positions) == 89

            every_position = benchmark._snapshot_positions(
                capture, 89, 100, 1_000.0,
            )
            @test every_position == collect(1:89)
            @test_throws ArgumentError benchmark._snapshot_positions(
                capture, 90, 100, 1_000.0,
            )
            @test_throws ArgumentError benchmark._snapshot_positions(
                capture, 1, 0, 1_000.0,
            )
            @test_throws ArgumentError benchmark._snapshot_positions(
                capture, 1, 100, 0.0,
            )
        end

        @testset "capture-declared rate drives BER PSR and timing accounting" begin
            capture = benchmark.identity_capture(
                fs=19_200.0, fc=25_000.0, receiver=3,
            )
            rows = benchmark.benchmark_capture(
                capture;
                channel_id="identity",
                packets=2,
                snr_db=Inf,
                seed=91,
            )

            @test length(rows) == length(benchmark.algorithm_descriptors())
            @test Tuple(Symbol(row.profile) for row in rows) ==
                  Tuple(filter(profile -> profile !== :frame_wide_ldpc,
                               JunaCore.Juna._RECEIVER_PROFILES))
            for row in rows
                @test row.packets == 2
                @test row.successful_packets == 2
                @test row.decode_failures == 0
                @test row.payload_bits == 2 * 84
                @test row.bit_errors == 0
                @test row.ber == 0.0
                @test row.psr == 1.0
                @test 0.0 < row.psr_ci95_low < row.psr
                @test row.psr_ci95_high == 1.0
                @test isfinite(row.total_decode_seconds)
                @test row.total_decode_seconds >= 0
                @test row.mean_decode_seconds == row.total_decode_seconds / row.packets
                @test isfinite(row.median_decode_seconds)
                @test isfinite(row.p95_decode_seconds)
                @test 0 <= row.median_decode_seconds <= row.p95_decode_seconds
                @test row.status == "ok"
                @test row.receiver == 3
                @test row.modem_fs == 19_200.0
                @test row.capture_fs == 19_200.0
                @test row.requested_modem_bw == 1.0
                @test row.requested_modem_bandwidth_hz == 19_200.0
                @test row.channel_bandwidth_hz == 9_600.0
                @test row.effective_bandwidth_hz == 9_600.0
                @test row.effective_bw == 0.5
            end
        end

        @testset "every color family defaults to its own declared rate" begin
            declared_rates = (
                red=19_200.0,
                blue=9_765.625,
                yellow=12_500.0,
            )
            lite = benchmark.select_algorithms(["lite"])
            for (color, fs) in pairs(declared_rates)
                capture = benchmark.identity_capture(fs=fs, receiver=1)
                row = only(benchmark.benchmark_capture(
                    capture; channel_id=String(color), packets=1,
                    algorithms=lite, seed=11,
                ))
                @test row.modem_fs == fs
                @test row.capture_fs == fs
                @test row.channel_bandwidth_hz == fs / 2
                @test row.effective_bandwidth_hz == fs / 2
                @test row.effective_bw == 0.5
                @test row.ber == 0.0
            end
        end

        @testset "Rpchan winner profile pins its frame and modem geometry" begin
            profiles = benchmark.modem_profile_descriptors()
            @test Tuple(profile.id for profile in profiles) == (:default, :rpchan_winner)
            winner = benchmark.select_modem_profile(:rpchan_winner)
            @test winner.frame_packets == 10
            @test winner.passband_oversample == 12

            receivers, payload_per_packet = benchmark._receiver_set(
                benchmark.algorithm_descriptors(), 25_000.0, 9_600.0;
                modem_profile=:rpchan_winner,
            )
            @test payload_per_packet == 735
            for item in receivers
                m = item.receiver
                @test Int(m.nc) == 1024
                @test Int(m.np) == 32
                @test m.bpc == 2
                @test JunaCore.Juna._pilot_spacing(m) == 5
                @test JunaCore.Juna._inner_pilot_spacing(m) == 10
                @test (m.ldpc_k, m.ldpc_n, m.ldpc_npc) == (817, 1634, 9)
                @test m.partial_fft_parts == 4
                @test m.partial_fft_nbands == 4
                @test m.sync === true
                @test m.sync_profile === :rpchan
                @test m.rpchan_guard_s == 0.0
                @test m.rpchan_doppler_ppm == 0.0
                @test m.rpchan_doppler_steps == 1
                @test m.rpchan_sync_max_lag == 400
            end

            rows = benchmark.benchmark_capture(
                benchmark.identity_capture(fs=19_200.0, fc=25_000.0, receiver=1);
                channel_id="identity", packets=20,
                modem_fs=:rpchan, modem_profile=:rpchan_winner,
                seed=27,
            )
            @test length(rows) == length(benchmark.algorithm_descriptors())
            for row in rows
                @test row.modem_profile == "rpchan_winner"
                @test row.frame_packets == 10
                @test row.modem_fs == 9_600.0
                @test row.requested_modem_bandwidth_hz == 9_600.0
                @test row.channel_bandwidth_hz == 9_600.0
                @test row.effective_bandwidth_hz == 9_600.0
                @test row.effective_bw == 1.0
                @test row.packets == 20
                @test row.successful_packets == 20
                @test row.payload_bits == 20 * 735
                @test row.bit_errors == 0
                @test row.ber == 0.0
                @test row.psr == 1.0
            end
            @test_throws ArgumentError benchmark.benchmark_capture(
                benchmark.identity_capture(); packets=11,
                modem_fs=:rpchan, modem_profile=:rpchan_winner,
            )
        end

        @testset "modem rate is resampled through the independent channel grid" begin
            segment = benchmark.ReplayCoupledSegment
            capture = segment.ReplayCapture(
                reshape(ComplexF64[0.25, 1.0, 0.1im, 0.25, 1.0, 0.1im], 3, 2),
                collect(range(0.0, 0.2; length=128)),
                19_200.0, 25_000.0, 8, 2, "rate_bridge",
            )
            transmitted = ComplexF64[cis(0.31i) for i in 0:31]
            channel_input = vec(SignalAnalysis.resample(
                transmitted, capture.fs / 5_000.0; dims=1,
            ))
            channel_output = segment.apply_capture(
                capture, channel_input; snapshot=1,
            )
            expected = vec(SignalAnalysis.resample(
                channel_output, 5_000.0 / capture.fs; dims=1,
            ))

            actual = segment.replay_at_modem_rate(
                capture, transmitted; snapshot=1, modem_fs=5_000.0,
            )
            @test actual == expected
            @test length(actual) != length(segment.apply_capture(
                capture, transmitted; snapshot=1,
            ))
            @test_throws ArgumentError segment.replay_at_modem_rate(
                capture, transmitted; modem_fs=0.0,
            )
        end

        @testset "CSV schema carries provenance and requested metrics" begin
            capture = benchmark.identity_capture()
            rows = benchmark.benchmark_capture(
                capture; channel_id="identity", packets=1,
                algorithms=benchmark.select_algorithms(["lite"]), seed=7,
            )
            mktempdir() do dir
                path = benchmark.write_benchmark_csv(joinpath(dir, "result.csv"), rows)
                csv = read(path, String)
                header = first(split(csv, '\n'))
                for column in ("channel", "color", "algorithm", "profile", "packets",
                               "receiver", "modem_fs", "capture_fs",
                               "successful_packets", "psr", "payload_bits", "bit_errors",
                               "psr_ci95_low", "psr_ci95_high", "ber",
                               "decode_failures", "mean_decode_seconds",
                               "median_decode_seconds", "p95_decode_seconds",
                               "total_decode_seconds", "snr_db", "seed", "status")
                    @test column in split(header, ',')
                end
                @test occursin("identity", csv)
                @test occursin("JUNA-Lite", csv)
            end
        end

        @testset "CLI SNR grid emits one row per receiver and SNR" begin
            @test benchmark._parse_snr_grid("0:5:30") == collect(0.0:5.0:30.0)
            @test benchmark._parse_snr_grid("10:-5:0") == [10.0, 5.0, 0.0]
            @test benchmark._parse_snr_grid("0, 10, 30") == [0.0, 10.0, 30.0]
            @test_throws ArgumentError benchmark._parse_snr_grid("0:0:30")
            @test_throws ArgumentError benchmark._parse_snr_grid("0:-5:30")
            @test_throws ArgumentError benchmark._parse_snr_grid("0:5")

            mktempdir() do dir
                path = joinpath(dir, "sweep.csv")
                output = read(
                    `julia --project=$BenchmarkRoot $BenchmarkTool --fixture identity --algorithms standard,lite --packets 1 --snr 0:5:10 --seed 17 --strict true --out $path`,
                    String,
                )
                lines = readlines(path)
                @test length(lines) == 1 + 2 * 3
                @test count(line -> startswith(line, "##BENCH_ROW##"),
                            split(output, '\n')) == 6
                @test occursin("##BENCH_DONE##rows=6", output)

                header = split(first(lines), ',')
                snr_column = findfirst(==("snr_db"), header)
                algorithm_column = findfirst(==("algorithm"), header)
                @test snr_column !== nothing
                @test algorithm_column !== nothing
                rows = split.(lines[2:end], ',')
                @test Set(parse(Float64, row[snr_column]) for row in rows) ==
                      Set((0.0, 5.0, 10.0))
                @test Set(row[algorithm_column] for row in rows) ==
                      Set(("Standard OFDM", "JUNA-Lite"))
            end
        end

        @testset "strict report validation rejects incomplete or failed rows" begin
            capture = benchmark.identity_capture()
            rows = benchmark.benchmark_capture(
                capture; channel_id="identity", packets=2,
                algorithms=benchmark.select_algorithms(["lite"]), seed=19,
            )
            @test benchmark.validate_report_rows(
                rows; expected_rows=1, require_ok=true,
            ) === nothing
            @test_throws ArgumentError benchmark.validate_report_rows(
                rows; expected_rows=2, require_ok=true,
            )
            failed = merge(only(rows), (
                status="capture failure: fixture", decode_failures=2,
            ))
            @test_throws ArgumentError benchmark.validate_report_rows(
                [failed]; expected_rows=1, require_ok=true,
            )
            @test_throws ArgumentError benchmark.validate_report_rows(
                [only(rows), only(rows)]; expected_rows=2, require_ok=true,
            )
            wrong_bandwidth = merge(only(rows), (
                effective_bandwidth_hz=only(rows).requested_modem_bandwidth_hz,
                effective_bw=only(rows).requested_modem_bw,
            ))
            @test_throws ArgumentError benchmark.validate_report_rows(
                [wrong_bandwidth]; expected_rows=1, require_ok=true,
            )
        end

        @testset "optional real red1 records declared and Rpchan rates separately" begin
            if get(ENV, "JUNA_RECEIVER_BENCHMARK_REAL", "0") == "1"
                path = get(
                    ENV, "JUNA_REPLAY_SEGMENT_PATH",
                    joinpath(homedir(), "Documents", "GitHub",
                             "Juna_replay_channel_1ch", "data", "red_1.mat"),
                )
                capture = benchmark.ReplayCoupledSegment.load_capture(
                    path; receiver=3,
                )
                declared_rows = benchmark.benchmark_capture(
                    capture; channel_id="red1", packets=1, seed=1,
                )
                @test length(declared_rows) == length(benchmark.algorithm_descriptors())
                @test all(row -> row.receiver == 3, declared_rows)
                @test all(row -> row.modem_fs == 19_200.0, declared_rows)
                @test all(row -> row.capture_fs == 19_200.0, declared_rows)
                @test all(row -> row.decode_failures == 0, declared_rows)
                @test all(row -> isfinite(row.ber), declared_rows)
                declared_lite = only(filter(row -> row.profile == "lite", declared_rows))
                declared_wz = only(filter(row -> row.profile == "full", declared_rows))
                declared_wcz = only(filter(row -> row.profile == "coupled", declared_rows))
                @test declared_wcz.bit_errors <= declared_lite.bit_errors
                @test declared_wcz.bit_errors <= declared_wz.bit_errors

                rpchan_rows = benchmark.benchmark_capture(
                    capture; channel_id="red1", packets=1, seed=1,
                    modem_fs=capture.fs / 2,
                )
                @test all(row -> row.modem_fs == 9_600.0, rpchan_rows)
                @test all(row -> row.capture_fs == 19_200.0, rpchan_rows)
                @test all(row -> row.bit_errors == 0, rpchan_rows)
                @test all(row -> row.ber == 0.0, rpchan_rows)
                @test all(row -> row.psr == 1.0, rpchan_rows)
            else
                @info "real receiver benchmark disabled; set JUNA_RECEIVER_BENCHMARK_REAL=1"
                @test_skip true
            end
        end


        @testset "optional all-capture 0/30 dB report preflight" begin
            if get(ENV, "JUNA_RECEIVER_BENCHMARK_PREFLIGHT", "0") == "1"
                data_dir = get(
                    ENV, "JUNA_REPLAY_DATA_DIR",
                    joinpath(homedir(), "Documents", "GitHub",
                             "Juna_replay_channel_1ch", "data"),
                )
                out = get(
                    ENV, "JUNA_RECEIVER_BENCHMARK_PREFLIGHT_CSV",
                    joinpath(BenchmarkRoot, "reports", "all_channels_preflight.csv"),
                )
                channels = benchmark.channel_descriptors()
                algorithms = benchmark.algorithm_descriptors()
                rows = benchmark.run_benchmark_sweep(
                    data_dir; channels=channels, algorithms=algorithms,
                    packets=1, snrs=(0.0, 30.0), seed=1,
                    modem_fs=:capture, receiver=3, out=out,
                )
                @test length(rows) == 120
                @test benchmark.validate_report_rows(
                    rows; expected_rows=120, require_ok=true,
                ) === nothing
                @test Set(row.channel for row in rows) ==
                      Set(String(entry.id) for entry in channels)
                @test Set(row.snr_db for row in rows) == Set((0.0, 30.0))
                @test Set(Symbol(row.profile) for row in rows) ==
                      Set(JunaCore.Juna._RECEIVER_PROFILES)
                @test allunique((row.channel, row.algorithm, row.receiver,
                                 row.modem_fs, row.snr_db, row.seed) for row in rows)
                for algorithm in unique(row.algorithm for row in rows)
                    errors_at(snr) = sum(
                        row.bit_errors for row in rows
                        if row.algorithm == algorithm && row.snr_db == snr
                    )
                    @test errors_at(30.0) <= errors_at(0.0)
                end
                @test isfile(out)
            else
                @info "all-capture preflight disabled; set JUNA_RECEIVER_BENCHMARK_PREFLIGHT=1"
                @test_skip true
            end
        end
    end

    @testset "live page exposes comparison controls and result columns" begin
        python = Sys.which("python3")
        @test python !== nothing
        if python !== nothing && isfile(BenchmarkPage)
            mktempdir() do dir
                port = 8900 + (getpid() % 80)
                history = joinpath(dir, "runs.jsonl")
                server = run(pipeline(
                    `$python $BenchmarkServer --repo $BenchmarkRoot --port $port --history $history`;
                    stdout=joinpath(dir, "server.log"), stderr=joinpath(dir, "server.log")),
                    wait=false)
                try
                    base = "http://127.0.0.1:$port"
                    ready = false
                    for _ in 1:50
                        try
                            benchmark_curl("$base/api/status")
                            ready = true
                            break
                        catch
                            sleep(0.2)
                        end
                    end
                    @test ready
                    page = benchmark_curl("$base/benchmark")
                    for marker in ("id=\"channel-picker\"", "id=\"algorithm-picker\"",
                                   "id=\"packet-count\"", "id=\"snr-db\"",
                                   "id=\"modem-fs\"", "id=\"modem-profile\"",
                                   "id=\"receiver-lane\"",
                                   "id=\"benchmark-progress\"", "id=\"benchmark-results\"",
                                   "id=\"benchmark-summary\"", "id=\"download-csv\"",
                                   "BER", "PSR", "PSR 95%", "Median decode",
                                   "P95 decode", "Declared fs_delay", "0:5:30")
                        @test occursin(marker, page)
                    end
                    @test occursin("value=\"capture\" selected", page)
                    @test occursin("Capture fs_delay stress rate", page)
                    @test occursin("Rpchan winner geometry", page)
                    @test occursin("value=\"3\" selected", page)
                    @test occursin("Red 1", page)
                    @test occursin("Blue 1", page)
                    @test occursin("Yellow 1", page)
                    @test occursin("JUNA-Lite", page)
                    @test occursin("JUNA-Wz", page)
                    @test occursin("JUNA-WCz", page)

                    invalid = benchmark_curl(
                        "-X", "POST", "-H", "Content-Type: application/json",
                        "-d", "{\"channels\":[\"orange1\"],\"algorithms\":[\"lite\"],\"packets\":1}",
                        "$base/api/benchmark",
                    )
                    @test occursin("unknown channel", invalid)

                    invalid_rate = benchmark_curl(
                        "-X", "POST", "-H", "Content-Type: application/json",
                        "-d", "{\"channels\":[\"red1\"],\"algorithms\":[\"lite\"],\"packets\":1,\"modem_fs\":0,\"receiver\":3}",
                        "$base/api/benchmark",
                    )
                    @test occursin("modem rate", invalid_rate)

                    invalid_receiver = benchmark_curl(
                        "-X", "POST", "-H", "Content-Type: application/json",
                        "-d", "{\"channels\":[\"red1\"],\"algorithms\":[\"lite\"],\"packets\":1,\"modem_fs\":5000,\"receiver\":4}",
                        "$base/api/benchmark",
                    )
                    @test occursin("receiver lane", invalid_receiver)

                    invalid_profile = benchmark_curl(
                        "-X", "POST", "-H", "Content-Type: application/json",
                        "-d", "{\"channels\":[\"red1\"],\"algorithms\":[\"lite\"],\"packets\":1,\"modem_profile\":\"unknown\"}",
                        "$base/api/benchmark",
                    )
                    @test occursin("modem profile", invalid_profile)

                    invalid_snr_grid = benchmark_curl(
                        "-X", "POST", "-H", "Content-Type: application/json",
                        "-d", "{\"channels\":[\"red1\"],\"algorithms\":[\"lite\"],\"packets\":1,\"snr_db\":\"0:0:30\"}",
                        "$base/api/benchmark",
                    )
                    @test occursin("SNR grid", invalid_snr_grid)
                finally
                    kill(server)
                end
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA colored-channel receiver benchmark checks passed")
end
