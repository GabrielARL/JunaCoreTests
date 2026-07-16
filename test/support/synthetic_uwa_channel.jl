module SyntheticUWAChannel

using Random
using Statistics

export UWAChannelProfile,
       add_awgn,
       apply_channel,
       apply_multipath,
       apply_per_path_doppler,
       paper_channel_profile

const _PAPER_POWER_DB = Float64[0.0, -0.9, -4.9, -8.0, -7.8, -23.7]
const _PAPER_DELAYS_S = Float64[0.0, 0.0008, 0.0017, 0.0027, 0.0038, 0.0050]

struct UWAChannelProfile
    fs::Float64
    taps::Vector{ComplexF64}
    delay_samples::Vector{Int}
    power_db::Vector{Float64}
end

function paper_channel_profile(fs::Real; seed::Integer = 0)
    fs2 = Float64(fs)
    isfinite(fs2) && fs2 > 0 ||
        throw(ArgumentError("sample rate must be finite and positive"))

    delays = round.(Int, _PAPER_DELAYS_S .* fs2)
    allunique(delays) ||
        throw(ArgumentError("sample rate is too low to distinguish the paper channel taps"))
    rng = Xoshiro(seed)
    phases = 2pi .* rand(rng, length(delays))
    amplitudes = 10.0 .^ (_PAPER_POWER_DB ./ 20.0)
    taps = zeros(ComplexF64, last(delays) + 1)
    taps[delays .+ 1] .= amplitudes .* cis.(phases)
    UWAChannelProfile(fs2, taps, delays, copy(_PAPER_POWER_DB))
end

function apply_multipath(x::AbstractVector{<:Number}, h::AbstractVector{<:Number})
    isempty(x) && throw(ArgumentError("channel input must not be empty"))
    isempty(h) && throw(ArgumentError("channel impulse response must not be empty"))
    y = zeros(ComplexF64, length(x) + length(h) - 1)
    @inbounds for i in eachindex(x), j in eachindex(h)
        y[i + j - 1] += ComplexF64(x[i]) * ComplexF64(h[j])
    end
    y
end

@inline function _linear_sample(x::AbstractVector{<:Number}, u::Float64)
    last_u = length(x) - 1
    0.0 <= u <= last_u || return 0.0 + 0.0im
    lo = floor(Int, u)
    hi = min(lo + 1, last_u)
    fraction = u - lo
    (1.0 - fraction) * ComplexF64(x[lo + 1]) + fraction * ComplexF64(x[hi + 1])
end

function apply_per_path_doppler(x::AbstractVector{<:Number},
                                h::AbstractVector{<:Number},
                                doppler_scales::AbstractVector{<:Real};
                                fs::Real,
                                fc::Real = 0.0,
                                sample_offset::Integer = 0)
    isempty(x) && throw(ArgumentError("channel input must not be empty"))
    isempty(h) && throw(ArgumentError("channel impulse response must not be empty"))
    length(doppler_scales) == length(h) ||
        throw(DimensionMismatch("one Doppler scale is required per channel tap"))
    fs2 = Float64(fs)
    fc2 = Float64(fc)
    isfinite(fs2) && fs2 > 0 ||
        throw(ArgumentError("sample rate must be finite and positive"))
    isfinite(fc2) || throw(ArgumentError("carrier frequency must be finite"))
    all(a -> isfinite(a), doppler_scales) ||
        throw(ArgumentError("Doppler scales must be finite"))

    y = zeros(ComplexF64, length(x) + length(h) - 1)
    @inbounds for n0 in 0:length(y)-1
        value = 0.0 + 0.0im
        for d0 in 0:length(h)-1
            tap = ComplexF64(h[d0 + 1])
            iszero(tap) && continue
            scale = Float64(doppler_scales[d0 + 1])
            source_time = (1.0 + scale) * (n0 - d0)
            sample = _linear_sample(x, source_time)
            iszero(sample) && continue
            carrier = iszero(fc2) ? 1.0 + 0.0im :
                      cis(2pi * fc2 * scale * (n0 + sample_offset) / fs2)
            value += tap * sample * carrier
        end
        y[n0 + 1] = value
    end
    y
end

function add_awgn(x::AbstractVector{<:Number}, snr_db::Real;
                  rng::AbstractRNG = Random.default_rng())
    isempty(x) && throw(ArgumentError("channel input must not be empty"))
    snr = Float64(snr_db)
    isfinite(snr) || throw(ArgumentError("SNR must be finite"))
    signal_power = mean(abs2, x)
    isfinite(signal_power) && signal_power > 0 ||
        throw(ArgumentError("channel input must have finite positive power"))
    noise_power = signal_power / 10.0^(snr / 10.0)
    sigma = sqrt(noise_power / 2.0)
    ComplexF64.(x) .+ sigma .* (randn(rng, length(x)) .+ im .* randn(rng, length(x)))
end

function apply_channel(x::AbstractVector{<:Number}, profile::UWAChannelProfile;
                       doppler_scales = zeros(length(profile.taps)),
                       fc::Real = 0.0,
                       sample_offset::Integer = 0,
                       snr_db::Union{Nothing,Real} = nothing,
                       rng::AbstractRNG = Random.default_rng())
    y = apply_per_path_doppler(
        x, profile.taps, doppler_scales;
        fs = profile.fs, fc = fc, sample_offset = sample_offset,
    )
    snr_db === nothing ? y : add_awgn(y, snr_db; rng = rng)
end

end # module SyntheticUWAChannel
