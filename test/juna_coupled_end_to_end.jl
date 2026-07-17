#!/usr/bin/env julia
#
# JUNA-WCz Step 10: final public evidence on clean multi-block data, controlled
# residual ICI plus seeded AWGN, coupled dispatch/seed improvement, and warmed
# execution.
#
# The impairment is a residual frequency offset of 0.08 subcarrier spacings:
# x[n] * exp(j*2*pi*0.08*n/N). It creates inter-carrier interference without
# invoking the optional sync/CFO correction, so the coupled receiver must work
# through its ordinary Partial-FFT, pilot, C/W/z, BP path.
#
# Run alone: julia --project=. test/juna_coupled_end_to_end.jl
# Via runner: julia --project=. test/runtests.jl coupled-e2e

using Random
using Test
using JunaCore

const CoupledE2EJuna = JunaCore.Juna
const CoupledE2EModulations = JunaCore.Modulations
const COUPLED_E2E_FC = 24_000.0
const COUPLED_E2E_FS = 24_000.0
const COUPLED_E2E_SEED = 20_260_713
const COUPLED_E2E_CFO_BINS = 0.08

coupled_e2e_payload(n::Integer) =
    Bool[isodd(count_ones(41i + 9)) for i in 1:Int(n)]

function coupled_e2e_impaired_waveform(m, bits, snr_db::Real)
    waveform = CoupledE2EModulations.modulate(
        m, bits, COUPLED_E2E_FC, COUPLED_E2E_FS,
    )
    sample = collect(0:length(waveform)-1)
    rotated = waveform .* exp.(
        2im * pi * COUPLED_E2E_CFO_BINS .* sample ./ Int(m.nc),
    )
    rng = Xoshiro(COUPLED_E2E_SEED)
    sigma = sqrt(10.0^(-Float64(snr_db) / 10) / 2)
    rotated .+ sigma .* (
        randn(rng, length(rotated)) .+ im .* randn(rng, length(rotated))
    )
end

function coupled_e2e_errors(m, bits, snr_db::Real)
    impaired = coupled_e2e_impaired_waveform(m, bits, snr_db)
    metrics, cfo = CoupledE2EModulations.demodulate(
        m, length(bits), impaired, COUPLED_E2E_FC, COUPLED_E2E_FS,
    )
    (; errors = count((metrics .> 0) .!= bits), metrics, cfo)
end

function coupled_e2e_candidates(m, bits, snr_db::Real)
    impaired = coupled_e2e_impaired_waveform(m, bits, snr_db)
    code = CoupledE2EJuna._code(m)
    layout = CoupledE2EJuna._layout(m, COUPLED_E2E_FS)
    yparts = CoupledE2EJuna._branch_observations(m, impaired)
    seed = CoupledE2EJuna._seed_candidate(m, code, layout, yparts)
    direct = CoupledE2EJuna._coupled_candidate(m, code, layout, yparts, seed)
    dispatched = CoupledE2EJuna._juna_candidate(m, code, layout, yparts, seed)
    (; impaired, code, layout, seed, direct, dispatched)
end

function coupled_e2e_candidate_errors(m, code, candidate, bits)
    decoded = CoupledE2EJuna._payload_from_metrics(m, code, candidate.lpost_metric)
    count(decoded .!= bits)
end

