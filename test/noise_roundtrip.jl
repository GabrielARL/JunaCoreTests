#!/usr/bin/env julia
#
# Seeded-AWGN noise roundtrip - the modem's core claim: decode under noise.
#
# Paper claims protected (papers/main.tex):
#   sec:method (1919-1964)        Receivers are scored by payload BER / packet
#                                 success after AWGN is added to the replayed
#                                 waveform (the reported results are BER/PSR-vs-SNR
#                                 waterfalls).
#   acceptance rule (1928-1932)   A packet is accepted only on payload-exact
#                                 recovery; here PSR == 1 means every packet's
#                                 payload came back bit-for-bit.
#
# Every other suite decodes a clean (or deterministically faded) loopback, so a
# regression that shifts the waterfall by a few dB, flips a near-threshold LLR
# sign, weakens BP, or makes the receiver ignore its input entirely (decoding
# payload from regenerated pilots) passes all of them. This suite brackets the
# waterfall from both sides and pins an anti-cheat floor.
#
# PORTABILITY: the noise is drawn from a fixed-seed Xoshiro stream, so on one
# machine the BER values are bit-reproducible. Base RNG streams are NOT
# guaranteed identical across Julia major versions, so the assertions are BANDS
# and an ORDERING, never exact BER values - a different noise realization stays
# inside them, but a real waterfall shift does not. SNR convention matches
# tools/bench_decode.jl: sigma = sqrt(10^(-snr/10) / 2) per complex component,
# signal power ~= 1 after the block is std-normalized.
#
# If this fails: the receiver no longer decodes at the SNR it used to (upward
# shift), decodes at an SNR it never should (downward shift / input-ignoring
# cheat), or the payload BER accounting broke.
#
# Run alone:  julia --project=. test/noise_roundtrip.jl
# Via runner: julia --project=. test/runtests.jl noise

using Random
using Test
using JunaCore

if !isdefined(@__MODULE__, :PUBLIC_RECEIVER_DESCRIPTORS)
    include(joinpath(@__DIR__, "support", "public_receivers.jl"))
end

const NoiseJuna = JunaCore.Juna
const NoiseModulations = JunaCore.Modulations
const NOISE_FC = 24_000.0
const NOISE_FS = 24_000.0
const NOISE_SEED = 20_260_710
const NOISE_PACKETS = 12

# Generate payload and unit complex noise exactly once. Receivers sharing one
# transmit FEC see identical samples; Frame-wide LDPC uses its matched codeword
# while retaining the same payload and noise realization.
function noise_trials(npackets::Int; seed::Int = NOISE_SEED)
    tx = NoiseJuna.LiteModulation()
    bps = NoiseModulations.bitspersymbol(tx)
    nsamples = NoiseModulations.signallength(
        tx, bps, NOISE_FC, NOISE_FS)
    rng = Xoshiro(seed)
    [begin
        bits = rand(rng, Bool, bps)
        unit_noise = randn(rng, nsamples) .+
                     im .* randn(rng, nsamples)
        (; bits, unit_noise)
    end for _ in 1:npackets]
end

# BER / PSR over one shared fixture at a requested SNR.
function noise_point(descriptor, snr_db, trials)
    m = public_receiver(descriptor)
    sigma = snr_db === nothing ? 0.0 : sqrt(10.0^(-snr_db / 10) / 2)
    nerr = 0
    npass = 0
    for trial in trials
        clean = NoiseModulations.modulate(
            m, trial.bits, NOISE_FC, NOISE_FS)
        length(clean) == length(trial.unit_noise) ||
            throw(DimensionMismatch(
                "matched receiver waveform and shared noise differ in length"))
        waveform = clean .+ sigma .* trial.unit_noise
        metrics, _ = NoiseModulations.demodulate(
            m, length(trial.bits), waveform, NOISE_FC, NOISE_FS)
        e = count((metrics .> 0) .!= trial.bits)
        nerr += e
        npass += (e == 0)
    end
    nbits = sum(length(trial.bits) for trial in trials)
    (ber = nerr / nbits, psr = npass / length(trials))
end

# Assert the same waterfall shape for every receiver: clean above threshold,
# still erroring at the edge, and genuinely channel-limited at the floor.
function assert_waterfall(descriptor, trials)
    clean_snr = descriptor.profile === :frame_wide_ldpc ? 7.0 : 4.0
    clean = noise_point(descriptor, clean_snr, trials)
    edge = noise_point(descriptor, 1.5, trials)
    floor = noise_point(descriptor, 0.0, trials)

    # Ordinary codes are clean at 4 dB; the distinct sparse frame code is clean
    # at its measured 7 dB sentinel. An upward waterfall shift breaks this.
    @test clean.ber == 0.0
    @test clean.psr == 1.0

    # Waterfall edge: 1.5 dB sits mid-cliff - some errors, not all packets clean.
    # A downward shift (or an input-ignoring receiver) drives BER to 0 and breaks
    # the lower bound; a collapse drives it past the upper bound.
    @test 0.0 < edge.ber < 0.30
    @test edge.psr < 1.0

    # Anti-cheat floor: at 0 dB the channel dominates. A receiver that recovered
    # the payload without really using the noisy waveform would decode here too.
    @test floor.ber > 0.05

    # Monotone: more noise, no fewer errors.
    @test floor.ber >= edge.ber >= clean.ber
end

@testset verbose = true "JUNA seeded-AWGN noise roundtrip" begin
    assert_public_receiver_catalog()
    trials = noise_trials(NOISE_PACKETS)

    @testset "all registered receivers share one bracketed AWGN waterfall" begin
        for descriptor in public_receiver_descriptors()
            @testset "$(descriptor.name)" begin
                assert_waterfall(descriptor, trials)
            end
        end
    end

    @testset "seeded payload and noise fixture is reproducible run to run" begin
        again = noise_trials(NOISE_PACKETS)
        @test [trial.bits for trial in trials] == [trial.bits for trial in again]
        @test [trial.unit_noise for trial in trials] ==
              [trial.unit_noise for trial in again]
        ordinary = public_receiver_descriptors()[1:5]
        reference = [
            NoiseModulations.modulate(
                public_receiver(first(ordinary)), trial.bits,
                NOISE_FC, NOISE_FS)
            for trial in trials
        ]
        for descriptor in ordinary[2:end]
            @test [
                NoiseModulations.modulate(
                    public_receiver(descriptor), trial.bits,
                    NOISE_FC, NOISE_FS)
                for trial in trials
            ] == reference
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA seeded-AWGN noise roundtrip checks passed")
end
