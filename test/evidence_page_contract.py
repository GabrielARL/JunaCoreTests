#!/usr/bin/env python3
"""Contract for the static Evidence page (suite claims + latest results).

The Evidence page is the one-screen answer to "which suites exist, what does
each prove, and what happened last run". It is generated from two inputs only:
the suite registry in test/runtests.jl (keys, titles, claims) and a recorded
run in reports/evidence.json (per-suite assertion counts, provenance). The
page must stay honest: failed suites are flagged and listed first, opt-in
external-data suites read "gate off" with the enabling environment variable,
suites without a recorded run read "not run", and nothing is rendered as a
pass without a recorded passing run.
"""

import json
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GENERATOR = REPO / "tools" / "build_evidence_page.py"
EMITTER = REPO / "tools" / "emit_evidence.jl"
REGISTRY = REPO / "test" / "runtests.jl"
WORKFLOW = REPO / ".github" / "workflows" / "pages.yml"


def load_generator():
    spec = importlib.util.spec_from_file_location("build_evidence_page", GENERATOR)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FIXTURE = {
    "generated_at": "2026-07-20T07:00:00Z",
    "commit": "89b4781",
    "julia": "1.12.6",
    # the VAR=0 / auxiliary-path attack surface: these being "set" must not
    # flip any skipped suite to a pass — status comes from recorded skips
    "env_set": ["JUNA_RPCHAN_GOLDEN", "JUNA_REPLAY_DATA_DIR"],
    "suites": [
        {"key": "contract", "passes": 427, "fails": 0, "errors": 0,
         "broken": 0, "seconds": 41.2},
        {"key": "lite", "passes": 1290, "fails": 2, "errors": 0,
         "broken": 0, "seconds": 12.0},
        {"key": "golden-diff", "passes": 19, "fails": 0, "errors": 0,
         "broken": 1, "seconds": 0.3},
        {"key": "receiver-benchmark", "passes": 573, "fails": 0, "errors": 0,
         "broken": 2, "seconds": 98.6},
        {"key": "sizing", "passes": 0, "fails": 0, "errors": 0,
         "broken": 0, "seconds": 0.0},
    ],
}


