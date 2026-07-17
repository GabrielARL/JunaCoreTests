#!/usr/bin/env julia

using JunaCore
using Printf

include(joinpath(@__DIR__, "receiver_channel_benchmark.jl"))
const RpchanBaseline = Main.ReceiverChannelBenchmark

const OUTPUT_COLUMNS = (
    :juna_core_commit,
    RpchanBaseline.PAPER_ALGORITHM_RESULT_COLUMNS...,
)

function parse_args(args)
    options = Dict(
        "data-dir" => joinpath(homedir(), "Documents", "GitHub", "Rpchan", "data"),
        "source-root" => normpath(joinpath(@__DIR__, "..", "..", "JunaCore.jl")),
        "out" => normpath(joinpath(
            @__DIR__, "..", "reports",
            "sg1_rpchan_pinned_five_algorithms_20db.csv")),
        "max-packets" => "360",
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
    length(commit) == 40 || throw(ArgumentError(
        "JunaCore did not return a full commit SHA"))
    commit
end

csv_value(value::AbstractFloat) = @sprintf("%.12g", value)
csv_value(value) = string(value)

function write_rows(path, commit, rows)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        println(io, join(string.(OUTPUT_COLUMNS), ','))
        for row in rows
            recorded = merge((juna_core_commit=commit,), row)
            println(io, join(
                (csv_value(getproperty(recorded, column))
                 for column in OUTPUT_COLUMNS),
                ',',
            ))
        end
    end
    abspath(path)
end

function main(args=ARGS)
    options = parse_args(args)
    commit = source_commit(options["source-root"])
    config = only(filter(
        item -> item.id === :red1,
        RpchanBaseline.paper_frame_wide_config_descriptors(),
    ))
    channel = only(filter(
        item -> item.id === :red1,
        RpchanBaseline.channel_descriptors(),
    ))
    capture = RpchanBaseline.load_capture(
        joinpath(options["data-dir"], channel.filename); receiver=3)
    RpchanBaseline._validate_capture_rate(channel, capture)
    packets = parse(Int, options["max-packets"])
    rows = RpchanBaseline.benchmark_paper_frame_wide_algorithms(
        capture,
        config;
        decoded_packets=min(packets, config.target_decoded_packets),
        snr_db=20.0,
        seed=51_001,
        warmup=true,
    )
    length(rows) == length(RpchanBaseline.frame_algorithm_descriptors()) ||
        error("incomplete SG-1 Rpchan receiver comparison")
    all(row -> row.status == "ok", rows) ||
        error("one or more SG-1 Rpchan receiver rows failed")
    output = write_rows(options["out"], commit, rows)
    for row in rows
        @printf("%-18s packet PSR %.3f frame PSR %.3f BER %.5g %.3fs/frame\n",
                row.algorithm, row.packet_psr, row.frame_psr, row.ber,
                row.mean_decode_seconds_per_frame)
    end
    println("wrote $(length(rows)) pinned SG-1 rows to $output")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
