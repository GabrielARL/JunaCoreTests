#!/usr/bin/env julia
module ReceiverChannelBenchmark

using JunaCore
using Printf
using Random
using Statistics

include(joinpath(@__DIR__, "replay_coupled_segment.jl"))
using .ReplayCoupledSegment: ReplayCapture, align_to_reference, apply_capture,
                             load_capture, replay_at_modem_rate,
                             replay_passband_at_modem_rate

const Juna = JunaCore.Juna
const Modulations = JunaCore.Modulations

export ALGORITHM_DESCRIPTORS, CHANNEL_DESCRIPTORS, RESULT_COLUMNS,
       algorithm_descriptors, benchmark_capture, channel_descriptors,
       identity_capture, modem_profile_descriptors, run_benchmark,
       run_benchmark_sweep, select_algorithms, select_channels,
       select_modem_profile, validate_report_rows, write_benchmark_csv,
       PAPER_FRAME_WIDE_CONFIG_DESCRIPTORS,
       PAPER_FRAME_WIDE_RESULT_COLUMNS,
       benchmark_paper_frame_wide_capture,
       paper_frame_wide_config_descriptors,
       run_paper_frame_wide_reproduction,
       write_paper_frame_wide_csv

const DEFAULT_RECEIVER = 3

const ALGORITHM_DESCRIPTORS = (
    (id=:standard, name="Standard OFDM", profile=:standard, factory=Juna.StandardModulation),
    (id=:pfft, name="Partial FFT+FEC", profile=:pfft, factory=Juna.PartialFFTModulation),
    (id=:lite, name="JUNA-Lite", profile=:lite, factory=Juna.LiteModulation),
    (id=:wz, name="JUNA-Wz", profile=:full, factory=Juna.FullModulation),
    (id=:wcz, name="JUNA-WCz", profile=:coupled, factory=Juna.CoupledModulation),
)

const MODEM_PROFILE_DESCRIPTORS = (
    (id=:default, name="JunaCore default", frame_packets=1, passband_oversample=1),
    (id=:rpchan_winner, name="Rpchan winner geometry (JunaCore block projection)", frame_packets=10,
     passband_oversample=12),
)

const CHANNEL_DESCRIPTORS = (
    (id=:red1, label="Red 1", color=:red, filename="red_1.mat", capture_fs=19_200.0),
    (id=:red2, label="Red 2", color=:red, filename="red_2.mat", capture_fs=19_200.0),
    (id=:red3, label="Red 3", color=:red, filename="red_3.mat", capture_fs=19_200.0),
    (id=:blue1, label="Blue 1", color=:blue, filename="blue_1.mat", capture_fs=9_765.625),
    (id=:blue2, label="Blue 2", color=:blue, filename="blue_2.mat", capture_fs=9_765.625),
    (id=:blue3, label="Blue 3", color=:blue, filename="blue_3.mat", capture_fs=9_765.625),
    (id=:yellow1, label="Yellow 1", color=:yellow, filename="yellow_1.mat", capture_fs=12_500.0),
    (id=:yellow2, label="Yellow 2", color=:yellow, filename="yellow_2.mat", capture_fs=12_500.0),
    (id=:yellow3, label="Yellow 3", color=:yellow, filename="yellow_3.mat", capture_fs=12_500.0),
    (id=:yellow4, label="Yellow 4", color=:yellow, filename="yellow_4.mat", capture_fs=12_500.0),
    (id=:yellow5, label="Yellow 5", color=:yellow, filename="yellow_5.mat", capture_fs=12_500.0),
    (id=:yellow6, label="Yellow 6", color=:yellow, filename="yellow_6.mat", capture_fs=12_500.0),
)

# Canonical Table 1 inputs and outputs from Rpchan's full-capture 20 dB run.
# `coded_bits_per_packet` follows ReplayCh's active-carrier mask (DC and Nyquist
# excluded); one direct LDPC graph spans ten packets.
const PAPER_FRAME_WIDE_CONFIG_DESCRIPTORS = (
    (id=:red1, label="SG-1", nfft=1024, cp=16, outer_spacing=5, inner_spacing=10,
     fec_rate=0.5, dc=10, coded_bits_per_packet=1634, payload_bits_per_frame=7353,
     capture_fs=19_200.0, modem_fs=9_600.0, carrier_hz=25_000.0,
     target_decoded_packets=360, target_accepted_packets=360,
     target_psr=1.000, target_ber=0.0, target_rate_bps=5540),
    (id=:red2, label="SG-2", nfft=1024, cp=64, outer_spacing=5, inner_spacing=10,
     fec_rate=0.5, dc=10, coded_bits_per_packet=1634, payload_bits_per_frame=7353,
     capture_fs=19_200.0, modem_fs=9_600.0, carrier_hz=25_000.0,
     target_decoded_packets=350, target_accepted_packets=200,
     target_psr=0.571, target_ber=0.06162, target_rate_bps=3078),
    (id=:red3, label="SG-3", nfft=1024, cp=64, outer_spacing=5, inner_spacing=10,
     fec_rate=0.5, dc=10, coded_bits_per_packet=1634, payload_bits_per_frame=7353,
     capture_fs=19_200.0, modem_fs=9_600.0, carrier_hz=25_000.0,
     target_decoded_packets=149, target_accepted_packets=85,
     target_psr=0.570, target_ber=0.03585, target_rate_bps=1308),
    (id=:blue1, label="NA-1", nfft=1024, cp=0, outer_spacing=5, inner_spacing=5,
     fec_rate=0.5, dc=8, coded_bits_per_packet=1634, payload_bits_per_frame=6536,
     capture_fs=9_765.625, modem_fs=4_882.8125, carrier_hz=13_000.0,
     target_decoded_packets=220, target_accepted_packets=220,
     target_psr=1.000, target_ber=0.0, target_rate_bps=2751),
    (id=:blue2, label="NA-2", nfft=512, cp=0, outer_spacing=5, inner_spacing=10,
     fec_rate=0.5, dc=6, coded_bits_per_packet=816, payload_bits_per_frame=3672,
     capture_fs=9_765.625, modem_fs=4_882.8125, carrier_hz=13_000.0,
     target_decoded_packets=166, target_accepted_packets=113,
     target_psr=0.681, target_ber=0.01159, target_rate_bps=793),
    (id=:blue3, label="NA-3", nfft=512, cp=32, outer_spacing=5, inner_spacing=10,
     fec_rate=0.5, dc=10, coded_bits_per_packet=816, payload_bits_per_frame=3672,
     capture_fs=9_765.625, modem_fs=4_882.8125, carrier_hz=13_000.0,
     target_decoded_packets=163, target_accepted_packets=61,
     target_psr=0.374, target_ber=0.08388, target_rate_bps=428),
    (id=:yellow1, label="HW-1", nfft=2048, cp=64, outer_spacing=4, inner_spacing=4,
     fec_rate=0.25, dc=8, coded_bits_per_packet=3068, payload_bits_per_frame=5752,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=140, target_accepted_packets=140,
     target_psr=1.000, target_ber=0.0, target_rate_bps=1565),
    (id=:yellow2, label="HW-2", nfft=1024, cp=16, outer_spacing=7, inner_spacing=10,
     fec_rate=0.5, dc=8, coded_bits_per_packet=1752, payload_bits_per_frame=7884,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=270, target_accepted_packets=260,
     target_psr=0.963, target_ber=0.008475, target_rate_bps=3985),
    (id=:yellow3, label="HW-3", nfft=512, cp=32, outer_spacing=7, inner_spacing=10,
     fec_rate=0.5, dc=8, coded_bits_per_packet=874, payload_bits_per_frame=3933,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=460, target_accepted_packets=430,
     target_psr=0.935, target_ber=0.01466, target_rate_bps=3303),
    (id=:yellow4, label="HW-4", nfft=2048, cp=64, outer_spacing=4, inner_spacing=4,
     fec_rate=0.25, dc=8, coded_bits_per_packet=3068, payload_bits_per_frame=5752,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=140, target_accepted_packets=140,
     target_psr=1.000, target_ber=0.0, target_rate_bps=1546),
    (id=:yellow5, label="HW-5", nfft=512, cp=0, outer_spacing=5, inner_spacing=7,
     fec_rate=0.5, dc=10, coded_bits_per_packet=816, payload_bits_per_frame=3497,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=490, target_accepted_packets=330,
     target_psr=0.673, target_ber=0.09853, target_rate_bps=2254),
    (id=:yellow6, label="HW-6", nfft=512, cp=16, outer_spacing=7, inner_spacing=7,
     fec_rate=0.5, dc=8, coded_bits_per_packet=874, payload_bits_per_frame=3745,
     capture_fs=12_500.0, modem_fs=6_250.0, carrier_hz=13_000.0,
     target_decoded_packets=480, target_accepted_packets=280,
     target_psr=0.583, target_ber=0.09667, target_rate_bps=2024),
)

