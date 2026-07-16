module RpchanGoldenComparison

using LinearAlgebra

export GoldenTrace, StageResult, ComparisonReport, compare_traces, stage_result,
       with_stage, print_report, write_report

const STAGE_ORDER = (
    :passband,
    :acquisition_lag,
    :partial_fft,
    :seed_equalized_symbols,
    :seed_llrs,
    :seed_ldpc_output,
    :equalized_symbols,
    :llrs,
    :ldpc_output,
)

Base.@kwdef struct GoldenTrace
    source::String
    passband::Vector{Float64}
    acquisition_lag::Int
    active_bins::Vector{Int}
    partial_fft::Array{ComplexF64}
    seed_equalized::Union{Nothing,Array{ComplexF64}} = nothing
    seed_llrs::Union{Nothing,Vector{Float64}} = nothing
    seed_ldpc_output::Union{Nothing,Vector{Bool}} = nothing
    equalized::Array{ComplexF64}
    llrs::Vector{Float64}
    ldpc_output::Vector{Bool}
    fft_size::Int
    partial_fft_representation::Symbol = :replay_active_scaled
    equalized_representation::Symbol = :replay_active
    metadata::Dict{String,Any} = Dict{String,Any}()
end

Base.@kwdef struct StageResult
    stage::Symbol
    status::Symbol
    max_abs::Float64 = NaN
    relative_l2::Float64 = NaN
    reference_shape::Tuple = ()
    actual_shape::Tuple = ()
    note::String = ""
end

struct ComparisonReport
    stages::Vector{StageResult}
    first_divergence::Union{Nothing,Symbol}
end

function with_stage(trace::GoldenTrace, stage::Symbol, value;
                    partial_fft_representation=trace.partial_fft_representation,
                    equalized_representation=trace.equalized_representation)
    values = Dict{Symbol,Any}(
        :source => trace.source,
        :passband => trace.passband,
        :acquisition_lag => trace.acquisition_lag,
        :active_bins => trace.active_bins,
        :partial_fft => trace.partial_fft,
        :seed_equalized => trace.seed_equalized,
        :seed_llrs => trace.seed_llrs,
        :seed_ldpc_output => trace.seed_ldpc_output,
        :equalized => trace.equalized,
        :llrs => trace.llrs,
        :ldpc_output => trace.ldpc_output,
        :fft_size => trace.fft_size,
        :metadata => trace.metadata,
    )
    field = stage === :seed_equalized_symbols ? :seed_equalized :
            stage === :seed_llrs ? :seed_llrs :
            stage === :seed_ldpc_output ? :seed_ldpc_output : stage
    haskey(values, field) || throw(ArgumentError("unknown golden stage $stage"))
    values[field] = value
    GoldenTrace(;
        source=String(values[:source]),
        passband=Float64.(values[:passband]),
        acquisition_lag=Int(values[:acquisition_lag]),
        active_bins=Int.(values[:active_bins]),
        partial_fft=ComplexF64.(values[:partial_fft]),
        seed_equalized=values[:seed_equalized] === nothing ? nothing :
            ComplexF64.(values[:seed_equalized]),
        seed_llrs=values[:seed_llrs] === nothing ? nothing :
            Float64.(values[:seed_llrs]),
        seed_ldpc_output=values[:seed_ldpc_output] === nothing ? nothing :
            Bool.(values[:seed_ldpc_output]),
        equalized=ComplexF64.(values[:equalized]),
        llrs=Float64.(values[:llrs]),
        ldpc_output=Bool.(values[:ldpc_output]),
        fft_size=Int(values[:fft_size]),
        partial_fft_representation=Symbol(partial_fft_representation),
        equalized_representation=Symbol(equalized_representation),
        metadata=Dict{String,Any}(values[:metadata]),
    )
end

stage_result(report::ComparisonReport, stage::Symbol) =
    only(filter(result -> result.stage === stage, report.stages))

