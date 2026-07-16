#!/usr/bin/env julia
#
# LDPC belief propagation - exact sum-product reference, profiled normalized
# min-sum, inner clamps, and syndrome status.
#
# Paper claims protected (papers/main.tex):
#   sec:solver (843)                 Decoder feedback is the bridge from LDPC/BP
#                                    posterior metrics into the JUNA refinements.
#   eq:bp-check / eq:bp-var          Check-to-variable and variable-to-check
#                                    messages follow exact BP; the profiled
#                                    receiver uses normalized min-sum.
#   inner pilots (523-524, 670-679)  Known LDPC message positions are clamped
#                                    before parity decoding consumes metrics.
#
# If this fails: BP may be using the wrong metric polarity, ignoring known inner
# pilots, reusing stale scratch buffers, or reporting a syndrome that does not
# match the posterior hard decision.
#
# Run alone:  julia --project=. test/ldpc_belief_propagation.jl
# Via runner: julia --project=. test/runtests.jl bp

using Test
using JunaCore

const BPJuna = JunaCore.Juna
const BPModulations = JunaCore.Modulations
const BP_ALPHA = 0.8
const BP_INNER_CLAMP = 20.0

function bp_toy_code(H::AbstractMatrix{Bool}; k::Integer = 0,
                     npc::Integer = 1, method::AbstractString = "toy")
    n = size(H, 2)
    check_vars = [findall(@view H[row, :]) for row in axes(H, 1)]
    var_edges = [Tuple{Int,Int}[] for _ in 1:n]
    for c in eachindex(check_vars)
        for (a, v) in enumerate(check_vars[c])
            push!(var_edges[v], (c, a))
        end
    end
    BPJuna._Code(Int(k), n, Int(npc), String(method), 0, collect(1:n),
                 falses(max(n - Int(k), 0), Int(k)), Matrix{Bool}(H),
                 check_vars, var_edges, collect(1:n))
end

bp_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(17i + 5)) for i in 1:n]

bp_metrics_for_codeword(codeword::AbstractVector{Bool}; magnitude::Real = 6.0) =
    Float64[bit ? Float64(magnitude) : -Float64(magnitude) for bit in codeword]

function bp_fixture()
    m = BPJuna.LiteModulation()
    code = BPJuna._code(m)
    payload = bp_payload_pattern(BPModulations.bitspersymbol(m))
    message = BPJuna._build_message(m, code, payload)
    codeword = BPJuna._encode(code, message)
    (m = m, code = code, payload = payload, message = message,
     codeword = codeword, metrics = bp_metrics_for_codeword(codeword))
end

function bp_inner_positions(m, code)
    isp = BPJuna._inner_pilot_spacing(m)
    isp < 1 && return Int[]
    mparity = code.n - code.k
    [code.invperm[mparity + p] for p in 1:code.k if (p - 1) % isp == 0]
end

function bp_expected_inner_lch(code, p::Integer)
    BPJuna._inner_bit(p) ? -BP_INNER_CLAMP : BP_INNER_CLAMP
end

function corrupt_first!(metrics::Vector{Float64}, codeword::AbstractVector{Bool}, nflip::Integer)
    for i in 1:Int(nflip)
        metrics[i] = codeword[i] ? -40.0 : 40.0
    end
    metrics
end

function assert_bp_result_contract(code, bp)
    @test keys(bp) == (:lpost_metric, :valid, :syndrome)
    @test bp.lpost_metric isa Vector{Float64}
    @test length(bp.lpost_metric) == code.n
    @test all(isfinite, bp.lpost_metric)
    @test bp.syndrome == BPJuna._syndrome_weight(code, bp.lpost_metric .> 0)
    @test bp.valid == (bp.syndrome == 0)
end

