#!/usr/bin/env julia
#
# Stage-by-stage differential contract for one ReplayCh-exported frame.
#
# This suite protects the diagnostic itself: representational differences are
# normalized before comparison, and the report names only the first genuine
# numerical or structural divergence.
#
# Run alone: julia --project=. test/rpchan_golden_comparison.jl

using Test

include(joinpath(@__DIR__, "..", "tools", "rpchan_golden_comparison.jl"))
using .RpchanGoldenComparison

@testset "golden comparator enters through the public JUNA-FrameRLS facade" begin
    comparator = read(joinpath(
        @__DIR__, "..", "tools", "compare_rpchan_golden_frame.jl"), String)
    @test occursin("JunaCore.JunaFrameRLS.Modulation(", comparator)
end

function synthetic_trace(; partial_delta=0.0, ldpc_length=8)
    passband = collect(range(-0.75, 0.75; length=24))
    active_bins = [2, 3, 7, 8]
    raw_full = ComplexF64[
        0  1+2im  3-1im  0  0  0  -2+im  1-im;
        0  2+4im  6-2im  0  0  0  -4+2im  2-2im;
    ]
    partial_active = raw_full[:, active_bins] ./ sqrt(8)
    partial_active[1, 2] += partial_delta
    equalized = ComplexF64[1+im, 1-im, -1+im, -1-im]
    llrs = Float64[2, 2, 2, -2, -2, 2, -2, -2]
    decoded = Bool[false, true, false, true]
    GoldenTrace(
        source="synthetic",
        passband=passband,
        acquisition_lag=13,
        active_bins=active_bins,
        partial_fft=partial_active,
        equalized=equalized,
        llrs=llrs,
        ldpc_output=decoded,
        fft_size=8,
        metadata=Dict("ldpc_n" => ldpc_length),
    )
end

@testset verbose = true "Real SG-1 exported-frame differential gate" begin
    if get(ENV, "JUNA_RPCHAN_GOLDEN", "0") != "1"
        @info "real golden comparison disabled; set JUNA_RPCHAN_GOLDEN=1"
        @test_skip true
    else
        repo_root = normpath(joinpath(@__DIR__, ".."))
        rpchan_root = abspath(get(
            ENV,
            "RPCHAN_ROOT",
            joinpath(homedir(), "Documents", "GitHub", "Rpchan"),
        ))
        @test isfile(joinpath(rpchan_root, "Project.toml"))
        mktempdir() do directory
            artifact = joinpath(directory, "sg1_frame.mat")
            report = joinpath(directory, "first_divergence.tsv")
            julia = Base.julia_cmd()
            exporter = joinpath(repo_root, "tools", "export_rpchan_golden_frame.jl")
            comparator = joinpath(repo_root, "tools", "compare_rpchan_golden_frame.jl")

            run(setenv(
                `$julia --project=$rpchan_root $exporter $artifact`,
                "RPCHAN_ROOT" => rpchan_root,
            ))
            run(`$julia --project=$repo_root $comparator $artifact $report`)

            contents = read(report, String)
            @test occursin("passband\tpass", contents)
            @test occursin("acquisition_lag\tpass", contents)
            @test occursin("partial_fft\tpass", contents)
            @test occursin("seed_equalized_symbols\tpass", contents)
            @test occursin("seed_llrs\tpass", contents)
            @test occursin("seed_ldpc_output\tpass", contents)
            @test occursin("equalized_symbols\tpass", contents)
            @test occursin("llrs\tpass", contents)
            @test occursin("ldpc_output\tpass", contents)
            @test occursin("first_divergence\tnone", contents)
        end
    end
end

@testset verbose = true "ReplayCh golden stage comparison" begin
    @testset "identical traces pass every stage" begin
        golden = synthetic_trace()
        actual = synthetic_trace()
        report = compare_traces(golden, actual)

        @test report.first_divergence === nothing
        @test all(stage.status == :pass for stage in report.stages)
        @test stage_result(report, :passband).max_abs == 0.0
        @test stage_result(report, :ldpc_output).status == :pass
    end

    @testset "full-bin partial FFT is normalized to ReplayCh active-bin convention" begin
        golden = synthetic_trace()
        actual = synthetic_trace()
        full_bins = zeros(ComplexF64, 2, 8)
        full_bins[:, golden.active_bins] .= golden.partial_fft .* sqrt(golden.fft_size)
        actual = with_stage(actual, :partial_fft, full_bins;
                            partial_fft_representation=:juna_full_unscaled)
        report = compare_traces(golden, actual)

        @test stage_result(report, :partial_fft).status == :pass
        @test report.first_divergence === nothing
    end

    @testset "the first genuine divergence blocks dependent comparisons" begin
        golden = synthetic_trace()
        actual = synthetic_trace(partial_delta=1e-2)
        report = compare_traces(golden, actual; atol=1e-10, rtol=1e-8)

        @test report.first_divergence == :partial_fft
        @test stage_result(report, :passband).status == :pass
        @test stage_result(report, :acquisition_lag).status == :pass
        @test stage_result(report, :partial_fft).status == :diverge
        @test stage_result(report, :equalized_symbols).status == :blocked
        @test stage_result(report, :llrs).status == :blocked
        @test stage_result(report, :ldpc_output).status == :blocked
    end

    @testset "an LDPC shape mismatch is reported as structural divergence" begin
        golden = synthetic_trace(ldpc_length=8)
        actual = synthetic_trace(ldpc_length=4)
        report = compare_traces(golden, actual)
        result = stage_result(report, :seed_ldpc_output)

        @test report.first_divergence == :seed_ldpc_output
        @test result.status == :structural_divergence
        @test occursin("ldpc_n", result.note)
        @test occursin("8", result.note)
        @test occursin("4", result.note)
    end
end
