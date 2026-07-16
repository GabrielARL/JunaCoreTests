#!/usr/bin/env julia
#
# Candidate demodulation - equalized carriers to soft metrics and candidate fields.
#
# Paper claims protected (papers/main.tex):
#   sec:solver (843)                  Candidate construction bridges pilot
#                                     equalization and LDPC/BP feedback.
#   eq:candidate-score                Candidate selection uses pilot residual,
#                                     posterior tie, syndrome, and posterior
#                                     confidence terms.
#   sec:method (1919-1964)            Positive output metrics represent bit 1
#                                     at the public demodulation boundary.
#
# If this fails: equalized QPSK carriers may be converted to the wrong soft-bit
# polarity, candidate score fields may no longer be finite/consistent, or clean
# candidates may stop preserving payload bits before JUNA refinement begins.
#
# Run alone:  julia --project=. test/candidate_demodulation.jl
# Via runner: julia --project=. test/runtests.jl candidate

using Test
using JunaCore

const CandidateJuna = JunaCore.Juna
const CandidateModulations = JunaCore.Modulations
const CANDIDATE_FS = 24_000.0
const CANDIDATE_LLR_CLIP = 20.0
const CANDIDATE_BETA_FLOOR = 0.02

candidate_payload_pattern(n::Integer) =
    Bool[isodd(count_ones(11i + 3)) for i in 1:n]

candidate_pm(bit::Bool) = bit ? -1.0 : 1.0

function candidate_qpsk_symbol(codeword::AbstractVector{Bool}, tone::Integer)
    j = 2 * (Int(tone) - 1) + 1
    bI = codeword[j]
    bQ = j + 1 <= length(codeword) ? codeword[j + 1] : false
    ComplexF64(candidate_pm(bI), candidate_pm(bQ)) / sqrt(2)
end

function candidate_fixture()
    m = CandidateJuna.LiteModulation()
    layout = CandidateJuna._layout(m, CANDIDATE_FS)
    code = CandidateJuna._code(m)
    bits = candidate_payload_pattern(CandidateModulations.bitspersymbol(m))
    message = CandidateJuna._build_message(m, code, bits)
    codeword = CandidateJuna._encode(code, message)
    equalized = zeros(ComplexF64, Int(m.nc))
    equalized[layout.pilot_idx] .= layout.pilot_syms
    ntones = CandidateJuna._ndata_tones(m, code.n)
    for t in 1:ntones
        equalized[layout.data_idx[t]] = candidate_qpsk_symbol(codeword, t)
    end
    for t in ntones+1:length(layout.data_idx)
        equalized[layout.data_idx[t]] = one(ComplexF64)
    end
    (m = m, layout = layout, code = code, bits = bits,
     codeword = codeword, equalized = equalized)
end

function local_pilot_mse(layout, equalized)
    isempty(layout.pilot_idx) && return 0.0
    pilot_sum = 0.0
    for i in eachindex(layout.pilot_idx)
        pilot_sum += abs2(equalized[layout.pilot_idx[i]] - layout.pilot_syms[i])
    end
    pilot_sum / length(layout.pilot_idx)
end

function local_candidate_metrics(m, code, layout, equalized)
    pilot_mse = local_pilot_mse(layout, equalized)
    beta = max(pilot_mse, CANDIDATE_BETA_FLOOR)
    metrics = Vector{Float64}(undef, code.n)
    ntones = CandidateJuna._ndata_tones(m, code.n)
    for t in 1:ntones
        s = equalized[layout.data_idx[t]]
        metrics[2t - 1] = clamp((-2.0 * real(s)) / beta, -CANDIDATE_LLR_CLIP, CANDIDATE_LLR_CLIP)
        2t <= code.n && (metrics[2t] = clamp((-2.0 * imag(s)) / beta, -CANDIDATE_LLR_CLIP, CANDIDATE_LLR_CLIP))
    end
    metrics, pilot_mse
end

function local_candidate_score(candidate, code)
    syndrome_norm = candidate.syndrome / max(size(code.H, 1), 1)
    candidate.pilot_mse + 0.25 * candidate.tie_mse +
        0.05 * syndrome_norm - 1e-4 * candidate.mean_abs_lpost
end

function assert_candidate_contract(m, code, bits, codeword, candidate)
    @test keys(candidate) == (:lpost_metric, :valid, :syndrome, :mean_abs_lpost,
                              :pilot_mse, :tie_mse, :score)
    @test candidate.lpost_metric isa Vector{Float64}
    @test length(candidate.lpost_metric) == code.n
    @test all(isfinite, candidate.lpost_metric)
    @test all(isfinite, (candidate.mean_abs_lpost, candidate.pilot_mse,
                         candidate.tie_mse, candidate.score))
    @test candidate.valid
    @test candidate.syndrome == 0
    @test (candidate.lpost_metric .> 0) == codeword
    @test CandidateJuna._payload_from_metrics(m, code, candidate.lpost_metric) == bits
    @test candidate.score ≈ local_candidate_score(candidate, code) atol=1e-12
