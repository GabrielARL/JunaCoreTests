module ReplayMatSchema

using Printf

export ReplayMatSchemaError, phase_key, schema_summary, validate_replay_mat_dict,
       load_replay_mat

struct ReplayMatSchemaError <: Exception
    message::String
end

Base.showerror(io::IO, err::ReplayMatSchemaError) = print(io, err.message)

fail(message) = throw(ReplayMatSchemaError(message))

function dict_has(d, key::AbstractString)
    haskey(d, key) || haskey(d, Symbol(key))
end

function dict_get(d, key::AbstractString)
    haskey(d, key) && return d[key]
    sym = Symbol(key)
    haskey(d, sym) && return d[sym]
    fail("missing key: $(key)")
end

function phase_key(data)
    dict_has(data, "phi_hat") && return "phi_hat"
    dict_has(data, "theta_hat") && return "theta_hat"
    fail("missing phase estimates: expected phi_hat or theta_hat")
end

function scalar_float(value, name)
    x = value
    if x isa AbstractArray
        length(x) == 1 || fail("$(name) must be a scalar, got array size $(size(x))")
        x = first(x)
    end
    x isa Number || fail("$(name) must be numeric, got $(typeof(x))")
    abs(imag(x)) <= eps(Float64) || fail("$(name) must be real-valued")
    y = Float64(real(x))
    isfinite(y) || fail("$(name) must be finite")
    y
end

positive_float(value, name) =
    (y = scalar_float(value, name); y > 0 || fail("$(name) must be positive"); y)

function sample_is_finite(array, name)
    n = min(length(array), 64)
    n == 0 && fail("$(name) must not be empty")
    values = vec(array)
    for idx in 1:n
        value = values[idx]
        value isa Number || fail("$(name) entries must be numeric")
        isfinite(real(value)) && isfinite(imag(value)) ||
            fail("$(name) entries must be finite")
    end
end

function validate_replay_mat_dict(data; receiver::Integer=1)
    dict_has(data, "h_hat") || fail("missing h_hat")
    dict_has(data, "params") || fail("missing params")

    h = dict_get(data, "h_hat")
    h isa AbstractArray || fail("h_hat must be an array")
    ndims(h) == 3 || fail("h_hat must be a 3-D tap x receiver x snapshot array")
    all(>(0), size(h)) || fail("h_hat dimensions must be nonzero")
    sample_is_finite(h, "h_hat")

    rx = Int(receiver)
    1 <= rx <= size(h, 2) || fail("receiver $(rx) is outside h_hat receiver dimension $(size(h, 2))")

    pk = phase_key(data)
    phase = dict_get(data, pk)
    phase isa AbstractArray || fail("$(pk) must be an array")
    ndims(phase) == 2 || fail("$(pk) must be a 2-D receiver x sample array")
    all(>(0), size(phase)) || fail("$(pk) dimensions must be nonzero")
    size(phase, 1) >= rx || fail("$(pk) has $(size(phase, 1)) receiver rows, need receiver $(rx)")
    sample_is_finite(phase, pk)

    params = dict_get(data, "params")
    dict_has(params, "fs_delay") || fail("params missing fs_delay")
    dict_has(params, "fc") || fail("params missing fc")
    dict_has(params, "fs_time") || fail("params missing fs_time")

    fs_delay = positive_float(dict_get(params, "fs_delay"), "params.fs_delay")
    fc = positive_float(dict_get(params, "fc"), "params.fc")
    fs_time = positive_float(dict_get(params, "fs_time"), "params.fs_time")
    step = round(Int, fs_delay / fs_time)
    step > 0 || fail("derived replay step must be positive")
    duration_s = (size(h, 3) - 1) * step / fs_delay
    duration_s > 0 || fail("derived replay duration must be positive")

    (
        phase_key = pk,
        h_size = size(h),
        phase_size = size(phase),
        receiver = rx,
        fs_delay_hz = fs_delay,
        fc_hz = fc,
        fs_time_hz = fs_time,
        step = step,
        duration_s = duration_s,
    )
end

function load_replay_mat(path::AbstractString)
    try
        @eval import MAT
    catch
        error("MAT.jl is required to read replay MAT files; run with the replay workbench project or add MAT to this project")
    end
    MAT.matread(path)
end

schema_summary(path::AbstractString; receiver::Integer=1) =
    validate_replay_mat_dict(load_replay_mat(path); receiver=receiver)

function parse_args(args)
    receiver = 1
    path = ""
    idx = 1
    while idx <= length(args)
        arg = args[idx]
        if arg == "--receiver"
            idx += 1
            idx <= length(args) || error("--receiver needs an integer")
            receiver = parse(Int, args[idx])
        elseif startswith(arg, "--receiver=")
            receiver = parse(Int, split(arg, "=", limit=2)[2])
        elseif arg in ("-h", "--help")
            println("usage: julia --project=<with MAT> tools/replay_mat_schema.jl <data/channel.mat> [--receiver N]")
            exit(0)
        elseif startswith(arg, "-")
            error("unknown option: $(arg)")
        elseif isempty(path)
            path = arg
        else
            error("unexpected extra path: $(arg)")
        end
        idx += 1
    end
    isempty(path) && error("missing replay MAT path")
    path, receiver
end

function main(args=ARGS)
    path, receiver = parse_args(args)
    summary = schema_summary(path; receiver=receiver)
    println("schema: ok")
    println("path: ", abspath(path))
    println("phase_key: ", summary.phase_key)
    println("h_size: ", summary.h_size)
    println("phase_size: ", summary.phase_size)
    @printf("fs_delay_hz: %.6g\n", summary.fs_delay_hz)
    @printf("fc_hz: %.6g\n", summary.fc_hz)
    @printf("fs_time_hz: %.6g\n", summary.fs_time_hz)
    println("step: ", summary.step)
    @printf("duration_s: %.6f\n", summary.duration_s)
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    ReplayMatSchema.main()
end