const PAPER_FRAME_WIDE_RESULT_COLUMNS = (
    :channel,
    :label,
    :algorithm,
    :receiver,
    :nfft,
    :cp,
    :outer_spacing,
    :inner_spacing,
    :fec_rate,
    :check_degree,
    :modem_fs,
    :capture_fs,
    :snr_db,
    :seed,
    :frames,
    :decoded_packets,
    :accepted_packets,
    :psr,
    :psr_ci95_low,
    :psr_ci95_high,
    :payload_bits,
    :bit_errors,
    :ber,
    :decode_failures,
    :mean_decode_seconds,
    :total_decode_seconds,
    :effective_rate_bps,
    :target_decoded_packets,
    :target_accepted_packets,
    :target_psr,
    :target_ber,
    :target_rate_bps,
    :psr_delta,
    :ber_delta,
    :status,
)

const RESULT_COLUMNS = (
    :channel,
    :color,
    :algorithm,
    :profile,
    :modem_profile,
    :frame_packets,
    :receiver,
    :modem_fs,
    :capture_fs,
    :packets,
    :successful_packets,
    :psr,
    :psr_ci95_low,
    :psr_ci95_high,
    :payload_bits,
    :bit_errors,
    :ber,
    :decode_failures,
    :mean_decode_seconds,
    :median_decode_seconds,
    :p95_decode_seconds,
    :total_decode_seconds,
    :snr_db,
    :seed,
    :status,
)

algorithm_descriptors() = ALGORITHM_DESCRIPTORS
channel_descriptors() = CHANNEL_DESCRIPTORS
modem_profile_descriptors() = MODEM_PROFILE_DESCRIPTORS
paper_frame_wide_config_descriptors() = PAPER_FRAME_WIDE_CONFIG_DESCRIPTORS

function _paper_frame_wide_modem(config, fc::Real, fs::Real)
    receiver = Juna.FrameWideLDPCModulation(
        nc=config.nfft,
        np=config.cp,
        bpc=2,
        pilot_ratio=1 / config.outer_spacing,
        inner_pilot_ratio=1 / config.inner_spacing,
        sync=true,
        sync_profile=:rpchan,
        compatibility_profile=:rpchan,
        rpchan_preamble_seed=61_001,
        rpchan_guard_s=0.02,
        rpchan_doppler_ppm=5_000.0,
        rpchan_doppler_steps=81,
        rpchan_sync_max_lag=400,
        ldpc_k=round(Int, config.fec_rate * config.coded_bits_per_packet),
        ldpc_n=config.coded_bits_per_packet,
        ldpc_npc=config.dc,
        ldpc_seed=51_001,
        partial_fft_parts=4,
        partial_fft_nbands=4,
    )
    isvalid(receiver, fc, fs) || throw(ArgumentError(
        "$(config.id) paper frame-wide modem is invalid at fc=$fc, fs=$fs"))
    receiver
end

function _select(values, descriptors, kind::String)
    isempty(values) && throw(ArgumentError("select at least one $kind"))
    requested = Symbol.(lowercase.(String.(values)))
    unknown = setdiff(requested, [entry.id for entry in descriptors])
    isempty(unknown) || throw(ArgumentError("unknown $kind: $(join(unknown, ", "))"))
    Tuple(entry for entry in descriptors if entry.id in requested)
end

select_algorithms(values) = _select(values, ALGORITHM_DESCRIPTORS, "algorithm")
select_channels(values) = _select(values, CHANNEL_DESCRIPTORS, "channel")

function select_modem_profile(value)
    requested = Symbol(replace(lowercase(String(value)), '-' => '_'))
    index = findfirst(profile -> profile.id === requested, MODEM_PROFILE_DESCRIPTORS)
    index === nothing && throw(ArgumentError("unknown modem profile: $value"))
    MODEM_PROFILE_DESCRIPTORS[index]
end

function identity_capture(; fs::Real=19_200.0, fc::Real=25_000.0,
                          receiver::Integer=DEFAULT_RECEIVER)
    ReplayCapture(ones(ComplexF64, 1, 1_024), zeros(250_000), fs, fc, 200,
                  receiver,
                  "identity")
end

function _wilson_interval(successes::Integer, trials::Integer;
                          z::Real=1.959963984540054)
    n = Int(trials)
    k = Int(successes)
    n > 0 || throw(ArgumentError("Wilson interval needs at least one trial"))
    0 <= k <= n || throw(ArgumentError("successes must be in 0:trials"))
    isfinite(z) && z > 0 || throw(ArgumentError("Wilson z must be positive"))
    p = k / n
    z2 = Float64(z)^2
    denominator = 1 + z2 / n
    center = (p + z2 / (2n)) / denominator
    radius = Float64(z) * sqrt(p * (1 - p) / n + z2 / (4n^2)) / denominator
    (max(0.0, center - radius), min(1.0, center + radius))
