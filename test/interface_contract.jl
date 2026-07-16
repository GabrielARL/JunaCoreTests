#!/usr/bin/env julia
#
# Interface contract — the end-to-end executable contract for every receiver path.
#
# Paper claims protected (papers/main.tex):
#   sec:method (lines 1919-1964)     OFDM+FEC, Partial-FFT+FEC, and JUNA share one
#                                    transmitted frame and one public boundary; only
#                                    receiver processing differs. Here: the default,
#                                    Lite, and Full modulations all satisfy the same
#                                    contract on the same 170-bit / 1280-sample frame.
#   acceptance rule (1928-1932,      Acceptance is payload-exact recovery. The
#   tab:hyperparams line 2029)       noiseless loopback below applies exactly that
#                                    rule: every payload bit recovered, bit for bit.
#   eq:goodput (1934-1939)           payload_rate(128 bits) == 128*24000/1280 == 2400 bit/s.
#   sec:solver (843)                 :lite runs JUNA-lite (ssec:junalite, 1522), :full
#                                    runs JUNA-Wz (ssec:gradient-juna, 1622); both must
#                                    survive the full modulate->demodulate path.
#   eq:juna-total /                  The constrained band-tied C,W,z receiver must declare
#   eq:gradient-rescue               :coupled_cwz and execute its real adapter, initializer,
#                                    analytic-gradient optimizer, and candidate conversion.
#
# The noiseless loopback runs UNCONDITIONALLY (it is deterministic and cheap).
# Set JUNA_INTERFACE_ROUNDTRIP=1 (or `test/runtests.jl roundtrip`) to additionally
# run the extended multi-block loopback on every receiver.
#
# If this fails: a receiver path crashed, produced non-finite metrics, or can no
# longer decode its own clean transmission — nothing downstream is trustworthy.
#
# Run alone:  julia --project=. test/interface_contract.jl
# Strict:     JUNA_INTERFACE_ROUNDTRIP=1 julia --project=. test/interface_contract.jl
# Via runner: julia --project=. test/runtests.jl contract   (or: roundtrip)

using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const Modulations = JunaCore.Modulations
const Juna = JunaCore.Juna

const ROOT = get(ENV, "JUNA_CORE_ROOT",
    normpath(joinpath(dirname(pathof(JunaCore)), "..")))
const FC = 24_000.0
const FS = 24_000.0

# A non-JUNA modem proves that refinement is an optional capability of the
# shared interface, not a requirement silently imposed on every modulation.
struct InterfaceOnlyModulation <: Modulations.Modulation end
Modulations.init(::InterfaceOnlyModulation, fc, fs) = nothing
Modulations.bitspersymbol(::InterfaceOnlyModulation) = 1
Modulations.signallength(::InterfaceOnlyModulation, nbits, fc, fs) = Int(nbits)
Modulations.modulate(::InterfaceOnlyModulation, bits, fc, fs) =
    ComplexF64[bit ? -1.0 : 1.0 for bit in bits]
Modulations.demodulate(::InterfaceOnlyModulation, nbits, x, fc, fs) =
    (Float64[real(x[i]) < 0 ? 1.0 : -1.0 for i in 1:Int(nbits)], 0.0)
Base.isvalid(::InterfaceOnlyModulation, fc, fs) = true

function assert_ldpc_tools_present()
    # LDPC.build shells out to these vendored binaries; _tool() would silently fall
    # back to bare names on PATH, so their presence must be pinned here.
    for tool in ("make-ldpc", "make-gen", "print-pchk")
        path = joinpath(ROOT, "tools", "ldpc", tool)
        @test isfile(path)
    end
end

function assert_receiver_profiles()
    standard = Juna.StandardModulation()
    pfft = Juna.PartialFFTModulation()
    lite = Juna.LiteModulation()
    full = Juna.FullModulation()
    coupled = Juna.CoupledModulation()
    frame_wide = Juna.FrameWideLDPCModulation()
    legacy_full = Juna.Modulation(mode = :robust)

    @test standard.mode === :standard
    @test pfft.mode === :pfft
    @test lite.mode === :lite
    @test full.mode === :full
    @test coupled.mode === :coupled
    @test frame_wide.mode === :frame_wide_ldpc
    @test legacy_full.mode === :robust
    @test JunaCore.JunaStandard.Modulation().mode === :standard
    @test JunaCore.JunaPartialFFT.Modulation().mode === :pfft
    @test JunaCore.JunaLite.Modulation().mode === :lite
    @test JunaCore.JunaFull.Modulation().mode === :full
    @test JunaCore.JunaCoupled.Modulation().mode === :coupled
    @test JunaCore.JunaFrameWideLDPC.Modulation().mode === :frame_wide_ldpc
    @test Juna.receiver_profile(standard) === :standard
    @test Juna.receiver_profile(pfft) === :pfft
    @test Juna.receiver_profile(lite) === :lite
    @test Juna.receiver_profile(full) === :full
    @test Juna.receiver_profile(coupled) === :coupled
    @test Juna.receiver_profile(frame_wide) === :frame_wide_ldpc
    @test Juna.receiver_profile(legacy_full) === :full
    # the baselines never refine, so BPSK stays legal for them (like Lite)
    @test isvalid(Juna.StandardModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680), FC, FS)
    @test isvalid(Juna.PartialFFTModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680), FC, FS)
    @test !isvalid(Juna.Modulation(mode = :unknown), FC, FS)
