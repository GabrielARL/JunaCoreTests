#!/usr/bin/env julia
#
# Replay-channel download contract - optional measured-channel fixture fetch.
#
# Inspired by Juna_replay_channel_1ch:
#   make bootstrap  -> git-LFS replaychan data (~6 GB)
#   make sanity     -> decode one short segment of every red/blue/yellow capture
#
# This smaller JunaCore bundle keeps the network/data step explicit. By default
# this suite only checks the channel naming, URL, and MAT signature/size
# contracts. To fetch real data, run:
#
#   JUNA_REPLAY_DOWNLOAD=1 JUNA_REPLAY_CHANNELS=red_1 julia --project=. test/replay_channel_download.jl
#
# For all 12 color channels, use JUNA_REPLAY_CHANNELS=all. That is about 6 GB.

using Test

const ReplayDownloadRoot = normpath(joinpath(@__DIR__, ".."))
include(joinpath(ReplayDownloadRoot, "tools", "replay_channel_download.jl"))
const ReplayDownload = ReplayChannelDownload

@testset verbose = true "JUNA replay-channel download contract" begin
    @testset "canonical color-channel set" begin
        @test length(ReplayDownload.ALL_CHANNELS) == 12
        @test ReplayDownload.ALL_CHANNELS[1:3] == ("red_1", "red_2", "red_3")
        @test ReplayDownload.ALL_CHANNELS[4:6] == ("blue_1", "blue_2", "blue_3")
        @test ReplayDownload.ALL_CHANNELS[7:end] ==
              ("yellow_1", "yellow_2", "yellow_3", "yellow_4", "yellow_5", "yellow_6")
    end

    @testset "user channel selection is normalized and bounded" begin
        @test ReplayDownload.parse_channel_list("") == ["red_1"]
        @test ReplayDownload.parse_channel_list("all") == collect(ReplayDownload.ALL_CHANNELS)
        @test ReplayDownload.parse_channel_list("red:1 blue-2,yellow_6") ==
              ["red_1", "blue_2", "yellow_6"]
        @test_throws ErrorException ReplayDownload.parse_channel_list("green_1")
        @test_throws ErrorException ReplayDownload.parse_channel_list("red_4")
    end

    @testset "git-LFS paths are scoped to replaychan/data" begin
        @test ReplayDownload.channel_path("red_1") == "data/red_1.mat"
        @test ReplayDownload.channel_path("yellow-6") == "data/yellow_6.mat"
        @test ReplayDownload.git_lfs_include(["red_1", "blue_2"]) ==
              "data/red_1.mat,data/blue_2.mat"
    end

    @testset "direct media URL is an explicit override, not the default path" begin
        @test_throws ErrorException ReplayDownload.channel_url("red_1"; base_url="")
        @test ReplayDownload.channel_url("yellow_6"; base_url="https://example.invalid/base/") ==
              "https://example.invalid/base/yellow_6.mat"
    end

    @testset "MAT fixture gate rejects placeholders and accepts MAT signatures" begin
        mktempdir() do dir
            missing = joinpath(dir, "missing.mat")
            empty = joinpath(dir, "empty.mat")
            pointer = joinpath(dir, "pointer.mat")
            zeros_only = joinpath(dir, "zeros_only.mat")
            mat_v5 = joinpath(dir, "mat_v5.mat")
            mat_hdf5 = joinpath(dir, "mat_hdf5.mat")

            write(empty, UInt8[])
            write(pointer, "version https://git-lfs.github.com/spec/v1\n")
            open(zeros_only, "w") do io
                write(io, zeros(UInt8, 1_000_002))
            end
            open(mat_v5, "w") do io
                header = rpad("MATLAB 5.0 MAT-file JUNA fixture", 128, ' ')
                write(io, codeunits(header))
                write(io, zeros(UInt8, 1_000_002))
            end
            open(mat_hdf5, "w") do io
                write(io, UInt8[0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a])
                write(io, zeros(UInt8, 1_000_122))
            end

            @test !ReplayDownload.is_real_mat(missing)
            @test !ReplayDownload.is_real_mat(empty)
            @test !ReplayDownload.is_real_mat(pointer)
            @test !ReplayDownload.is_real_mat(zeros_only)
            @test ReplayDownload.is_real_mat(mat_v5)
            @test ReplayDownload.is_real_mat(mat_hdf5)
        end
    end

    @testset "optional real web download" begin
        if get(ENV, "JUNA_REPLAY_DOWNLOAD", "0") == "1"
            channels = ReplayDownload.parse_channel_list(get(ENV, "JUNA_REPLAY_CHANNELS", "red_1"))
            data_dir = get(ENV, "JUNA_REPLAY_DATA_DIR", joinpath(ReplayDownloadRoot, "data"))
            results = ReplayDownload.download_channels(channels; data_dir=data_dir)
            @test length(results) == length(channels)
            for result in results
                @test result.channel in channels
                @test endswith(result.path, result.channel * ".mat")
                @test ReplayDownload.is_real_mat(result.path)
                @test result.bytes > 1_000_000
                @test result.method in ("git-lfs", "git-lfs-cache", "direct", "direct-cache")
            end
        else
            @info "real channel download disabled; set JUNA_REPLAY_DOWNLOAD=1 and JUNA_REPLAY_CHANNELS=red_1 or all"
            @test_skip true
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    println("JUNA replay-channel download contract checks passed")
end
