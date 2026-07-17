#!/usr/bin/env python3
import csv
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools" / "front_page_matrix.py"
RANKING_GENERATOR = ROOT / "tools" / "generate_sg1_rankings.py"
SWEEP = ROOT / "reports" / "all_channels_snr_sweep.csv"
FRAME_WIDE = ROOT / "reports" / "paper_frame_wide_all_channels_stateful_full_20db.csv"
HISTORY = ROOT / "reports" / "sg1_20db_commit_history.csv"
FRAME_HISTORY = ROOT / "reports" / "sg1_20db_frame_commit_history.csv"
RPCHAN_BASELINE = ROOT / "reports" / "sg1_rpchan_pinned_five_algorithms_20db.csv"
RANKINGS = {
    "psr": ROOT / "reports" / "sg1_20db_ranked_by_psr.md",
    "ber": ROOT / "reports" / "sg1_20db_ranked_by_ber.md",
    "rate": ROOT / "reports" / "sg1_20db_ranked_by_rate.md",
    "time": ROOT / "reports" / "sg1_20db_ranked_by_time.md",
}
RECEIVERS = ["Standard OFDM", "Partial FFT + FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
SITES = ["SG-1", "SG-2", "SG-3", "NA-1", "NA-2", "NA-3",
         "HW-1", "HW-2", "HW-3", "HW-4", "HW-5", "HW-6"]


def ranked_rows(path):
    result = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not re.match(r"^\| \d+ \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        result.append({
            "rank": int(cells[0]),
            "commit": cells[1],
            "pilot_ratio": cells[2],
            "code_rate": cells[3],
            "nfft": cells[4],
            "algorithm": cells[5],
            "psr": float(cells[6]),
            "ber": float(cells[7]),
            "time_ms": float(cells[8]),
            "rate_bps": float(cells[9]),
        })
    return result