end

function _timing_summary(samples)
    values = Float64.(collect(samples))
    isempty(values) && throw(ArgumentError("timing summary needs at least one sample"))
    all(value -> isfinite(value) && value >= 0, values) ||
        throw(ArgumentError("timing samples must be finite and nonnegative"))
    total = sum(values)
    (total=total, mean=total / length(values), median=median(values),
     p95=quantile(values, 0.95))
end

function _validate_benchmark(packets::Integer, snr_db::Real, seed::Integer)
    1 <= packets <= 1_000 || throw(ArgumentError("packets must be in 1:1000"))
    (isinf(snr_db) && snr_db > 0) || (-30 <= snr_db <= 100) ||
        throw(ArgumentError("SNR must be Inf or between -30 and 100 dB"))
    seed >= 0 || throw(ArgumentError("seed must be nonnegative"))
    nothing
end

function _resolve_modem_fs(capture::ReplayCapture, requested)
    requested === nothing && return capture.fs
    requested === :capture && return capture.fs
    requested === :rpchan && return capture.fs / 2
    requested isa Real ||
        throw(ArgumentError("modem fs must be :capture, :rpchan, or a positive rate"))
    rate = Float64(requested)
    isfinite(rate) && rate > 0 || throw(ArgumentError("modem fs must be positive"))
    rate
end

function _validate_rate_request(requested)
    requested === nothing && return nothing
    requested in (:capture, :rpchan) && return nothing
    requested isa Real ||
        throw(ArgumentError("modem fs must be :capture, :rpchan, or a positive rate"))
    isfinite(requested) && requested > 0 ||
        throw(ArgumentError("modem fs must be positive"))
    nothing
end

function _add_awgn(signal::AbstractVector{<:Number}, snr_db::Real,
                   rng::AbstractRNG)
    isinf(snr_db) && return ComplexF64.(signal)
    power = sum(abs2, signal) / length(signal)
    power == 0 && return ComplexF64.(signal)
    noise_power = power / 10.0^(Float64(snr_db) / 10)
    sigma = sqrt(noise_power / 2)
    ComplexF64.(signal) .+ sigma .* (randn(rng, length(signal)) .+
                                     im .* randn(rng, length(signal)))
end

function _snapshot_positions(capture::ReplayCapture, packets::Integer,
                             waveform_length::Integer, modem_fs::Real)
    count = Int(packets)
    count > 0 || throw(ArgumentError("packets must be positive"))
    waveform_length > 0 || throw(ArgumentError("waveform length must be positive"))
    rate = Float64(modem_fs)
    isfinite(rate) && rate > 0 || throw(ArgumentError("modem fs must be positive"))
    channel_samples, stop = _capture_position_limit(
        capture, waveform_length, rate)
    count <= stop || throw(ArgumentError(
        "capture has only $stop distinct packet positions, requested $count"))
    packets == 1 && return [1]
    positions = round.(Int, range(1, stop; length=count))
    allunique(positions) || throw(ArgumentError("packet positions are not distinct"))
    positions
end

function _capture_position_limit(capture::ReplayCapture,
                                 waveform_length::Integer,
                                 modem_fs::Real)
    waveform_length > 0 || throw(ArgumentError("waveform length must be positive"))
    rate = Float64(modem_fs)
    isfinite(rate) && rate > 0 || throw(ArgumentError("modem fs must be positive"))
    channel_samples = ceil(Int, waveform_length * capture.fs / rate)
    output_samples = channel_samples + size(capture.h, 1) - 1
    last_offset = output_samples - 1
    # Keep both the interpolated tap snapshot and phase index away from their
    # clamp-to-last fallbacks. Every reported packet must use a fully observed
    # capture segment rather than silently extending its tail.
    last_tap_snapshot = size(capture.h, 2) - div(last_offset, capture.step) - 1
    last_phase_snapshot = div(length(capture.phase) - last_offset, capture.step)
    stop = min(last_tap_snapshot, last_phase_snapshot)
    stop >= 1 || throw(ArgumentError("capture is too short for one waveform"))
    channel_samples, stop
end

function _full_capture_positions(capture::ReplayCapture,
                                 waveform_length::Integer,
                                 modem_fs::Real)
    channel_samples, stop = _capture_position_limit(
        capture, waveform_length, modem_fs)
    count = fld((stop - 1) * capture.step, channel_samples) + 1
    positions = unique(round.(Int,
        1 .+ (0:(count - 1)) .* (channel_samples / capture.step)))
    isempty(positions) && throw(ArgumentError("capture has no complete block positions"))
    last(positions) <= stop ||
        throw(ArgumentError("full-capture position exceeds channel support"))
    positions
end

function _effective_data_rate(successful_blocks::Integer,
                              payload_bits_per_block::Integer,
                              duration_seconds::Real)
    successful_blocks >= 0 ||
        throw(ArgumentError("successful block count must be nonnegative"))
    payload_bits_per_block > 0 ||
        throw(ArgumentError("payload bits per block must be positive"))
    isfinite(duration_seconds) && duration_seconds > 0 ||
        throw(ArgumentError("capture duration must be finite and positive"))
    successful_blocks * payload_bits_per_block / Float64(duration_seconds)
end

function _paper_frame_packet_counts(decoded_packets::Integer)
    total = Int(decoded_packets)
    total > 0 || throw(ArgumentError("decoded packet count must be positive"))
    full_frames, remainder = divrem(total, 10)
    counts = fill(10, full_frames)
    remainder == 0 || push!(counts, remainder)
    counts
end

function _paper_packet_success_count(receiver, payload, decisions, packet_count::Integer)
    blocks = Int(packet_count)
    length(payload) == length(decisions) ||
        throw(DimensionMismatch("decoded payload length does not match transmitted payload"))
    code = Juna._frame_code(receiver, blocks)
    transmitted_message = Juna._build_frame_message(
        receiver, code, Bool.(payload), blocks,
    )
    decoded_message = Juna._build_frame_message(
        receiver, code, Bool.(decisions), blocks,
    )
    transmitted_codeword = Juna._encode(code, transmitted_message)
    decoded_codeword = Juna._encode(code, decoded_message)
    block_n = Int(receiver.ldpc_n)
    successes = 0
    for block in 1:blocks
        block_range = (1 + (block - 1) * block_n):(block * block_n)
        successes += @views transmitted_codeword[block_range] ==
                           decoded_codeword[block_range]
    end
    successes
end

function _paper_replay_adapter(capture::ReplayCapture, transmitted;
                               snapshot::Integer, modem_fs::Real)
    replay_passband_at_modem_rate(
        capture, transmitted; snapshot=snapshot, modem_fs=modem_fs,
        passband_oversample=12,
    )
end

