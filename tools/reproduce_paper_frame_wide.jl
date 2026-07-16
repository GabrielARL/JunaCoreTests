#!/usr/bin/env julia
# Run JUNA's matched frame-wide LDPC transmitter/receiver at the twelve
# winner configurations reported by Rpchan's cross-channel paper.

include(joinpath(@__DIR__, "receiver_channel_benchmark.jl"))
using .ReceiverChannelBenchmark
using Printf

function parse_options(args)
    options = Dict(
        "data-dir" => joinpath(homedir(), "Documents", "GitHub", "Rpchan", "data"),
        "channels" => "all",
        "snr" => "20",
        "seed" => "51001",
        "receiver" => "3",
        "max-packets" => "paper",
        "out" => joinpath(pwd(), "reports", "paper_frame_wide_20db.csv"),
    )
    index = 1
    while index <= length(args)
        argument = args[index]
        startswith(argument, "--") || throw(ArgumentError("unknown argument: $argument"))
        key = argument[3:end]
        haskey(options, key) || throw(ArgumentError("unknown option: --$key"))
        index < length(args) || throw(ArgumentError("--$key needs a value"))
        options[key] = args[index + 1]
        index += 2
    end
    options
end

function selected_configs(value)
    configs = paper_frame_wide_config_descriptors()
    lowercase(strip(value)) == "all" && return configs
    requested = Symbol.(strip.(split(lowercase(value), ',')))
    unknown = setdiff(requested, [config.id for config in configs])
    isempty(unknown) || throw(ArgumentError(
        "unknown paper channel: $(join(unknown, ", "))"))
    Tuple(config for config in configs if config.id in requested)
end

function main(args=ARGS)
    options = parse_options(args)
    configs = selected_configs(options["channels"])
    max_text = lowercase(strip(options["max-packets"]))
    max_packets = max_text == "paper" ? nothing : parse(Int, max_text)
    output = abspath(options["out"])

    emit = function (kind, value)
        if kind === :begin
            println("starting ", value)
        elseif kind === :row
            @printf("%-5s PSR %.3f (paper %.3f), BER %.5g (paper %.5g), %.3fs/frame\n",
                    value.label, value.psr, value.target_psr,
                    value.ber, value.target_ber, value.mean_decode_seconds)
        end
        flush(stdout)
    end

    rows = run_paper_frame_wide_reproduction(
        abspath(options["data-dir"]);
        configs=configs,
        snr_db=parse(Float64, options["snr"]),
        seed=parse(Int, options["seed"]),
        receiver=parse(Int, options["receiver"]),
        max_decoded_packets=max_packets,
        out=output,
        emit=emit,
    )
    failed = filter(row -> row.status != "ok", rows)
    isempty(failed) || error(
        "$(length(failed)) channel run(s) had decode failures; inspect $output")
    println("wrote ", output)
end

main()