class FrontPageMatrixContract(unittest.TestCase):
    def test_generated_page_leads_with_commit_code_rate_performance(self):
        self.assertTrue(GENERATOR.is_file())
        with tempfile.TemporaryDirectory() as directory:
            readme = Path(directory) / "README.md"
            readme.write_text("# Test\n", encoding="utf-8")
            subprocess.run([sys.executable, str(GENERATOR), "--repo", str(ROOT),
                            "--readme", str(readme)], check=True)
            text = readme.read_text(encoding="utf-8")

        self.assertIn("## Measured-channel performance", text)
        self.assertIn("JUNA Frame-wide LDPC", text)
        self.assertIn("| SG-1 | `red1` | 360/360 | **1.000** | 0 |", text)
        self.assertIn("## Commit-by-rate receiver performance", text)
        self.assertLess(text.index("Commit-by-rate receiver performance"),
                        text.index("True frame-wide receiver performance"))
        self.assertLess(text.index("True frame-wide receiver performance"),
                        text.index("Frame-wide LDPC vs paper target"))
        self.assertIn("not directly comparable", text)
        self.assertIn("modem rate equals the capture rate", text)
        self.assertIn("does not include JUNA Frame-wide LDPC", text)
        self.assertIn("| JunaCore commit | Pilot Ratio | code rate | N | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |", text)
        for pilot_ratio in ("0.25", "0.50", "0.75"):
            self.assertIn(f"| {pilot_ratio} |", text)
        for code_rate in ("1/16", "1/8", "1/4", "1/2"):
            self.assertIn(f"| {code_rate} |", text)
        for nfft in ("512", "1024", "2048"):
            self.assertIn(f"| 0.25 | 1/16 | {nfft} |", text)
        self.assertIn("180 measured cases", text)
        self.assertIn("## True frame-wide receiver performance", text)
        self.assertTrue(RPCHAN_BASELINE.is_file())
        self.assertIn("### Pinned SG-1 Rpchan baseline", text)
        self.assertIn("9.6 kHz modem / 19.2 kHz capture", text)
        self.assertIn("outer 1/5, inner 1/10", text)
        self.assertIn("packet PSR / exact-frame PSR / BER", text)
        self.assertEqual(
            text.count('<details class="rpchan-frame-cell-details">'), 5)
        self.assertIn("10 OFDM blocks share one LDPC codeword", text)
        self.assertIn("PSR / mean BER / mean decode time per frame / effective data rate", text)
        self.assertEqual(
            text.count("| JunaCore commit | Pilot Ratio | code rate | N | "
                       "Standard OFDM | Partial FFT + FEC | JUNA-Lite | "
                       "JUNA-Wz | JUNA-WCz |"),
            3,
        )
        self.assertIn(
            "[highest PSR](reports/sg1_20db_ranked_by_psr.md)", text)
        self.assertIn(
            "[lowest BER](reports/sg1_20db_ranked_by_ber.md)", text)
        self.assertIn(
            "[highest effective rate](reports/sg1_20db_ranked_by_rate.md)",
            text,
        )
        self.assertIn(
            "[fastest decode](reports/sg1_20db_ranked_by_time.md)", text)
        self.assertIn("split equally between inner and outer pilots", text)
        self.assertIn("snap to realizable 1/k comb spacings", text)
        self.assertIn("full 47-second SG-1 capture", text)
        self.assertIn(
            "PSR / mean BER / mean decode time per block / effective data rate",
            text,
        )
        self.assertIn("0a2d927", text)
        self.assertIn("paper target PSR", text)
        self.assertIn("mean decode/frame", text)

        for receiver in RECEIVERS:
            self.assertIn(f"| {receiver} ", text)
        for site in SITES:
            self.assertEqual(text.count(f"<summary><b>{site}</b>"), 1)
            self.assertIn(f"| {site} |", text)
        with HISTORY.open(encoding="utf-8") as stream:
            history_count = sum(1 for _ in csv.DictReader(stream))
        with FRAME_HISTORY.open(encoding="utf-8") as stream:
            frame_history_count = sum(1 for _ in csv.DictReader(stream))
        self.assertEqual(text.count('<details class="cell-details">'),
                         history_count)
        self.assertEqual(text.count('<details class="frame-cell-details">'),
                         frame_history_count)
        self.assertEqual(text.count("Click a cell to reveal"), 1)
        self.assertNotIn("<abbr title=", text)
        self.assertIn("N: 1024<br>CP: 16", text)
        self.assertIn("requested pilot ratio: 0.25", text)
        self.assertIn("requested split: inner=0.125, outer=0.125", text)
        self.assertIn("actual combs: inner=1/8, outer=1/8", text)
        self.assertIn("modem rate: 19200", text)
        self.assertIn("channel bandwidth: 9600", text)
        self.assertIn("requested modem bandwidth: 19200", text)
        self.assertIn("effective occupied bandwidth: 9600", text)
        self.assertIn("effective normalized bw: 0.5", text)
        self.assertIn("bandwidth policy: min channel/modem", text)
        self.assertIn("bandwidth policy: legacy uncapped", text)
        self.assertIn("smaller of the Red channel and modem bandwidths", text)
        self.assertIn(
            "Historical rows retain their recorded bandwidth policy", text)
        self.assertIn("mean decode:", text)
        self.assertIn("mean decode: ", text)
        self.assertIn("ms/frame", text)
        self.assertIn("paper target rate", text)
        self.assertIn("ΔPSR", text)

    def test_ranked_views_are_complete_and_monotonic(self):
        self.assertTrue(RANKING_GENERATOR.is_file())
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(
                [
                    sys.executable,
                    str(RANKING_GENERATOR),
                    "--repo",
                    str(ROOT),
                    "--out-dir",
                    directory,
                ],
                check=True,
            )
            generated = {
                metric: Path(directory) / path.name
                for metric, path in RANKINGS.items()
            }
            for metric, committed in RANKINGS.items():
                self.assertTrue(committed.is_file())
                self.assertEqual(
                    generated[metric].read_text(encoding="utf-8"),
                    committed.read_text(encoding="utf-8"),
                )

        parsed = {metric: ranked_rows(path)
                  for metric, path in RANKINGS.items()}
        with HISTORY.open(encoding="utf-8") as stream:
            expected_count = sum(1 for _ in csv.DictReader(stream))
        for rows in parsed.values():
            self.assertEqual(len(rows), expected_count)
            self.assertEqual([row["rank"] for row in rows],
                             list(range(1, expected_count + 1)))

        def identities(rows):
            return {
                (
                    row["commit"], row["pilot_ratio"], row["code_rate"],
                    row["nfft"], row["algorithm"],
                )
                for row in rows
            }

        expected_identities = identities(parsed["psr"])
        self.assertEqual(len(expected_identities), expected_count)
        for rows in parsed.values():
            self.assertEqual(identities(rows), expected_identities)

        self.assertEqual(
            [row["psr"] for row in parsed["psr"]],
            sorted((row["psr"] for row in parsed["psr"]), reverse=True),
        )
        self.assertEqual(
            [row["ber"] for row in parsed["ber"]],
            sorted(row["ber"] for row in parsed["ber"]),
        )
        self.assertEqual(
            [row["rate_bps"] for row in parsed["rate"]],
            sorted(
                (row["rate_bps"] for row in parsed["rate"]), reverse=True),
        )
        self.assertEqual(
            [row["time_ms"] for row in parsed["time"]],
            sorted(row["time_ms"] for row in parsed["time"]),
        )

    def test_sources_have_complete_frame_wide_and_20db_matrices(self):
        with SWEEP.open(encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        at_20 = {(row["channel"], row["algorithm"]) for row in rows if row["snr_db"] == "20"}
        with FRAME_WIDE.open(encoding="utf-8") as stream:
            frame_rows = list(csv.DictReader(stream))
        channels = {row["channel"] for row in frame_rows}
        algorithms = {"Standard OFDM", "Partial FFT+FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"}
        self.assertEqual(at_20, {(channel, algorithm) for channel in channels for algorithm in algorithms})
        self.assertEqual(len(frame_rows), 12)
        self.assertTrue(all(row["status"] == "ok" for row in frame_rows))
        sg1 = next(row for row in frame_rows if row["label"] == "SG-1")
        self.assertEqual((sg1["accepted_packets"], sg1["decoded_packets"]),
                         ("360", "360"))
        self.assertEqual((sg1["psr"], sg1["ber"]), ("1", "0"))

        with HISTORY.open(encoding="utf-8") as stream:
            history_rows = list(csv.DictReader(stream))
        self.assertGreaterEqual(len(history_rows), 180)
        self.assertEqual(len(history_rows) % 180, 0)
        self.assertEqual({row["channel"] for row in history_rows}, {"red1"})
        self.assertEqual({row["snr_db"] for row in history_rows}, {"20"})
        self.assertEqual({row["nfft"] for row in history_rows},
                         {"512", "1024", "2048"})
        self.assertEqual({row["cp"] for row in history_rows}, {"16"})
        self.assertEqual({row["code_rate"] for row in history_rows},
                         {"0.0625", "0.125", "0.25", "0.5"})
        self.assertEqual({row["pilot_ratio"] for row in history_rows},
                         {"0.25", "0.5", "0.75"})
        self.assertEqual(
            {
                (row["pilot_ratio"], row["outer_pilot_spacing"],
                 row["inner_pilot_spacing"])
                for row in history_rows
            },
            {("0.25", "8", "8"), ("0.5", "4", "4"), ("0.75", "3", "3")},
        )
        self.assertTrue(all(int(row["blocks"]) > 400 for row in history_rows))
        self.assertTrue(all(47 < float(row["capture_duration_seconds"]) < 49
                            for row in history_rows))
        self.assertTrue(all(
            float(row["covered_duration_seconds"]) /
            float(row["capture_duration_seconds"]) > 0.99
            for row in history_rows
        ))
        self.assertTrue(all(len(row["juna_core_commit"]) == 40 for row in history_rows))
        self.assertTrue(all(float(row["mean_decode_seconds_per_block"]) > 0
                            for row in history_rows))
        self.assertEqual(
            {row["bandwidth_policy"] for row in history_rows},
            {"legacy_uncapped", "min_channel_modem"},
        )
        for row in history_rows:
            requested = float(row["requested_modem_bandwidth_hz"])
            channel = float(row["channel_bandwidth_hz"])
            effective = float(row["effective_bandwidth_hz"])
            normalized = float(row["effective_bw"])
            if row["bandwidth_policy"] == "min_channel_modem":
                self.assertEqual(effective, min(channel, requested))
            else:
                self.assertEqual(effective, requested)
            self.assertEqual(normalized, effective / float(row["modem_fs"]))
        for commit in {row["juna_core_commit"] for row in history_rows}:
            for pilot_ratio in ("0.25", "0.5", "0.75"):
                for code_rate in ("0.0625", "0.125", "0.25", "0.5"):
                    for nfft in ("512", "1024", "2048"):
                        commit_rows = [
                            row for row in history_rows
                            if row["juna_core_commit"] == commit and
                            row["pilot_ratio"] == pilot_ratio and
                            row["code_rate"] == code_rate and
                            row["nfft"] == nfft
                        ]
                        self.assertEqual(len(commit_rows), 5)
                        self.assertEqual(
                            {row["algorithm"] for row in commit_rows},
                            algorithms,
                        )
                        for row in commit_rows:
                            self.assertAlmostEqual(
                                float(row["psr"]),
                                int(row["successful_blocks"]) / int(row["blocks"]),
                            )
                            self.assertAlmostEqual(
                                float(row["ber"]),
                                int(row["bit_errors"]) / int(row["payload_bits"]),
                            )
                            payload_per_block = (
                                int(row["payload_bits"]) / int(row["blocks"])
                            )
                            self.assertAlmostEqual(
                                float(row["effective_data_rate_bps"]),
                                int(row["successful_blocks"]) * payload_per_block /
                                float(row["capture_duration_seconds"]),
                            )

        with FRAME_HISTORY.open(encoding="utf-8") as stream:
            frame_history = list(csv.DictReader(stream))
        self.assertGreaterEqual(len(frame_history), 180)
        self.assertEqual(len(frame_history) % 180, 0)
        self.assertEqual({row["frame_blocks"] for row in frame_history}, {"10"})
        self.assertEqual({row["pilot_ratio"] for row in frame_history},
                         {"0.25", "0.5", "0.75"})
        self.assertEqual({row["code_rate"] for row in frame_history},
                         {"0.0625", "0.125", "0.25", "0.5"})
        self.assertEqual({row["nfft"] for row in frame_history},
                         {"512", "1024", "2048"})
        self.assertEqual({row["algorithm"] for row in frame_history},
                         algorithms)
        self.assertTrue(all(row["status"] == "ok" for row in frame_history))
        self.assertEqual(
            {row["bandwidth_policy"] for row in frame_history},
            {"legacy_uncapped", "min_channel_modem"},
        )
        for commit in {row["juna_core_commit"] for row in frame_history}:
            self.assertEqual(
                sum(row["juna_core_commit"] == commit for row in frame_history),
                180,
            )
        for row in frame_history:
            requested = float(row["requested_modem_bandwidth_hz"])
            channel = float(row["channel_bandwidth_hz"])
            effective = float(row["effective_bandwidth_hz"])
            normalized = float(row["effective_bw"])
            if row["bandwidth_policy"] == "min_channel_modem":
                self.assertEqual(effective, min(channel, requested))
            else:
                self.assertEqual(effective, requested)
            self.assertEqual(normalized, effective / float(row["modem_fs"]))
            self.assertAlmostEqual(
                float(row["psr"]),
                int(row["successful_frames"]) / int(row["frames"]),
            )
            self.assertAlmostEqual(
                float(row["ber"]),
                int(row["bit_errors"]) / int(row["payload_bits"]),
            )
            payload_per_frame = (
                int(row["payload_bits"]) / int(row["frames"])
            )
            self.assertAlmostEqual(
                float(row["effective_data_rate_bps"]),
                int(row["successful_frames"]) * payload_per_frame /
                float(row["capture_duration_seconds"]),
            )


if __name__ == "__main__":
    unittest.main()
