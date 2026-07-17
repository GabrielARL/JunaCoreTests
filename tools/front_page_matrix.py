#!/usr/bin/env python3
"""Generate the measured-channel performance section in README.md."""

import argparse
import csv
import html
from pathlib import Path

BEGIN = "<!-- juna:receiver-matrix:begin -->"
END = "<!-- juna:receiver-matrix:end -->"
ALGORITHMS = ["Standard OFDM", "Partial FFT+FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
HEADERS = ["Standard OFDM", "Partial FFT + FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
SNRS = [0, 5, 10, 15, 20, 25, 30]
JUNA_CORE_COMMITS = "https://github.com/GabrielARL/JunaCore.jl/commit"
CODE_RATES = (
    (0.0625, "1/16"),
    (0.125, "1/8"),
    (0.25, "1/4"),
    (0.5, "1/2"),
)
FFT_SIZES = (512, 1024, 2048)
PILOT_RATIOS = (0.25, 0.5, 0.75)


def rows(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def fmt_psr(value: str) -> str:
    return f"{float(value):.3f}"


def fmt_ber(value: str) -> str:
    number = float(value)
    return f"{number:.3f}" if number >= 0.001 else ("0" if number == 0 else f"{number:.1e}")


def value(row: dict) -> str:
    return f"{fmt_psr(row['psr'])} / {fmt_ber(row['ber'])}"


def bandwidth_items(row: dict) -> list[str]:
    policy = {
        "min_channel_modem": "min channel/modem",
        "legacy_uncapped": "legacy uncapped",
    }[row["bandwidth_policy"]]
    channel_bandwidth = float(row["channel_bandwidth_hz"])
    requested_bandwidth = float(row["requested_modem_bandwidth_hz"])
    effective_bandwidth = float(row["effective_bandwidth_hz"])
    return [
        f"bandwidth policy: {policy}",
        f"channel bandwidth: {channel_bandwidth:g} Hz",
        f"requested modem bandwidth: {requested_bandwidth:g} Hz",
        f"effective occupied bandwidth: {effective_bandwidth:g} Hz",
        f"effective normalized bw: {float(row['effective_bw']):g}",
    ]


def history_cell(row: dict) -> str:
    milliseconds = 1_000 * float(row["mean_decode_seconds_per_block"])
    effective_rate = float(row["effective_data_rate_bps"])
    summary = (f"{value(row)} / {milliseconds:.2f} ms / "
               f"{effective_rate:.1f} bit/s")
    items = [
        f"channel: SG-1 ({row['channel']})", f"SNR: {row['snr_db']} dB",
        f"requested pilot ratio: {float(row['pilot_ratio']):.2f}",
        "requested split: "
        f"inner={float(row['pilot_ratio']) / 2:g}, "
        f"outer={float(row['pilot_ratio']) / 2:g}",
        "actual combs: "
        f"inner=1/{row['inner_pilot_spacing']}, "
        f"outer=1/{row['outer_pilot_spacing']}",
        f"code rate: {code_rate_label(row['code_rate'])}",
        f"N: {row['nfft']}", f"CP: {row['cp']}",
        f"modem rate: {row['modem_fs']} samples/s",
        f"capture rate: {row['capture_fs']} samples/s",
        *bandwidth_items(row),
        f"blocks: {row['blocks']}", f"seed: {row['seed']}",
        f"mean decode: {milliseconds:.2f} ms/block",
        f"bit errors: {row['bit_errors']}/{row['payload_bits']}",
        f"capture duration: {float(row['capture_duration_seconds']):.3f} s",
        f"covered duration: {float(row['covered_duration_seconds']):.3f} s",
        f"effective data rate: {effective_rate:.1f} bit/s",
    ]
    details = "<br>".join(html.escape(item) for item in items)
    return ('<details class="cell-details"><summary>' + summary +
            '</summary><sub>' + details + '</sub></details>')


def frame_history_cell(row: dict) -> str:
    milliseconds = 1_000 * float(row["mean_decode_seconds_per_frame"])
    effective_rate = float(row["effective_data_rate_bps"])
    summary = (f"{value(row)} / {milliseconds:.2f} ms / "
               f"{effective_rate:.1f} bit/s")
    items = [
        f"channel: SG-1 ({row['channel']})", f"SNR: {row['snr_db']} dB",
        f"requested pilot ratio: {float(row['pilot_ratio']):.2f}",
        "requested split: "
        f"inner={float(row['pilot_ratio']) / 2:g}, "
        f"outer={float(row['pilot_ratio']) / 2:g}",
        "actual combs: "
        f"inner=1/{row['inner_pilot_spacing']}, "
        f"outer=1/{row['outer_pilot_spacing']}",
        f"code rate: {code_rate_label(row['code_rate'])}",
        f"N: {row['nfft']}", f"CP: {row['cp']}",
        f"frame geometry: {row['frame_blocks']} OFDM blocks/codeword",
        f"modem rate: {row['modem_fs']} samples/s",
        f"capture rate: {row['capture_fs']} samples/s",
        *bandwidth_items(row),
        f"frames: {row['frames']}", f"seed: {row['seed']}",
        f"mean decode: {milliseconds:.2f} ms/frame",
        f"bit errors: {row['bit_errors']}/{row['payload_bits']}",
        f"capture duration: {float(row['capture_duration_seconds']):.3f} s",
        f"covered duration: {float(row['covered_duration_seconds']):.3f} s",
        f"effective data rate: {effective_rate:.1f} bit/s",
    ]
    details = "<br>".join(html.escape(item) for item in items)
    return ('<details class="frame-cell-details"><summary>' + summary +
            '</summary><sub>' + details + '</sub></details>')


def rpchan_frame_cell(row: dict) -> str:
    milliseconds = 1_000 * float(row["mean_decode_seconds_per_frame"])
    effective_rate = float(row["effective_rate_bps"])
    summary = (
        f"pkt {fmt_psr(row['packet_psr'])} / "
        f"frm {fmt_psr(row['frame_psr'])} / {fmt_ber(row['ber'])} / "
        f"{milliseconds:.2f} ms / {effective_rate:.1f} bit/s"
    )
    items = [
        f"channel: SG-1 ({row['channel']})", f"SNR: {row['snr_db']} dB",
        "pinned pilots: outer=1/5 (0.20), inner=1/10 (0.10)",
        "code: Rpchan systematic frame LDPC",
        f"code rate: {float(row['fec_rate']):g}",
        f"check degree: {row['check_degree']}",
        f"N: {row['nfft']}", f"CP: {row['cp']}",
        f"frame geometry: {row['frame_blocks']} OFDM blocks/codeword",
        f"modem rate: {row['modem_fs']} samples/s",
        f"capture rate: {row['capture_fs']} samples/s",
        f"frames: {row['frames']}",
        f"packets accepted: {row['accepted_packets']}/{row['decoded_packets']}",
        f"exact frames: {row['successful_frames']}/{row['frames']}",
        f"seed: {row['seed']}",
        f"mean decode: {milliseconds:.2f} ms/frame",
        f"bit errors: {row['bit_errors']}/{row['payload_bits']}",
        f"effective data rate: {effective_rate:.1f} bit/s",
    ]
    details = "<br>".join(html.escape(item) for item in items)
    return ('<details class="rpchan-frame-cell-details"><summary>' + summary +
            '</summary><sub>' + details + '</sub></details>')


def code_rate_label(value: str) -> str:
    number = float(value)
    for expected, label in CODE_RATES:
        if number == expected:
            return label
    raise ValueError(f"unsupported commit-history code rate: {value}")


def frame_wide_table(configs: list[dict]) -> list[str]:
    if len(configs) != 12:
        raise ValueError(f"frame-wide report must contain 12 rows, got {len(configs)}")
    if any(row["status"] != "ok" for row in configs):
        failed = [row["channel"] for row in configs if row["status"] != "ok"]
        raise ValueError(f"frame-wide report contains failed rows: {failed}")
    if len({row["channel"] for row in configs}) != len(configs):
        raise ValueError("frame-wide report contains duplicate channels")

    lines = [
        "### JUNA Frame-wide LDPC vs paper target (20 dB, full capture)", "",
        "| site | channel | accepted | PSR | BER | rate (bit/s) | mean decode/frame | paper target PSR | paper target rate | ΔPSR |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in configs:
        delta = float(row["psr"]) - float(row["target_psr"])
        lines.append(
            f"| {row['label']} | `{row['channel']}` | "
            f"{row['accepted_packets']}/{row['decoded_packets']} | "
            f"**{fmt_psr(row['psr'])}** | {fmt_ber(row['ber'])} | "
            f"{float(row['effective_rate_bps']):.0f} | "
            f"{float(row['mean_decode_seconds']):.3f} s | "
            f"{fmt_psr(row['target_psr'])} | "
            f"{float(row['target_rate_bps']):.0f} | {delta:+.3f} |"
        )
    return lines


def commit_history_table(history: list[dict]) -> list[str]:
    grouped = {}
    commits = []
    for row in history:
        commit = row["juna_core_commit"]
        if commit not in commits:
            commits.append(commit)
        rate = float(row["code_rate"])
        pilot_ratio = float(row["pilot_ratio"])
        nfft = int(row["nfft"])
        code_rate_label(row["code_rate"])
        if pilot_ratio not in PILOT_RATIOS:
            raise ValueError(
                f"unsupported commit-history pilot ratio: {pilot_ratio}")
        if nfft not in FFT_SIZES:
            raise ValueError(f"unsupported commit-history FFT size: {nfft}")
        results = grouped.setdefault((commit, pilot_ratio, rate, nfft), {})
        if row["algorithm"] in results:
            raise ValueError(
                f"commit {commit[:7]} pilots {pilot_ratio} rate {rate} "
                f"N={nfft} contains duplicate "
                f"{row['algorithm']} results")
        results[row["algorithm"]] = row

    lines = [
        "This main comparison runs each configuration through the full 47-second "
        "SG-1 capture at 20 dB with seed 1. Each commit therefore records "
        f"{len(PILOT_RATIOS) * len(FFT_SIZES) * len(CODE_RATES) * len(ALGORITHMS)} "
        "measured cases. The requested Pilot Ratio values {0.25, 0.50, 0.75} "
        "are split equally between inner and outer pilots. JunaCore densities "
        "snap to realizable 1/k comb spacings, so each cell records the actual "
        "inner and outer spacing. The sweep uses N={512, 1024, 2048} with CP=16. "
        "For the latest commit, the occupied width is the smaller of the Red "
        "channel and modem bandwidths: "
        "min(19.2 kHz / 2, 1.0 x 19.2 kHz) = 9.6 kHz, so JunaCore uses bw=0.5. "
        "Historical rows retain their recorded bandwidth policy and values. "
        "Each receiver cell is "
        "**PSR / mean BER / mean decode time per block / effective data rate**. "
        "PSR is the fraction of payload-exact blocks; effective rate counts only "
        "successful payload blocks over the full capture duration. Click a cell to "
        "reveal the geometry, coverage, payload size, and bit errors.", "",
        "GitHub README tables are static. Rank all receiver cells using "
        "[highest PSR](reports/sg1_20db_ranked_by_psr.md), "
        "[lowest BER](reports/sg1_20db_ranked_by_ber.md), "
        "[highest effective rate](reports/sg1_20db_ranked_by_rate.md), or "
        "[fastest decode](reports/sg1_20db_ranked_by_time.md).", "",
        "| JunaCore commit | Pilot Ratio | code rate | N | " +
        " | ".join(HEADERS) + " |",
        "|---|---:|---:|---:|" + "---:|" * len(HEADERS),
    ]
    for commit in commits:
        if len(commit) != 40:
            raise ValueError(f"JunaCore commit must be a full 40-character SHA: {commit}")
        link = f"[`{commit[:7]}`]({JUNA_CORE_COMMITS}/{commit})"
        for pilot_ratio in PILOT_RATIOS:
            for rate, label in CODE_RATES:
                for nfft in FFT_SIZES:
                    results = grouped.get(
                        (commit, pilot_ratio, rate, nfft), {})
                    missing = sorted(set(ALGORITHMS) - set(results))
                    extra = sorted(set(results) - set(ALGORITHMS))
                    if missing or extra:
                        raise ValueError(
                            f"commit {commit[:7]} pilots {pilot_ratio:.2f} "
                            f"rate {label} N={nfft} has incomplete receiver "
                            f"results; missing={missing}, extra={extra}")
                    expected_spacing = {0.25: 8, 0.5: 4, 0.75: 3}[pilot_ratio]
                    if any(
                        row["channel"] != "red1" or
                        float(row["snr_db"]) != 20 or
                        int(row["blocks"]) < 1 or int(row["cp"]) != 16 or
                        int(row["nfft"]) != nfft or
                        float(row["pilot_ratio"]) != pilot_ratio or
                        int(row["outer_pilot_spacing"]) != expected_spacing or
                        int(row["inner_pilot_spacing"]) != expected_spacing
                        for row in results.values()
                    ):
                        raise ValueError(
                            f"commit {commit[:7]} pilots {pilot_ratio:.2f} "
                            f"rate {label} N={nfft} mixes benchmark "
                            "configurations")
                    if any(row["status"] != "ok" for row in results.values()):
                        raise ValueError(
                            f"commit {commit[:7]} pilots {pilot_ratio:.2f} "
                            f"rate {label} N={nfft} contains a failed benchmark")

                    cells = [
                        history_cell(results[algorithm])
                        for algorithm in ALGORITHMS
                    ]
                    lines.append(
                        f"| {link} | {pilot_ratio:.2f} | {label} | {nfft} | " +
                        " | ".join(cells) + " |")
    return lines


def frame_commit_history_table(history: list[dict]) -> list[str]:
    grouped = {}
    commits = []
    for row in history:
        commit = row["juna_core_commit"]
        if commit not in commits:
            commits.append(commit)
        rate = float(row["code_rate"])
        pilot_ratio = float(row["pilot_ratio"])
        nfft = int(row["nfft"])
        code_rate_label(row["code_rate"])
        if pilot_ratio not in PILOT_RATIOS:
            raise ValueError(
                f"unsupported frame-history pilot ratio: {pilot_ratio}")
        if nfft not in FFT_SIZES:
            raise ValueError(f"unsupported frame-history FFT size: {nfft}")
        results = grouped.setdefault((commit, pilot_ratio, rate, nfft), {})
        if row["algorithm"] in results:
            raise ValueError(
                f"frame commit {commit[:7]} pilots {pilot_ratio} rate {rate} "
                f"N={nfft} contains duplicate {row['algorithm']} results")
        results[row["algorithm"]] = row

    latest_commit = commits[-1]
    latest_rows = [
        row for row in history if row["juna_core_commit"] == latest_commit]
    latest_best_psr = max(float(row["psr"]) for row in latest_rows)
    latest_note = (
        f"For the latest commit `{latest_commit[:7]}`, the best frame PSR is "
        f"**{latest_best_psr:.3f}**."
    )
    if latest_best_psr == 0:
        latest_note += (
            " "
            "No complete ten-block frame was payload-exact, so effective data "
            "rate is also zero in every cell; BER remains the finer diagnostic."
        )

    lines = [
        "This table repeats the same 36 SG-1 geometries and five receiver names "
        "using true frame-level decoding. Here **10 OFDM blocks share one LDPC "
        "codeword** and one cross-block parity graph, giving 180 measured cases "
        "per commit. A frame succeeds only when its complete payload is exact. "
        "Each receiver cell is **PSR / mean BER / mean decode time per frame / "
        "effective data rate**; effective rate counts only successful full-frame "
        "payloads over the 47-second capture.", "",
        latest_note, "",
        "| JunaCore commit | Pilot Ratio | code rate | N | " +
        " | ".join(HEADERS) + " |",
        "|---|---:|---:|---:|" + "---:|" * len(HEADERS),
    ]
    for commit in commits:
        if len(commit) != 40:
            raise ValueError(
                f"JunaCore commit must be a full 40-character SHA: {commit}")
        link = f"[`{commit[:7]}`]({JUNA_CORE_COMMITS}/{commit})"
        for pilot_ratio in PILOT_RATIOS:
            for rate, label in CODE_RATES:
                for nfft in FFT_SIZES:
                    results = grouped.get(
                        (commit, pilot_ratio, rate, nfft), {})
                    missing = sorted(set(ALGORITHMS) - set(results))
                    extra = sorted(set(results) - set(ALGORITHMS))
                    if missing or extra:
                        raise ValueError(
                            f"frame commit {commit[:7]} pilots "
                            f"{pilot_ratio:.2f} rate {label} N={nfft} has "
                            f"incomplete receiver results; missing={missing}, "
                            f"extra={extra}")
                    expected_spacing = {0.25: 8, 0.5: 4, 0.75: 3}[pilot_ratio]
                    if any(
                        row["channel"] != "red1" or
                        float(row["snr_db"]) != 20 or
                        int(row["frames"]) < 1 or
                        int(row["frame_blocks"]) != 10 or
                        int(row["cp"]) != 16 or
                        int(row["nfft"]) != nfft or
                        float(row["pilot_ratio"]) != pilot_ratio or
                        int(row["outer_pilot_spacing"]) != expected_spacing or
                        int(row["inner_pilot_spacing"]) != expected_spacing
                        for row in results.values()
                    ):
                        raise ValueError(
                            f"frame commit {commit[:7]} pilots "
                            f"{pilot_ratio:.2f} rate {label} N={nfft} mixes "
                            "benchmark configurations")
                    if any(row["status"] != "ok" for row in results.values()):
                        raise ValueError(
                            f"frame commit {commit[:7]} pilots "
                            f"{pilot_ratio:.2f} rate {label} N={nfft} contains "
                            "a failed benchmark")

                    cells = [
                        frame_history_cell(results[algorithm])
                        for algorithm in ALGORITHMS
                    ]
                    lines.append(
                        f"| {link} | {pilot_ratio:.2f} | {label} | {nfft} | " +
                        " | ".join(cells) + " |")
    return lines


def rpchan_pinned_table(baseline: list[dict]) -> list[str]:
    if len(baseline) != len(ALGORITHMS):
        raise ValueError(
            f"pinned SG-1 baseline must contain five rows, got {len(baseline)}")
    by_algorithm = {row["algorithm"]: row for row in baseline}
    if len(by_algorithm) != len(baseline):
        raise ValueError("pinned SG-1 baseline contains duplicate algorithms")
    missing = sorted(set(ALGORITHMS) - set(by_algorithm))
    extra = sorted(set(by_algorithm) - set(ALGORITHMS))
    if missing or extra:
        raise ValueError(
            f"pinned SG-1 receiver set is incomplete; missing={missing}, extra={extra}")

    expected_profiles = {
        "Standard OFDM": "standard",
        "Partial FFT+FEC": "pfft",
        "JUNA-Lite": "lite",
        "JUNA-Wz": "full",
        "JUNA-WCz": "coupled",
    }
    commits = {row["juna_core_commit"] for row in baseline}
    if len(commits) != 1 or len(next(iter(commits))) != 40:
        raise ValueError("pinned SG-1 baseline needs one full JunaCore commit")
    for algorithm, row in by_algorithm.items():
        exact = (
            row["channel"] == "red1" and row["label"] == "SG-1" and
            row["profile"] == expected_profiles[algorithm] and
            int(row["receiver"]) == 3 and int(row["nfft"]) == 1024 and
            int(row["cp"]) == 16 and int(row["outer_spacing"]) == 5 and
            int(row["inner_spacing"]) == 10 and
            float(row["fec_rate"]) == 0.5 and
            int(row["check_degree"]) == 10 and
            float(row["modem_fs"]) == 9_600 and
            float(row["capture_fs"]) == 19_200 and
            float(row["snr_db"]) == 20 and int(row["seed"]) == 51_001 and
            int(row["frame_blocks"]) == 10 and
            int(row["decoded_packets"]) == 360 and
            int(row["frames"]) == 36 and row["status"] == "ok"
        )
        if not exact:
            raise ValueError(
                f"{algorithm} does not match the pinned SG-1 Rpchan contract")

    commit = next(iter(commits))
    link = f"[`{commit[:7]}`]({JUNA_CORE_COMMITS}/{commit})"
    cells = [rpchan_frame_cell(by_algorithm[algorithm])
             for algorithm in ALGORITHMS]
    return [
        "### Pinned SG-1 Rpchan baseline", "",
        "This is the exact paper configuration: **9.6 kHz modem / 19.2 kHz "
        "capture**, N=1024, CP=16, QPSK, rate-1/2 Rpchan frame LDPC with "
        "degree 10, outer 1/5, inner 1/10, passband replay, preamble "
        "acquisition, and Doppler search. One generated/noised sample vector "
        "feeds all five decoders per frame. Each cell is **packet PSR / "
        "exact-frame PSR / BER / mean decode time per frame / effective data "
        "rate**.", "",
        "| JunaCore commit | Pilot Ratio | code rate | N | " +
        " | ".join(HEADERS) + " |",
        "|---|---:|---:|---:|" + "---:|" * len(HEADERS),
        f"| {link} | 0.30 (outer 0.20, inner 0.10) | 1/2 | 1024 | " +
        " | ".join(cells) + " |",
    ]


def render(repo: Path) -> str:
    sweep = rows(repo / "reports" / "all_channels_snr_sweep.csv")
    configs = rows(repo / "reports" / "paper_frame_wide_all_channels_stateful_full_20db.csv")
    history = rows(repo / "reports" / "sg1_20db_commit_history.csv")
    frame_history = rows(
        repo / "reports" / "sg1_20db_frame_commit_history.csv")
    rpchan_baseline = rows(
        repo / "reports" / "sg1_rpchan_pinned_five_algorithms_20db.csv")
    by_key = {(row["channel"], int(float(row["snr_db"])), row["algorithm"]): row for row in sweep}
    required = {(config["channel"], snr, algorithm)
                for config in configs for snr in SNRS for algorithm in ALGORITHMS}
    missing = sorted(required - set(by_key))
    if missing:
        raise ValueError(f"incomplete receiver matrix; missing {missing[:5]}")

    lines = [BEGIN, "## Commit-by-rate receiver performance", ""]
    lines += commit_history_table(history)
    lines += ["", "## True frame-wide receiver performance", ""]
    lines += rpchan_pinned_table(rpchan_baseline)
    lines += ["", "### Generic geometry sweep", ""]
    lines += frame_commit_history_table(frame_history)
    lines += [
        "",
        "## Measured-channel performance", "",
        "The headline result is **JUNA Frame-wide LDPC** with Rpchan-compatible "
        "framing, pilots, code construction, preamble acquisition, and one LDPC "
        "codeword spanning each OFDM frame. Each row uses the channel's declared "
        "sample rate and its paper configuration at 20 dB.", "",
    ]
    lines += frame_wide_table(configs)
    lines += [
             "", "<details>",
             "<summary><b>Per-symbol receiver diagnostic sweep (different experiment)</b></summary>", "",
             "These values are **not directly comparable** with the frame-wide table. "
             "This diagnostic does not include JUNA Frame-wide LDPC: it sends ten "
             "independently coded packets per point through a shared known-waveform "
             "replay, uses oracle alignment, and the modem rate equals the capture rate "
             "instead of Rpchan's half-rate modem configuration. A packet succeeds only "
             "when every payload bit is correct, so the measured BER values naturally "
             "produce PSR 0/10 throughout this small diagnostic.", "",
             "### All per-symbol SNR configurations", ""]
    for config in configs:
        channel = config["channel"]
        lines += ["<details>",
                  f"<summary><b>{config['label']}</b> (<code>{channel}</code>) — "
                  f"N={config['nfft']}, CP={config['cp']}</summary>", "",
                  "| SNR | " + " | ".join(HEADERS) + " |",
                  "|---:|" + "---:|" * len(HEADERS)]
        for snr in SNRS:
            cells = [value(by_key[(channel, snr, algorithm)]) for algorithm in ALGORITHMS]
            lines.append(f"| {snr} dB | " + " | ".join(cells) + " |")
        lines += ["", "</details>", ""]

    lines += ["</details>", "",
              "PSR = packet-success rate. BER = payload bit-error rate. Sources: "
              "[`reports/paper_frame_wide_all_channels_stateful_full_20db.csv`]"
              "(reports/paper_frame_wide_all_channels_stateful_full_20db.csv) and "
              "[`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv). "
              "Commit history: [`reports/sg1_20db_commit_history.csv`]"
              "(reports/sg1_20db_commit_history.csv). Frame history: "
              "[`reports/sg1_20db_frame_commit_history.csv`]"
              "(reports/sg1_20db_frame_commit_history.csv). Pinned five-receiver "
              "baseline: [`reports/sg1_rpchan_pinned_five_algorithms_20db.csv`]"
              "(reports/sg1_rpchan_pinned_five_algorithms_20db.csv).",
              END]
    return "\n".join(lines)


def update(readme: Path, section: str) -> None:
    text = readme.read_text(encoding="utf-8")
    if BEGIN in text and END in text:
        before, rest = text.split(BEGIN, 1)
        _, after = rest.split(END, 1)
        text = before.rstrip() + "\n\n" + section + after
    else:
        text = text.rstrip() + "\n\n" + section + "\n"
    readme.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--readme", default="README.md")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    readme = Path(args.readme)
    if not readme.is_absolute():
        readme = repo / readme
    update(readme, render(repo))
    print(f"wrote receiver matrix to {readme}")


if __name__ == "__main__":
    main()
