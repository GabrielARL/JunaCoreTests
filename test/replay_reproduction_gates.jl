#!/usr/bin/env julia
#
# Replay-paper reproduction gates.
#
# These checks turn the measured-channel paper reproduction into explicit stages.
# Ordinary Pkg.test runs only the cheap structural gates. Real data and long
# ReplayCh runs are opt-in through the JUNA_REPLAY_* environment variables named
# in each testset and in test/README.md.
#
# Run structural gates:
#   julia --project=. test/runtests.jl replay-gates
#
# Run real workbench presence + ReplayCh load:
#   JUNA_REPLAY_WORKSPACE_CHECK=1 JUNA_REPLAY_LOAD=1 \
#     julia --project=. test/replay_reproduction_gates.jl

using Test
using TOML

const ReplayGateRoot = normpath(joinpath(@__DIR__, ".."))
const ReplayGateWorkspace = get(
    ENV, "JUNA_REPLAY_WORKSPACE",
    joinpath(homedir(), "Documents", "GitHub", "Juna_replay_channel_1ch"),
)
const ReplayGateTex = get(ENV, "JUNA_REPLAY_TEX", "replay channel results juna.tex")
const ReplayGateJulia = get(ENV, "JULIA", "julia")

include(joinpath(ReplayGateRoot, "tools", "replay_channel_download.jl"))
const ReplayGateDownload = ReplayChannelDownload

const ReplayGateExpectedChannels = [
    "red_1", "red_2", "red_3",
    "blue_1", "blue_2", "blue_3",
    "yellow_1", "yellow_2", "yellow_3", "yellow_4", "yellow_5", "yellow_6",
]

const ReplayGateWorkspaceFiles = [
    "Makefile",
    "run_all.sh",
    "src/ReplayCh.jl",
    "scripts/workbench/sweeps.jl",
    "scripts/workbench/figures.py",
]

const ReplayGateRuntimeFiles = [
    "scripts/workbench/packet_decoder.jl",
    "scripts/workbench/workbench_backend.jl",
    "src/ReplayCh/OFDM/ModemRuntime.jl",
    "src/ReplayCh/OFDM/ModemRuntime/functions/act_subc.jl",
    "src/ReplayCh/OFDM/ModemRuntime/functions/band_split.jl",
    "src/ReplayCh/OFDM/ModemRuntime/functions/bb_align.jl",
]

const ReplayGateExpectedFigureData = [
    "figure_data/tab_best.tex",
    "figure_data/tab_oat.tex",
    "figure_data/fixedcfg_psr20.dat",
    "figure_data/threemethod_winner20.dat",
    "figure_data/threemethod_red1_snr.dat",
    "figure_data/threemethod_blue1_snr.dat",
    "figure_data/interact_red1_n_cp.dat",
    "figure_data/interact_blue3_n_cp.dat",
    "figure_data/cir_SG1_heatmap.png",
    "figure_data/cir_NA1_heatmap.png",
    "figure_data/cir_HW1_heatmap.png",
]

truthy_env(name) = lowercase(strip(get(ENV, name, "0"))) in ("1", "true", "yes", "on")

replay_gate_script_path(name) = joinpath(ReplayGateRoot, "scripts", "replay", name)
tex_pdf_name() = replace(ReplayGateTex, r"\.tex$" => ".pdf")
report_pdf_path() = joinpath(ReplayGateRoot, "reports", "replay", "latest", tex_pdf_name())

function skip_replay_gate(env_name::AbstractString, detail::AbstractString)
    @info "$(detail); set $(env_name)=1"
    @test_skip true
end

function cmd_in(dir::AbstractString, args; env=())
    cmd = Cmd(Cmd(String.(collect(args))); dir=dir)
    isempty(env) ? cmd : addenv(cmd, env...)
end

cmd_text(args::AbstractString...; dir::AbstractString=ReplayGateRoot, env=()) =
    read(cmd_in(dir, collect(args); env=env), String)

function missing_workspace_files(workspace::AbstractString=ReplayGateWorkspace)
    required = vcat(ReplayGateWorkspaceFiles, ReplayGateRuntimeFiles,
                    ["tex/$(ReplayGateTex)"])
    [rel for rel in required if !isfile(joinpath(workspace, rel))]
end

function require_real_workspace()
    missing = missing_workspace_files()
    isempty(missing) || error("missing ReplayCh workbench files: " * join(missing, ", "))
    ReplayGateWorkspace
end

function write_fake_mat(path::AbstractString; bytes::Integer=2048)
    open(path, "w") do io
        write(io, "MATLAB 5.0 MAT-file")
        written = position(io)
        write(io, zeros(UInt8, max(0, bytes - written)))
    end
    path
end

