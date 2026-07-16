#!/usr/bin/env julia
#
# Frame-wide LDPC receiver -- one Tanner graph spans every OFDM block in the
# requested frame while all existing receivers retain per-symbol LDPC.
#
# This is an implementation-derived extension, not yet a claim in main.tex.
# It protects the FEC-scope distinction exposed by the ReplayCh SG-1 ablation:
# the carrier geometry remains block based, but encoding and BP decoding happen
# once over the complete frame.
#
# Run alone: julia --project=. test/frame_wide_ldpc.jl

using Test
using JunaCore
using LinearAlgebra

const FrameWideJuna = JunaCore.Juna
const FrameWideModulations = JunaCore.Modulations
const FRAME_WIDE_FC = 24_000.0
const FRAME_WIDE_FS = 24_000.0

function frame_observations(receiver, waveform, blocks)
    block_length = Int(receiver.nc) + Int(receiver.np)
    observations = Array{ComplexF64}(
        undef, receiver.partial_fft_parts, Int(receiver.nc), blocks)
    for block in 1:blocks
        lo = 1 + (block - 1) * block_length
        hi = block * block_length
        observations[:, :, block] .= FrameWideJuna._branch_observations(
            receiver, @view waveform[lo:hi])
    end
    observations
end

function compact_receiver(factory)
    factory(
        nc = 128,
        np = 32,
        ldpc_k = 24,
        ldpc_n = 48,
        ldpc_npc = 2,
        partial_fft_parts = 1,
        partial_fft_nbands = 4,
        pilot_ratio = 1 / 4,
        inner_pilot_ratio = 1 / 3,
    )
end

function compact_frame_receiver(profile)
    FrameWideJuna.FrameWideLDPCModulation(
        frame_receiver = profile,
        nc = 128,
        np = 32,
        ldpc_k = 24,
        ldpc_n = 48,
        ldpc_npc = 2,
        partial_fft_parts = 1,
        partial_fft_nbands = 4,
        pilot_ratio = 1 / 4,
        inner_pilot_ratio = 1 / 3,
    )
end