end

function assert_frame_wide_ldpc_contract(m)
    @test Juna.receiver_profile(m) === :frame_wide_ldpc
    @test isvalid(m, FC, FS)
    blocks = 2
    code = Juna._frame_code(m, blocks)
    @test (code.k, code.n) == (blocks * Int(m.ldpc_k), blocks * Int(m.ldpc_n))

    capacity = blocks * Modulations.bitspersymbol(m)
    payload = Bool[isodd(count_ones(19i + 11)) for i in 1:capacity]
    message = Juna._build_frame_message(m, code, payload, blocks)
    codeword = Juna._encode(code, message)
    @test Juna._syndrome_weight(code, codeword) == 0
end

# :pilot_band_ls is the ONLY objective the Partial-FFT baseline solves: the
# pilot-trained per-band ridge LS of eq:pfft-ls. Executable contract: the
# fitted branch weights must satisfy the ridge normal equations against an
# INDEPENDENT recomputation, and the resulting seed candidate must decode a
# clean block payload-exactly.
function assert_pilot_band_ls_objective_contract(m)
    @test Juna.receiver_profile(m) === :pfft
    @test isvalid(m, FC, FS)

    layout = Juna._layout(m, FS)
    code = Juna._code(m)
    bits = Bool[isodd(count_ones(31i + 5)) for i in 1:Modulations.bitspersymbol(m)]
    message = Juna._build_message(m, code, bits)
    codeword = Juna._encode(code, message)
    waveform = Juna._modulate_block(m, layout, codeword)
    yparts = Juna._branch_observations(m, waveform)

    P = Int(m.partial_fft_parts)
    weights = zeros(ComplexF64, P)
    A = zeros(ComplexF64, P, P)
    b = zeros(ComplexF64, P)
    positions = collect(eachindex(layout.pilot_idx))
    Juna._fit_branch_weights!(
        weights, A, b, m, yparts, layout.pilot_idx, layout.pilot_syms, positions)

    gram = zeros(ComplexF64, P, P)
    rhs = zeros(ComplexF64, P)
    for (row, k) in enumerate(layout.pilot_idx), p in 1:P
        rhs[p] += conj(yparts[p, k]) * layout.pilot_syms[row]
        for q in 1:P
            gram[p, q] += conj(yparts[p, k]) * yparts[q, k]
        end
    end
    for p in 1:P
        gram[p, p] += Juna._RIDGE
    end
    residual = gram * weights - rhs
    @test maximum(abs, residual) < 1e-8 * max(maximum(abs, rhs), 1.0)

    seed = Juna._seed_candidate(m, code, layout, yparts)
    @test seed.valid
    @test Juna._payload_from_metrics(m, code, seed.lpost_metric) == bits
end

function assert_coupled_cwz_objective_contract(m)
    @test Juna.receiver_profile(m) === :coupled
    @test Int(m.bpc) == 2
    @test isvalid(m, FC, FS)

    layout = Juna._layout(m, FS)
    code = Juna._code(m)
    bits = Bool[isodd(count_ones(29i + 7)) for i in 1:Modulations.bitspersymbol(m)]
    message = Juna._build_message(m, code, bits)
    codeword = Juna._encode(code, message)
    waveform = Juna._modulate_block(m, layout, codeword)
    yparts = Juna._branch_observations(m, waveform)
    seed = Juna._seed_candidate(m, code, layout, yparts)
    problem = Juna._coupled_problem_from_receiver(m, code, layout, yparts)
    initial = Juna._initial_coupled_state(m, code, layout, problem, seed)
    solved = Juna._coupled_wcz_solve(
        problem,
        initial;
        config = Juna._CoupledOptimizerConfig(steps = 1),
    )
    candidate = Juna._coupled_state_candidate(m, code, layout, problem, solved.state)

    @test isfinite(solved.initial_loss)
    @test isfinite(solved.best_loss)
    @test solved.best_loss <= solved.initial_loss
    @test all(isfinite, candidate.lpost_metric)
    @test Juna._payload_from_metrics(m, code, candidate.lpost_metric) == bits