end

@testset verbose = true "JUNA candidate demodulation" begin
    @testset "_candidate_from_equalized uses QPSK soft-metric polarity and clipping" begin
        f = candidate_fixture()
        metrics, pilot_mse = local_candidate_metrics(f.m, f.code, f.layout, f.equalized)
        candidate = CandidateJuna._candidate_from_equalized(f.m, f.code, f.layout, f.equalized)
        explicit = CandidateJuna._decode_candidate(f.m, f.code, f.layout, f.equalized, metrics, pilot_mse)

        @test pilot_mse == 0.0
        @test Set(metrics) == Set([-CANDIDATE_LLR_CLIP, CANDIDATE_LLR_CLIP])
        @test (metrics .> 0) == f.codeword
        @test candidate.lpost_metric == explicit.lpost_metric
        @test candidate == explicit
        @test candidate.pilot_mse == 0.0
        @test candidate.tie_mse < 1e-24
        assert_candidate_contract(f.m, f.code, f.bits, f.codeword, candidate)
    end

    @testset "_decode_candidate accepts explicit softer metrics and returns finite score fields" begin
        f = candidate_fixture()
        metrics = Float64[bit ? 4.0 : -4.0 for bit in f.codeword]
        candidate = CandidateJuna._decode_candidate(f.m, f.code, f.layout, f.equalized, metrics, 0.0)

        @test (metrics .> 0) == f.codeword
        @test candidate.mean_abs_lpost > 0
        @test candidate.mean_abs_lpost < 25
        @test candidate.tie_mse < 1e-9
        assert_candidate_contract(f.m, f.code, f.bits, f.codeword, candidate)
    end

    @testset "pilot residuals flow into pilot_mse and candidate score" begin
        f = candidate_fixture()
        clean = CandidateJuna._candidate_from_equalized(f.m, f.code, f.layout, f.equalized)
        noisy = copy(f.equalized)
        pilot_offset = 0.3 + 0.1im
        noisy[f.layout.pilot_idx] .+= pilot_offset
        metrics, pilot_mse = local_candidate_metrics(f.m, f.code, f.layout, noisy)
        candidate = CandidateJuna._candidate_from_equalized(f.m, f.code, f.layout, noisy)
        explicit = CandidateJuna._decode_candidate(f.m, f.code, f.layout, noisy, metrics, pilot_mse)

        @test pilot_mse ≈ abs2(pilot_offset) atol=2e-15
        @test candidate == explicit
        @test candidate.pilot_mse ≈ abs2(pilot_offset) atol=2e-15
        @test candidate.score > clean.score
        assert_candidate_contract(f.m, f.code, f.bits, f.codeword, candidate)
    end

    @testset "posterior tie term increases when equalized data leaves its anchor" begin
        f = candidate_fixture()
        metrics = Float64[bit ? 4.0 : -4.0 for bit in f.codeword]
        base = CandidateJuna._decode_candidate(f.m, f.code, f.layout, f.equalized, metrics, 0.0)
        drifted = copy(f.equalized)
        drifted[f.layout.data_idx[17]] += 0.2 - 0.1im
        candidate = CandidateJuna._decode_candidate(f.m, f.code, f.layout, drifted, metrics, 0.0)

        @test candidate.tie_mse > base.tie_mse + 1e-5
        @test candidate.score > base.score
        assert_candidate_contract(f.m, f.code, f.bits, f.codeword, candidate)
    end

    @testset "posterior tie MSE uses the paper confidence weights and floor" begin
        for m in (
            CandidateJuna.LiteModulation(),
            CandidateJuna.LiteModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680),
        )
            layout = CandidateJuna._layout(m, CANDIDATE_FS)
            metrics = Int(m.bpc) == 2 ? [0.0, 0.0, 6.0, 6.0] : [0.0, 6.0]
            anchors = CandidateJuna._posterior_symbols(m, metrics)
            confidence = CandidateJuna._posterior_confidence(m, metrics)
            equalized = zeros(ComplexF64, Int(m.nc))
            equalized[layout.data_idx[1]] = anchors[1] + 2.0
            equalized[layout.data_idx[2]] = anchors[2] + 1.0
            weights = max.(confidence, 1e-3)
            expected = (4weights[1] + weights[2]) / sum(weights)
            actual = CandidateJuna._posterior_tie_mse(m, equalized, layout, metrics)

            @test weights[1] == 1e-3
            @test weights[2] > 0.99
            @test actual ≈ expected atol=1e-14
            @test abs(actual - 2.5) > 1.0
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA candidate demodulation checks passed")
end
