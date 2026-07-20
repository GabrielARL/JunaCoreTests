#!/usr/bin/env julia
#
# Run registered test suites and record per-suite results to evidence.json.
#
# Usage:
#   julia --project=. tools/emit_evidence.jl                    # all suites
#   julia --project=. tools/emit_evidence.jl layout pilots      # matching suites
#   julia --project=. tools/emit_evidence.jl --out reports/evidence.json
#
# The JSON feeds tools/build_evidence_page.py. It is written even when suites
# fail; the exit status is nonzero iff any assertion failed or errored, so CI
# can build the honest page first and fail the job afterwards.

using Test

const EVIDENCE_CLI = copy(ARGS)

evidence_out = joinpath(dirname(@__DIR__), "reports", "evidence.json")
evidence_selectors = String[]
let i = 1
    while i <= length(EVIDENCE_CLI)
        if EVIDENCE_CLI[i] == "--out"
            i == length(EVIDENCE_CLI) && error("--out requires a path")
            global evidence_out = EVIDENCE_CLI[i + 1]
            i += 2
        elseif startswith(EVIDENCE_CLI[i], "-")
            error("unknown flag $(EVIDENCE_CLI[i]); usage: " *
                  "emit_evidence.jl [--out path] [selector...]")
        else
            push!(evidence_selectors, EVIDENCE_CLI[i])
            i += 1
        end
    end
end

# Mirror runtests.jl's special selector: 'roundtrip' means the contract suite
# with the extended multi-block loopback enabled, not a substring match.
if "roundtrip" in evidence_selectors
    ENV["JUNA_INTERFACE_ROUNDTRIP"] = "1"
    evidence_selectors = filter(!=("roundtrip"), evidence_selectors)
    push!(evidence_selectors, "contract")
end

# Load the suite registry without running anything: runtests.jl in list mode
# defines SUITES and select_suites, prints the map, and returns.
empty!(ARGS)
push!(ARGS, "list")
include(joinpath(dirname(@__DIR__), "test", "runtests.jl"))

evidence_suites = isempty(evidence_selectors) ? SUITES :
    select_suites(evidence_selectors)

function evidence_counts(ts::Test.DefaultTestSet)
    passes = ts.n_passed
    fails = 0
    errors = 0
    broken = 0
    for result in ts.results
        if result isa Test.DefaultTestSet
            p, f, e, b = evidence_counts(result)
            passes += p; fails += f; errors += e; broken += b
        elseif result isa Test.Pass
            passes += 1
        elseif result isa Test.Fail
            fails += 1
        elseif result isa Test.Error
            errors += 1
        elseif result isa Test.Broken
            broken += 1
        end
    end
    (passes, fails, errors, broken)
end

function json_escape(s::AbstractString)
    out = IOBuffer()
    for c in s
        if c == '\\'
            print(out, "\\\\")
        elseif c == '"'
            print(out, "\\\"")
        elseif c < ' '
            print(out, "\\u", string(UInt16(c), base = 16, pad = 4))
        else
            print(out, c)
        end
    end
    String(take!(out))
end

function run_git(dir, args...)
    try
        strip(read(setenv(`git -C $dir $(collect(args))`), String))
    catch
        ""
    end
end

evidence_results = NamedTuple[]
for suite in evidence_suites
    println("evidence: running ", suite.key)
    flush(stdout)
    started = time()
    passes = fails = errors = broken = 0
    try
        ts = @testset "$(suite.key)" begin
            include(joinpath(dirname(@__DIR__), "test", suite.file))
        end
        passes, fails, errors, broken = evidence_counts(ts)
    catch err
        err isa Test.TestSetException || rethrow()
        passes = err.pass
        fails = err.fail
        errors = err.error
        broken = err.broken
    end
    push!(evidence_results, (
        key = String(suite.key),
        file = String(suite.file),
        passes = passes,
        fails = fails,
        errors = errors,
        broken = broken,
        seconds = round(time() - started; digits = 3),
    ))
end

repo_dir = dirname(@__DIR__)
commit = run_git(repo_dir, "rev-parse", "--short", "HEAD")
dirty = !isempty(run_git(repo_dir, "status", "--porcelain"))
generated_at = try
    strip(read(`date -u +%Y-%m-%dT%H:%M:%SZ`, String))
catch
    string("epoch:", round(Int, time()))
end
# Provenance only: the page derives gate status from recorded skip counts,
# never from these names. env_enabled applies the repo's truthiness rule.
env_set = sort([k for k in keys(ENV) if startswith(k, "JUNA_")])
env_enabled = sort([k for k in env_set
                    if lowercase(ENV[k]) in ("1", "true", "yes")])

suite_json = join([
    string(
        "    {\"key\": \"", json_escape(r.key), "\",",
        " \"file\": \"", json_escape(r.file), "\",",
        " \"passes\": ", r.passes, ",",
        " \"fails\": ", r.fails, ",",
        " \"errors\": ", r.errors, ",",
        " \"broken\": ", r.broken, ",",
        " \"seconds\": ", r.seconds, "}",
    ) for r in evidence_results], ",\n")

mkpath(dirname(abspath(evidence_out)))
open(evidence_out, "w") do io
    print(io, "{\n")
    print(io, "  \"generated_at\": \"", json_escape(generated_at), "\",\n")
    print(io, "  \"commit\": \"", json_escape(commit), dirty ? "-dirty" : "", "\",\n")
    print(io, "  \"julia\": \"", json_escape(string(VERSION)), "\",\n")
    print(io, "  \"selectors\": [",
          join(["\"" * json_escape(s) * "\"" for s in evidence_selectors], ", "),
          "],\n")
    print(io, "  \"env_set\": [",
          join(["\"" * json_escape(v) * "\"" for v in env_set], ", "),
          "],\n")
    print(io, "  \"env_enabled\": [",
          join(["\"" * json_escape(v) * "\"" for v in env_enabled], ", "),
          "],\n")
    print(io, "  \"suites\": [\n", suite_json, "\n  ]\n}\n")
end

total_bad = sum(r.fails + r.errors for r in evidence_results; init = 0)
total_pass = sum(r.passes for r in evidence_results; init = 0)
println("evidence: ", length(evidence_results), " suites, ", total_pass,
        " passed, ", total_bad, " failed/errored -> ", evidence_out)
total_bad > 0 && exit(1)