@testset verbose = true "JUNA frame-wide LDPC receiver" begin
    @testset "band RLS carries weights and inverse covariance across symbols" begin
        weights = zeros(ComplexF64, 2)
        inverse_covariance = Matrix{ComplexF64}(I, 2, 2)

        FrameWideJuna._frame_rls_update!(
            weights, inverse_covariance, ComplexF64[1, 0], 1 + 0im;
            forgetting=1.0,
        )
        @test weights ≈ ComplexF64[0.5, 0.0] atol=1e-14
        @test inverse_covariance ≈ ComplexF64[0.5 0; 0 1] atol=1e-14

        FrameWideJuna._frame_rls_update!(
            weights, inverse_covariance, ComplexF64[0, 1], 2 + 0im;
            forgetting=1.0,
        )
        @test weights ≈ ComplexF64[0.5, 1.0] atol=1e-14
        @test inverse_covariance ≈ ComplexF64[0.5 0; 0 0.5] atol=1e-14
        @test_throws ArgumentError FrameWideJuna._frame_rls_update!(
            weights, inverse_covariance, ComplexF64[1, 0], 1 + 0im;
            forgetting=0.0,
        )
    end

    @testset "stateful frame equalizer and posterior anchors span OFDM blocks" begin
        receiver = FrameWideJuna.FrameWideLDPCModulation(
            nc=128,
            np=32,
            ldpc_k=24,
            ldpc_n=48,
            ldpc_npc=2,
            partial_fft_parts=2,
            partial_fft_nbands=2,
            compatibility_profile=:rpchan,
            pilot_ratio=1 / 4,
            inner_pilot_ratio=1 / 3,
        )
        blocks = 3
        payload = Bool[isodd(i) for i in
                       1:FrameWideJuna._frame_payload_capacity(receiver, blocks)]
        waveform = FrameWideModulations.modulate(
            receiver, payload, FRAME_WIDE_FC, FRAME_WIDE_FS)
        layout = FrameWideJuna._layout(receiver, FRAME_WIDE_FS)
        observations = frame_observations(receiver, waveform, blocks)

        seed = FrameWideJuna._frame_stateful_band_rls(
            receiver, layout, observations)
        reset_last = FrameWideJuna._frame_stateful_band_rls(
            receiver, layout, @view observations[:, :, blocks:blocks])
        @test size(seed.equalized) == (Int(receiver.nc), blocks)
        @test size(seed.weights) ==
              (receiver.partial_fft_parts, receiver.partial_fft_nbands, blocks)
        @test seed.weights[:, :, blocks] != reset_last.weights[:, :, 1]
        @test all(isfinite, seed.equalized)
        @test seed.data_anchor_counts == zeros(Int, blocks)

        code = FrameWideJuna._frame_code(receiver, blocks)
        posterior = fill(3.0, code.n)
        refined = FrameWideJuna._frame_stateful_band_rls(
            receiver, layout, observations; posterior_metrics=posterior)
        @test all(>(0), refined.data_anchor_counts)
        @test all(<=(length(layout.data_idx)), refined.data_anchor_counts)
        @test all(isfinite, refined.equalized)
        @test refined.equalized != seed.equalized
    end

    @testset "frame JUNA keeps the best global-code candidate" begin
        receiver = FrameWideJuna.FrameWideLDPCModulation(
            nc=128,
            np=32,
            ldpc_k=24,
            ldpc_n=48,
            ldpc_npc=2,
            partial_fft_parts=2,
            partial_fft_nbands=2,
            compatibility_profile=:rpchan,
            pilot_ratio=1 / 4,
            inner_pilot_ratio=1 / 3,
        )
        blocks = 3
        payload = Bool[isodd(i) for i in
                       1:FrameWideJuna._frame_payload_capacity(receiver, blocks)]
        waveform = FrameWideModulations.modulate(
            receiver, payload, FRAME_WIDE_FC, FRAME_WIDE_FS)
        layout = FrameWideJuna._layout(receiver, FRAME_WIDE_FS)
        code = FrameWideJuna._frame_code(receiver, blocks)
        observations = frame_observations(receiver, waveform, blocks)
        trace = FrameWideJuna._frame_juna_refine(
            receiver, code, layout, observations)

        @test trace.seed.valid
        @test trace.best.valid
        @test trace.selected_iteration == 0
        @test trace.best.score == trace.seed.score
        @test trace.best.lpost_metric == trace.seed.lpost_metric
    end

    @testset "public constructor and facade select only the frame-wide profile" begin
        receiver = FrameWideJuna.FrameWideLDPCModulation()
        facade = JunaCore.JunaFrameWideLDPC

        @test receiver.mode === :frame_wide_ldpc
        @test FrameWideJuna.receiver_profile(receiver) === :frame_wide_ldpc
        @test FrameWideModulations.refinement_objective(receiver) === :frame_wide_ldpc
        @test facade.Modulation().mode === :frame_wide_ldpc
        @test names(facade; all=false, imported=false) ==
              [:JunaFrameWideLDPC, :Modulation]
    end

    @testset "five receiver algorithms use one true frame-wide LDPC graph" begin
        profiles = (:standard, :pfft, :lite, :full, :coupled)
        blocks = 3
        payload = Bool[
            isodd(count_ones(31i + 7))
            for i in 1:FrameWideJuna._frame_payload_capacity(
                compact_frame_receiver(:standard), blocks)
        ]

        for profile in profiles
            @testset "$profile frame decoder" begin
                receiver = compact_frame_receiver(profile)
                @test receiver.frame_receiver === profile
                @test FrameWideJuna._frame_receiver_profile(receiver) === profile
                @test isvalid(receiver, FRAME_WIDE_FC, FRAME_WIDE_FS)

                waveform = FrameWideModulations.modulate(
                    receiver, payload, FRAME_WIDE_FC, FRAME_WIDE_FS)
                layout = FrameWideJuna._layout(receiver, FRAME_WIDE_FS)
                code = FrameWideJuna._frame_code(receiver, blocks)
                observations = frame_observations(receiver, waveform, blocks)
                trace = FrameWideJuna._frame_receiver_trace(
                    receiver, code, layout, observations)
                metrics, cfo = FrameWideModulations.demodulate(
                    receiver, length(payload), waveform,
                    FRAME_WIDE_FC, FRAME_WIDE_FS)

                @test trace.profile === profile
                @test trace.best.valid
                @test trace.best.syndrome == 0
                @test (code.k, code.n) == (blocks * 24, blocks * 48)
                @test any(code.check_vars) do variables
                    length(unique(cld(variable, 48) for variable in variables)) > 1
                end
                @test (metrics .> 0) == payload
                @test cfo == 0.0
            end
        end

        @test !isvalid(
            compact_frame_receiver(:unknown),
            FRAME_WIDE_FC,
            FRAME_WIDE_FS,
        )
        @test !isvalid(
            FrameWideJuna.FrameWideLDPCModulation(
                frame_receiver=:full,
                bpc=1,
                nc=128,
                np=32,
                ldpc_k=24,
                ldpc_n=48,
                ldpc_npc=2,
                partial_fft_parts=1,
                partial_fft_nbands=4,
                pilot_ratio=1 / 4,
                inner_pilot_ratio=1 / 3,
            ),
            FRAME_WIDE_FC,
            FRAME_WIDE_FS,
        )
    end

    @testset "default frame code stays sparse as frame dimensions grow" begin
        receiver = compact_frame_receiver(:standard)
        blocks = 10
        code = FrameWideJuna._frame_code(receiver, blocks)
        message = Bool[isodd(count_ones(17i + 5)) for i in 1:code.k]
        codeword = FrameWideJuna._encode(code, message)

        @test code.method == "frame_sparse"
        @test code.H isa BitMatrix
        @test count(code.gen) == code.k * receiver.ldpc_npc
        @test sum(length, code.check_vars) ==
              code.k * receiver.ldpc_npc + (code.n - code.k)
        @test codeword[1:code.k] == message
        @test all(iszero, mod.(Int.(code.H) * Int.(codeword), 2))
        @test any(code.check_vars) do variables
            length(unique(cld(variable, Int(receiver.ldpc_n))
                          for variable in variables)) > 1
        end
    end

    @testset "three OFDM blocks share one LDPC codeword and one parity graph" begin
        receiver = compact_receiver(FrameWideJuna.FrameWideLDPCModulation)
        blocks = 3
        payload_capacity = blocks * FrameWideModulations.bitspersymbol(receiver)
        payload = Bool[isodd(count_ones(17i + 3)) for i in 1:payload_capacity-5]

        @test isvalid(receiver, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test FrameWideModulations.bitspersymbol(receiver) == 16
        @test FrameWideJuna._nblocks(receiver, length(payload)) == blocks

        code = FrameWideJuna._frame_code(receiver, blocks)
        @test (code.k, code.n) == (blocks * 24, blocks * 48)
        @test any(code.check_vars) do variables
            length(unique(cld(variable, 48) for variable in variables)) > 1
        end

        padded = vcat(payload, falses(payload_capacity - length(payload)))
        message = FrameWideJuna._build_frame_message(receiver, code, padded, blocks)
        codeword = FrameWideJuna._encode(code, message)
        @test length(message) == blocks * 24
        @test length(codeword) == blocks * 48
        @test FrameWideJuna._syndrome_weight(code, codeword) == 0
        for p in 1:3:code.k
            @test message[p] == FrameWideJuna._frame_inner_bit(receiver, p)
        end

        waveform = FrameWideModulations.modulate(
            receiver, payload, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test length(waveform) == blocks * (128 + 32)

        metrics, cfo = FrameWideModulations.demodulate(
            receiver, length(payload), waveform, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test (metrics .> 0) == payload
        @test cfo == 0.0
    end

    @testset "frame-wide inner pilots and payload capacity span block boundaries" begin
        receiver = FrameWideJuna.FrameWideLDPCModulation(
            nc = 128,
            np = 32,
            ldpc_k = 24,
            ldpc_n = 48,
            ldpc_npc = 2,
            partial_fft_parts = 1,
            partial_fft_nbands = 4,
            pilot_ratio = 1 / 4,
            inner_pilot_ratio = 1 / 7,
        )
        blocks = 3

        # Per-block framing would expose only 3 * (24 - ceil(24/7)) = 60 bits.
        # One frame-wide comb has ceil(72/7) = 11 pilots and therefore 61 bits.
        @test FrameWideModulations.bitspersymbol(receiver) == 20
        @test FrameWideJuna._frame_payload_capacity(receiver, blocks) == 61
        @test FrameWideJuna._frame_nblocks(receiver, 61) == blocks

        code = FrameWideJuna._frame_code(receiver, blocks)
        payload = Bool[isodd(i) for i in 1:61]
        message = FrameWideJuna._build_frame_message(receiver, code, payload, blocks)
        inner_positions = collect(1:7:code.k)
        @test length(inner_positions) == 11
        @test all(p -> message[p] == FrameWideJuna._frame_inner_bit(receiver, p),
                  inner_positions)

        waveform = FrameWideModulations.modulate(
            receiver, payload, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test length(waveform) == blocks * (128 + 32)
        metrics, _ = FrameWideModulations.demodulate(
            receiver, length(payload), waveform, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test (metrics .> 0) == payload
    end

    @testset "Rpchan compatibility profile reproduces its carrier and pilot order" begin
        receiver = FrameWideJuna.FrameWideLDPCModulation(
            nc = 128,
            np = 16,
            ldpc_k = 47,
            ldpc_n = 94,
            ldpc_npc = 6,
            partial_fft_parts = 1,
            partial_fft_nbands = 2,
            pilot_ratio = 1 / 4,
            inner_pilot_ratio = 1 / 5,
            compatibility_profile = :rpchan,
            ldpc_seed = 51_001,
        )
        layout = FrameWideJuna._layout(receiver, FRAME_WIDE_FS)
        code = FrameWideJuna._frame_code(receiver, 3)
        expected_active = vcat(collect(66:128), collect(2:64))

        @test layout.active == expected_active
        @test layout.pilot_idx == expected_active[1:4:end]
        @test all(==(ComplexF64(1, 1) / sqrt(2)), layout.pilot_syms)
        @test length(layout.active) == 126       # excludes DC and Nyquist
        @test length(layout.data_idx) == 94
        @test all(column -> count(@view code.H[:, column]) == receiver.ldpc_npc,
                  1:code.k)
        message = Bool[isodd(count_ones(19i + 3)) for i in 1:code.k]
        codeword = FrameWideJuna._encode(code, message)
        @test codeword[1:code.k] == message
        @test all(iszero, mod.(Int.(code.H) * Int.(codeword), 2))
        @test FrameWideJuna._frame_inner_bit(receiver, 1) === false
        @test FrameWideJuna._frame_inner_bit(receiver, 6) === true
        @test !isvalid(FrameWideJuna.FrameWideLDPCModulation(
            compatibility_profile = :unknown), FRAME_WIDE_FC, FRAME_WIDE_FS)
    end

    @testset "existing Lite remains per-symbol and malformed frames fail loudly" begin
        lite = compact_receiver(FrameWideJuna.LiteModulation)
        frame_wide = compact_receiver(FrameWideJuna.FrameWideLDPCModulation)
        nbits = 2 * FrameWideModulations.bitspersymbol(lite) + 1
        bits = Bool[isodd(i) for i in 1:nbits]

        lite_waveform = FrameWideModulations.modulate(
            lite, bits, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test (lite.code.k, lite.code.n) == (24, 48)

        frame_waveform = FrameWideModulations.modulate(
            frame_wide, bits, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test (frame_wide.code.k, frame_wide.code.n) == (3 * 24, 3 * 48)
        @test frame_wide.code !== lite.code

        @test_throws ArgumentError FrameWideModulations.demodulate(
            frame_wide,
            nbits,
            @view(frame_waveform[1:end-1]),
            FRAME_WIDE_FC,
            FRAME_WIDE_FS,
        )

        lite_metrics, _ = FrameWideModulations.demodulate(
            lite, nbits, lite_waveform, FRAME_WIDE_FC, FRAME_WIDE_FS)
        @test (lite_metrics .> 0) == bits
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA frame-wide LDPC checks passed")
end
