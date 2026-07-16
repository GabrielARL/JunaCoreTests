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
        "Each receiver cell is "
        "**PSR / mean BER / mean decode time per block / effective data rate**. "
        "PSR is the fraction of payload-exact blocks; effective rate counts only "
        "successful payload blocks over the full capture duration. Click a cell to "
        "reveal the geometry, coverage, payload size, and bit errors.", "",
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


def render(repo: Path) -> str:
    sweep = rows(repo / "reports" / "all_channels_snr_sweep.csv")
    configs = rows(repo / "reports" / "paper_frame_wide_all_channels_stateful_full_20db.csv")
    history = rows(repo / "reports" / "sg1_20db_commit_history.csv")
    by_key = {(row["channel"], int(float(row["snr_db"])), row["algorithm"]): row for row in sweep}
    required = {(config["channel"], snr, algorithm)
                for config in configs for snr in SNRS for algorithm in ALGORITHMS}
    missing = sorted(required - set(by_key))
    if missing:
        raise ValueError(f"incomplete receiver matrix; missing {missing[:5]}")

    lines = [BEGIN, "## Commit-by-rate receiver performance", ""]
    lines += commit_history_table(history)
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
              "(reports/sg1_20db_commit_history.csv).",
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
