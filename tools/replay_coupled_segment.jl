module ReplayCoupledSegment

using Printf
using JunaCore
import MAT
import SignalAnalysis

const Juna = JunaCore.Juna
const Modulations = JunaCore.Modulations

export ReplayCapture, RESULT_COLUMNS, align_to_reference, apply_capture,
       capture_from_dict, decode_segment, deterministic_signature, load_capture,
       replay_at_modem_rate, replay_passband_at_modem_rate, write_result_csv

struct ReplayCapture
    h::Matrix{ComplexF64}       # oldest-delay to zero-delay tap x snapshot
    phase::Vector{Float64}      # baseband phase track for that lane
    fs::Float64
    fc::Float64
    step::Int
    receiver::Int
    name::String
    function ReplayCapture(h::Matrix{ComplexF64},
                           phase::Vector{Float64},
                           fs::Float64,
                           fc::Float64,
                           step::Int,
                           receiver::Int,
                           name::String)
        size(h, 1) > 0 || throw(ArgumentError("replay capture needs at least one tap"))
        size(h, 2) > 0 || throw(ArgumentError("replay capture needs at least one snapshot"))
        isempty(phase) && throw(ArgumentError("replay capture phase track must not be empty"))
        isfinite(fs) && fs > 0 || throw(ArgumentError("replay capture fs must be positive"))
        isfinite(fc) && fc > 0 || throw(ArgumentError("replay capture fc must be positive"))
        step > 0 || throw(ArgumentError("replay capture step must be positive"))
        receiver > 0 || throw(ArgumentError("replay receiver must be positive"))
        isempty(name) && throw(ArgumentError("replay capture name must not be empty"))
        all(x -> isfinite(real(x)) && isfinite(imag(x)), h) ||
            throw(ArgumentError("replay taps must be finite"))
        all(isfinite, phase) || throw(ArgumentError("replay phase must be finite"))
        new(h, phase, fs, fc, step, receiver, name)
    end
end

function ReplayCapture(h::AbstractMatrix,
                       phase::AbstractVector,
                       fs::Real,
                       fc::Real,
                       step::Integer,
                       receiver::Integer,
                       name::AbstractString)
    h2 = Matrix{ComplexF64}(h)
    phase2 = Float64.(phase)
    ReplayCapture(h2, phase2, Float64(fs), Float64(fc), Int(step),
                  Int(receiver), String(name))
end

_has(data, key::String) = haskey(data, key) || haskey(data, Symbol(key))
_get(data, key::String) = haskey(data, key) ? data[key] : data[Symbol(key)]

function _scalar(value, name::String)
    x = value isa AbstractArray ? only(value) : value
    x isa Number || throw(ArgumentError("$name must be numeric"))
    iszero(imag(x)) || throw(ArgumentError("$name must be real"))
    y = Float64(real(x))
    isfinite(y) || throw(ArgumentError("$name must be finite"))
    y
end

function capture_from_dict(data;
                           receiver::Integer=1,
                           name::AbstractString="replay")
    _has(data, "h_hat") || throw(ArgumentError("replay data is missing h_hat"))
    _has(data, "params") || throw(ArgumentError("replay data is missing params"))
    phase_key = _has(data, "phi_hat") ? "phi_hat" :
                (_has(data, "theta_hat") ? "theta_hat" : "")
    isempty(phase_key) &&
        throw(ArgumentError("replay data is missing phi_hat/theta_hat"))

    hraw = _get(data, "h_hat")
    ndims(hraw) == 3 || throw(ArgumentError("h_hat must be tap x receiver x snapshot"))
    rx = Int(receiver)
    1 <= rx <= size(hraw, 2) ||
        throw(ArgumentError("receiver $rx is outside h_hat lane count $(size(hraw, 2))"))
    # Match ReplayCh.open_red_ch: delay estimates are stored in reverse tap order.
    h = reverse(ComplexF64.(hraw[:, rx, :]); dims=1)

    phase_raw = _get(data, phase_key)
    ndims(phase_raw) == 2 || throw(ArgumentError("$phase_key must be receiver x sample"))
    size(phase_raw, 1) >= rx ||
        throw(ArgumentError("$phase_key has no receiver lane $rx"))
    phase = Float64.(vec(phase_raw[rx, :]))

    params = _get(data, "params")
    for key in ("fs_delay", "fc", "fs_time")
        _has(params, key) || throw(ArgumentError("replay params is missing $key"))
    end
    fs = _scalar(_get(params, "fs_delay"), "params.fs_delay")
    fc = _scalar(_get(params, "fc"), "params.fc")
    fs_time = _scalar(_get(params, "fs_time"), "params.fs_time")
    step = round(Int, fs / fs_time)
    ReplayCapture(h, phase, fs, fc, step, rx, name)