end

function assert_reduced_wz_objective_contract(m)
    @test Juna.receiver_profile(m) === :full
    @test Int(m.bpc) == 2
    @test isvalid(m, FC, FS)

    layout = Juna._layout(m, FS)
    code = Juna._code(m)
    bits = Bool[isodd(count_ones(23i + 5)) for i in 1:Modulations.bitspersymbol(m)]
    message = Juna._build_message(m, code, bits)
    codeword = Juna._encode(code, message)

    equalized = zeros(ComplexF64, Int(m.nc))
    equalized[layout.pilot_idx] .= layout.pilot_syms
    ntones = Juna._ndata_tones(m, code.n)
    for tone in 1:ntones
        base = 2tone - 1
        xr = codeword[base] ? -1.0 : 1.0
        xi = base + 1 <= code.n && codeword[base + 1] ? -1.0 : 1.0
        equalized[layout.data_idx[tone]] = ComplexF64(xr, xi) / sqrt(2)
    end
    equalized[layout.data_idx[ntones+1:end]] .= one(ComplexF64)
    yparts = reshape(copy(equalized), 1, :)

    metrics = Float64[bit ? 6.0 : -6.0 for bit in codeword]
    W = Juna._initial_gradient_W(m, yparts, layout)
    z = -copy(metrics)
    W0 = copy(W)
    z0 = copy(z)
    confidence = Juna._posterior_confidence(m, z0)
    gW = similar(W)
    gz = zeros(Float64, length(z))
    scratch = Juna._GradientScratch(m, code)

    loss = Juna._wz_loss_and_grad!(
        m, code, layout, gW, gz, W, z, W0, z0, yparts,
        confidence, code.check_vars, scratch)

    @test isfinite(loss)
    @test loss > 0.0
    @test all(x -> isfinite(real(x)) && isfinite(imag(x)), gW)
    @test all(isfinite, gz)
    @test sum(abs2, gW) > 0.0
    @test sum(abs2, gz) > 0.0
end

function assert_declared_refinement_contract(m)
    capability = Modulations.refinement_objective(m)
    contracts = Dict{Symbol,Function}(
        :none => _ -> (@test true),
        :pilot_band_ls => assert_pilot_band_ls_objective_contract,
        :posterior_anchor_ls => receiver -> begin
            @test Juna.receiver_profile(receiver) === :lite
            @test isdefined(Juna, :_juna_step)
        end,
        :reduced_wz => assert_reduced_wz_objective_contract,
        :coupled_cwz => assert_coupled_cwz_objective_contract,
        :frame_wide_ldpc => assert_frame_wide_ldpc_contract,
    )

    @test capability isa Symbol
    @test haskey(contracts, capability)
    contracts[capability](m)
end

function assert_modulation_contract(m)
    @test m isa Modulations.Modulation
    @test hasmethod(Modulations.init, Tuple{typeof(m), Float64, Float64})
    @test hasmethod(Modulations.modulate, Tuple{typeof(m), Vector{Bool}, Float64, Float64})
    @test hasmethod(Modulations.demodulate, Tuple{typeof(m), Int, Vector{ComplexF64}, Float64, Float64})
    @test hasmethod(Modulations.bitspersymbol, Tuple{typeof(m)})
    @test hasmethod(Modulations.signallength, Tuple{typeof(m), Int, Float64, Float64})
    @test hasmethod(Base.isvalid, Tuple{typeof(m), Float64, Float64})
    @test hasmethod(Modulations.refinement_objective, Tuple{typeof(m)})

    @test Modulations.init(m, FC, FS) === nothing
    @test isvalid(m, FC, FS)

    # All receivers share the paper frame: 170 payload bits per 1280-sample block.
    @test Modulations.bitspersymbol(m) == 170

    nbits = 128                                        # sub-block payload, zero-padded
    @test Modulations.signallength(m, nbits, FC, FS) == 1280

    # eq:goodput accounting: 128 bits over one 1280-sample block at 24 kHz.
    @test Modulations.payload_rate(m, nbits, FC, FS) == 2400.0

    # Noiseless loopback with a non-trivial pattern; payload-exact acceptance, the
    # paper's PSR rule. An all-zeros payload would hide polarity/ordering bugs.
    bits = Vector{Bool}(isodd.(1:nbits))
    waveform = Modulations.modulate(m, bits, FC, FS)
    @test waveform isa Vector{ComplexF64}
    @test length(waveform) == 1280

    metrics, cfo = Modulations.demodulate(m, nbits, waveform, FC, FS)
    @test metrics isa Vector{Float64}
    @test length(metrics) == nbits
    @test all(isfinite, metrics)
    @test (metrics .> 0) == bits                       # payload-exact recovery
    @test cfo isa Float64
    @test cfo == 0.0                                   # sync disabled -> no CFO estimate
