#!/usr/bin/env julia
#
# Export one deterministic ReplayCh SG-1 receiver-3 frame at 20 dB. Run this
# script with Rpchan's Julia project so every intermediate comes from the same
# frame, channel realization, and AWGN draw:
#
#   julia --project=/path/to/Rpchan tools/export_rpchan_golden_frame.jl out.mat

using MAT

const RPCHAN_ROOT = abspath(get(ENV, "RPCHAN_ROOT",
    joinpath(homedir(), "Documents", "GitHub", "Rpchan")))
const OUTPUT_PATH = abspath(isempty(ARGS) ?
    joinpath(@__DIR__, "..", "artifacts", "rpchan_golden", "sg1_frame.mat") :
    ARGS[1])

isfile(joinpath(RPCHAN_ROOT, "Project.toml")) ||
    error("Rpchan root not found at $RPCHAN_ROOT")

cd(RPCHAN_ROOT) do
    include(joinpath(RPCHAN_ROOT, "scripts", "workbench",
                     "color_max_bandwidth_search_snr_sweep.jl"))
end

function sg1_params()
    channel_file = "red_1.mat"
    meta = color_channel_metadata(channel_file)
    params, carrier, baseband, oversample, _, _ =
        color_channel_params(Dict{String,String}(), "red", channel_file, meta)
    params["nfft"] = "1024"
    params["cp"] = "16"
    params["symbols"] = "10"
    params["pilot_spacing"] = "5"
    params["inner_pilot_spacing"] = "10"
    params["fec_rate"] = "0.5"
    params["d_msg"] = "10"
    params["modulation"] = "QPSK"
    params["partial_fft_parts"] = "4"
    params["partial_fft_nbands"] = "4"
    params["snr"] = "20"
    params, carrier, baseband, oversample, channel_file
end

function aligned_payload(received_passband, frame, pulse, config)
    coarse_baseband = R.to_bb(received_passband, pulse, config)
    doppler = R.dopp_est(coarse_baseband, frame, config)
    aligned = if isapprox(doppler.scale, 1.0; rtol=0.0, atol=eps(Float64))
        R.payload_at_lag(coarse_baseband, frame, doppler.lag, doppler.score)
    else
        bank = R.dopp_fbank(config)
        corrected_passband = R.tscale_resamp_sig(
            received_passband, doppler.scale; filter_bank=bank)
        corrected_baseband = R.to_bb(corrected_passband, pulse, config)
        R.payload_align(corrected_baseband, frame, config)
    end
    coarse_baseband, doppler, aligned
end