end

function load_capture(path::AbstractString; receiver::Integer=1)
    isfile(path) || throw(ArgumentError("replay MAT file does not exist: $path"))
    filesize(path) > 1_000_000 ||
        throw(ArgumentError("replay MAT file is too small and may be a Git LFS pointer"))
    data = MAT.matread(path)
    name = first(splitext(basename(path)))
    capture_from_dict(data; receiver=receiver, name=name)
end

# ReplayCh-compatible time-varying FIR interpolation for one selected lane.
function apply_capture(capture::ReplayCapture,
                       input::AbstractVector{<:Number};
                       snapshot::Integer=1)
    isempty(input) && throw(ArgumentError("replay input must not be empty"))
    start = Int(snapshot)
    1 <= start <= size(capture.h, 2) ||
        throw(ArgumentError("snapshot $start is outside 1:$(size(capture.h, 2))"))

    x = ComplexF64.(input)
    ntaps, nsnapshots = size(capture.h)
    output = zeros(ComplexF64, length(x) + ntaps - 1)
    @inbounds for output_idx in eachindex(output)
        offset = output_idx - 1
        snap = min(start + div(offset, capture.step), nsnapshots)
        next_snap = min(snap + 1, nsnapshots)
        alpha = mod(offset, capture.step) / capture.step
        base = output_idx - ntaps
        acc = 0.0 + 0.0im
        for tap in 1:ntaps
            input_idx = base + tap
            1 <= input_idx <= length(x) || continue
            response = (1 - alpha) * capture.h[tap, snap] +
                       alpha * capture.h[tap, next_snap]
            acc += response * x[input_idx]
        end
        phase_idx = min(start * capture.step + offset, length(capture.phase))
        output[output_idx] = acc * cis(capture.phase[phase_idx])
    end
    output
end

"""
    replay_at_modem_rate(capture, transmitted; snapshot=1, modem_fs)

Apply a replay capture whose taps live on `capture.fs` to a waveform sampled at
the independent modem rate. The conversion in both directions is part of the
physical channel adapter; `capture.fs` is a delay-grid rate, not a modem default.
"""
function replay_at_modem_rate(capture::ReplayCapture,
                              transmitted::AbstractVector{<:Number};
                              snapshot::Integer=1,
                              modem_fs::Real)
    isempty(transmitted) && throw(ArgumentError("replay input must not be empty"))
    modem_rate = Float64(modem_fs)
    isfinite(modem_rate) && modem_rate > 0 ||
        throw(ArgumentError("modem fs must be positive"))

    channel_input = modem_rate == capture.fs ? ComplexF64.(transmitted) :
        vec(SignalAnalysis.resample(
            ComplexF64.(transmitted), capture.fs / modem_rate; dims=1,
        ))
    channel_output = apply_capture(capture, channel_input; snapshot=snapshot)
    modem_rate == capture.fs && return channel_output
    vec(SignalAnalysis.resample(
        channel_output, modem_rate / capture.fs; dims=1,
    ))
end

