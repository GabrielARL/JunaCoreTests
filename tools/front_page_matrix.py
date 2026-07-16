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


def cell_details(row: dict, config: dict) -> str:
    items = [
        f"profile: {row['profile']}", f"N: {config['nfft']}", f"CP: {config['cp']}",
        f"modem rate: {row['modem_fs']} samples/s",
        f"capture rate: {row['capture_fs']} samples/s",
        f"packets: {row['packets']}", f"seed: {row['seed']}",
        f"mean decode: {float(row['mean_decode_seconds']):.4f} s",
        f"bit errors: {row['bit_errors']}/{row['payload_bits']}",
    ]
    return "<br>".join(html.escape(item) for item in items)


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


def render(repo: Path) -> str:
    sweep = rows(repo / "reports" / "all_channels_snr_sweep.csv")
    configs = rows(repo / "reports" / "paper_frame_wide_all_channels_stateful_full_20db.csv")
    by_key = {(row["channel"], int(float(row["snr_db"])), row["algorithm"]): row for row in sweep}
    required = {(config["channel"], snr, algorithm)
                for config in configs for snr in SNRS for algorithm in ALGORITHMS}
    missing = sorted(required - set(by_key))
    if missing:
        raise ValueError(f"incomplete receiver matrix; missing {missing[:5]}")

    lines = [
        BEGIN,
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
             "### Five per-symbol receivers at 20 dB", "",
             "Each cell is **PSR / BER**. Click a cell to reveal its configuration, sample rates, "
             "packet count, seed, decode time, and bit errors.", "",
             "| site | " + " | ".join(HEADERS) + " |",
             "|---|" + "---:|" * len(HEADERS)]
    for config in configs:
        channel = config["channel"]
        cells = []
        for algorithm in ALGORITHMS:
            row = by_key[(channel, 20, algorithm)]
            cells.append('<details class="cell-details"><summary>' + value(row) +
                         '</summary><sub>' + cell_details(row, config) + '</sub></details>')
        lines.append(f"| {config['label']} | " + " | ".join(cells) + " |")

    lines += ["", "### All per-symbol SNR configurations", ""]
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
              "[`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv).",
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
