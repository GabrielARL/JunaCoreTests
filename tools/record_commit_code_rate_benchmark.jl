#!/usr/bin/env julia

using JunaCore
using Printf

include(joinpath(@__DIR__, "receiver_channel_benchmark.jl"))
const CommitRateBenchmark = Main.ReceiverChannelBenchmark

const CODE_RATES = (1 / 16, 1 / 8, 1 / 4, 1 / 2)
const FFT_SIZES = (512, 1024, 2048)
const PILOT_RATIOS = (0.25, 0.5, 0.75)
const CYCLIC_PREFIX = 16
const HISTORY_COLUMNS = (
    :juna_core_commit,
    :channel,
    :snr_db,
    :pilot_ratio,
    :outer_pilot_spacing,
    :inner_pilot_spacing,
    :code_rate,
    :nfft,
    :cp,
    :modem_fs,
    :capture_fs,
    :bandwidth_policy,
    :requested_modem_bandwidth_hz,
    :channel_bandwidth_hz,
    :effective_bandwidth_hz,
    :effective_bw,
    :algorithm,
    :blocks,
    :successful_blocks,
    :psr,
    :payload_bits,
    :bit_errors,
    :ber,
    :mean_decode_seconds_per_block,
    :capture_duration_seconds,
    :covered_duration_seconds,
    :effective_data_rate_bps,
    :seed,
    :status,
)

function parse_args(args)
    options = Dict(
        "data-dir" => joinpath(homedir(), "Documents", "GitHub", "Rpchan", "data"),
        "source-root" => normpath(joinpath(@__DIR__, "..", "..", "JunaCore.jl")),
        "out" => normpath(joinpath(@__DIR__, "..", "reports",
                                   "sg1_20db_commit_history.csv")),
    )
    index = 1
    while index <= length(args)
        key = args[index]
        startswith(key, "--") || throw(ArgumentError("unknown argument: $key"))
        name = key[3:end]
        haskey(options, name) || throw(ArgumentError("unknown option: $key"))
        index < length(args) || throw(ArgumentError("$key needs a value"))
        options[name] = args[index + 1]
        index += 2
    end
    options
end

function source_commit(source_root)
    root = abspath(source_root)
    commit = strip(read(`git -C $root rev-parse HEAD`, String))
    status = strip(read(`git -C $root status --porcelain`, String))
    isempty(status) || throw(ArgumentError(
        "JunaCore source is dirty; commit or restore it before recording performance"))
    length(commit) == 40 || throw(ArgumentError("JunaCore did not return a full commit SHA"))
    commit
end

csv_value(value::AbstractFloat) = @sprintf("%.12g", value)
csv_value(value) = string(value)

function history_row(commit, nfft, code_rate, pilot_ratio, capture_duration, row)
    payload_bits_per_block = div(row.payload_bits, row.packets)
    covered_duration = row.packets * (nfft + CYCLIC_PREFIX) / row.modem_fs
    pilot_geometry = CommitRateBenchmark._pilot_budget_geometry(pilot_ratio)
    (
        juna_core_commit=commit,
        channel=row.channel,
        snr_db=row.snr_db,
        pilot_ratio=pilot_geometry.requested,
        outer_pilot_spacing=pilot_geometry.outer_spacing,
        inner_pilot_spacing=pilot_geometry.inner_spacing,
        code_rate=code_rate,
        nfft=nfft,
        cp=CYCLIC_PREFIX,
        modem_fs=row.modem_fs,
        capture_fs=row.capture_fs,
        bandwidth_policy="min_channel_modem",
        requested_modem_bandwidth_hz=row.requested_modem_bandwidth_hz,
        channel_bandwidth_hz=row.channel_bandwidth_hz,
        effective_bandwidth_hz=row.effective_bandwidth_hz,
        effective_bw=row.effective_bw,
        algorithm=row.algorithm,
        blocks=row.packets,
        successful_blocks=row.successful_packets,
        psr=row.psr,
        payload_bits=row.payload_bits,
        bit_errors=row.bit_errors,
        ber=row.ber,
        mean_decode_seconds_per_block=row.mean_decode_seconds,
        capture_duration_seconds=capture_duration,
        covered_duration_seconds=covered_duration,
        effective_data_rate_bps=CommitRateBenchmark._effective_data_rate(
            row.successful_packets, payload_bits_per_block, capture_duration),
        seed=row.seed,
        status=row.status,
    )
end

function write_history(path, commit, fresh_rows)
    header = join(string.(HISTORY_COLUMNS), ',')
    preserved = String[]
    if isfile(path)
        existing = readlines(path)
        if !isempty(existing) && first(existing) != header
            old_commits = Set(first(split(line, ',')) for line in existing[2:end]
                              if !isempty(line))
            old_commits == Set([commit]) || throw(ArgumentError(
                "history CSV schema changed and contains other source commits"))
        else
            append!(preserved,
                    filter(line -> !startswith(line, commit * ","), existing[2:end]))
        end
    end

    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        println(io, header)
        foreach(line -> println(io, line), preserved)
        for row in fresh_rows
            println(io, join((csv_value(getproperty(row, column))
                              for column in HISTORY_COLUMNS), ','))
        end
    end
    abspath(path)
end

function main(args=ARGS)
    options = parse_args(args)
    commit = source_commit(options["source-root"])
    channel = only(filter(item -> item.id === :red1,
                          CommitRateBenchmark.channel_descriptors()))
    capture = CommitRateBenchmark.load_capture(
        joinpath(options["data-dir"], channel.filename);
        receiver=3,
    )
    CommitRateBenchmark._validate_capture_rate(channel, capture)
    capture_duration = length(capture.phase) / capture.fs

    fresh_rows = NamedTuple[]
    for pilot_ratio in PILOT_RATIOS, code_rate in CODE_RATES, nfft in FFT_SIZES
        println(
            "benchmarking full SG-1 capture: pilots=$pilot_ratio " *
            "N=$nfft rate=$code_rate",
        )
        flush(stdout)
        rows = CommitRateBenchmark.benchmark_capture(
            capture;
            channel_id="red1",
            packets=1,
            algorithms=CommitRateBenchmark.algorithm_descriptors(),
            snr_db=20.0,
            seed=1,
            modem_fs=:capture,
            modem_profile=:default,
            nfft=nfft,
            cp=CYCLIC_PREFIX,
            code_rate=code_rate,
            pilot_ratio=pilot_ratio,
            full_capture=true,
            warmup=true,
        )
        append!(fresh_rows,
                history_row.(Ref(commit), Ref(nfft), Ref(code_rate),
                             Ref(pilot_ratio),
                             Ref(capture_duration), rows))
    end

    length(fresh_rows) == length(FFT_SIZES) * length(CODE_RATES) *
                          length(PILOT_RATIOS) *
                          length(CommitRateBenchmark.algorithm_descriptors()) ||
        error("incomplete code-rate/pilot benchmark")
    all(row -> row.status == "ok", fresh_rows) ||
        error("one or more code-rate benchmark rows failed")
    output = write_history(options["out"], commit, fresh_rows)
    println("wrote $(length(fresh_rows)) commit/code-rate/pilot rows to $output")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
