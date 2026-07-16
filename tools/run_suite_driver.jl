#!/usr/bin/env julia
#
# Live suite driver for the test runner server.
#
# Wraps one test suite file in a custom AbstractTestSet that emits flushed,
# machine-readable markers per testset (nested @testset blocks inherit the
# custom type), so a streaming consumer can show live progress and move a
# code pointer while the suite runs:
#
#   ##TS_BEGIN##<description>
#   ##TS_FAIL##<description>                     (first failure/error in a set)
#   ##TS_END##<description>##<seconds>##<pass>##<fail>##<error>##<broken>##
#   ##DRIVER_NOTE##<text>                        (e.g. surgery fallback)
#   ##DRIVER_DONE##<pass>##<fail>##<error>##<broken>##<seconds>##
#
# All other output (including Test.jl's own failure reports) passes through
# untouched, so the stream doubles as the verbose terminal view.
#
# Usage:
#   julia --project=. tools/run_suite_driver.jl <file.jl>
#   julia --project=. tools/run_suite_driver.jl <file.jl> --only-b64 <base64 JSON array of depth-1 testset names>
#
# --only-b64 keeps only the selected depth-1 `@testset` blocks (4-space
# indent) of the file via line surgery. The surgery is validated - every
# removed block must start with `    @testset` and end with `    end`, and
# kept+removed lines must reconstruct the file - otherwise the FULL file runs
# and a ##DRIVER_NOTE##fallback_full marker is emitted. The temporary file is
# written next to the original so @__DIR__-relative paths keep working.

using Test
import Base64

const DRIVER_ROOT = normpath(joinpath(@__DIR__, ".."))

# ---------------------------------------------------------------------------
# Live testset: constructor fires at block entry, finish at block exit.
# ---------------------------------------------------------------------------

mutable struct LiveTestSet <: Test.AbstractTestSet
    inner::Test.DefaultTestSet
    t0::Float64
    failed::Bool
end

function LiveTestSet(desc::AbstractString; kwargs...)
    println("##TS_BEGIN##", desc)
    flush(stdout)
    LiveTestSet(Test.DefaultTestSet(desc; kwargs...), time(), false)
end

function Test.record(ts::LiveTestSet, res)
    if (res isa Test.Fail || res isa Test.Error) && !ts.failed
        ts.failed = true
        println("##TS_FAIL##", ts.inner.description)
        flush(stdout)
    end
    Test.record(ts.inner, res)
    res
end

# pass/fail/error/broken totals, recursing into child testsets
function live_counts(ds::Test.DefaultTestSet)
    p, f, e, b = ds.n_passed, 0, 0, 0
    for r in ds.results
        if r isa Test.Fail
            f += 1
        elseif r isa Test.Error
            e += 1
        elseif r isa Test.Broken
            b += 1
        elseif r isa Test.DefaultTestSet
            cp, cf, ce, cb = live_counts(r)
            p += cp; f += cf; e += ce; b += cb
        end
    end
    (p, f, e, b)
end

function Test.finish(ts::LiveTestSet)
    p, f, e, b = live_counts(ts.inner)
    dt = round(time() - ts.t0, digits = 3)
    println("##TS_END##", ts.inner.description, "##", dt, "##", p, "##", f, "##", e, "##", b, "##")
    flush(stdout)
    if Test.get_testset_depth() > 0
        Test.record(Test.get_testset(), ts.inner)
        return ts.inner
    end
    Test.finish(ts.inner)
end

# ---------------------------------------------------------------------------
# --only surgery: keep selected depth-1 @testset blocks, drop the others.
# ---------------------------------------------------------------------------

# depth-1 blocks: lines starting with exactly 4 spaces + @testset ... down to
# the matching 4-space `end`. Returns (name, first_line, last_line) triples.
function depth1_blocks(lines)
    blocks = Tuple{String,Int,Int}[]
    i = 1
    while i <= length(lines)
        line = lines[i]
        m = match(r"^    @testset\s+(?:verbose\s*=\s*\w+\s+)?\"((?:[^\"\\]|\\.)*)\"", line)
        if m !== nothing
            j = i + 1
            found = 0
            while j <= length(lines)
                if lines[j] == "    end"
                    found = j
                    break
                end
                # a new depth-1 statement before `    end` means we misparsed
                startswith(lines[j], "    @testset") && break
                j += 1
            end
            if found > 0
                push!(blocks, (m.captures[1], i, found))
                i = found + 1
                continue
            end
        end
        i += 1
    end
    blocks
end

function surgery(path::AbstractString, only::Vector{String})
    lines = readlines(path)
    blocks = depth1_blocks(lines)
    isempty(blocks) && return nothing
    keep = [b for b in blocks if b[1] in only]
    length(keep) == length(only) || return nothing   # a requested name is missing
    drop = [b for b in blocks if !(b[1] in only)]
    # validation: every dropped block is well-formed (checked in depth1_blocks
    # by construction) and blocks never overlap
    ranges = sort([(b[2], b[3]) for b in blocks])
    for k in 2:length(ranges)
        ranges[k][1] > ranges[k-1][2] || return nothing
    end
    dropset = Set{Int}()
    for (_, lo, hi) in drop, ln in lo:hi
        push!(dropset, ln)
    end
    kept = [lines[ln] for ln in 1:length(lines) if !(ln in dropset)]
    length(kept) + length(dropset) == length(lines) || return nothing
    kept
end

# ---------------------------------------------------------------------------

function main()
    isempty(ARGS) && error("usage: run_suite_driver.jl <testfile.jl> [--only-b64 <b64 JSON array>]")
    file = ARGS[1]
    only = String[]
    i = 2
    while i <= length(ARGS)
        if ARGS[i] == "--only-b64" && i < length(ARGS)
            raw = String(Base64.base64decode(ARGS[i+1]))
            # minimal JSON string-array parse: ["a","b"] with \" escapes
            for m in eachmatch(r"\"((?:[^\"\\]|\\.)*)\"", raw)
                push!(only, replace(m.captures[1], "\\\"" => "\""))
            end
            i += 2
        else
            error("unknown driver flag $(ARGS[i])")
        end
    end

    path = joinpath(DRIVER_ROOT, "test", file)
    isfile(path) || error("no such test file: $path")

    run_path = path
    cleanup = nothing
    if !isempty(only)
        kept = surgery(path, only)
        if kept === nothing
            println("##DRIVER_NOTE##fallback_full")
            flush(stdout)
        else
            # same directory, so @__DIR__-relative paths in the suite still work
            run_path = joinpath(dirname(path), ".runner_tmp_$(getpid()).jl")
            write(run_path, join(kept, "\n") * "\n")
            cleanup = run_path
        end
    end

    t0 = time()
    totals = (0, 0, 0, 0)
    try
        ts = @testset LiveTestSet "runner" begin
            include(run_path)
        end
        totals = live_counts(ts isa Test.DefaultTestSet ? ts : ts.inner)
    catch err
        if err isa Test.TestSetException
            # top-level finish throws on failures; the exception carries totals
            totals = (err.pass, err.fail, err.error, err.broken)
        else
            showerror(stdout, err)
            println(stdout)
        end
    finally
        cleanup !== nothing && rm(cleanup; force = true)
    end
    p, f, e, b = totals
    println("##DRIVER_DONE##", p, "##", f, "##", e, "##", b, "##",
            round(time() - t0, digits = 3), "##")
    flush(stdout)
    exit(f + e > 0 ? 1 : 0)
end

main()