"""
    benchmark_paper_frame_wide_capture(capture, config; ...)

Exercise the frame-wide transmitter and receiver using one paper configuration.
The packet-success rule matches Rpchan: re-encode the decoded systematic
message, split the reconstructed codeword by OFDM packet, and require an exact
coded-bit match for each accepted packet. BER is measured independently on the
payload bits.
"""
function benchmark_paper_frame_wide_capture(
        capture::ReplayCapture, config;
        decoded_packets::Integer=config.target_decoded_packets,
        snr_db::Real=20.0,
        seed::Integer=51_001,
        warmup::Bool=true,
        channel_adapter::Function=_paper_replay_adapter)
    _validate_benchmark(decoded_packets, snr_db, seed)
    isapprox(capture.fs, config.capture_fs; rtol=0, atol=eps(config.capture_fs)) ||
        throw(ArgumentError(
            "$(config.id) capture fs=$(capture.fs), expected $(config.capture_fs)"))
    isapprox(capture.fc, config.carrier_hz; rtol=0, atol=eps(config.carrier_hz)) ||
        throw(ArgumentError(
            "$(config.id) carrier fc=$(capture.fc), expected $(config.carrier_hz)"))

    receiver = _paper_frame_wide_modem(
        config, config.carrier_hz, config.modem_fs,
    )
    Juna._frame_payload_capacity(receiver, 10) == config.payload_bits_per_frame ||
        throw(ArgumentError("$(config.id) frame payload geometry drifted"))
    packet_counts = _paper_frame_packet_counts(decoded_packets)

    warm_payload = falses(Juna._frame_payload_capacity(receiver, maximum(packet_counts)))
    warm_waveform = Modulations.modulate(
        receiver, warm_payload, config.carrier_hz, config.modem_fs,
    )
    warmup && Modulations.demodulate(
        receiver, length(warm_payload), warm_waveform,
        config.carrier_hz, config.modem_fs,
    )
    snapshots = _snapshot_positions(
        capture, length(packet_counts), length(warm_waveform), config.modem_fs,
    )

    accepted_packets = 0
    payload_bits = 0
    bit_errors = 0
    decode_failures = 0
    decode_samples = Float64[]
    first_error = ""

    for (frame, packet_count) in pairs(packet_counts)
        rng = MersenneTwister(Int(seed) + frame - 1)
        frame_payload_bits = Juna._frame_payload_capacity(receiver, packet_count)
        payload = rand(rng, Bool, frame_payload_bits)
        transmitted = Modulations.modulate(
            receiver, payload, config.carrier_hz, config.modem_fs,
        )
        replayed = channel_adapter(
            capture, transmitted; snapshot=snapshots[frame],
            modem_fs=config.modem_fs,
        )
        received = _add_awgn(replayed, snr_db, rng)
        payload_bits += frame_payload_bits

        started = time_ns()
        try
            metrics, _ = Modulations.demodulate(
                receiver, frame_payload_bits, received,
                config.carrier_hz, config.modem_fs,
            )
            length(metrics) == frame_payload_bits || throw(DimensionMismatch(
                "decoder returned $(length(metrics)) metrics, expected $frame_payload_bits"))
            decisions = metrics .> 0
            bit_errors += count(decisions .!= payload)
            accepted_packets += _paper_packet_success_count(
                receiver, payload, decisions, packet_count,
            )
        catch exception
            decode_failures += 1
            bit_errors += frame_payload_bits
            isempty(first_error) &&
                (first_error = sprint(showerror, exception; context=:compact => true))
        finally
            push!(decode_samples, (time_ns() - started) / 1e9)
        end
    end

    decoded = Int(decoded_packets)
    psr = accepted_packets / decoded
    ber = bit_errors / payload_bits
    psr_interval = _wilson_interval(accepted_packets, decoded)
    timing = _timing_summary(decode_samples)
    duration_s = length(capture.phase) / capture.fs
    nominal_packet_payload = config.payload_bits_per_frame / 10
    effective_rate = accepted_packets * nominal_packet_payload / duration_s
    status = decode_failures == 0 ? "ok" :
             "$decode_failures frame decode failure(s): $first_error"

    (
        channel=String(config.id), label=String(config.label),
        algorithm="JUNA Frame-wide LDPC", receiver=capture.receiver,
        nfft=config.nfft, cp=config.cp,
        outer_spacing=config.outer_spacing,
        inner_spacing=config.inner_spacing,
        fec_rate=Float64(config.fec_rate), check_degree=config.dc,
        modem_fs=Float64(config.modem_fs), capture_fs=capture.fs,
        snr_db=Float64(snr_db), seed=Int(seed),
        frames=length(packet_counts), decoded_packets=decoded,
        accepted_packets=accepted_packets, psr=psr,
        psr_ci95_low=psr_interval[1], psr_ci95_high=psr_interval[2],
        payload_bits=payload_bits, bit_errors=bit_errors, ber=ber,
        decode_failures=decode_failures,
        mean_decode_seconds=timing.mean,
        total_decode_seconds=timing.total,
        effective_rate_bps=effective_rate,
        target_decoded_packets=config.target_decoded_packets,
        target_accepted_packets=config.target_accepted_packets,
        target_psr=Float64(config.target_psr),
        target_ber=Float64(config.target_ber),
        target_rate_bps=config.target_rate_bps,
        psr_delta=psr - config.target_psr,
        ber_delta=ber - config.target_ber,
        status=status,
    )
end

function _validate_capture_rate(channel, capture::ReplayCapture)
    isapprox(capture.fs, channel.capture_fs; rtol=0, atol=eps(channel.capture_fs)) ||
        throw(ArgumentError(
            "$(channel.id) declares fs_delay=$(capture.fs), expected $(channel.capture_fs)"))
    nothing
end

function _pilot_budget_geometry(pilot_ratio)
    pilot_ratio === nothing && return nothing
    pilot_ratio isa Real || throw(ArgumentError("pilot ratio must be real"))
    requested = Float64(pilot_ratio)
    isfinite(requested) && 0 < requested <= 1 ||
        throw(ArgumentError("pilot ratio must be finite and in (0, 1]"))
    per_domain = requested / 2
    outer_spacing = Juna._ratio_spacing(per_domain, 2)
    inner_spacing = Juna._ratio_spacing(per_domain, 1)
    (
        requested=requested,
        per_domain=per_domain,
        outer_spacing=outer_spacing,
        inner_spacing=inner_spacing,
        outer_density=1 / outer_spacing,
        inner_density=1 / inner_spacing,
    )
end

function _configure_pilot_budget!(receiver, pilot_ratio)
    geometry = _pilot_budget_geometry(pilot_ratio)
    geometry === nothing && return receiver
    receiver.pilot_ratio = geometry.per_domain
    receiver.inner_pilot_ratio = geometry.per_domain
    receiver.layout = nothing
    receiver.code = nothing
    receiver.bp_scratch = nothing
    receiver
end