end

# Extended roundtrip: multiple blocks with an aperiodic pattern (Thue-Morse:
# parity of the bit count of the index), so the three blocks carry three DIFFERENT
# payloads — a receiver that swapped or repeated blocks would fail here.
function assert_extended_roundtrip(m)
    nbits = 2 * 170 + 17
    bits = Vector{Bool}([isodd(count_ones(p)) for p in 1:nbits])
    waveform = Modulations.modulate(m, bits, FC, FS)
    @test length(waveform) == Modulations.signallength(m, nbits, FC, FS)
    metrics, cfo = Modulations.demodulate(m, nbits, waveform, FC, FS)
    @test (metrics .> 0) == bits
    @test cfo == 0.0
end

@testset verbose = true "JUNA interface contract" begin
    @testset "LDPC helper binaries are vendored" begin
        assert_ldpc_tools_present()
    end

    @testset "receiver family includes per-symbol modes and :frame_wide_ldpc" begin
        assert_receiver_profiles()
    end

    @testset "shared receiver catalog covers every runtime profile" begin
        assert_public_receiver_catalog()
    end

    @testset "JunaCoupled facade exposes only its Modulations provider" begin
        facade = JunaCore.JunaCoupled
        @test names(facade; all=false, imported=false) == [:JunaCoupled, :Modulation]
        @test !isdefined(facade, :Juna)
        @test !isdefined(facade, :_coupled_wcz_solve)
        @test !isdefined(facade, :_coupled_objective_and_gradient!)

        provider = facade.Modulation()
        @test provider isa Modulations.Modulation
        @test Modulations.refinement_objective(provider) === :coupled_cwz
    end

    @testset "declared refinement capability matches an executable objective" begin
        providers = (
            ("unrelated interface implementation", InterfaceOnlyModulation()),
            ("Standard OFDM baseline", Juna.StandardModulation()),
            ("JunaStandard module", JunaCore.JunaStandard.Modulation()),
            ("Partial-FFT baseline", Juna.PartialFFTModulation()),
            ("JunaPartialFFT module", JunaCore.JunaPartialFFT.Modulation()),
            ("default JUNA-lite", Juna.Modulation()),
            ("JunaLite module", JunaCore.JunaLite.Modulation()),
            ("JUNA-Wz full", Juna.FullModulation(partial_fft_parts = 1)),
            ("JunaFull module", JunaCore.JunaFull.Modulation(partial_fft_parts = 1)),
            ("JUNA-WCz coupled", Juna.CoupledModulation(partial_fft_parts = 1)),
            ("JunaCoupled module", JunaCore.JunaCoupled.Modulation(partial_fft_parts = 1)),
            ("JUNA Frame-wide LDPC", Juna.FrameWideLDPCModulation()),
            ("JunaFrameWideLDPC module", JunaCore.JunaFrameWideLDPC.Modulation()),
            ("legacy robust alias", Juna.Modulation(mode = :robust, partial_fft_parts = 1)),
        )
        expected = (:none, :none, :none, :pilot_band_ls, :pilot_band_ls,
                    :posterior_anchor_ls, :posterior_anchor_ls,
                    :reduced_wz, :reduced_wz, :coupled_cwz, :coupled_cwz,
                    :frame_wide_ldpc, :frame_wide_ldpc,
                    :reduced_wz)

        for ((name, provider), objective) in zip(providers, expected)
            @testset "$name declares $objective" begin
                @test Modulations.refinement_objective(provider) === objective
                assert_declared_refinement_contract(provider)
            end
        end

        unsupported = Juna.FullModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680)
        @test Modulations.refinement_objective(unsupported) === :reduced_wz
        @test !isvalid(unsupported, FC, FS)
        unsupported_coupled = Juna.CoupledModulation(bpc = 1, ldpc_k = 170, ldpc_n = 680)
        @test Modulations.refinement_objective(unsupported_coupled) === :coupled_cwz
        @test !isvalid(unsupported_coupled, FC, FS)
    end

    @testset "default constructor remains the Lite public alias" begin
        assert_modulation_contract(Juna.Modulation())
    end

    for descriptor in public_receiver_descriptors()
        @testset "$(descriptor.name): interface + noiseless loopback decodes payload-exactly" begin
            assert_modulation_contract(public_receiver(descriptor))
        end
    end

    if get(ENV, "JUNA_INTERFACE_ROUNDTRIP", "0") == "1"
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name): extended multi-block loopback (357 bits, 3 blocks)" begin
                assert_extended_roundtrip(public_receiver(descriptor))
            end
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA interface contract passed")
end