class EvidencePageContract(unittest.TestCase):
    def setUp(self):
        self.assertTrue(GENERATOR.is_file(), "missing tools/build_evidence_page.py")
        self.gen = load_generator()

    def render_fixture(self, evidence=FIXTURE):
        with tempfile.TemporaryDirectory() as directory:
            evidence_path = Path(directory) / "evidence.json"
            evidence_path.write_text(json.dumps(evidence), encoding="utf-8")
            out = Path(directory) / "evidence.html"
            self.gen.main(["--registry", str(REGISTRY),
                           "--evidence", str(evidence_path),
                           "--out", str(out)])
            return out.read_text(encoding="utf-8")

    def test_registry_parser_finds_every_registered_suite(self):
        suites = self.gen.parse_registry(REGISTRY)
        keys = [s["key"] for s in suites]
        self.assertEqual(len(keys), len(set(keys)), "duplicate suite keys")
        self.assertGreaterEqual(len(keys), 40)
        for expected in ("contract", "golden-diff", "lite", "frame-wide-ldpc",
                         "replay-gates"):
            self.assertIn(expected, keys)
        for suite in suites:
            self.assertTrue(suite["claim"], f"suite {suite['key']} has no claim")
            self.assertTrue((REPO / "test" / suite["file"]).is_file(),
                            f"suite {suite['key']} file missing")

    def test_gate_detection_finds_true_enabling_switches(self):
        suites = self.gen.parse_registry(REGISTRY)
        gates = self.gen.detect_gates(REPO / "test", suites)
        self.assertIn("JUNA_RPCHAN_GOLDEN", gates["golden-diff"])
        self.assertIn("JUNA_RECEIVER_BENCHMARK_REAL", gates["receiver-benchmark"])
        self.assertIn("JUNA_REPLAY_DOWNLOAD", gates["replay-download"])
        # auxiliary path variables are not enabling switches
        self.assertNotIn("JUNA_REPLAY_DATA_DIR", gates["receiver-benchmark"])
        self.assertEqual(gates.get("lite", []), [])

    def test_page_reports_fixture_statuses_honestly(self):
        html = self.render_fixture()
        # data embed carries one entry per registered suite, real statuses
        payload = json.loads(html.split("/*EVIDENCE*/")[1])
        by_key = {s["key"]: s for s in payload["suites"]}
        registry_keys = {s["key"] for s in self.gen.parse_registry(REGISTRY)}
        self.assertEqual(set(by_key), registry_keys)
        self.assertEqual(by_key["contract"]["status"], "pass")
        self.assertEqual(by_key["contract"]["passes"], 427)
        self.assertEqual(by_key["lite"]["status"], "fail")
        # recorded skips keep the gate honest even though the fixture claims
        # JUNA_RPCHAN_GOLDEN is set (the VAR=0 attack) — skips are the truth
        self.assertEqual(by_key["golden-diff"]["status"], "gate")
        self.assertIn("JUNA_RPCHAN_GOLDEN", by_key["golden-diff"]["gate_env"])
        # auxiliary JUNA_REPLAY_DATA_DIR being set must not turn the skipped
        # benchmark lane green
        self.assertEqual(by_key["receiver-benchmark"]["status"], "gate")
        # a recorded run with zero executed assertions is not a pass
        self.assertEqual(by_key["sizing"]["status"], "notrun")
        # a registered suite with no recorded run and no gate is "not run"
        self.assertEqual(by_key["packaging"]["status"], "notrun")
        # the headline assertion KPI counts passing suites only
        self.assertEqual(payload["kpi_assertions"],
                         sum(s["passes"] for s in payload["suites"]
                             if s["status"] == "pass"))
        # claims are the page's primary text
        self.assertIn("every public receiver", html.lower())
        # provenance is visible
        self.assertIn("89b4781", html)
        self.assertIn("2026-07-20", html)

    def test_failed_suites_are_pinned_first(self):
        html = self.render_fixture()
        payload = json.loads(html.split("/*EVIDENCE*/")[1])
        statuses = [s["status"] for s in payload["suites"]]
        self.assertIn("fail", statuses)
        first_fail = statuses.index("fail")
        module_of = {s["key"]: s["module"] for s in payload["suites"]}
        lite_module = module_of["lite"]
        same_module = [s for s in payload["suites"] if s["module"] == lite_module]
        self.assertEqual(same_module[0]["status"], "fail",
                         "failed suite must lead its module group")
        self.assertGreaterEqual(first_fail, 0)

    def test_every_suite_lands_in_a_named_module_group(self):
        html = self.render_fixture()
        payload = json.loads(html.split("/*EVIDENCE*/")[1])
        self.assertNotIn("Other suites", payload["modules"],
                         "a registered suite is missing an explicit module group")
        for suite in payload["suites"]:
            self.assertIsInstance(suite["module"], int)
            self.assertLess(suite["module"], len(payload["modules"]))

    def test_page_is_self_contained(self):
        html = self.render_fixture()
        self.assertNotIn("src=\"http", html)
        self.assertNotIn("href=\"http", html.replace(
            "href=\"https://github.com/GabrielARL/", ""))
        self.assertNotIn("@import", html)

    def test_missing_evidence_renders_without_false_passes(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory) / "evidence.html"
            self.gen.main(["--registry", str(REGISTRY), "--out", str(out)])
            html = out.read_text(encoding="utf-8")
        payload = json.loads(html.split("/*EVIDENCE*/")[1])
        self.assertFalse([s for s in payload["suites"] if s["status"] == "pass"],
                         "no recorded run may render as a pass")

    def test_emitter_and_workflow_are_wired(self):
        self.assertTrue(EMITTER.is_file(), "missing tools/emit_evidence.jl")
        text = EMITTER.read_text(encoding="utf-8")
        self.assertIn("evidence.json", text)
        self.assertIn("roundtrip", text,
                      "emitter must honor the documented roundtrip selector")
        self.assertIn("JUNA_INTERFACE_ROUNDTRIP", text)
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("build_evidence_page.py", workflow,
                      "pages deploy must ship the evidence page")
        ondemand = (REPO / ".github" / "workflows" /
                    "on-demand-tests.yml").read_text(encoding="utf-8")
        for step_env in ("SUITES:", "JUNACORE_REF:"):
            self.assertIn(step_env, ondemand,
                          "dispatch inputs must be routed through env, not "
                          "interpolated into run scripts")

    def test_registry_parse_refuses_partial_matches(self):
        with tempfile.TemporaryDirectory() as directory:
            bad = Path(directory) / "runtests.jl"
            bad.write_text('''const SUITES = [
    (key = "good", file = "a.jl",
     title = "A", claim = "does a thing"),
    (key = "malformed", file = "b.jl",
     titl = "missing field", claim = "never parsed"),
]\n''', encoding="utf-8")
            with self.assertRaises(ValueError):
                self.gen.parse_registry(bad)


if __name__ == "__main__":
    unittest.main(verbosity=2)