function _configure_code_rate!(receiver, code_rate)
    code_rate === nothing && return receiver
    code_rate isa Real || throw(ArgumentError("code rate must be real"))
    rate = Float64(code_rate)
    isfinite(rate) && 0 < rate < 1 ||
        throw(ArgumentError("code rate must be finite and strictly between zero and one"))
    block_n = Int(receiver.ldpc_n)
    block_k = round(Int, rate * block_n)
    block_k / block_n == rate || throw(ArgumentError(
        "code rate $rate is not exactly representable with LDPC block length $block_n"))
    receiver.ldpc_k = block_k
    receiver.code = nothing
    receiver.bp_scratch = nothing
    receiver
end

function _configure_fft_geometry!(receiver, fs::Real, nfft, cp)
    nfft === nothing && cp === nothing && return receiver
    nfft === nothing || nfft isa Integer ||
        throw(ArgumentError("FFT size must be an integer"))
    cp === nothing || cp isa Integer ||
        throw(ArgumentError("cyclic-prefix length must be an integer"))
    N = nfft === nothing ? Int(receiver.nc) : Int(nfft)
    L = cp === nothing ? Int(receiver.np) : Int(cp)
    2 < N <= typemax(UInt16) && count_ones(N) == 1 ||
        throw(ArgumentError("FFT size must be a UInt16-representable power of two"))
    0 <= L < N ||
        throw(ArgumentError("cyclic-prefix length must satisfy 0 <= CP < N"))

    original_rate = Int(receiver.ldpc_k) / Int(receiver.ldpc_n)
    receiver.nc = UInt16(N)
    receiver.np = UInt16(L)
    receiver.layout = nothing
    layout = Juna._layout(receiver, fs)
    coded_capacity = Int(receiver.bpc) * length(layout.data_idx)
    block_n = coded_capacity - mod(coded_capacity, 16)
    block_n >= 16 || throw(ArgumentError(
        "FFT geometry has insufficient coded-bit capacity"))
    block_k = round(Int, original_rate * block_n)
    receiver.ldpc_n = block_n
    receiver.ldpc_k = block_k
    receiver.code = nothing
    receiver.bp_scratch = nothing
    receiver
end

function _configure_modem!(receiver, fc::Real, fs::Real, modem_profile;
                           nfft=nothing, cp=nothing, code_rate=nothing,
                           pilot_ratio=nothing)
    profile = select_modem_profile(modem_profile)
    Modulations.init(receiver, fc, fs)
    if profile.id === :rpchan_winner
        receiver.nc = UInt16(1024)
        receiver.np = UInt16(32)
        receiver.bpc = 2
        receiver.pilot_ratio = 1 / 5
        receiver.inner_pilot_ratio = 1 / 10
        receiver.ldpc_k = 817
        receiver.ldpc_n = 1634
        receiver.ldpc_npc = 9
        receiver.partial_fft_parts = 4
        receiver.partial_fft_nbands = 4
        receiver.sync = true
        receiver.sync_profile = :rpchan
        receiver.rpchan_guard_s = 0.0
        receiver.rpchan_doppler_ppm = 0.0
        receiver.rpchan_doppler_steps = 1
        receiver.rpchan_sync_max_lag = 400
        receiver.code = nothing
        receiver.layout = nothing
        receiver.bp_scratch = nothing
    end
    _configure_pilot_budget!(receiver, pilot_ratio)
    _configure_fft_geometry!(receiver, fs, nfft, cp)
    _configure_code_rate!(receiver, code_rate)
end

function _receiver_set(algorithms, fc::Real, fs::Real;
                       modem_profile=:default, nfft=nothing, cp=nothing,
                       code_rate=nothing, pilot_ratio=nothing)
    receivers = map(algorithms) do descriptor
        receiver = _configure_modem!(
            descriptor.factory(), fc, fs, modem_profile;
            nfft=nfft, cp=cp, code_rate=code_rate,
            pilot_ratio=pilot_ratio)
        isvalid(receiver, fc, fs) ||
            throw(ArgumentError("$(descriptor.name) is invalid at fc=$fc, fs=$fs"))
        (descriptor=descriptor, receiver=receiver)
    end
    payload_sizes = unique(Modulations.bitspersymbol(item.receiver) for item in receivers)
    length(payload_sizes) == 1 ||
        throw(ArgumentError("selected receivers do not share one payload geometry"))
    receivers, only(payload_sizes)
end

function _warm_receivers!(receivers, waveform, payload_bits, fc, fs)
    for item in receivers
        Modulations.demodulate(item.receiver, payload_bits, waveform, fc, fs)
    end
    nothing
end

function _channel_color(channel_id::AbstractString)
    descriptor = findfirst(entry -> String(entry.id) == channel_id,
                           CHANNEL_DESCRIPTORS)
    descriptor === nothing ? "fixture" : String(CHANNEL_DESCRIPTORS[descriptor].color)
end

