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
CONFIG = ROOT / "reports" / "paper_frame_wide_all_channels_full_20db.csv"
RECEIVERS = ["Standard OFDM", "Partial FFT + FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"]
SITES = ["SG-1", "SG-2", "SG-3", "NA-1", "NA-2", "NA-3",
         "HW-1", "HW-2", "HW-3", "HW-4", "HW-5", "HW-6"]


class FrontPageMatrixContract(unittest.TestCase):
    def test_generated_matrix_is_complete_and_has_no_paper_target_columns(self):
        self.assertTrue(GENERATOR.is_file())
        with tempfile.TemporaryDirectory() as directory:
            readme = Path(directory) / "README.md"
            readme.write_text("# Test\n", encoding="utf-8")
            subprocess.run([sys.executable, str(GENERATOR), "--repo", str(ROOT),
                            "--readme", str(readme)], check=True)
            text = readme.read_text(encoding="utf-8")

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
        self.assertNotIn("paper target PSR", text)
        self.assertNotIn("paper target rate", text)
        self.assertNotIn("ΔPSR", text)

    def test_sources_have_a_complete_20db_matrix(self):
        with SWEEP.open(encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        at_20 = {(row["channel"], row["algorithm"]) for row in rows if row["snr_db"] == "20"}
        with CONFIG.open(encoding="utf-8") as stream:
            channels = {row["channel"] for row in csv.DictReader(stream)}
        algorithms = {"Standard OFDM", "Partial FFT+FEC", "JUNA-Lite", "JUNA-Wz", "JUNA-WCz"}
        self.assertEqual(at_20, {(channel, algorithm) for channel in channels for algorithm in algorithms})


if __name__ == "__main__":
    unittest.main()