@testset verbose = true "JUNA-WCz public end-to-end behavior" begin
    @testset "clean three-block payload roundtrips exactly" begin
        m = CoupledE2EJuna.CoupledModulation()
        bits = coupled_e2e_payload(2 * 170 + 17)
        waveform = CoupledE2EModulations.modulate(
            m, bits, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )
        metrics, cfo = CoupledE2EModulations.demodulate(
            m, length(bits), waveform, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )

        @test length(waveform) == 3 * (1024 + 256)
        @test length(metrics) == length(bits)
        @test all(isfinite, metrics)
        @test (metrics .> 0) == bits
        @test cfo == 0.0
    end

    @testset "residual ICI plus seeded AWGN has a real waterfall" begin
        m = CoupledE2EJuna.CoupledModulation()
        bits = coupled_e2e_payload(CoupledE2EModulations.bitspersymbol(m))
        high = coupled_e2e_errors(m, bits, 12.0)
        edge = coupled_e2e_errors(m, bits, 1.5)
        floor = coupled_e2e_errors(m, bits, 0.0)

        @test high.errors == 0
        @test edge.errors < length(bits) ÷ 2
        @test floor.errors >= edge.errors
        @test all(isfinite, high.metrics)
        @test high.cfo == edge.cfo == floor.cfo == 0.0
    end

    @testset "public coupled dispatch improves its mismatched 0 dB seed" begin
        m = CoupledE2EJuna.CoupledModulation()
        lite = CoupledE2EJuna.LiteModulation()
        bits = coupled_e2e_payload(CoupledE2EModulations.bitspersymbol(m))
        f = coupled_e2e_candidates(m, bits, 0.0)

        public_metrics, cfo = CoupledE2EModulations.demodulate(
            m, length(bits), f.impaired, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )
        lite_metrics, _ = CoupledE2EModulations.demodulate(
            lite, length(bits), f.impaired, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )
        seed_errors = coupled_e2e_candidate_errors(m, f.code, f.seed, bits)
        direct_errors = coupled_e2e_candidate_errors(m, f.code, f.direct, bits)
        dispatched_errors = coupled_e2e_candidate_errors(
            m, f.code, f.dispatched, bits,
        )
        public_errors = count((public_metrics .> 0) .!= bits)

        @test CoupledE2EJuna._juna_better(f.seed, f.direct)
        @test f.dispatched.lpost_metric == f.direct.lpost_metric
        @test f.dispatched.syndrome < f.seed.syndrome
        @test seed_errors > 0
        @test direct_errors < seed_errors
        @test dispatched_errors == direct_errors
        @test public_errors == dispatched_errors
        @test public_metrics != lite_metrics
        @test cfo == 0.0
    end

    @testset "proxy-selected candidate has a bounded truth-error tradeoff" begin
        m = CoupledE2EJuna.CoupledModulation()
        bits = coupled_e2e_payload(CoupledE2EModulations.bitspersymbol(m))
        f = coupled_e2e_candidates(m, bits, 1.5)
        seed_errors = coupled_e2e_candidate_errors(m, f.code, f.seed, bits)
        selected_errors = coupled_e2e_candidate_errors(
            m, f.code, f.dispatched, bits,
        )

        @test CoupledE2EJuna._juna_better(f.seed, f.direct)
        @test f.dispatched.syndrome < f.seed.syndrome
        @test selected_errors <= seed_errors + 4
        @test selected_errors < length(bits) ÷ 2
        seed_syndrome = f.seed.syndrome
        selected_syndrome = f.dispatched.syndrome
        @info "JUNA-WCz proxy/truth tradeoff" seed_syndrome selected_syndrome seed_errors selected_errors
    end

    @testset "valid 3 dB seed is retained" begin
        m = CoupledE2EJuna.CoupledModulation()
        bits = coupled_e2e_payload(CoupledE2EModulations.bitspersymbol(m))
        f = coupled_e2e_candidates(m, bits, 3.0)

        @test f.seed.valid
        @test f.seed.syndrome == 0
        @test coupled_e2e_candidate_errors(m, f.code, f.seed, bits) == 0
        @test f.dispatched.lpost_metric == f.seed.lpost_metric
    end

    @testset "warmed one-block decode remains correct" begin
        m = CoupledE2EJuna.CoupledModulation()
        bits = coupled_e2e_payload(CoupledE2EModulations.bitspersymbol(m))
        impaired = coupled_e2e_impaired_waveform(m, bits, 12.0)

        # Warm compilation and LDPC/layout caches before measuring runtime.
        CoupledE2EModulations.demodulate(
            m, length(bits), impaired, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )
        elapsed = @elapsed metrics, _ = CoupledE2EModulations.demodulate(
            m, length(bits), impaired, COUPLED_E2E_FC, COUPLED_E2E_FS,
        )

        @test (metrics .> 0) == bits
        @info "JUNA-WCz warmed one-block decode" seconds = elapsed
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA-WCz public end-to-end checks passed")
end
