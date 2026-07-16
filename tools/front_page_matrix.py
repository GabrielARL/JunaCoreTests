#!/usr/bin/env python3
"""Generate the five-receiver measured-channel matrix in README.md."""

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


def tooltip(row: dict, config: dict) -> str:
    details = (
        f"profile={row['profile']}; N={config['nfft']}; CP={config['cp']}; "
        f"modem rate={row['modem_fs']} samples/s; capture rate={row['capture_fs']} samples/s; "
        f"packets={row['packets']}; seed={row['seed']}; "
        f"mean decode={float(row['mean_decode_seconds']):.4f} s; "
        f"bit errors={row['bit_errors']}/{row['payload_bits']}"
    )
    return html.escape(details, quote=True)


def render(repo: Path) -> str:
    sweep = rows(repo / "reports" / "all_channels_snr_sweep.csv")
    configs = rows(repo / "reports" / "paper_frame_wide_all_channels_full_20db.csv")
    by_key = {(row["channel"], int(float(row["snr_db"])), row["algorithm"]): row for row in sweep}
    required = {(config["channel"], snr, algorithm)
                for config in configs for snr in SNRS for algorithm in ALGORITHMS}
    missing = sorted(required - set(by_key))
    if missing:
        raise ValueError(f"incomplete receiver matrix; missing {missing[:5]}")

    lines = [BEGIN, "## Five-receiver comparison", "",
             "Headline values are **PSR / BER at 20 dB**. Hover over a cell for its "
             "configuration, sample rates, packet count, seed, decode time, and bit errors. "
             "Expand a site below the table to compare every SNR configuration.", "",
             "| site | " + " | ".join(HEADERS) + " |",
             "|---|" + "---:|" * len(HEADERS)]
    for config in configs:
        channel = config["channel"]
        cells = []
        for algorithm in ALGORITHMS:
            row = by_key[(channel, 20, algorithm)]
            cells.append(f'<abbr title="{tooltip(row, config)}">{value(row)}</abbr>')
        lines.append(f"| {config['label']} | " + " | ".join(cells) + " |")

    lines += ["", "### All configurations", ""]
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

    lines += ["PSR = packet-success rate. BER = payload bit-error rate. "
              "Source: [`reports/all_channels_snr_sweep.csv`](reports/all_channels_snr_sweep.csv).",
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
