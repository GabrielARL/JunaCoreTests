module ReplayChannelDownload

using Downloads
using Printf

export ALL_CHANNELS, channel_url, download_channel, download_channels,
       channel_path, git_lfs_include, is_real_mat, parse_channel_list

const DEFAULT_REPLAY_REPO = get(ENV, "JUNA_REPLAY_REPO", "https://github.com/GabrielARL/replaychan.git")
const DEFAULT_REPLAY_BRANCH = get(ENV, "JUNA_REPLAY_BRANCH", "main")
const DEFAULT_DIRECT_BASE_URL = get(ENV, "JUNA_REPLAY_DIRECT_BASE_URL", "")

const CHANNEL_INDEX_LIMITS = Dict(
    "red" => 3,
    "blue" => 3,
    "yellow" => 6,
)

const ALL_CHANNELS = Tuple(
    "$(color)_$(idx)"
    for color in ("red", "blue", "yellow")
    for idx in 1:CHANNEL_INDEX_LIMITS[color]
)

strip_trailing_slashes(s::AbstractString) = replace(String(s), r"/+$" => "")

function canonical_channel(raw)
    token = lowercase(strip(String(raw)))
    token = replace(token, ":" => "_", "-" => "_")
    m = match(r"^(red|blue|yellow)_(\d+)$", token)
    m === nothing && error("unknown replay channel '$(raw)'; expected red_1, blue_2, yellow_6, or all")
    color = String(m[1])
    idx = parse(Int, m[2])
    1 <= idx <= CHANNEL_INDEX_LIMITS[color] ||
        error("channel index out of range for $(color): $(idx)")
    "$(color)_$(idx)"
end

function parse_channel_list(raw)
    token = strip(String(raw))
    isempty(token) && return ["red_1"]
    lowercase(token) in ("all", "colors", "color") && return collect(ALL_CHANNELS)
    channels = canonical_channel.(filter(!isempty, split(token, r"[,\s]+")))
    unique(channels)
end

channel_path(channel) = "data/" * canonical_channel(channel) * ".mat"

function channel_url(channel; base_url=DEFAULT_DIRECT_BASE_URL)
    isempty(strip(String(base_url))) &&
        error("no direct MAT base URL configured; use git-LFS replaychan download or set JUNA_REPLAY_DIRECT_BASE_URL")
    strip_trailing_slashes(base_url) * "/" * canonical_channel(channel) * ".mat"
end

git_lfs_include(channels) = join(channel_path.(channels), ",")

function is_real_mat(path; min_bytes=1_000_000)
    isfile(path) && filesize(path) > min_bytes || return false
    open(path, "r") do io
        head = read(io, min(filesize(path), 128))
        hdf5 = length(head) >= 8 &&
            head[1:8] == UInt8[0x89, 0x48, 0x44, 0x46, 0x0d, 0x0a, 0x1a, 0x0a]
        hdf5 ||
            occursin("MATLAB", String(head[1:min(end, 116)]))
    end
end

function link_or_copy(src, dst)
    mkpath(dirname(dst))
    rm(dst; force=true)
    try
        symlink(abspath(src), dst)
    catch
        cp(src, dst; force=true)
    end
    dst
end

function ensure_git_lfs()
    Sys.which("git") !== nothing || error("git is required to fetch replay channel data")
    try
        run(pipeline(`git lfs version`; stdout=devnull, stderr=devnull))
    catch
        error("git-lfs is required to fetch replay channel data")
    end
end

function ensure_replay_repo(repo_dir; repo_url=DEFAULT_REPLAY_REPO, branch=DEFAULT_REPLAY_BRANCH)
    if !isdir(joinpath(repo_dir, ".git"))
        mkpath(dirname(repo_dir))
        @printf("Cloning replay data repo into %s\n", abspath(repo_dir))
        withenv("GIT_LFS_SKIP_SMUDGE" => "1") do
            run(`git clone --filter=blob:none --branch $branch $repo_url $repo_dir`)
        end
        run(pipeline(`git -C $repo_dir lfs install --local`; stdout=devnull, stderr=devnull))
    else
        run(`git -C $repo_dir fetch --depth=1 origin $branch`)
        run(`git -C $repo_dir checkout $branch`)
    end
    repo_dir
end

