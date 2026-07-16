#!/usr/bin/env julia
#
# Fixed-config decode benchmark for the test dashboard.
#
# Measures BER / PSR / decode time for the paper benchmark geometry
# (default LiteModulation()/FullModulation() = n1024_cp256_sym1_p3_r0p25_ip2)
# under seeded AWGN, and writes one JSON record consumed by
# tools/test_dashboard.py.
#
# The SNR points were chosen from a measured waterfall sweep (2026-07):
#   1.5 dB  mid-waterfall (lite BER ~5e-2) - maximally regression-sensitive
#   2.5 dB  near-clean sentinel (catches "regressed to failure")
# plus a noiseless point for common-path decode time. The noise seed is fixed
# (Xoshiro(42)), so on unchanged code the BER/PSR values are bit-identical
# run to run; any movement is a code change, not noise.
#
# Usage:
#   julia --project=. tools/bench_decode.jl                       # full record
#   julia --project=. tools/bench_decode.jl --packets 2 --receivers lite --snrs 1.5 --out /tmp/x.json
#
# Flags: --packets N (40) | --receivers lite,full | --snrs 1.5,2.5 |
#        --no-clean | --seed 42 | --out bench/latest.json

using JunaCore
using Random
using Statistics
using Printf

const ROOT = normpath(joinpath(@__DIR__, ".."))
const J = JunaCore.Juna
const M = JunaCore.Modulations
const FC = 24_000.0
const FS = 24_000.0
const CONFIG_ID = "n1024_cp256_sym1_p3_r0p25_ip2"

function parse_args(args)
    opts = Dict{String,Any}(
        "packets" => 40, "receivers" => ["lite", "full"],
        "snrs" => [1.5, 2.5], "clean" => true, "seed" => 42,
        "out" => joinpath(ROOT, "bench", "latest.json"),
    )
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--packets"
            opts["packets"] = parse(Int, args[i+1]); i += 2
        elseif a == "--receivers"
            opts["receivers"] = split(args[i+1], ","); i += 2
        elseif a == "--snrs"
            opts["snrs"] = parse.(Float64, split(args[i+1], ",")); i += 2
        elseif a == "--seed"
            opts["seed"] = parse(Int, args[i+1]); i += 2
        elseif a == "--out"
            opts["out"] = args[i+1]; i += 2
        elseif a == "--no-clean"
            opts["clean"] = false; i += 1
        else
            error("unknown flag $a (see header of tools/bench_decode.jl)")
        end
    end
    opts
end

modulation(receiver) = receiver == "full" ? J.FullModulation() : J.LiteModulation()

# One benchmark point: fixed-seed AWGN (or noiseless when snr_db === nothing).
function bench_point(receiver::AbstractString, snr_db, npackets::Int, seed::Int)
    m = modulation(receiver)
    bps = M.bitspersymbol(m)
    rng = Xoshiro(seed)
    sigma = snr_db === nothing ? 0.0 : sqrt(10.0^(-snr_db / 10) / 2)
    nerr = 0
    npass = 0
    times = Float64[]
    for _ in 1:npackets
        bits = rand(rng, Bool, bps)
        w = M.modulate(m, bits, FC, FS)
        if sigma > 0
            w = w .+ sigma .* (randn(rng, length(w)) .+ im .* randn(rng, length(w)))
        end
        t0 = time_ns()
        metrics, _ = M.demodulate(m, bps, w, FC, FS)
        push!(times, (time_ns() - t0) / 1e6)
        e = count((metrics .> 0) .!= bits)
        nerr += e
        npass += (e == 0)
    end
    (
        receiver = String(receiver),
        snr_db = snr_db,
        ber = nerr / (npackets * bps),
        psr = npass / npackets,
        t_med_ms = median(times),
        t_p90_ms = quantile(times, 0.9),
    )
end

function git_info(root)
    short(cmd) = try strip(read(cmd, String)) catch; "" end
    commit = short(`git -C $root rev-parse --short HEAD`)
    isempty(commit) && return (commit = "nogit", dirty = true, tracked = false)
    status = short(`git -C $root status --porcelain -- .`)
    tracked = !isempty(short(`git -C $root ls-files -- .`))
    (commit = commit, dirty = !isempty(status), tracked = tracked)
end

jnum(x) = x === nothing ? "null" : (x isa Int ? string(x) : @sprintf("%.6g", x))
jstr(s) = "\"" * replace(String(s), "\\" => "\\\\", "\"" => "\\\"") * "\""

function point_json(p)
    "{\"receiver\": $(jstr(p.receiver)), \"snr_db\": $(jnum(p.snr_db)), " *
    "\"ber\": $(jnum(p.ber)), \"psr\": $(jnum(p.psr)), " *
    "\"t_med_ms\": $(jnum(p.t_med_ms)), \"t_p90_ms\": $(jnum(p.t_p90_ms))}"
end

function main()
    opts = parse_args(ARGS)
    git = git_info(ROOT)

    # warm up compile paths once per receiver so timings measure decode, not JIT
    for r in opts["receivers"]
        bench_point(r, 2.5, 1, opts["seed"])
    end

    points = NamedTuple[]
    for r in opts["receivers"], snr in opts["snrs"]
        push!(points, bench_point(r, snr, opts["packets"], opts["seed"]))
    end
    if opts["clean"]
        for r in opts["receivers"]
            push!(points, bench_point(r, nothing, max(opts["packets"] ÷ 2, 1), opts["seed"]))
        end
    end

    record = """
{
  "schema": 1,
  "ts": $(jstr(string(round(Int, time())))),
  "commit": $(jstr(git.commit)),
  "dirty": $(git.dirty),
  "tracked": $(git.tracked),
  "julia": $(jstr(string(VERSION))),
  "config": $(jstr(CONFIG_ID)),
  "seed": $(opts["seed"]),
  "npackets": $(opts["packets"]),
  "points": [
    $(join(point_json.(points), ",\n    "))
  ]
}
"""
    out = opts["out"]
    mkpath(dirname(abspath(out)))
    write(out, record)
    println("wrote $out ($(length(points)) points, commit $(git.commit)$(git.dirty ? "+dirty" : ""))")
end

main()
