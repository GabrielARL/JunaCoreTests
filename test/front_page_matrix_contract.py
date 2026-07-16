#!/usr/bin/env python3
import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tools" / "front_page_matrix.py"
SWEEP = ROOT / "reports" / "all_channels_snr_sweep.csv"
FRAME_WIDE = ROOT / "reports" / "paper_frame_wide_all_channels_stateful_full_20db.csv"
HISTORY = ROOT / "reports" / "sg1_20db_commit_history.csv"
RECEIVERS = ["Standard OFDM", "Partial FFT + FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
SITES = ["SG-1", "SG-2", "SG-3", "NA-1", "NA-2", "NA-3",
         "HW-1", "HW-2", "HW-3", "HW-4", "HW-5", "HW-6"]


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
                        text.index("Frame-wide LDPC vs paper target"))
        self.assertIn("not directly comparable", text)
        self.assertIn("modem rate equals the capture rate", text)
        self.assertIn("does not include JUNA Frame-wide LDPC", text)
        self.assertIn("| JunaCore commit | code rate | N | Standard OFDM | Partial FFT + FEC | JUNA-Lite | JUNA-Wz | JUNA-WCz |", text)
        for code_rate in ("1/16", "1/8", "1/4", "1/2"):
            self.assertIn(f"| {code_rate} |", text)
        for nfft in ("512", "1024", "2048"):
            self.assertIn(f"| 1/16 | {nfft} |", text)
        self.assertIn("60 measured cases", text)
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
        self.assertEqual(text.count('<details class="cell-details">'), history_count)
        self.assertEqual(text.count("Click a cell to reveal"), 1)
        self.assertNotIn("<abbr title=", text)
        self.assertIn("N: 1024<br>CP: 16", text)
        self.assertIn("modem rate: 19200", text)
        self.assertIn("mean decode:", text)
        self.assertIn("paper target rate", text)
        self.assertIn("ΔPSR", text)

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
        self.assertGreaterEqual(len(history_rows), 60)
        self.assertEqual(len(history_rows) % 60, 0)
        self.assertEqual({row["channel"] for row in history_rows}, {"red1"})
        self.assertEqual({row["snr_db"] for row in history_rows}, {"20"})
        self.assertEqual({row["nfft"] for row in history_rows},
                         {"512", "1024", "2048"})
        self.assertEqual({row["cp"] for row in history_rows}, {"16"})
        self.assertEqual({row["code_rate"] for row in history_rows},
                         {"0.0625", "0.125", "0.25", "0.5"})
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
        for commit in {row["juna_core_commit"] for row in history_rows}:
            for code_rate in ("0.0625", "0.125", "0.25", "0.5"):
                for nfft in ("512", "1024", "2048"):
                    commit_rows = [
                        row for row in history_rows
                        if row["juna_core_commit"] == commit and
                        row["code_rate"] == code_rate and
                        row["nfft"] == nfft
                    ]
                    self.assertEqual(len(commit_rows), 5)
                    self.assertEqual({row["algorithm"] for row in commit_rows},
                                     algorithms)
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


if __name__ == "__main__":
    unittest.main()