function _array_error(reference, actual)
    reference_shape = size(reference)
    actual_shape = size(actual)
    reference_shape == actual_shape || return (
        status=:structural_divergence,
        max_abs=Inf,
        relative_l2=Inf,
        reference_shape,
        actual_shape,
        note="shape mismatch $(reference_shape) != $(actual_shape)",
    )
    isempty(reference) && return (
        status=:pass,
        max_abs=0.0,
        relative_l2=0.0,
        reference_shape,
        actual_shape,
        note="both stages are empty",
    )
    delta = actual .- reference
    max_abs = maximum(abs, delta)
    denominator = max(norm(reference), eps(Float64))
    (
        status=:candidate,
        max_abs,
        relative_l2=norm(delta) / denominator,
        reference_shape,
        actual_shape,
        note="",
    )
end

function _numeric_result(stage, reference, actual; atol, rtol, note="")
    error = _array_error(reference, actual)
    if error.status === :structural_divergence
        return StageResult(; stage, error...)
    end
    threshold = atol + rtol * (isempty(reference) ? 0.0 : maximum(abs, reference))
    status = error.max_abs <= threshold ? :pass : :diverge
    StageResult(
        stage=stage,
        status=status,
        max_abs=error.max_abs,
        relative_l2=error.relative_l2,
        reference_shape=error.reference_shape,
        actual_shape=error.actual_shape,
        note=note,
    )
end

function _normalize_partial(trace::GoldenTrace)
    representation = trace.partial_fft_representation
    representation === :replay_active_scaled && return trace.partial_fft
    representation === :juna_full_unscaled || throw(ArgumentError(
        "unknown partial-FFT representation $representation"))
    size(trace.partial_fft, 2) == trace.fft_size || throw(DimensionMismatch(
        "Juna full-bin partial FFT has $(size(trace.partial_fft, 2)) bins, expected $(trace.fft_size)"))
    maximum(trace.active_bins; init=0) <= trace.fft_size || throw(BoundsError(
        trace.partial_fft, (:, trace.active_bins)))
    selected = Any[Colon() for _ in 1:ndims(trace.partial_fft)]
    selected[2] = trace.active_bins
    trace.partial_fft[selected...] ./ sqrt(trace.fft_size)
end

function _normalize_equalized(trace::GoldenTrace; seed::Bool=false)
    values = seed && trace.seed_equalized !== nothing ?
        trace.seed_equalized : trace.equalized
    representation = trace.equalized_representation
    representation === :replay_active && return values
    representation === :juna_full_bins || throw(ArgumentError(
        "unknown equalized-symbol representation $representation"))
    size(values, 1) == trace.fft_size || throw(DimensionMismatch(
        "Juna equalized array has $(size(values, 1)) bins, expected $(trace.fft_size)"))
    values[trace.active_bins, :]
end

function _ldpc_structure(trace::GoldenTrace)
    keys = ("ldpc_n", "ldpc_blocks", "ldpc_block_n", "ldpc_block_k")
    Dict(key => trace.metadata[key] for key in keys if haskey(trace.metadata, key))
end

function _compare_ldpc(reference::GoldenTrace, actual::GoldenTrace;
                       seed::Bool=false)
    reference_structure = _ldpc_structure(reference)
    actual_structure = _ldpc_structure(actual)
    if reference_structure != actual_structure
        return StageResult(
            stage=seed ? :seed_ldpc_output : :ldpc_output,
            status=:structural_divergence,
            reference_shape=size(seed && reference.seed_ldpc_output !== nothing ?
                                 reference.seed_ldpc_output : reference.ldpc_output),
            actual_shape=size(seed && actual.seed_ldpc_output !== nothing ?
                              actual.seed_ldpc_output : actual.ldpc_output),
            note="LDPC structure mismatch: reference=$(reference_structure), actual=$(actual_structure)",
        )
    end
    reference_bits = seed && reference.seed_ldpc_output !== nothing ?
        reference.seed_ldpc_output : reference.ldpc_output
    actual_bits = seed && actual.seed_ldpc_output !== nothing ?
        actual.seed_ldpc_output : actual.ldpc_output
    _numeric_result(seed ? :seed_ldpc_output : :ldpc_output,
                    Int.(reference_bits), Int.(actual_bits);
                    atol=0.0, rtol=0.0)
