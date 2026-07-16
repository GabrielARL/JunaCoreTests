#!/usr/bin/env python3
"""Generate GitHub-readable rankings from the SG-1 commit benchmark."""

import argparse
import csv
from pathlib import Path

JUNA_CORE_COMMITS = "https://github.com/GabrielARL/JunaCore.jl/commit"
CODE_RATE_LABELS = {
    0.0625: "1/16",
    0.125: "1/8",
    0.25: "1/4",
    0.5: "1/2",
}
RANKINGS = {
    "psr": {
        "filename": "sg1_20db_ranked_by_psr.md",
        "title": "Highest PSR",
        "description": "Packet-success rate descending.",
    },
    "ber": {
        "filename": "sg1_20db_ranked_by_ber.md",
        "title": "Lowest BER",
        "description": "Mean payload bit-error rate ascending.",
    },
    "rate": {
        "filename": "sg1_20db_ranked_by_rate.md",
        "title": "Highest effective data rate",
        "description": "Successful payload bits per full-capture second descending.",
    },
    "time": {
        "filename": "sg1_20db_ranked_by_time.md",
        "title": "Fastest decode",
        "description": "Mean public demodulation time per block ascending.",
    },
}


def load_history(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if not rows:
        raise ValueError("SG-1 commit history is empty")
    if any(row["status"] != "ok" for row in rows):
        raise ValueError("SG-1 commit history contains failed measurements")
    identities = {
        (
            row["juna_core_commit"],
            row["pilot_ratio"],
            row["code_rate"],
            row["nfft"],
            row["algorithm"],
        )
        for row in rows
    }
    if len(identities) != len(rows):
        raise ValueError("SG-1 commit history contains duplicate measurements")
    return rows


def numbers(row: dict) -> tuple[float, float, float, float]:
    return (
        float(row["psr"]),
        float(row["ber"]),
        1_000 * float(row["mean_decode_seconds_per_block"]),
        float(row["effective_data_rate_bps"]),
    )


def stable_identity(row: dict) -> tuple:
    return (
        row["juna_core_commit"],
        float(row["pilot_ratio"]),
        float(row["code_rate"]),
        int(row["nfft"]),
        row["algorithm"],
    )


def ranking_key(row: dict, metric: str) -> tuple:
    psr, ber, time_ms, rate_bps = numbers(row)
    identity = stable_identity(row)
    if metric == "psr":
        return (-psr, ber, -rate_bps, time_ms, identity)
    if metric == "ber":
        return (ber, -psr, -rate_bps, time_ms, identity)
    if metric == "rate":
        return (-rate_bps, -psr, ber, time_ms, identity)
    if metric == "time":
        return (time_ms, -psr, ber, -rate_bps, identity)
    raise ValueError(f"unsupported ranking metric: {metric}")


def code_rate_label(value: str) -> str:
    number = float(value)
    try:
        return CODE_RATE_LABELS[number]
    except KeyError as exception:
        raise ValueError(f"unsupported code rate: {value}") from exception


def render(rows: list[dict], metric: str) -> str:
    spec = RANKINGS[metric]
    ranked = sorted(rows, key=lambda row: ranking_key(row, metric))
    lines = [
        f"# SG-1 at 20 dB: {spec['title']}",
        "",
        f"{spec['description']} All {len(ranked)} measured receiver cells are "
        "shown. [Return to the main matrix](../README.md).",
        "",
        "| rank | JunaCore commit | Pilot Ratio | code rate | N | receiver | PSR | BER | decode (ms/block) | effective rate (bit/s) |",
        "|---:|---|---:|---:|---:|---|---:|---:|---:|---:|",
    ]
    for rank, row in enumerate(ranked, start=1):
        commit = row["juna_core_commit"]
        if len(commit) != 40:
            raise ValueError(
                f"JunaCore commit must be a full 40-character SHA: {commit}")
        psr, ber, time_ms, rate_bps = numbers(row)
        link = f"[`{commit[:7]}`]({JUNA_CORE_COMMITS}/{commit})"
        lines.append(
            f"| {rank} | {link} | {float(row['pilot_ratio']):.2f} | "
            f"{code_rate_label(row['code_rate'])} | {row['nfft']} | "
            f"{row['algorithm']} | {psr:.12g} | {ber:.12g} | "
            f"{time_ms:.12g} | {rate_bps:.12g} |"
        )
    return "\n".join(lines) + "\n"


def write_rankings(repo: Path, out_dir: Path) -> None:
    history = load_history(repo / "reports" / "sg1_20db_commit_history.csv")
    out_dir.mkdir(parents=True, exist_ok=True)
    for metric, spec in RANKINGS.items():
        path = out_dir / spec["filename"]
        path.write_text(render(history, metric), encoding="utf-8")
        print(f"wrote {metric} ranking to {path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=".")
    parser.add_argument("--out-dir", default="reports")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    out_dir = Path(args.out_dir)
    if not out_dir.is_absolute():
        out_dir = repo / out_dir
    write_rankings(repo, out_dir)


if __name__ == "__main__":
    main()