"""
    benchmark_capture(capture; ...)

Compare every selected public receiver on identical packet bits and identical
replayed samples. BER penalizes a thrown decoder as one entirely erroneous
packet; `decode_failures` keeps that operational failure visible. A packet is
successful only when all payload bits are recovered exactly. Decode timing
contains the public `demodulate` call only and follows an untimed warm-up.
When `code_rate` is provided, the benchmark keeps the profile's coded block
length and changes its information length only; the requested rate must be
exactly representable by that block length.
When `nfft` or `cp` is provided, the benchmark applies that actual OFDM
geometry and fits the coded block length to the QPSK data-carrier capacity,
rounded down to a multiple of 16 so the supported rate sweep stays exact.
When `pilot_ratio` is provided, it is a total requested pilot budget split
equally between inner message pilots and outer carrier pilots. Each half is
snapped by JunaCore to its nearest realizable `1/k` comb before carrier
capacity is fitted.
"""
function benchmark_capture(capture::ReplayCapture;
                           channel_id::AbstractString=capture.name,
                           packets::Integer=1,
                           algorithms=ALGORITHM_DESCRIPTORS,
                           snr_db::Real=Inf,
                           seed::Integer=1,
                           modem_fs=nothing,
                           modem_profile=:default,
                           nfft=nothing,
                           cp=nothing,
                           code_rate=nothing,
                           pilot_ratio=nothing,
                           full_capture::Bool=false,
                           warmup::Bool=true)
    full_capture && packets != 1 && throw(ArgumentError(
        "full-capture benchmark derives its block count; leave packets=1"))
    _validate_benchmark(full_capture ? 1 : packets, snr_db, seed)
    isempty(algorithms) && throw(ArgumentError("select at least one algorithm"))
    fs = _resolve_modem_fs(capture, modem_fs)
    fc = capture.fc
    profile = select_modem_profile(modem_profile)
    frame_packets = profile.frame_packets
    full_capture || packets % frame_packets == 0 || throw(ArgumentError(
        "$(profile.id) requires packet count divisible by $frame_packets"))
    receivers, payload_per_packet = _receiver_set(
        algorithms, fc, fs; modem_profile=profile.id,
        nfft=nfft, cp=cp, code_rate=code_rate, pilot_ratio=pilot_ratio,
    )

    transmitter = _configure_modem!(
        Juna.LiteModulation(), fc, fs, profile.id;
        nfft=nfft, cp=cp, code_rate=code_rate, pilot_ratio=pilot_ratio)
    Modulations.bitspersymbol(transmitter) == payload_per_packet ||
        throw(ArgumentError("transmitter and receivers disagree on payload geometry"))

    payload_per_frame = frame_packets * payload_per_packet
    warm_bits = falses(payload_per_frame)
    warm_waveform = Modulations.modulate(transmitter, warm_bits, fc, fs)
    warmup && _warm_receivers!(receivers, warm_waveform, payload_per_frame, fc, fs)

    successful = zeros(Int, length(receivers))
    bit_errors = zeros(Int, length(receivers))
    failures = zeros(Int, length(receivers))
    decode_samples = [Float64[] for _ in receivers]
    errors = fill("", length(receivers))
    snapshots = full_capture ?
        _full_capture_positions(capture, length(warm_waveform), fs) :
        _snapshot_positions(capture, div(packets, frame_packets),
                            length(warm_waveform), fs)
    frame_count = length(snapshots)
    packets = frame_count * frame_packets

    for frame in 1:frame_count
        rng = MersenneTwister(Int(seed) + frame - 1)
        payload = rand(rng, Bool, payload_per_frame)
        transmitted = Modulations.modulate(transmitter, payload, fc, fs)
        replayed = if profile.id === :rpchan_winner
            replay_passband_at_modem_rate(
                capture, transmitted; snapshot=snapshots[frame], modem_fs=fs,
                passband_oversample=profile.passband_oversample,
            )
        else
            replay_at_modem_rate(
                capture, transmitted; snapshot=snapshots[frame], modem_fs=fs,
            )
        end
        noisy = _add_awgn(replayed, snr_db, rng)
        received = profile.id === :rpchan_winner ? noisy : align_to_reference(
            noisy, transmitted; max_lag=length(noisy) - length(transmitted),
        ).waveform

        for (index, item) in pairs(receivers)
            started = time_ns()
            try
                metrics, _ = Modulations.demodulate(
                    item.receiver, payload_per_frame, received, fc, fs,
                )
                length(metrics) == payload_per_frame ||
                    throw(DimensionMismatch("decoder returned $(length(metrics)) metrics"))
                decisions = metrics .> 0
                for packet in 1:frame_packets
                    first_bit = 1 + (packet - 1) * payload_per_packet
                    last_bit = packet * payload_per_packet
                    packet_errors = count(
                        @view(decisions[first_bit:last_bit]) .!=
                        @view(payload[first_bit:last_bit]),
                    )
                    bit_errors[index] += packet_errors
                    successful[index] += iszero(packet_errors)
                end
            catch exception
                failures[index] += frame_packets
                bit_errors[index] += payload_per_frame
                isempty(errors[index]) &&
                    (errors[index] = sprint(showerror, exception; context=:compact => true))
            finally
                seconds_per_packet = (time_ns() - started) / 1e9 / frame_packets
                append!(decode_samples[index], fill(seconds_per_packet, frame_packets))
            end
        end
    end

    attempted_bits = packets * payload_per_packet
    color = _channel_color(String(channel_id))
    map(eachindex(receivers)) do index
        descriptor = receivers[index].descriptor
        timing = _timing_summary(decode_samples[index])
        psr_interval = _wilson_interval(successful[index], packets)
        status = failures[index] == 0 ? "ok" :
                 "$(failures[index]) decode failure(s): $(errors[index])"
        (
            channel=String(channel_id),
            color=color,
            algorithm=descriptor.name,
            profile=String(descriptor.profile),
            modem_profile=String(profile.id),
            frame_packets=frame_packets,
            receiver=capture.receiver,
            modem_fs=fs,
            capture_fs=capture.fs,
            packets=Int(packets),
            successful_packets=successful[index],
            psr=successful[index] / packets,
            psr_ci95_low=psr_interval[1],
            psr_ci95_high=psr_interval[2],
            payload_bits=attempted_bits,
            bit_errors=bit_errors[index],
            ber=bit_errors[index] / attempted_bits,
            decode_failures=failures[index],
            mean_decode_seconds=timing.mean,
            median_decode_seconds=timing.median,
            p95_decode_seconds=timing.p95,
            total_decode_seconds=timing.total,
            snr_db=Float64(snr_db),
            seed=Int(seed),
            status=status,
        )
    end
end

function _failed_rows(channel, algorithms, packets, snr_db, seed, modem_fs,
                      modem_profile, receiver, message)
    profile = select_modem_profile(modem_profile)
    requested_fs = modem_fs isa Real ? Float64(modem_fs) : NaN
    payload_per_packet = profile.id === :rpchan_winner ? 735 : 170
    attempted_bits = Int(packets) * payload_per_packet
    psr_interval = _wilson_interval(0, packets)
    map(algorithms) do descriptor
        (
            channel=String(channel.id), color=String(channel.color),
            algorithm=descriptor.name, profile=String(descriptor.profile),
            modem_profile=String(profile.id), frame_packets=profile.frame_packets,
            receiver=Int(receiver), modem_fs=requested_fs, capture_fs=NaN,
            packets=Int(packets), successful_packets=0, psr=0.0,
            psr_ci95_low=psr_interval[1], psr_ci95_high=psr_interval[2],
            payload_bits=attempted_bits, bit_errors=attempted_bits, ber=1.0,
            decode_failures=Int(packets), mean_decode_seconds=NaN,
            median_decode_seconds=NaN, p95_decode_seconds=NaN,
            total_decode_seconds=NaN, snr_db=Float64(snr_db), seed=Int(seed),
            status="capture failure: $message",
        )
    end
end

function run_benchmark(data_dir::AbstractString;
                       channels=CHANNEL_DESCRIPTORS,
                       algorithms=ALGORITHM_DESCRIPTORS,
                       packets::Integer=1,
                       snr_db::Real=Inf,
                       seed::Integer=1,
                       modem_fs=nothing,
                       modem_profile=:default,
                       receiver::Integer=DEFAULT_RECEIVER,
                       out::Union{Nothing,AbstractString}=nothing,
                       emit::Function=(_kind, _value) -> nothing)
    _validate_benchmark(packets, snr_db, seed)
    _validate_rate_request(modem_fs)
    1 <= receiver <= 3 || throw(ArgumentError("receiver lane must be in 1:3"))
    isempty(channels) && throw(ArgumentError("select at least one channel"))
    rows = NamedTuple[]
    for channel in channels
        emit(:begin, String(channel.id))
        path = joinpath(data_dir, channel.filename)
        channel_rows = try
            capture = load_capture(path; receiver=receiver)
            _validate_capture_rate(channel, capture)
            benchmark_capture(
                capture; channel_id=String(channel.id), packets=packets,
                algorithms=algorithms, snr_db=snr_db, seed=seed,
                modem_fs=modem_fs, modem_profile=modem_profile,
            )
        catch exception
            _failed_rows(channel, algorithms, packets, snr_db, seed,
                         modem_fs, modem_profile, receiver,
                         sprint(showerror, exception; context=:compact => true))
        end
        append!(rows, channel_rows)
        foreach(row -> emit(:row, row), channel_rows)
        GC.gc()
    end
    out === nothing || write_benchmark_csv(out, rows)
    rows