end

function _blocked(stage, first_divergence)
    StageResult(
        stage=stage,
        status=:blocked,
        note="not compared because $first_divergence diverged first",
    )
end

function _implementation_note(reference::GoldenTrace, actual::GoldenTrace, key::String)
    reference_value = get(reference.metadata, key, nothing)
    actual_value = get(actual.metadata, key, nothing)
    reference_value === nothing && actual_value === nothing && return ""
    "reference=$(something(reference_value, "unspecified")); actual=$(something(actual_value, "unspecified"))"
end

"""
    compare_traces(reference, actual; atol=1e-10, rtol=1e-8)

Compare one frame in dependency order. Input samples and acquisition lag are
exact contracts. Partial FFTs are converted from Juna's full-bin unscaled form
to ReplayCh's active-bin `1/sqrt(N)` form before applying numeric tolerances.
Once a stage diverges, dependent stages are marked `:blocked` so the report
cannot obscure the root cause with downstream differences.
"""
function compare_traces(reference::GoldenTrace, actual::GoldenTrace;
                        atol::Real=1e-10, rtol::Real=1e-8)
    results = StageResult[]
    first_divergence = nothing
    for stage in STAGE_ORDER
        if first_divergence !== nothing
            push!(results, _blocked(stage, first_divergence))
            continue
        end

        result = if stage === :passband
            _numeric_result(stage, reference.passband, actual.passband;
                            atol=0.0, rtol=0.0,
                            note="exact immutable input sample contract")
        elseif stage === :acquisition_lag
            _numeric_result(stage, [reference.acquisition_lag], [actual.acquisition_lag];
                            atol=0.0, rtol=0.0)
        elseif stage === :partial_fft
            _numeric_result(stage, _normalize_partial(reference), _normalize_partial(actual);
                            atol=Float64(atol), rtol=Float64(rtol),
                            note="active-bin ordering and 1/sqrt(N) scale normalized")
        elseif stage === :seed_equalized_symbols
            _numeric_result(stage,
                            _normalize_equalized(reference; seed=true),
                            _normalize_equalized(actual; seed=true);
                            atol=Float64(atol), rtol=Float64(rtol),
                            note=_implementation_note(
                                reference, actual, "equalizer_contract"))
        elseif stage === :seed_llrs
            reference_llrs = reference.seed_llrs === nothing ?
                reference.llrs : reference.seed_llrs
            actual_llrs = actual.seed_llrs === nothing ? actual.llrs : actual.seed_llrs
            _numeric_result(stage, reference_llrs, actual_llrs;
                            atol=Float64(atol), rtol=Float64(rtol))
        elseif stage === :seed_ldpc_output
            _compare_ldpc(reference, actual; seed=true)
        elseif stage === :equalized_symbols
            _numeric_result(stage, _normalize_equalized(reference), _normalize_equalized(actual);
                            atol=Float64(atol), rtol=Float64(rtol),
                            note=_implementation_note(
                                reference, actual, "equalizer_contract"))
        elseif stage === :llrs
            _numeric_result(stage, reference.llrs, actual.llrs;
                            atol=Float64(atol), rtol=Float64(rtol))
        else
            _compare_ldpc(reference, actual)
        end
        push!(results, result)
        result.status in (:diverge, :structural_divergence) &&
            (first_divergence = stage)
    end
    ComparisonReport(results, first_divergence)
end

function print_report(io::IO, report::ComparisonReport)
    println(io, "stage\tstatus\tmax_abs\trelative_l2\tnote")
    for result in report.stages
        println(io, join((
            result.stage,
            result.status,
            result.max_abs,
            result.relative_l2,
            replace(result.note, '\t' => ' '),
        ), '\t'))
    end
    println(io, "first_divergence\t",
            something(report.first_divergence, "none"))
end

print_report(report::ComparisonReport) = print_report(stdout, report)

function write_report(path::AbstractString, report::ComparisonReport)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        print_report(io, report)
    end
    path
end

end