function export_frame()
    params, carrier, baseband, oversample, channel_file = sg1_params()
    mkpath(dirname(OUTPUT_PATH))

    with_profile_env(; carrier_hz=carrier, baseband_hz=baseband,
                     passband_oversample=oversample) do
        candidate = C.probe_candidate_from_params(params)
        channel = OfdmUiBackend.cached_red_replay_channel(
            3; channel_file=channel_file)
        config, sweep, pulse, packets =
            OfdmUiBackend.live_video_clean_packets(
                channel, candidate, [0.0], 20.0)
        clean = only(packets)
        modem = R.pkt_cfg(
            sweep;
            snr_db=20.0,
            replay_start=clean.replay_start_index,
            noise_seed=R.noise_seed(sweep, 1, clean.packet),
        )
        noisy = R.pb_awgn(clean.clean, modem)
        probe = R.rx_probe(
            "red_1",
            noisy.signal,
            clean.frame,
            pulse,
            modem;
            include_standard=false,
            include_partial=true,
            include_partial_metrics=false,
            include_partial_channel=true,
        )
        coarse_baseband, doppler, aligned =
            aligned_payload(noisy.signal, clean.frame, pulse, modem)
        blocks = R.cp_strip(aligned.payload, modem)
        seed_details = R.fec_decode_eq(
            probe.partial_lwlsc, clean.frame, clean.fec, sweep)
        juna = R.juna_refine(
            probe.partial_lwlsc_yparts,
            probe.partial_lwlsc,
            clean.frame,
            clean.fec,
            sweep,
            config,
        )
        details = juna.fec_details

        passband_samples = Float64.(vec(R.samples(noisy.signal)))
        bp_bits = Int8.(details.bp.bits)
        channel_llrs = hasproperty(details, :channel_llrs) ?
            Float64.(details.channel_llrs) : Float64.(details.llrs)
        fec_scheme = hasproperty(clean.fec, :scheme) ?
            string(clean.fec.scheme) : "direct"

        MAT.matwrite(OUTPUT_PATH, Dict{String,Any}(
            "schema_version" => 1,
            "source_utf8" => Int16.(collect(codeunits("Rpchan SG-1 receiver 3, first frame, 20 dB"))),
            "channel_file_utf8" => Int16.(collect(codeunits(channel_file))),
            "receiver_index" => 3,
            "snr_db" => 20.0,
            "carrier_hz" => modem.carrier_hz,
            "baseband_sample_rate_hz" => modem.baseband_sample_rate_hz,
            "passband_sample_rate_hz" => modem.baseband_sample_rate_hz * modem.passband_oversample,
            "passband_oversample" => modem.passband_oversample,
            "interpolation_rolloff" => modem.interpolation_rolloff,
            "nfft" => modem.nfft,
            "cp" => modem.cp,
            "nofdm_symbols" => modem.nofdm_symbols,
            "pilot_spacing" => modem.pilot_spacing,
            "inner_pilot_spacing" => sweep.inner_pilot_spacing,
            "partial_fft_parts" => modem.partial_fft_parts,
            "partial_fft_nbands" => modem.partial_fft_nbands,
            "preamble_duration_s" => modem.preamble_duration_s,
            "preamble_seed" => sweep.frame_seed_base + clean.packet + 10_000,
            "preamble_guard_s" => modem.preamble_guard_s,
            "sync_max_lag_samples" => modem.sync_max_lag_samples,
            "doppler_search_ppm" => modem.doppler_search_ppm,
            "doppler_search_steps" => modem.doppler_search_steps,
            "fec_scheme_utf8" => Int16.(collect(codeunits(fec_scheme))),
            "fec_n" => clean.fec.n,
            "fec_k" => clean.fec.k,
            "fec_d_c" => clean.fec.d_c,
            "fec_bp_iters" => sweep.fec_bp_iters,
            "passband" => passband_samples,
            "coarse_baseband" => ComplexF64.(coarse_baseband),
            "preamble" => ComplexF64.(clean.frame.preamble),
            "aligned_payload" => ComplexF64.(aligned.payload),
            "payload_blocks" => ComplexF64.(blocks),
            "acquisition_lag" => probe.lag,
            "acquisition_score" => probe.sync_score,
            "doppler_scale" => doppler.scale,
            "doppler_ppm" => doppler.ppm,
            "active_bins" => Int32.(clean.frame.active_bins),
            "pilot_mask" => Int8.(clean.frame.pilot_mask),
            "data_mask" => Int8.(clean.frame.data_mask),
            "partial_fft" => ComplexF64.(probe.partial_lwlsc_yparts),
            "seed_equalized_symbols" => ComplexF64.(probe.partial_lwlsc),
            "seed_channel_llrs" => Float64.(seed_details.channel_llrs),
            "seed_ldpc_output" => Int8.(seed_details.bp.bits),
            "equalized_symbols" => ComplexF64.(juna.equalized),
            "channel_llrs" => channel_llrs,
            "ldpc_output" => bp_bits,
            "transmitted_code_bits" => Int8.(clean.fec.coded_bits),
            "transmitted_message_bits" => Int8.(clean.fec.message_bits),
        ); compress=true)

        println("exported: ", OUTPUT_PATH)
        println("passband_samples=", length(passband_samples),
                " lag=", probe.lag,
                " doppler_ppm=", probe.doppler_ppm)
        println("partial_fft=", size(probe.partial_lwlsc_yparts),
                " equalized=", size(probe.partial_lwlsc),
                " llrs=", length(channel_llrs),
                " ldpc=", length(bp_bits),
                " seed_valid=", seed_details.bp.valid,
                " juna_valid=", details.bp.valid,
                " juna_selected_iter=", juna.selected_iter)
    end
end

export_frame()
