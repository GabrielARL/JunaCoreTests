#!/usr/bin/env julia
#
# Replay-paper reproduction script contract.
#
# These checks keep the heavy measured-channel workflow runnable without making
# ordinary tests download data or decode the full replay captures.

using Test

const ReplayScriptRoot = normpath(joinpath(@__DIR__, ".."))
const ReplayScripts = joinpath(ReplayScriptRoot, "scripts", "replay")

function script_path(name)
    joinpath(ReplayScripts, name)
end

function script_output(name, args...)
    read(Cmd([script_path(name), args...]), String)
end

function make_fake_replay_workspace(dir)
    mkpath(joinpath(dir, "scripts", "workbench"))
    mkpath(joinpath(dir, "src"))
    mkpath(joinpath(dir, "tex"))

    write(joinpath(dir, "Makefile"), """
.PHONY: bootstrap sanity
bootstrap:
\t@echo bootstrap >> replay.log
sanity:
\t@echo sanity >> replay.log
""")
    run_all = joinpath(dir, "run_all.sh")
    write(run_all, """
#!/usr/bin/env bash
set -euo pipefail
echo "run_all:\${MODE:-unset}" >> replay.log
""")
    chmod(run_all, 0o755)

    write(joinpath(dir, "scripts", "workbench", "sweeps.jl"), "# fake sweeps entrypoint\n")
    write(joinpath(dir, "scripts", "workbench", "figures.py"), "# fake figure extractor\n")
    write(joinpath(dir, "src", "ReplayCh.jl"), "module ReplayCh\nend\n")
    write(joinpath(dir, "tex", "replay channel results juna.tex"), "% fake tex target\n")
    dir
end

@testset verbose = true "JUNA replay-paper reproduction scripts" begin
    expected_scripts = [
        "prepare_replay_workspace.sh",
        "run_replay_sanity.sh",
        "run_color_config_ber_sweep.sh",
        "build_juna_tex.sh",
        "reproduce_juna_tex_proxy.sh",
        "reproduce_juna_tex_full.sh",
    ]

    @testset "scripts are present, executable, and self-documenting" begin
        for name in expected_scripts
            path = script_path(name)
            @test isfile(path)
            @test Sys.isexecutable(path)

            help = script_output(name, "--help")
            @test occursin("Usage:", help)
            @test occursin("JUNA_REPLAY_WORKSPACE", help)
            @test occursin("--dry-run", help)
        end
    end

    @testset "dry-run commands match the sibling replay workflow" begin
        mktempdir() do fake_workspace
            prepare = script_output("prepare_replay_workspace.sh", "--dry-run",
                                    "--workspace", fake_workspace)
            @test occursin("make bootstrap", prepare)

            sanity = script_output("run_replay_sanity.sh", "--dry-run",
                                   "--workspace", fake_workspace)
            @test occursin("make sanity", sanity)

            ber_sweep = script_output("run_color_config_ber_sweep.sh", "--dry-run",
                                      "--workspace", fake_workspace)
            @test occursin("color_config_ber_sweep", ber_sweep)
            @test occursin("SWEEP_CHANNELS=red1,blue1,yellow1", ber_sweep)
            @test occursin("SWEEP_SNRS=0:5:30", ber_sweep)

            build = script_output("build_juna_tex.sh", "--dry-run", "--extract",
                                  "--workspace", fake_workspace,
                                  "--tex", "replay channel results juna.tex")
            @test occursin("figures.py extract_all_channels", build)
            @test occursin("pdflatex -interaction=nonstopmode -halt-on-error", build)
            @test occursin("replay channel results juna.tex", build)

            custom = withenv("JUNA_REPLAY_TEX" => "custom_juna.tex") do
                script_output("build_juna_tex.sh", "--dry-run",
                              "--workspace", fake_workspace)
            end
            @test occursin("custom_juna.tex", custom)

            proxy = script_output("reproduce_juna_tex_proxy.sh", "--dry-run",
                                  "--workspace", fake_workspace)
            @test occursin("MODE=proxy bash run_all.sh", proxy)
            @test occursin("build_juna_tex.sh", proxy) ||
                  occursin("pdflatex -interaction=nonstopmode -halt-on-error", proxy)

            full = script_output("reproduce_juna_tex_full.sh", "--dry-run",
                                 "--workspace", fake_workspace)
            @test occursin("MODE=full bash run_all.sh", full)
            @test occursin("pdflatex -interaction=nonstopmode -halt-on-error", full)
        end
    end

    @testset "real-mode replay helper reaches the requested workbench command" begin
        mktempdir() do fake_workspace
            make_fake_replay_workspace(fake_workspace)
            prepare = script_output("prepare_replay_workspace.sh",
                                    "--workspace", fake_workspace)
            log = read(joinpath(fake_workspace, "replay.log"), String)

            @test occursin("Replay workspace:", prepare)
            @test occursin("make bootstrap", prepare)
            @test occursin("Prepared replay workspace.", prepare)
            @test occursin("bootstrap", log)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA replay-paper reproduction script checks passed")
end