function direct_download_channel(channel; data_dir=joinpath(@__DIR__, "..", "data"),
                                 base_url=DEFAULT_DIRECT_BASE_URL, force=false,
                                 min_bytes=1_000_000)
    ch = canonical_channel(channel)
    mkpath(data_dir)
    dest = joinpath(data_dir, "$(ch).mat")
    if !force && is_real_mat(dest; min_bytes=min_bytes)
        return (channel=ch, path=abspath(dest), downloaded=false, bytes=filesize(dest), method="direct-cache")
    end

    url = channel_url(ch; base_url=base_url)
    tmp = dest * ".download"
    rm(tmp; force=true)
    @printf("Downloading %s from %s\n", ch, url)
    try
        Downloads.download(url, tmp)
        is_real_mat(tmp; min_bytes=min_bytes) ||
            error("downloaded file is too small to be a real channel MAT: $(filesize(tmp)) bytes")
        mv(tmp, dest; force=true)
        return (channel=ch, path=abspath(dest), downloaded=true, bytes=filesize(dest), method="direct")
    catch err
        rm(tmp; force=true)
        rethrow(err)
    end
end

function git_lfs_download_channels(channels; data_dir=joinpath(@__DIR__, "..", "data"),
                                   repo_dir=joinpath(data_dir, ".replaychan-lfs"),
                                   repo_url=DEFAULT_REPLAY_REPO,
                                   branch=DEFAULT_REPLAY_BRANCH,
                                   force=false,
                                   min_bytes=1_000_000)
    normalized = canonical_channel.(channels)
    mkpath(data_dir)

    ready = NamedTuple[]
    todo = String[]
    for ch in normalized
        dest = joinpath(data_dir, "$(ch).mat")
        if !force && is_real_mat(dest; min_bytes=min_bytes)
            push!(ready, (channel=ch, path=abspath(dest), downloaded=false,
                          bytes=filesize(dest), method="git-lfs-cache"))
        else
            push!(todo, ch)
        end
    end
    isempty(todo) && return ready

    ensure_git_lfs()
    repo = ensure_replay_repo(repo_dir; repo_url=repo_url, branch=branch)
    include_arg = git_lfs_include(todo)
    @printf("Fetching replay channel LFS objects: %s\n", include_arg)
    run(Cmd(["git", "-C", repo, "lfs", "pull", "--include=$(include_arg)", "--exclude="]))

    fetched = NamedTuple[]
    for ch in todo
        src = joinpath(repo, channel_path(ch))
        is_real_mat(src; min_bytes=min_bytes) ||
            error("git-lfs did not materialize $(channel_path(ch)); got $(isfile(src) ? filesize(src) : 0) bytes")
        dest = joinpath(data_dir, "$(ch).mat")
        link_or_copy(src, dest)
        push!(fetched, (channel=ch, path=abspath(dest), downloaded=true,
                        bytes=filesize(dest), method="git-lfs"))
    end
    vcat(ready, fetched)
end

function download_channel(channel; kwargs...)
    only(download_channels([channel]; kwargs...))
end

function download_channels(channels; method=get(ENV, "JUNA_REPLAY_DOWNLOAD_METHOD", "git-lfs"), kwargs...)
    normalized = canonical_channel.(channels)
    if method == "git-lfs"
        return git_lfs_download_channels(normalized; kwargs...)
    elseif method == "direct"
        return [direct_download_channel(ch; kwargs...) for ch in normalized]
    end
    error("unknown replay download method '$(method)'; expected git-lfs or direct")
end

function main(args=ARGS)
    raw = isempty(args) ? get(ENV, "JUNA_REPLAY_CHANNELS", "red_1") : join(args, " ")
    channels = parse_channel_list(raw)
    data_dir = get(ENV, "JUNA_REPLAY_DATA_DIR", joinpath(@__DIR__, "..", "data"))
    method = get(ENV, "JUNA_REPLAY_DOWNLOAD_METHOD", "git-lfs")
    force = get(ENV, "JUNA_REPLAY_FORCE", "0") == "1"

    @printf("Replay channel download target: %s\n", join(channels, ", "))
    @printf("Data directory: %s\n", abspath(data_dir))
    @printf("Download method: %s\n", method)
    for result in download_channels(channels; data_dir=data_dir, method=method, force=force)
        state = result.downloaded ? "downloaded" : "cached"
        @printf("  %-8s %-15s %-10s %.1f MB  %s\n",
                result.channel, result.method, state, result.bytes / 1_000_000, result.path)
    end
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    ReplayChannelDownload.main()
end