"""
    replay_passband_at_modem_rate(capture, transmitted; snapshot=1,
                                   modem_fs, passband_oversample=12)

Reproduce Rpchan's real-passband replay path: root-raised-cosine interpolation,
upconversion, analytic downmix onto the capture delay grid, time-varying replay,
remodulation, and matched downconversion to the modem grid.
"""
function replay_passband_at_modem_rate(
        capture::ReplayCapture,
        transmitted::AbstractVector{<:Number};
        snapshot::Integer=1,
        modem_fs::Real,
        passband_oversample::Integer=12)
    isempty(transmitted) && throw(ArgumentError("replay input must not be empty"))
    modem_rate = Float64(modem_fs)
    isfinite(modem_rate) && modem_rate > 0 ||
        throw(ArgumentError("modem fs must be positive"))
    oversample = Int(passband_oversample)
    oversample > 0 || throw(ArgumentError("passband oversample must be positive"))

    pulse = SignalAnalysis.rrcosfir(0.25, oversample)
    baseband = SignalAnalysis.signal(ComplexF64.(transmitted), modem_rate)
    passband = SignalAnalysis.upconvert(
        baseband, oversample, capture.fc, pulse,
    )
    passband_rate = Float64(SignalAnalysis.framerate(passband))

    analytic_passband = SignalAnalysis.analytic(passband)
    mixed = ComplexF64.(SignalAnalysis.samples(analytic_passband))
    @inbounds for n in eachindex(mixed)
        mixed[n] *= cispi(-2 * capture.fc * (n - 1) / passband_rate)
    end
    channel_input = vec(SignalAnalysis.resample(
        mixed, capture.fs / passband_rate; dims=1,
    ))
    channel_output = apply_capture(
        capture, channel_input; snapshot=snapshot,
    )

    remodulated = vec(SignalAnalysis.resample(
        channel_output, passband_rate / capture.fs; dims=1,
    ))
    @inbounds for n in eachindex(remodulated)
        remodulated[n] *= cispi(2 * capture.fc * (n - 1) / passband_rate)
    end
    received_passband = SignalAnalysis.signal(real.(remodulated), passband_rate)
    recovered = SignalAnalysis.downconvert(
        received_passband, oversample, capture.fc, pulse,
    )
    ComplexF64.(vec(SignalAnalysis.samples(recovered)))
end

function align_to_reference(received::AbstractVector{<:Number},
                            reference::AbstractVector{<:Number};
                            max_lag::Integer)
    isempty(reference) && throw(ArgumentError("alignment reference must not be empty"))
    length(received) >= length(reference) ||
        throw(DimensionMismatch("received segment is shorter than its reference"))
    limit = min(Int(max_lag), length(received) - length(reference))
    limit >= 0 || throw(ArgumentError("max_lag must be nonnegative"))

    rx = ComplexF64.(received)
    tx = ComplexF64.(reference)
    tx_power = sum(abs2, tx)
    tx_power > 0 || throw(ArgumentError("alignment reference must have nonzero power"))
    best_lag = 0
    best_score = -Inf
    @inbounds for lag in 0:limit
        segment = @view rx[lag+1:lag+length(tx)]
        cross = sum(conj.(tx) .* segment)
        segment_power = sum(abs2, segment)
        score = segment_power == 0 ? 0.0 : abs(cross) / sqrt(tx_power * segment_power)
        if score > best_score
            best_lag = lag
            best_score = score
        end
    end

    segment = copy(@view rx[best_lag+1:best_lag+length(tx)])
    segment_power = sum(abs2, segment)
    gain = segment_power == 0 ? one(ComplexF64) :
           sum(conj.(segment) .* tx) / segment_power
    (waveform = gain .* segment, lag = best_lag, score = best_score, gain = gain)
end

const RESULT_COLUMNS = (
    "channel",
    "receiver",
    "snapshot",
    "modem_fs",
    "capture_fs",
    "payload_bits",
    "bit_errors",
    "ber",
    "valid",
    "syndrome",
    "objective_initial",
    "objective_best",
    "objective_reduction",
    "selected_iteration",
    "selected_candidate",
    "decode_seconds",
    "alignment_lag",
    "alignment_score",
)