end

"""
    run_benchmark_sweep(data_dir; snrs, ...)

Run the same receiver comparison over several SNR points while loading each
measured capture only once. The returned and written rows are ordered by
channel, then SNR, then receiver.
"""
function run_benchmark_sweep(data_dir::AbstractString;
                             channels=CHANNEL_DESCRIPTORS,
                             algorithms=ALGORITHM_DESCRIPTORS,
                             packets::Integer=1,
                             snrs,
                             seed::Integer=1,
                             modem_fs=nothing,
                             modem_profile=:default,
                             receiver::Integer=DEFAULT_RECEIVER,
                             out::Union{Nothing,AbstractString}=nothing,
                             emit::Function=(_kind, _value) -> nothing)
    snr_values = Float64.(collect(snrs))
    isempty(snr_values) && throw(ArgumentError("select at least one SNR"))
    foreach(snr -> _validate_benchmark(packets, snr, seed), snr_values)
    _validate_rate_request(modem_fs)
    1 <= receiver <= 3 || throw(ArgumentError("receiver lane must be in 1:3"))
    isempty(channels) && throw(ArgumentError("select at least one channel"))

    rows = NamedTuple[]
    for channel in channels
        emit(:begin, String(channel.id))
        path = joinpath(data_dir, channel.filename)
        capture = try
            loaded_capture = load_capture(path; receiver=receiver)
            _validate_capture_rate(channel, loaded_capture)
            loaded_capture
        catch exception
            message = sprint(showerror, exception; context=:compact => true)
            for snr_db in snr_values
                channel_rows = _failed_rows(
                    channel, algorithms, packets, snr_db, seed, modem_fs,
                    modem_profile, receiver, message,
                )
                append!(rows, channel_rows)
                foreach(row -> emit(:row, row), channel_rows)
            end
            GC.gc()
            continue
        end

        for snr_db in snr_values
            channel_rows = benchmark_capture(
                capture; channel_id=String(channel.id), packets=packets,
                algorithms=algorithms, snr_db=snr_db, seed=seed,
                modem_fs=modem_fs, modem_profile=modem_profile,
            )
            append!(rows, channel_rows)
            foreach(row -> emit(:row, row), channel_rows)
        end
        GC.gc()
    end
    out === nothing || write_benchmark_csv(out, rows)
    rows
end

"""
    run_paper_frame_wide_reproduction(data_dir; ...)

Run the matched JUNA frame-wide transmitter/receiver at each paper winner
configuration. By default the paper's decoded-packet denominator is replayed;
`max_decoded_packets` provides a bounded plumbing run without changing the
configuration itself.
"""
function run_paper_frame_wide_reproduction(
        data_dir::AbstractString;
        configs=PAPER_FRAME_WIDE_CONFIG_DESCRIPTORS,
        snr_db::Real=20.0,
        seed::Integer=51_001,
        receiver::Integer=DEFAULT_RECEIVER,
        max_decoded_packets::Union{Nothing,Integer}=nothing,
        out::Union{Nothing,AbstractString}=nothing,
        emit::Function=(_kind, _value) -> nothing)
    isempty(configs) && throw(ArgumentError("select at least one paper configuration"))
    1 <= receiver <= 3 || throw(ArgumentError("receiver lane must be in 1:3"))
    max_decoded_packets === nothing || max_decoded_packets > 0 ||
        throw(ArgumentError("max decoded packets must be positive"))

    rows = NamedTuple[]
    for config in configs
        emit(:begin, String(config.id))
        channel = only(filter(item -> item.id === config.id, CHANNEL_DESCRIPTORS))
        capture = load_capture(joinpath(data_dir, channel.filename); receiver=receiver)
        _validate_capture_rate(channel, capture)
        packet_count = max_decoded_packets === nothing ?
            config.target_decoded_packets :
            min(config.target_decoded_packets, Int(max_decoded_packets))
        row = benchmark_paper_frame_wide_capture(
            capture, config; decoded_packets=packet_count,
            snr_db=snr_db, seed=seed,
        )
        push!(rows, row)
        emit(:row, row)
        GC.gc()
    end
    out === nothing || write_paper_frame_wide_csv(out, rows)
    rows
end


function validate_report_rows(rows; expected_rows=nothing, require_ok::Bool=false)
    isempty(rows) && throw(ArgumentError("benchmark report contains no rows"))
    if expected_rows !== nothing
        length(rows) == Int(expected_rows) || throw(ArgumentError(
            "benchmark report has $(length(rows)) rows, expected $(Int(expected_rows))"))
    end
    identities = map(rows) do row
        (row.channel, row.algorithm, row.receiver, row.modem_fs, row.snr_db, row.seed)
    end
    allunique(identities) || throw(ArgumentError(
        "benchmark report contains duplicate channel/receiver/SNR rows"))
    for row in rows
        require_ok && (row.status != "ok" || row.decode_failures != 0) &&
            throw(ArgumentError("$(row.channel)/$(row.algorithm) failed: $(row.status)"))
        row.packets > 0 || throw(ArgumentError("row packet count must be positive"))
        row.frame_packets > 0 && row.packets % row.frame_packets == 0 ||
            throw(ArgumentError("row frame packet count is invalid"))
        select_modem_profile(row.modem_profile)
        0 <= row.successful_packets <= row.packets ||
            throw(ArgumentError("row successful-packet count is invalid"))
        0 <= row.psr <= 1 || throw(ArgumentError("row PSR is outside [0,1]"))
        0 <= row.psr_ci95_low <= row.psr <= row.psr_ci95_high <= 1 ||
            throw(ArgumentError("row PSR interval does not contain PSR"))
        row.payload_bits > 0 || throw(ArgumentError("row payload count must be positive"))
        0 <= row.bit_errors <= row.payload_bits ||
            throw(ArgumentError("row bit-error count is invalid"))
        0 <= row.ber <= 1 || throw(ArgumentError("row BER is outside [0,1]"))
        if row.status == "ok"
            times = (row.mean_decode_seconds, row.median_decode_seconds,
                     row.p95_decode_seconds, row.total_decode_seconds)
            all(value -> isfinite(value) && value >= 0, times) ||
                throw(ArgumentError("row decode timing is not finite"))
            row.median_decode_seconds <= row.p95_decode_seconds ||
                throw(ArgumentError("row median decode time exceeds p95"))
        end
    end
    nothing