@testset verbose = true "JUNA LDPC belief propagation" begin
    @testset "_syndrome_weight counts unsatisfied checks on the Tanner graph" begin
        H = Bool[
            1 1 0 0
            0 1 1 1
            1 0 0 1
        ]
        code = bp_toy_code(H; npc = 2, method = "syndrome-toy")
        clean = Bool[false, false, false, false]
        one_bad = Bool[true, false, false, false]
        two_bad = Bool[true, true, false, false]

        @test BPJuna._syndrome_weight(code, clean) == 0
        @test BPJuna._syndrome_weight(code, one_bad) == 2
        @test BPJuna._syndrome_weight(code, two_bad) == 2
        @test BPJuna._syndrome_weight(code, two_bad) ==
              count(isodd, vec(Int.(H) * Int.(two_bad)))
    end

    @testset "_bp_scratch reuses matching buffers and reallocates on signature change" begin
        m = BPJuna.Modulation(inner_pilot_ratio = 0.0)
        first_code = bp_toy_code(Bool[1 1 1]; npc = 1, method = "toy-a")
        second_code = bp_toy_code(Bool[1 1 0; 0 1 1]; npc = 2, method = "toy-b")

        scratch = BPJuna._bp_scratch(m, first_code)
        @test scratch.signature == (first_code.k, first_code.n, first_code.npc,
                                    first_code.method, first_code.seed)
        @test length(scratch.lch) == first_code.n
        @test length(scratch.lpost) == first_code.n
        @test length(scratch.bits) == first_code.n
        @test length(scratch.q) == length(first_code.check_vars)
        @test length(scratch.r) == length(first_code.check_vars)
        @test [length(qc) for qc in scratch.q] == length.(first_code.check_vars)
        @test [length(rc) for rc in scratch.r] == length.(first_code.check_vars)

        scratch.lch[1] = 123.0
        @test BPJuna._bp_scratch(m, first_code) === scratch
        @test scratch.lch[1] == 123.0

        replacement = BPJuna._bp_scratch(m, second_code)
        @test replacement !== scratch
        @test replacement.signature == (second_code.k, second_code.n,
                                        second_code.npc, second_code.method,
                                        second_code.seed)
        @test m.bp_scratch === replacement
        @test length(replacement.q) == length(second_code.check_vars)
    end

    @testset "normalized min-sum update has the expected sign and magnitude" begin
        m = BPJuna.Modulation(inner_pilot_ratio = 0.0)
        code = bp_toy_code(Bool[1 1 1])
        metrics = [4.0, -2.0, -1.0]
        bp = BPJuna._bp_decode(m, code, metrics)
        scratch = BPJuna._bp_scratch(m, code)

        @test scratch.lch == [-4.0, 2.0, 1.0]
        @test scratch.r[1] ≈ [BP_ALPHA, -BP_ALPHA, -2 * BP_ALPHA] atol=1e-12
        @test scratch.q[1] ≈ scratch.lch atol=1e-12
        @test scratch.lpost ≈ [-3.2, 1.2, -0.6] atol=1e-12
        @test bp.lpost_metric ≈ [3.2, -1.2, 0.6] atol=1e-12
        @test (bp.lpost_metric .> 0) == Bool[true, false, true]
        assert_bp_result_contract(code, bp)
    end

    @testset "exact sum-product check update matches the paper atanh expression" begin
        incoming = [-4.0, 2.0, 1.0]
        outgoing = zeros(3)
        BPJuna._bp_check_sum_product!(outgoing, incoming)
        expected = Float64[
            2atanh(prod(tanh(incoming[b] / 2) for b in eachindex(incoming) if b != a))
            for a in eachindex(incoming)
        ]

        @test outgoing ≈ expected atol=1e-14
        @test all(isfinite, outgoing)

        forced = zeros(1)
        BPJuna._bp_check_sum_product!(forced, [3.0])
        @test forced == [BP_INNER_CLAMP]

        m = BPJuna.Modulation(inner_pilot_ratio = 0.0)
        code = bp_toy_code(Bool[1 1 1])
        exact = BPJuna._bp_decode_sum_product(m, code, [4.0, -2.0, -1.0])
        scratch = BPJuna._bp_scratch(m, code)
        @test scratch.r[1] ≈ expected atol=1e-14
        assert_bp_result_contract(code, exact)
    end

    @testset "degree-one parity checks saturate to a finite forced-zero message" begin
        m = BPJuna.Modulation(inner_pilot_ratio = 0.0)
        code = bp_toy_code(Bool[1 0; 0 1]; method = "degree-one-toy")
        bp = BPJuna._bp_decode(m, code, [6.0, -6.0])
        scratch = BPJuna._bp_scratch(m, code)

        assert_bp_result_contract(code, bp)
        @test scratch.r[1] == [BP_INNER_CLAMP]
        @test scratch.r[2] == [BP_INNER_CLAMP]
        @test bp.valid
        @test all(bp.lpost_metric .< 0.0)
    end

    @testset "_apply_inner_clamps! overrides only known message-pilot positions" begin
        m = BPJuna.LiteModulation()
        code = BPJuna._code(m)
        lch = fill(0.5, code.n)
        returned = BPJuna._apply_inner_clamps!(m, code, lch)
        positions = bp_inner_positions(m, code)
        mparity = code.n - code.k
        expected_by_position = Dict(
            code.invperm[mparity + p] => bp_expected_inner_lch(code, p)
            for p in 1:code.k if (p - 1) % BPJuna._inner_pilot_spacing(m) == 0
        )
        untouched = setdiff(1:code.n, positions)

        @test returned === lch
        @test length(positions) == 170
        @test all(lch[pos] == expected_by_position[pos] for pos in positions)
        @test all(lch[pos] == 0.5 for pos in untouched)

        off = BPJuna.LiteModulation(inner_pilot_ratio = 0.0)
        no_clamp = collect(Float64, 1:code.n)
        before = copy(no_clamp)
        @test BPJuna._apply_inner_clamps!(off, code, no_clamp) === no_clamp
        @test no_clamp == before
    end

    @testset "_bp_decode returns valid posterior metrics for a clean LDPC codeword" begin
        f = bp_fixture()
        bp = BPJuna._bp_decode(f.m, f.code, f.metrics)
        scratch = BPJuna._bp_scratch(f.m, f.code)

        assert_bp_result_contract(f.code, bp)
        @test bp.valid
        @test bp.syndrome == 0
        @test (bp.lpost_metric .> 0) == f.codeword
        @test scratch.bits == f.codeword
        @test BPJuna._payload_from_metrics(f.m, f.code, bp.lpost_metric) == f.payload

        positions = bp_inner_positions(f.m, f.code)
        @test !isempty(positions)
        @test all(abs(scratch.lch[pos]) == BP_INNER_CLAMP for pos in positions)
        free_pos = first(setdiff(1:f.code.n, positions))
        @test scratch.lch[free_pos] == -f.metrics[free_pos]

        exact = BPJuna._bp_decode_sum_product(f.m, f.code, f.metrics)
        assert_bp_result_contract(f.code, exact)
        @test exact.valid
        @test (exact.lpost_metric .> 0) == f.codeword
    end

    @testset "modest corruptions correct, heavy corruptions report invalid syndrome" begin
        f = bp_fixture()

        modest = corrupt_first!(copy(f.metrics), f.codeword, 8)
        corrected = BPJuna._bp_decode(f.m, f.code, modest)
        assert_bp_result_contract(f.code, corrected)
        @test corrected.valid
        @test corrected.syndrome == 0
        @test (corrected.lpost_metric .> 0) == f.codeword

        heavy = corrupt_first!(copy(f.metrics), f.codeword, 32)
        failed = BPJuna._bp_decode(f.m, f.code, heavy)
        assert_bp_result_contract(f.code, failed)
        @test !failed.valid
        @test failed.syndrome > 0
        @test count((failed.lpost_metric .> 0) .!= f.codeword) > 0
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA LDPC belief propagation checks passed")
end
