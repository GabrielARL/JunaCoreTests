#!/usr/bin/env julia
#
# Source layout — one wrapper loads shared runtime and coupled receiver code.
#
# This is a packaging suite, not a physics suite. Its one theory link is that the
# paper's two implemented receivers (papers/main.tex, sec:solver, line 843) exist
# as distinct code paths, beside the test-gated JUNA-WCz receiver:
#   - JUNA-lite  (ssec:junalite, main.tex:1522)      -> _juna_lite_candidate in juna/lite.jl
#   - JUNA-Wz    (ssec:gradient-juna, main.tex:1622) -> _juna_wz_gradient_solve in juna/full.jl
#
# If this fails: package composition drifted, a runtime solver disappeared, or
# the coupled public path disappeared or bypassed its solver module.
#
# Run alone:  julia --project=. test/source_layout.jl
# Via runner: julia --project=. test/runtests.jl packaging

using Test
using JunaCore

const SOURCE_LAYOUT_ROOT = get(ENV, "JUNA_CORE_ROOT",
    normpath(joinpath(dirname(pathof(JunaCore)), "..")))
const SOURCE_LAYOUT_SRC = joinpath(SOURCE_LAYOUT_ROOT, "src")

@testset verbose = true "JUNA source layout" begin
    wrapper = joinpath(SOURCE_LAYOUT_SRC, "Juna.jl")
    common = joinpath(SOURCE_LAYOUT_SRC, "juna", "common.jl")
    lite = joinpath(SOURCE_LAYOUT_SRC, "juna", "lite.jl")
    full = joinpath(SOURCE_LAYOUT_SRC, "juna", "full.jl")

    @testset "files exist: wrapper + common/lite/full split" begin
        @test isfile(wrapper)
        @test isfile(common)
        @test isfile(lite)
        @test isfile(full)
    end

    @testset "wrapper wires all three parts" begin
        wrapper_text = read(wrapper, String)
        @test occursin("include(joinpath(@__DIR__, \"juna\", \"common.jl\"))", wrapper_text)
        @test occursin("include(joinpath(@__DIR__, \"juna\", \"lite.jl\"))", wrapper_text)
        @test occursin("include(joinpath(@__DIR__, \"juna\", \"full.jl\"))", wrapper_text)
    end

    # The text checks above pass even on commented-out code; these fail unless the
    # includes actually loaded and defined the receiver solvers.
    @testset "the split is real, loaded code" begin
        @test isdefined(JunaCore, :Juna)
        @test JunaCore.Juna.Modulation <: JunaCore.Modulations.Modulation
        @test ismutabletype(JunaCore.Juna.Modulation)
        @test isdefined(JunaCore.Juna, :_juna_lite_candidate)    # JUNA-lite solver
        @test isdefined(JunaCore.Juna, :_juna_wz_gradient_solve) # JUNA-Wz solver
    end

    @testset "each receiver solver lives in its own file" begin
        @test occursin("_juna_lite_candidate", read(lite, String))
        @test occursin("_juna_wz_gradient_solve", read(full, String))
        @test occursin("mutable struct Modulation", read(common, String))
    end

    @testset "coupled solver and public receiver are loaded beside Lite and Full" begin
        coupled = joinpath(SOURCE_LAYOUT_SRC, "juna", "coupled.jl")
        wrapper_text = read(wrapper, String)
        coupled_text = read(coupled, String)

        @test isfile(coupled)
        @test occursin("include(joinpath(@__DIR__, \"juna\", \"coupled.jl\"))", wrapper_text)
        @test isdefined(JunaCore.Juna, :_CoupledGradient)
        @test isdefined(JunaCore.Juna, :_coupled_objective_and_gradient!)
        @test occursin("struct _CoupledGradient", coupled_text)
        @test occursin("function _coupled_objective_and_gradient!", coupled_text)
        @test isdefined(JunaCore.Juna, :_coupled_wcz_solve)
        @test isdefined(JunaCore.Juna, :_juna_wcz_candidate)
        @test isdefined(JunaCore.Juna, :CoupledModulation)
        @test JunaCore.JunaCoupled.Modulation().mode === :coupled
        @test isfile(joinpath(SOURCE_LAYOUT_ROOT, "src", "juna", "frame_wide_ldpc.jl"))
        @test isdefined(JunaCore.Juna, :FrameWideLDPCModulation)
        @test JunaCore.JunaFrameWideLDPC.Modulation().mode === :frame_wide_ldpc
        @test isdefined(JunaCore.Juna, :FrameRLSModulation)
        @test !isdefined(JunaCore.Juna, :RpchanModulation)
        @test JunaCore.JunaFrameRLS.Modulation().mode === :frame_rls
        @test !isdefined(JunaCore, :JunaRpchan)
        @test names(JunaCore.JunaFrameRLS; all=false, imported=false) ==
              [:JunaFrameRLS, :Modulation]
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA source layout checks passed")
end