end

function _csv_value(value)
    text = value isa AbstractFloat ? @sprintf("%.12g", value) : string(value)
    occursin(r"[,\"\n\r]", text) || return text
    "\"" * replace(text, '"' => "\"\"") * "\""
end

function write_benchmark_csv(path::AbstractString, rows)
    isempty(path) && throw(ArgumentError("CSV path must not be empty"))
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        println(io, join(string.(RESULT_COLUMNS), ','))
        for row in rows
            println(io, join((_csv_value(getproperty(row, column))
                              for column in RESULT_COLUMNS), ','))
        end
    end
    abspath(path)
end

function write_paper_frame_wide_csv(path::AbstractString, rows)
    isempty(path) && throw(ArgumentError("CSV path must not be empty"))
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        println(io, join(string.(PAPER_FRAME_WIDE_RESULT_COLUMNS), ','))
        for row in rows
            println(io, join((_csv_value(getproperty(row, column))
                              for column in PAPER_FRAME_WIDE_RESULT_COLUMNS), ','))
        end
    end
    abspath(path)
end

function _json_string(value)
    text = replace(string(value), '\\' => "\\\\", '"' => "\\\"",
                   '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")
    "\"$text\""
end

function _json_value(value)
    value isa Bool && return value ? "true" : "false"
    value isa Integer && return string(value)
    if value isa AbstractFloat
        isfinite(value) && return string(value)
        return _json_string(string(value))
    end
    _json_string(value)
end

function _row_json(row)
    entries = ("$(_json_string(column)):$(_json_value(getproperty(row, Symbol(column))))"
               for column in string.(RESULT_COLUMNS))
    "{" * join(entries, ',') * "}"
end

function _parse_list(value::String)
    filter(!isempty, strip.(split(value, ',')))
end

function _parse_snr_grid(value::String)
    values = Float64[]
    for item in _parse_list(value)
        fields = strip.(split(item, ':'))
        if length(fields) == 1
            push!(values, parse(Float64, only(fields)))
        elseif length(fields) == 3
            first_snr, step, last_snr = parse.(Float64, fields)
            iszero(step) && throw(ArgumentError("SNR grid step must be nonzero"))
            (last_snr - first_snr) * step >= 0 ||
                throw(ArgumentError("SNR grid step points away from its endpoint"))
            append!(values, first_snr:step:last_snr)
        else
            throw(ArgumentError("SNR grid entries must be values or start:step:stop"))
        end
    end
    isempty(values) && throw(ArgumentError("select at least one SNR"))
    length(values) <= 100 || throw(ArgumentError("SNR grid may contain at most 100 points"))
    values
end

function _parse_cli(args)
    options = Dict{String,String}(
        "data-dir" => get(ENV, "JUNA_REPLAY_DATA_DIR",
                          joinpath(homedir(), "Documents", "GitHub",
                                   "Juna_replay_channel_1ch", "data")),
        "channels" => "red1,blue1,yellow1",
        "algorithms" => "all",
        "packets" => "1",
        "snr" => "Inf",
        "seed" => "1",
        "modem-fs" => "capture",
        "modem-profile" => "default",
        "receiver" => string(DEFAULT_RECEIVER),
        "out" => "",
        "fixture" => "",
        "strict" => "false",
    )
    index = 1
    while index <= length(args)
        arg = args[index]
        startswith(arg, "--") || throw(ArgumentError("unknown argument: $arg"))
        key = arg[3:end]
        haskey(options, key) || throw(ArgumentError("unknown option: --$key"))
        index < length(args) || throw(ArgumentError("--$key needs a value"))
        options[key] = args[index + 1]
        index += 2
    end
    options
end

function _parse_bool(value::String)
    text = lowercase(strip(value))
    text in ("1", "true", "yes", "on") && return true
    text in ("0", "false", "no", "off") && return false
    throw(ArgumentError("boolean value must be true or false"))
end

function main(args=ARGS)
    options = _parse_cli(args)
    algorithm_values = options["algorithms"] == "all" ?
        string.([entry.id for entry in ALGORITHM_DESCRIPTORS]) :
        _parse_list(options["algorithms"])
    algorithms = select_algorithms(algorithm_values)
    packets = parse(Int, options["packets"])
    snr_text = lowercase(options["snr"])
    snrs = snr_text in ("inf", "+inf", "none", "off") ?
           [Inf] : _parse_snr_grid(options["snr"])
    seed = parse(Int, options["seed"])
    modem_text = lowercase(strip(options["modem-fs"]))
    modem_fs = modem_text == "capture" ? :capture :
               modem_text == "rpchan" ? :rpchan : parse(Float64, modem_text)
    modem_profile = select_modem_profile(options["modem-profile"]).id
    receiver = parse(Int, options["receiver"])
    out = isempty(options["out"]) ? nothing : options["out"]
    strict = _parse_bool(options["strict"])
    expected_rows = length(algorithms) * length(snrs)

    emit = function (kind, value)
        if kind === :begin
            println("##BENCH_BEGIN##", value)
        elseif kind === :row
            println("##BENCH_ROW##", _row_json(value))
        end
        flush(stdout)
    end

    rows = if options["fixture"] == "identity"
        result = NamedTuple[]
        capture = identity_capture(receiver=receiver)
        for snr_db in snrs
            append!(result, benchmark_capture(
                capture; channel_id="identity", packets=packets,
                algorithms=algorithms, snr_db=snr_db, seed=seed,
                modem_fs=modem_fs, modem_profile=modem_profile,
            ))
        end
        foreach(row -> emit(:row, row), result)
        out === nothing || write_benchmark_csv(out, result)
        result
    else
        channel_values = options["channels"] == "all" ?
            string.([entry.id for entry in CHANNEL_DESCRIPTORS]) :
            _parse_list(options["channels"])
        channels = select_channels(channel_values)
        expected_rows *= length(channels)
        if length(snrs) == 1
            run_benchmark(
                options["data-dir"]; channels=channels, algorithms=algorithms,
                packets=packets, snr_db=only(snrs), seed=seed,
                modem_fs=modem_fs, modem_profile=modem_profile,
                receiver=receiver, out=out, emit=emit,
            )
        else
            run_benchmark_sweep(
                options["data-dir"]; channels=channels, algorithms=algorithms,
                packets=packets, snrs=snrs, seed=seed, modem_fs=modem_fs,
                modem_profile=modem_profile, receiver=receiver, out=out, emit=emit,
            )
        end
    end
    strict && validate_report_rows(rows; expected_rows=expected_rows, require_ok=true)
    println("##BENCH_DONE##rows=$(length(rows))##csv=$(something(out, ""))")
    nothing
end

end # module ReceiverChannelBenchmark

if abspath(PROGRAM_FILE) == @__FILE__
    ReceiverChannelBenchmark.main()
end