function figure_data_refs(tex_path::AbstractString)
    text = read(tex_path, String)
    sort(unique(m.match for m in eachmatch(r"figure_data/[A-Za-z0-9_./-]+", text)))
end

function assert_png_signature(path::AbstractString)
    @test filesize(path) >= 8
    open(path, "r") do io
        @test read(io, 8) == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    end
end

function numeric_table(path::AbstractString)
    lines = filter(line -> !isempty(strip(line)) && !startswith(strip(line), "#"),
                   readlines(path))
    length(lines) >= 2 || error("numeric table has no rows: $(path)")
    header = split(strip(first(lines)))
    length(header) >= 2 || error("numeric table needs at least one value column: $(path)")

    rows = Dict{String, Dict{String, Float64}}()
    for line in lines[2:end]
        fields = split(strip(line))
        length(fields) == length(header) ||
            error("row has $(length(fields)) fields but header has $(length(header)): $(line)")
        rows[fields[1]] = Dict(header[i] => parse(Float64, fields[i]) for i in 2:length(header))
    end
    rows
end

function assert_unit_table(path::AbstractString)
    rows = numeric_table(path)
    @test !isempty(rows)
    for (_, cols) in rows, (_, value) in cols
        @test isfinite(value)
        @test 0.0 <= value <= 1.0
    end
    rows
end

function assert_replay_figure_artifacts(workspace::AbstractString=ReplayGateWorkspace;
                                        include_expected::Bool=true)
    tex_path = joinpath(workspace, "tex", ReplayGateTex)
    @test isfile(tex_path)
    refs = figure_data_refs(tex_path)
    if include_expected
        @test length(refs) >= 10
    else
        @test !isempty(refs)
    end

    checked_refs = include_expected ? unique(vcat(refs, ReplayGateExpectedFigureData)) : refs
    for rel in checked_refs
        path = joinpath(workspace, "tex", rel)
        @test isfile(path)
        if endswith(path, ".png")
            assert_png_signature(path)
        elseif endswith(path, ".dat")
            assert_unit_table(path)
        elseif endswith(path, ".tsv")
            @test length(filter(line -> !isempty(strip(line)), readlines(path))) >= 2
        elseif endswith(path, ".tex")
            @test occursin("\\begin{tabular}", read(path, String))
        end
    end
end

function log_chunk_after(logpath::AbstractString, before::Integer)
    isfile(logpath) || return ""
    open(logpath, "r") do io
        seek(io, min(before, filesize(logpath)))
        read(io, String)
    end
end

function run_workbench_mode(mode::AbstractString)
    require_real_workspace()
    logpath = joinpath(ReplayGateWorkspace, "logs", "run_all.log")
    before = isfile(logpath) ? filesize(logpath) : 0
    out = cmd_text("bash", "run_all.sh"; dir=ReplayGateWorkspace, env=("MODE" => mode,))
    chunk = log_chunk_after(logpath, before)
    @test !occursin("(rc=", chunk)
    @test !occursin("PAPER BUILD FAILED", chunk)
    out * "\n" * chunk
end

function run_proxy_sanity_text()
    require_real_workspace()
    cmd_text(
        ReplayGateJulia,
        "--threads=1",
        "--gcthreads=1",
        "--project=$(ReplayGateWorkspace)",
        "scripts/workbench/sweeps.jl",
        "proxy_sanity";
        dir=ReplayGateWorkspace,
    )
end

function run_repo_script(name::AbstractString, args::AbstractString...)
    run(cmd_in(ReplayGateRoot, [replay_gate_script_path(name), args...]))
end

function run_repo_script_checked(name::AbstractString, args::AbstractString...)
    require_real_workspace()
    logpath = joinpath(ReplayGateWorkspace, "logs", "run_all.log")
    before = isfile(logpath) ? filesize(logpath) : 0
    run_repo_script(name, args...)
    chunk = log_chunk_after(logpath, before)
    @test !occursin("(rc=", chunk)
    @test !occursin("PAPER BUILD FAILED", chunk)
    chunk
end

