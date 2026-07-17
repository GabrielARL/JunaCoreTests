#!/usr/bin/env julia
#
# Receiver configuration — selecting paper receivers and constrained JUNA-WCz.
#
# Paper claims protected (papers/main.tex):
#   sec:solver (line 843)          The paper implements exactly two receivers:
#                                  JUNA-lite (ssec:junalite, 1522) and JUNA-Wz
#                                  (ssec:gradient-juna, 1622). Here: mode :lite / :full.
#   sec:method (lines 1966-1971)   The benchmark geometry n1024_cp256_sym1_p3_r0p25_dc4_sig1_ip2:
#                                  N=1024, CP=256, outer pilot every 3rd active tone,
#                                  LDPC rate 0.25 (k=340, n=1360), inner pilot every
#                                  2nd message bit. init() must reset a modulation to
#                                  this geometry so every experiment measures the
#                                  receiver, not a drifted configuration. Known
#                                  divergence: the paper string carries dc4 (sparsity
#                                  knob d_cfg=4, main.tex:1970); the package pins
#                                  ldpc_npc=3, the make-ldpc per-column check count —
#                                  a related but differently parameterized knob.
#   tab:hyperparams (line 2021)    4 partial-FFT temporal views (partial_fft_parts = 4).
#
# :coupled is the test-gated full C,W,z implementation. :robust is a package-level
# legacy alias for :full; it does not appear in the paper.
#
# If this fails: experiments could silently run the wrong receiver or a non-paper
# frame geometry, invalidating any comparison against the paper's tables.
#
# Run alone:  julia --project=. test/receiver_configuration.jl
# Via runner: julia --project=. test/runtests.jl config

using Test
using JunaCore

const ReceiverConfigJuna = JunaCore.Juna
const ReceiverConfigModulations = JunaCore.Modulations

const RECEIVER_CONFIG_FC = 24_000.0
const RECEIVER_CONFIG_FS = 24_000.0

@testset verbose = true "JUNA receiver configuration" begin
    default = ReceiverConfigJuna.Modulation()
    lite = ReceiverConfigJuna.LiteModulation(mode = :full)
    full = ReceiverConfigJuna.FullModulation(mode = :lite)
    coupled = ReceiverConfigJuna.CoupledModulation(mode = :lite)
    frame_wide = ReceiverConfigJuna.FrameWideLDPCModulation(mode = :lite)
    legacy = ReceiverConfigJuna.Modulation(mode = :robust)

    @testset "constructors force the receiver they name" begin
        @test default isa ReceiverConfigModulations.Modulation
        @test default.mode === :lite                 # package default receiver is JUNA-lite
        @test lite.mode === :lite                    # LiteModulation wins over mode kwarg
        @test full.mode === :full                    # FullModulation wins over mode kwarg
        @test coupled.mode === :coupled              # CoupledModulation wins over mode kwarg
        @test frame_wide.mode === :frame_wide_ldpc   # named constructor wins over mode kwarg
        @test legacy.mode === :robust                # legacy spelling preserved on the struct
        @test JunaCore.JunaLite.Modulation(mode = :full).mode === :lite
        @test JunaCore.JunaFull.Modulation(mode = :lite).mode === :full
        @test JunaCore.JunaCoupled.Modulation(mode = :lite).mode === :coupled
        @test JunaCore.JunaFrameWideLDPC.Modulation(mode = :lite).mode === :frame_wide_ldpc
    end

    @testset "receiver_profile distinguishes Lite, Wz, and coupled WCz" begin
        @test ReceiverConfigJuna.receiver_profile(:lite) === :lite
        @test ReceiverConfigJuna.receiver_profile(:full) === :full
        @test ReceiverConfigJuna.receiver_profile(:robust) === :full
        @test ReceiverConfigJuna.receiver_profile(:coupled) === :coupled
        @test ReceiverConfigJuna.receiver_profile(default) === :lite
        @test ReceiverConfigJuna.receiver_profile(lite) === :lite
        @test ReceiverConfigJuna.receiver_profile(full) === :full
        @test ReceiverConfigJuna.receiver_profile(legacy) === :full
        @test ReceiverConfigJuna.receiver_profile(coupled) === :coupled
    end

    @testset "isvalid accepts only the known receiver modes" begin
        @test isvalid(default, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test isvalid(lite, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test isvalid(full, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test isvalid(coupled, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test isvalid(legacy, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test !isvalid(ReceiverConfigJuna.Modulation(mode = :unknown),
                       RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
        @test !isvalid(ReceiverConfigJuna.CoupledModulation(
                           bpc = 1, ldpc_k = 170, ldpc_n = 680,
                       ), RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
    end

    # Poison every geometry field and all caches, then check init() restores the
    # paper benchmark geometry exactly, clears the caches, and preserves only the
    # operator's choices: mode and acquisition profile.
    @testset "init() resets to the paper geometry, keeps mode+sync (main.tex:1966-1971)" begin
        configured = ReceiverConfigJuna.Modulation(
            mode = :full,
            sync = true,
            sync_profile = :rpchan,
            rpchan_guard_s = 0.0,
            rpchan_doppler_ppm = 250.0,
            rpchan_doppler_steps = 5,
            rpchan_sync_max_lag = 80,
            nc = UInt16(64),
            np = UInt16(16),
            bpc = 1,
            bw = 0.5,
            dc0 = Int16(1),
            pilot_ratio = 0.9,
            inner_pilot_ratio = 0.9,
            ldpc_k = 10,
            ldpc_n = 20,
            ldpc_npc = 7,
            partial_fft_parts = 9,
            partial_fft_nbands = 9,
        )
        configured.code = :stale_code_cache
        configured.layout = :stale_layout_cache
        configured.bp_scratch = :stale_bp_cache

        @test ReceiverConfigModulations.init(configured, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS) === nothing

        @test configured.mode === :full              # operator choice preserved
        @test configured.sync === true               # operator choice preserved
        @test configured.sync_profile === :rpchan
        @test configured.rpchan_guard_s == 0.0
        @test configured.rpchan_doppler_ppm == 250.0
        @test configured.rpchan_doppler_steps == 5
        @test configured.rpchan_sync_max_lag == 80

        @test configured.nc == UInt16(1024)          # N = 1024               (main.tex:1968)
        @test configured.np == UInt16(256)           # CP length = 256        (main.tex:1968)
        @test configured.bpc == 2                    # QPSK
        @test configured.bw == 1.0
        @test configured.dc0 == Int16(0)
        @test configured.pilot_ratio == 1 / 3        # outer pilot every 3rd active tone (p3)
        @test configured.inner_pilot_ratio == 1 / 2  # inner pilot every 2nd message bit (ip2)
        @test configured.ldpc_k == 340               # rate 340/1360 = 0.25   (r0p25)
        @test configured.ldpc_n == 1360
        @test configured.ldpc_npc == 3               # package knob; paper string says dc4 (see header)
        @test configured.partial_fft_parts == 4      # 4 temporal views       (main.tex:2021)
        @test configured.partial_fft_nbands == 16    # package-default ridge bands

        @test configured.code === nothing            # stale caches cleared
        @test configured.layout === nothing
        @test configured.bp_scratch === nothing
        @test isvalid(configured, RECEIVER_CONFIG_FC, RECEIVER_CONFIG_FS)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA receiver configuration checks passed")
end
