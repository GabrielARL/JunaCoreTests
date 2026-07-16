#!/usr/bin/env julia

using JunaCore
using Printf

include(joinpath(@__DIR__, "receiver_channel_benchmark.jl"))
const CommitRateBenchmark = Main.ReceiverChannelBenchmark

const CODE_RATES = (1 / 16, 1 / 8, 1 / 4, 1 / 2)
const FFT_SIZES = (512, 1024, 2048)
const CYCLIC_PREFIX = 16
const HISTORY_COLUMNS = (
    :juna_core_commit,
    :channel,
    :snr_db,
    :code_rate,
    :nfft,
    :cp,
    :modem_fs,
    :capture_fs,
    :algorithm,
    :packets,
    :successful_packets,
    :psr,
    :payload_bits,
    :bit_errors,
    :ber,
    :mean_decode_seconds_per_block,
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

function history_row(commit, nfft, code_rate, row)
    (
        juna_core_commit=commit,
        channel=row.channel,
        snr_db=row.snr_db,
        code_rate=code_rate,
        nfft=nfft,
        cp=CYCLIC_PREFIX,
        modem_fs=row.modem_fs,
        capture_fs=row.capture_fs,
        algorithm=row.algorithm,
        packets=row.packets,
        successful_packets=row.successful_packets,
        psr=row.psr,
        payload_bits=row.payload_bits,
        bit_errors=row.bit_errors,
        ber=row.ber,
        mean_decode_seconds_per_block=row.mean_decode_seconds,
        seed=row.seed,
        status=row.status,
    )
end

function write_history(path, commit, fresh_rows)
    header = join(string.(HISTORY_COLUMNS), ',')
    preserved = String[]
    if isfile(path)
        existing = readlines(path)
        isempty(existing) || first(existing) == header ||
            throw(ArgumentError("history CSV schema does not match recorder"))
        append!(preserved, filter(line -> !startswith(line, commit * ","), existing[2:end]))
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

    fresh_rows = NamedTuple[]
    for code_rate in CODE_RATES, nfft in FFT_SIZES
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
            warmup=true,
        )
        append!(fresh_rows,
                history_row.(Ref(commit), Ref(nfft), Ref(code_rate), rows))
    end

    length(fresh_rows) == length(FFT_SIZES) * length(CODE_RATES) *
                          length(CommitRateBenchmark.algorithm_descriptors()) ||
        error("incomplete code-rate benchmark")
    all(row -> row.status == "ok", fresh_rows) ||
        error("one or more code-rate benchmark rows failed")
    output = write_history(options["out"], commit, fresh_rows)
    println("wrote $(length(fresh_rows)) commit/code-rate rows to $output")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