@testset verbose = true "Replay paper reproduction gates" begin
    @testset "1 repo boundary: JunaCore tests do not claim replay reproduction" begin
        readme = read(joinpath(ReplayGateRoot, "README.md"), String)
        test_readme = read(joinpath(ReplayGateRoot, "test", "README.md"), String)
        reproduction_doc = read(joinpath(ReplayGateRoot, "docs", "REPLAY_JUNA_TEX_REPRODUCTION.md"), String)
        project = TOML.parsefile(joinpath(ReplayGateRoot, "Project.toml"))
        deps = get(project, "deps", Dict{String,Any}())

        @test haskey(deps, "JunaCore")
        @test !haskey(deps, "ReplayCh")
        @test occursin("heavier measured-channel paper pipeline still lives", readme)
        @test occursin("Juna_replay_channel_1ch", readme)
        @test occursin("replay_reproduction_gates.jl", test_readme)
        @test occursin("known transmit waveform for oracle alignment", test_readme)
        @test occursin("does not decode", test_readme)
        @test occursin("paper tables", test_readme)
        @test occursin("JUNA_REPLAY_", test_readme)
        @test occursin("ReplayCh", reproduction_doc)
        @test occursin("Juna_replay_channel_1ch", reproduction_doc)
    end

    @testset "2 workbench presence: ReplayCh engine shape is explicit" begin
        mktempdir() do fake
            for rel in vcat(ReplayGateWorkspaceFiles, ReplayGateRuntimeFiles, ["tex/$(ReplayGateTex)"])
                path = joinpath(fake, rel)
                mkpath(dirname(path))
                write(path, "# fake $(rel)\n")
            end
            @test isempty(missing_workspace_files(fake))
        end

        if truthy_env("JUNA_REPLAY_WORKSPACE_CHECK")
            missing = missing_workspace_files()
            @test isempty(missing)
        else
            skip_replay_gate("JUNA_REPLAY_WORKSPACE_CHECK", "real workbench presence disabled")
        end
    end

    @testset "3 data integrity: channel set and MAT gates are explicit" begin
        @test collect(ReplayGateDownload.ALL_CHANNELS) == ReplayGateExpectedChannels
        @test ReplayGateDownload.parse_channel_list("red:1 blue-2 yellow_6") ==
              ["red_1", "blue_2", "yellow_6"]
        @test ReplayGateDownload.git_lfs_include(["red_1", "blue_3"]) ==
              "data/red_1.mat,data/blue_3.mat"

        mktempdir() do dir
            real_mat = write_fake_mat(joinpath(dir, "red_1.mat"); bytes=2048)
            pointer = joinpath(dir, "blue_1.mat")
            write(pointer, "version https://git-lfs.github.com/spec/v1\n")
            @test ReplayGateDownload.is_real_mat(real_mat; min_bytes=512)
            @test !ReplayGateDownload.is_real_mat(pointer; min_bytes=512)
        end

        if truthy_env("JUNA_REPLAY_DATA_CHECK")
            channels = ReplayGateDownload.parse_channel_list(get(ENV, "JUNA_REPLAY_CHANNELS", "all"))
            data_dir = get(ENV, "JUNA_REPLAY_DATA_DIR", joinpath(ReplayGateWorkspace, "data"))
            for ch in channels
                path = joinpath(data_dir, "$(ch).mat")
                @test ReplayGateDownload.is_real_mat(path)
            end
        else
            skip_replay_gate("JUNA_REPLAY_DATA_CHECK", "real replay data check disabled")
        end
    end

    @testset "4 ReplayCh load: the paper engine imports" begin
        if truthy_env("JUNA_REPLAY_LOAD")
            require_real_workspace()
            out = cmd_text(ReplayGateJulia, "--project=$(ReplayGateWorkspace)", "-e",
                           "using ReplayCh; println(\"ReplayCh: ok\")";
                           dir=ReplayGateWorkspace)
            @test occursin("ReplayCh: ok", out)
        else
            skip_replay_gate("JUNA_REPLAY_LOAD", "ReplayCh import disabled")
        end
    end

    @testset "5 smoke pipeline: red_1 one-frame workbench run" begin
        if truthy_env("JUNA_REPLAY_SMOKE")
            chunk = run_workbench_mode("smoke")
            @test occursin("MODE=smoke", chunk)
        else
            skip_replay_gate("JUNA_REPLAY_SMOKE", "smoke pipeline disabled")
        end
    end

    @testset "6 sanity decode: measured-channel short decode" begin
        if truthy_env("JUNA_REPLAY_SANITY")
            out = run_proxy_sanity_text()
            @test occursin(r"(?i)(juna|accepted|decoded|payload|psr|ber|acc/dec)", out)
            @test occursin("decoded frames on 12/12 channels", out)
        else
            skip_replay_gate("JUNA_REPLAY_SANITY", "sanity decode disabled")
        end
    end

    @testset "7 figure extractors: referenced paper artifacts are parseable" begin
        mktempdir() do fake
            figdir = joinpath(fake, "tex", "figure_data")
            mkpath(figdir)
            write(joinpath(fake, "tex", ReplayGateTex),
                  "\\input{figure_data/tab_best.tex}\n" *
                  "\\includegraphics{figure_data/cir_SG1_heatmap.png}\n" *
                  "\\addplot table[x=channel,y=juna]{figure_data/threemethod_winner20.dat};\n")
            write(joinpath(figdir, "tab_best.tex"), "\\begin{tabular}{cc}a&b\\\\\\end{tabular}\n")
            write(joinpath(figdir, "threemethod_winner20.dat"),
                  "channel ofdm partial juna\nred1 0.1 0.8 1.0\n")
            open(joinpath(figdir, "cir_SG1_heatmap.png"), "w") do io
                write(io, UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
                write(io, zeros(UInt8, 16))
            end

            @test figure_data_refs(joinpath(fake, "tex", ReplayGateTex)) == [
                "figure_data/cir_SG1_heatmap.png",
                "figure_data/tab_best.tex",
                "figure_data/threemethod_winner20.dat",
            ]
            assert_replay_figure_artifacts(fake; include_expected=false)
        end

        if truthy_env("JUNA_REPLAY_FIGURE_CHECK")
            require_real_workspace()
            assert_replay_figure_artifacts()
        else
            skip_replay_gate("JUNA_REPLAY_FIGURE_CHECK", "real figure artifact check disabled")
        end
    end

    @testset "8 TeX artifact: replay paper builds from figure_data" begin
        dry = cmd_text(replay_gate_script_path("build_juna_tex.sh"), "--dry-run")
        @test occursin("pdflatex -interaction=nonstopmode -halt-on-error", dry)
        @test occursin(ReplayGateTex, dry)

        if truthy_env("JUNA_REPLAY_TEX_BUILD")
            require_real_workspace()
            run_repo_script("build_juna_tex.sh", "--workspace", ReplayGateWorkspace,
                            "--tex", ReplayGateTex)
            @test isfile(report_pdf_path())
            @test filesize(report_pdf_path()) > 10_000
        else
            skip_replay_gate("JUNA_REPLAY_TEX_BUILD", "real TeX build disabled")
        end
    end

    @testset "9 proxy reproduction: all captures, one frame each" begin
        if truthy_env("JUNA_REPLAY_PROXY")
            run_repo_script_checked("reproduce_juna_tex_proxy.sh",
                                    "--workspace", ReplayGateWorkspace,
                                    "--tex", ReplayGateTex)
            @test isfile(report_pdf_path())
            @test filesize(report_pdf_path()) > 10_000
        else
            skip_replay_gate("JUNA_REPLAY_PROXY", "proxy reproduction disabled")
        end
    end

    @testset "10 single-segment result: sanity output has decode metrics" begin
        if truthy_env("JUNA_REPLAY_SEGMENT_CHECK")
            out = run_proxy_sanity_text()
            @test occursin(r"(?i)(juna|acc|dec|payload|psr|ber)", out)
            @test occursin("decoded frames on 12/12 channels", out)
            @test !occursin(r"(?i)(error|exception|failed)", out)
        else
            skip_replay_gate("JUNA_REPLAY_SEGMENT_CHECK", "single-segment result check disabled")
        end
    end

    @testset "11 paper table spot-check: selected PSR tables are sane" begin
        if truthy_env("JUNA_REPLAY_SPOTCHECK")
            require_real_workspace()
            figdir = joinpath(ReplayGateWorkspace, "tex", "figure_data")
            fixed = assert_unit_table(joinpath(figdir, "fixedcfg_psr20.dat"))
            three = assert_unit_table(joinpath(figdir, "threemethod_winner20.dat"))
            red_snr = assert_unit_table(joinpath(figdir, "threemethod_red1_snr.dat"))
            blue_snr = assert_unit_table(joinpath(figdir, "threemethod_blue1_snr.dat"))

            @test fixed["red1"]["winner"] >= fixed["red1"]["coldbase"]
            @test fixed["blue1"]["ownbest"] >= fixed["blue1"]["coldbase"]
            @test three["red1"]["juna"] >= three["red1"]["ofdm"]
            @test three["blue1"]["juna"] >= three["blue1"]["ofdm"]
            @test red_snr["20"]["juna"] >= red_snr["20"]["ofdm"]
            @test blue_snr["20"]["juna"] >= blue_snr["20"]["ofdm"]
        else
            skip_replay_gate("JUNA_REPLAY_SPOTCHECK", "paper table spot-check disabled")
        end
    end

    @testset "12 full reproduction: full-capture paper pipeline" begin
        if truthy_env("JUNA_REPLAY_FULL_REPRO")
            run_repo_script_checked("reproduce_juna_tex_full.sh",
                                    "--workspace", ReplayGateWorkspace,
                                    "--tex", ReplayGateTex)
            assert_replay_figure_artifacts()
            @test isfile(report_pdf_path())
            @test filesize(report_pdf_path()) > 10_000
        else
            skip_replay_gate("JUNA_REPLAY_FULL_REPRO", "full reproduction disabled")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("Replay-paper reproduction gate checks passed")
end