function decode_segment(capture::ReplayCapture,
                        payload;
                        snapshot::Integer=1,
                        modem_fs::Real=capture.fs,
                        modulation=Juna.CoupledModulation(),
                        config=Juna._COUPLED_PUBLIC_CONFIG,
                        weights=Juna._COUPLED_RUNTIME_WEIGHTS)
    bits = Bool.(payload)
    modem_rate = Float64(modem_fs)
    isfinite(modem_rate) && modem_rate > 0 ||
        throw(ArgumentError("modem fs must be positive"))
    expected_bits = Modulations.bitspersymbol(modulation)
    length(bits) == expected_bits ||
        throw(DimensionMismatch("one replay segment requires exactly $expected_bits payload bits"))
    isvalid(modulation, capture.fc, modem_rate) ||
        throw(ArgumentError("invalid coupled modulation for replay capture"))

    transmitted = Modulations.modulate(modulation, bits, capture.fc, modem_rate)
    replayed = replay_at_modem_rate(
        capture, transmitted; snapshot=snapshot, modem_fs=modem_rate,
    )
    aligned = align_to_reference(
        replayed, transmitted; max_lag=length(replayed)-length(transmitted),
    )

    code = Juna._code(modulation)
    layout = Juna._layout(modulation, modem_rate)
    seed = nothing
    problem = nothing
    initial = nothing
    solved = nothing
    optimized = nothing
    selected = nothing
    decode_seconds = @elapsed begin
        observations = Juna._branch_observations(modulation, aligned.waveform)
        seed = Juna._seed_candidate(modulation, code, layout, observations)
        problem = Juna._coupled_problem_from_receiver(
            modulation, code, layout, observations,
        )
        initial = Juna._initial_coupled_state(
            modulation, code, layout, problem, seed,
        )
        solved = Juna._coupled_wcz_solve(
            problem, initial; weights=weights, config=config,
        )
        optimized = Juna._coupled_state_candidate(
            modulation, code, layout, problem, solved.state,
        )
        selected = Juna._juna_better(seed, optimized) ? optimized : seed
    end

    metrics = Juna._payload_from_metrics(modulation, code, selected.lpost_metric)
    bit_errors = count((metrics .> 0) .!= bits)
    objective_reduction = solved.initial_loss - solved.best_loss
    (
        channel = capture.name,
        receiver = capture.receiver,
        snapshot = Int(snapshot),
        modem_fs = modem_rate,
        capture_fs = capture.fs,
        payload_bits = length(bits),
        bit_errors = bit_errors,
        ber = bit_errors / length(bits),
        valid = selected.valid,
        syndrome = selected.syndrome,
        objective_initial = solved.initial_loss,
        objective_best = solved.best_loss,
        objective_reduction = objective_reduction,
        selected_iteration = solved.selected_iter,
        selected_candidate = selected === optimized ? "coupled" : "seed",
        decode_seconds = decode_seconds,
        alignment_lag = aligned.lag,
        alignment_score = aligned.score,
    )
end

deterministic_signature(result) = (
    result.channel,
    result.receiver,
    result.snapshot,
    result.modem_fs,
    result.capture_fs,
    result.payload_bits,
    result.bit_errors,
    result.ber,
    result.valid,
    result.syndrome,
    result.objective_initial,
    result.objective_best,
    result.objective_reduction,
    result.selected_iteration,
    result.selected_candidate,
    result.alignment_lag,
    result.alignment_score,
)

function _csv_value(value)
    value isa AbstractFloat && return @sprintf("%.12g", value)
    value isa Bool && return value ? "true" : "false"
    String(string(value))
end

function write_result_csv(path::AbstractString, result)
    isempty(path) && throw(ArgumentError("CSV path must not be empty"))
    mkpath(dirname(abspath(path)))
    values = [_csv_value(getproperty(result, Symbol(column))) for column in RESULT_COLUMNS]
    open(path, "w") do io
        println(io, join(RESULT_COLUMNS, ','))
        println(io, join(values, ','))
    end
    abspath(path)
end

end # module
