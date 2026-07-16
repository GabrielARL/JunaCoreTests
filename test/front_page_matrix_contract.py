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
RECEIVERS = ["Standard OFDM", "Partial FFT + FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
SITES = ["SG-1", "SG-2", "SG-3", "NA-1", "NA-2", "NA-3",
         "HW-1", "HW-2", "HW-3", "HW-4", "HW-5", "HW-6"]


class FrontPageMatrixContract(unittest.TestCase):
    def test_generated_page_leads_with_frame_wide_performance(self):
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
        self.assertLess(text.index("Frame-wide LDPC vs paper target"),
                        text.index("Per-symbol receiver diagnostic sweep"))
        self.assertIn("not directly comparable", text)
        self.assertIn("modem rate equals the capture rate", text)
        self.assertIn("does not include JUNA Frame-wide LDPC", text)
        self.assertIn("paper target PSR", text)
        self.assertIn("mean decode/frame", text)

        for receiver in RECEIVERS:
            self.assertIn(f"| {receiver} ", text)
        for site in SITES:
            self.assertEqual(text.count(f"<summary><b>{site}</b>"), 1)
            self.assertIn(f"| {site} |", text)
        self.assertEqual(text.count('<details class="cell-details">'), 12 * 5)
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


if __name__ == "__main__":
    unittest.main()
