#!/usr/bin/env julia
#
# Replay MAT schema contract - acceptance item 2 from the replay segment-decode
# proposal. Default tests use small in-memory dictionaries. Real MAT inspection is
# opt-in so ordinary tests do not download data or add MAT.jl to the core package.

using Test

const ReplaySchemaRoot = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ReplaySchemaRoot, "tools", "replay_mat_schema.jl"))
const Schema = ReplayMatSchema

function good_replay_dict(; phase_key="phi_hat", receivers=2, snapshots=6)
    Dict{String,Any}(
        "h_hat" => fill(1.0 + 0.25im, 4, receivers, snapshots),
        phase_key => fill(0.1, receivers, 256),
        "params" => Dict{String,Any}(
            "fs_delay" => 24_000.0,
            "fc" => 25_000.0,
            "fs_time" => 100.0,
        ),
    )
end

@testset verbose = true "JUNA replay MAT schema contract" begin
    @testset "valid replay-channel dictionaries match the sibling reader schema" begin
        summary = Schema.validate_replay_mat_dict(good_replay_dict(); receiver=1)
        @test summary.phase_key == "phi_hat"
        @test summary.h_size == (4, 2, 6)
        @test summary.phase_size == (2, 256)
        @test summary.receiver == 1
        @test summary.fs_delay_hz == 24_000.0
        @test summary.fc_hz == 25_000.0
        @test summary.fs_time_hz == 100.0
        @test summary.step == 240
        @test summary.duration_s == 0.05

        theta_summary = Schema.validate_replay_mat_dict(
            good_replay_dict(phase_key="theta_hat");
            receiver=2,
        )
        @test theta_summary.phase_key == "theta_hat"
        @test theta_summary.receiver == 2
    end

    @testset "schema failures name the missing or malformed replay field" begin
        missing_h = good_replay_dict()
        delete!(missing_h, "h_hat")
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(missing_h)

        missing_phase = good_replay_dict()
        delete!(missing_phase, "phi_hat")
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(missing_phase)

        bad_h = good_replay_dict()
        bad_h["h_hat"] = ones(ComplexF64, 4, 2)
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(bad_h)

        bad_receiver = good_replay_dict(receivers=1)
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(bad_receiver; receiver=2)

        bad_phase = good_replay_dict()
        bad_phase["phi_hat"] = ones(1, 256)
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(bad_phase; receiver=2)

        missing_param = good_replay_dict()
        delete!(missing_param["params"], "fs_time")
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(missing_param)

        bad_step = good_replay_dict()
        bad_step["params"]["fs_time"] = 1.0e9
        @test_throws Schema.ReplayMatSchemaError Schema.validate_replay_mat_dict(bad_step)
    end

    @testset "optional real downloaded MAT schema check" begin
        if get(ENV, "JUNA_REPLAY_SCHEMA", "0") == "1"
            include(joinpath(ReplaySchemaRoot, "tools", "replay_channel_download.jl"))
            channel = only(ReplayChannelDownload.parse_channel_list(get(ENV, "JUNA_REPLAY_CHANNEL", "red_1")))
            data_dir = get(ENV, "JUNA_REPLAY_DATA_DIR", joinpath(ReplaySchemaRoot, "data"))

            if get(ENV, "JUNA_REPLAY_DOWNLOAD", "0") == "1"
                ReplayChannelDownload.download_channel(channel; data_dir=data_dir)
            end

            mat_path = joinpath(data_dir, "$(channel).mat")
            @test ReplayChannelDownload.is_real_mat(mat_path)

            project = get(ENV, "JUNA_REPLAY_SCHEMA_PROJECT",
                          get(ENV, "JUNA_REPLAY_WORKSPACE",
                              joinpath(homedir(), "Documents", "GitHub", "Juna_replay_channel_1ch")))
            @test isfile(joinpath(project, "Project.toml"))

            out = read(Cmd(["julia", "--project=$(project)",
                            joinpath(ReplaySchemaRoot, "tools", "replay_mat_schema.jl"),
                            mat_path]), String)
            @test occursin("schema: ok", out)
            @test occursin("phase_key:", out)
            @test occursin("h_size:", out)
        else
            @info "real MAT schema check disabled; set JUNA_REPLAY_SCHEMA=1 and provide/download data/<channel>.mat"
            @test_skip true
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA replay MAT schema contract checks passed")
end
