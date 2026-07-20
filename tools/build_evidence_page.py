#!/usr/bin/env python3
"""Build the static Evidence page: every suite, its claim, its latest result.

Inputs are the suite registry in test/runtests.jl (keys, titles, claims) and
an optional recorded run in reports/evidence.json written by
tools/emit_evidence.jl. The page is one self-contained HTML file suitable for
GitHub Pages or the local workbench. Honesty rules: a suite renders as a pass
only with a recorded passing run; failed suites are flagged and lead their
group; opt-in external-data suites render "gate off" with the enabling
environment variable; everything else is "not run".
"""

import argparse
import json
import re
from pathlib import Path

SUITE_RE = re.compile(
    r"""\(\s*key\s*=\s*"(?P<key>[^"]+)"\s*,\s*
        file\s*=\s*"(?P<file>[^"]+)"\s*,\s*
        title\s*=\s*"(?P<title>[^"]+)"\s*,\s*
        claim\s*=\s*"(?P<claim>(?:[^"\\]|\\.)*)"\s*,\s*
        (?:paper\s*=\s*"(?P<paper>(?:[^"\\]|\\.)*)"\s*,?\s*)?\)""",
    re.VERBOSE | re.DOTALL)

# A gate switch is a variable the suite compares against "1" to enable its
# expensive opt-in portion — auxiliary path/config variables never match.
SWITCH_RE = re.compile(
    r"""get\(ENV,\s*"(JUNA_[A-Z0-9_]+)",\s*"[^"]*"\)\s*[!=]=\s*"1\"""")

# Module groups for the page. A registered key missing here falls into a
# trailing "Other suites" group so the page always builds; the contract test
# asserts the current registry is fully and explicitly grouped.
MODULE_GROUPS = [
    ("Package & public interface",
     ["packaging", "config", "interface", "input-robustness", "contract"]),
    ("OFDM geometry & pilots",
     ["sizing", "pilots", "layout", "frequency-geometry", "carrier"]),
    ("LDPC coding & framing",
     ["ldpc", "framing", "bp", "frame-wide-ldpc"]),
    ("Sync & acquisition",
     ["sync", "sync-doppler", "acquisition"]),
    ("Front end & equalization",
     ["frontend", "equalization", "candidate"]),
    ("JUNA receivers & channels",
     ["lite", "full", "coupled", "coupled-init", "coupled-solver",
      "coupled-bcd", "coupled-candidate", "coupled-e2e", "pfft", "noise",
      "synthetic-channel"]),
    ("Replay & reproduction (opt-in)",
     ["replay-download", "replay-schema", "replay-segment", "golden-diff",
      "receiver-benchmark", "commit-rate-benchmark", "commit-frame-benchmark",
      "replay-scripts", "replay-gates"]),
]


def _unescape(text):
    return text.replace('\\"', '"').replace("\\\\", "\\")


def parse_registry(path):
    text = Path(path).read_text(encoding="utf-8")
    suites = []
    for match in SUITE_RE.finditer(text):
        suites.append({
            "key": match.group("key"),
            "file": match.group("file"),
            "title": _unescape(match.group("title")),
            "claim": _unescape(match.group("claim")),
            "paper": _unescape(match.group("paper") or ""),
        })
    if not suites:
        raise ValueError(f"no suites parsed from registry {path}")
    declared = len(re.findall(r'\(\s*key\s*=\s*"', text))
    if declared != len(suites):
        parsed_keys = {s["key"] for s in suites}
        missing = [k for k in re.findall(r'\(\s*key\s*=\s*"([^"]+)"', text)
                   if k not in parsed_keys]
        raise ValueError(
            f"registry declares {declared} suites but only {len(suites)} "
            f"parsed; malformed entries: {missing}")
    return suites


def detect_gates(test_dir, suites):
    """Opt-in enabling switches per suite, read from the suite's own source.

    Used only for display (which variable enables the gate) and for suites
    with no recorded run; a recorded run's own skip counts decide status.
    """
    gates = {}
    for suite in suites:
        source = Path(test_dir) / suite["file"]
        found = set()
        if source.is_file():
            found.update(SWITCH_RE.findall(source.read_text(encoding="utf-8")))
        gates[suite["key"]] = sorted(found)
    return gates


def _status(entry, gate_env):
    """Recorded truth only: skips (broken) mark a gate regardless of env."""
    if entry is not None:
        if (entry.get("fails", 0) + entry.get("errors", 0)) > 0:
            return "fail"
        if entry.get("broken", 0) > 0:
            return "gate"
        if entry.get("passes", 0) > 0:
            return "pass"
        return "notrun"
    return "gate" if gate_env else "notrun"


def assemble(registry_path, evidence_path=None):
    suites = parse_registry(registry_path)
    gates = detect_gates(Path(registry_path).parent, suites)
    evidence = {}
    meta = {}
    if evidence_path and Path(evidence_path).is_file():
        recorded = json.loads(Path(evidence_path).read_text(encoding="utf-8"))
        meta = {k: v for k, v in recorded.items() if k != "suites"}
        evidence = {s["key"]: s for s in recorded.get("suites", [])}

    module_names = [name for name, _ in MODULE_GROUPS]
    module_of = {}
    for index, (_, keys) in enumerate(MODULE_GROUPS):
        for key in keys:
            module_of[key] = index
    ungrouped = [s["key"] for s in suites if s["key"] not in module_of]
    if ungrouped:
        module_names.append("Other suites")
        for key in ungrouped:
            module_of[key] = len(module_names) - 1

    rows = []
    for suite in suites:
        entry = evidence.get(suite["key"])
        gate_env = gates.get(suite["key"], [])
        row = {
            "key": suite["key"],
            "file": suite["file"],
            "title": suite["title"],
            "claim": suite["claim"],
            "module": module_of[suite["key"]],
            "status": _status(entry, gate_env),
            "gate_env": gate_env,
            "passes": (entry or {}).get("passes", 0),
            "fails": (entry or {}).get("fails", 0),
            "errors": (entry or {}).get("errors", 0),
            "broken": (entry or {}).get("broken", 0),
            "seconds": (entry or {}).get("seconds"),
        }
        rows.append(row)

    # failed suites lead their module group; registry order otherwise
    order = {"fail": 0, "pass": 1, "gate": 2, "notrun": 3}
    indexed = list(enumerate(rows))
    indexed.sort(key=lambda item: (item[1]["module"],
                                   0 if item[1]["status"] == "fail" else 1,
                                   item[0]))
    rows = [row for _, row in indexed]
    kpi_assertions = sum(r["passes"] for r in rows if r["status"] == "pass")
    return {"meta": meta, "modules": module_names, "suites": rows,
            "kpi_assertions": kpi_assertions}


def render(payload):
    data = json.dumps(payload, ensure_ascii=False).replace("</", "<\\/")
    return TEMPLATE.replace("__EVIDENCE_JSON__", data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path,
                        default=Path(__file__).resolve().parents[1] / "test" / "runtests.jl")
    parser.add_argument("--evidence", type=Path, default=None)
    parser.add_argument("--out", type=Path,
                        default=Path(__file__).resolve().parents[1] / "docs" / "evidence.html")
    args = parser.parse_args(argv)

    payload = assemble(args.registry, args.evidence)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(render(payload), encoding="utf-8")
    print(f"wrote evidence page to {args.out}")
    return args.out


TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>JunaCore Evidence</title>
<!-- This is a static evidence snapshot; runs execute in CI or the local workbench. -->
<style>
  :root {
    --bg:#f5f7fa; --panel:#ffffff; --inset:#eef2f7; --line:#d7dfe9;
    --ink:#1a2436; --muted:#5c6b84; --accent:#1273cc; --accent-soft:#e3effa;
    --good:#0ca30c; --warn:#a87408; --crit:#d03b3b;
    --good-bg:#e7f5e7; --warn-bg:#faf0d8; --crit-bg:#fae4e4; --na-bg:#e9edf3;
    --cell-good:#0ca30c; --cell-warn:#fab219; --cell-crit:#d03b3b; --cell-na:#a6b1c2;
    --shadow:0 1px 3px rgba(20,35,60,.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg:#0c1322; --panel:#121c30; --inset:#0e1728; --line:#22304a;
      --ink:#e8eef7; --muted:#8fa0b8; --accent:#5fb2f2; --accent-soft:#17304c;
      --good:#3fbf3f; --warn:#fab219; --crit:#e05252;
      --good-bg:rgba(12,163,12,.14); --warn-bg:rgba(250,178,25,.13);
      --crit-bg:rgba(208,59,59,.16); --na-bg:rgba(143,160,184,.14);
      --cell-na:#3a4a63;
      --shadow:0 1px 3px rgba(0,0,0,.35);
    }
  }
  :root[data-theme="dark"] {
    --bg:#0c1322; --panel:#121c30; --inset:#0e1728; --line:#22304a;
    --ink:#e8eef7; --muted:#8fa0b8; --accent:#5fb2f2; --accent-soft:#17304c;
    --good:#3fbf3f; --warn:#fab219; --crit:#e05252;
    --good-bg:rgba(12,163,12,.14); --warn-bg:rgba(250,178,25,.13);
    --crit-bg:rgba(208,59,59,.16); --na-bg:rgba(143,160,184,.14);
    --cell-na:#3a4a63;
    --shadow:0 1px 3px rgba(0,0,0,.35);
  }
  :root[data-theme="light"] {
    --bg:#f5f7fa; --panel:#ffffff; --inset:#eef2f7; --line:#d7dfe9;
    --ink:#1a2436; --muted:#5c6b84; --accent:#1273cc; --accent-soft:#e3effa;
    --good:#0ca30c; --warn:#a87408; --crit:#d03b3b;
    --good-bg:#e7f5e7; --warn-bg:#faf0d8; --crit-bg:#fae4e4; --na-bg:#e9edf3;
    --cell-na:#a6b1c2;
    --shadow:0 1px 3px rgba(20,35,60,.08);
  }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--bg); color:var(--ink);
    font:15px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif; }
  .mono { font-family:ui-monospace, "SF Mono", "Cascadia Code", "DejaVu Sans Mono", Menlo, monospace; }
  a { color:var(--accent); text-decoration:none; }
  a:hover { text-decoration:underline; }
  button { font:inherit; color:inherit; }
  :focus-visible { outline:2px solid var(--accent); outline-offset:2px; border-radius:4px; }
  .wrap { max-width:1060px; margin:0 auto; padding:0 20px 64px; }

  header { display:flex; align-items:baseline; gap:14px; flex-wrap:wrap; padding:22px 0 6px; }
  .wordmark { font-weight:650; font-size:17px; letter-spacing:.01em; }
  .wordmark .dim { color:var(--muted); font-weight:400; }
  .provenance { color:var(--muted); font-size:12.5px; display:flex; gap:8px;
    align-items:center; flex-wrap:wrap; }
  .provenance .sep { opacity:.5; }
  .searchbox { margin-left:auto; position:relative; }
  .searchbox input { background:var(--panel); border:1px solid var(--line); color:var(--ink);
    border-radius:7px; padding:7px 64px 7px 12px; width:250px; font-size:13.5px; }
  .searchbox .kbd { position:absolute; right:8px; top:50%; transform:translateY(-50%);
    font-size:11px; color:var(--muted); border:1px solid var(--line);
    border-radius:4px; padding:1px 5px; background:var(--inset); }
  .lede { color:var(--muted); font-size:13.5px; margin:2px 0 18px; max-width:64ch; }

  .strip-card { background:var(--panel); border:1px solid var(--line); border-radius:10px;
    box-shadow:var(--shadow); padding:16px 18px 14px; margin-bottom:14px; }
  .strip-head { display:flex; align-items:baseline; gap:18px; flex-wrap:wrap; margin-bottom:10px; }
  .strip-head h2 { font-size:13px; text-transform:uppercase; letter-spacing:.08em;
    color:var(--muted); font-weight:600; margin:0; }
  .kpis { display:flex; gap:18px; margin-left:auto; flex-wrap:wrap; }
  .kpi { display:flex; align-items:baseline; gap:6px; }
  .kpi b { font-size:19px; font-weight:650; font-variant-numeric:tabular-nums; }
  .kpi span { color:var(--muted); font-size:12.5px; }
  .kpi.pass b { color:var(--good); }
  .kpi.crit b { color:var(--crit); }
  .kpi.zero b { color:var(--muted); }

  .strip { display:flex; gap:3px; align-items:flex-end; }
  .cell { flex:1 1 0; height:26px; border-radius:3px; border:0; padding:0; cursor:pointer;
    background:var(--cell-good); opacity:.92; min-width:6px; }
  .cell.gate { background:var(--cell-warn); height:16px; }
  .cell.fail { background:var(--cell-crit); height:26px; }
  .cell.notrun { background:var(--cell-na); height:10px; }
  .cell:hover { opacity:1; transform:translateY(-2px); }
  @media (prefers-reduced-motion: no-preference) {
    .cell { transition:transform .12s ease, opacity .12s ease; }
  }
  .strip-legend { display:flex; gap:16px; margin-top:9px; font-size:12px;
    color:var(--muted); flex-wrap:wrap; }
  .dotk { display:inline-block; width:9px; height:9px; border-radius:2px;
    vertical-align:-1px; margin-right:5px; }

  .controls { display:flex; gap:8px; margin:18px 0 12px; flex-wrap:wrap; align-items:center; }
  .chipbtn { border:1px solid var(--line); background:var(--panel); border-radius:16px;
    padding:4px 12px; font-size:13px; cursor:pointer; color:var(--muted); }
  .chipbtn[aria-pressed="true"] { background:var(--accent-soft); color:var(--ink);
    border-color:var(--accent); }
  .controls .right { margin-left:auto; font-size:12.5px; color:var(--muted); }

  .module { background:var(--panel); border:1px solid var(--line); border-radius:10px;
    box-shadow:var(--shadow); margin-bottom:12px; overflow:hidden; }
  .module > h3 { margin:0; font-size:14px; font-weight:650; display:flex;
    align-items:center; gap:10px; padding:11px 16px; cursor:pointer; user-select:none; }
  .module > h3:hover { background:var(--inset); }
  .module > h3 .count { color:var(--muted); font-weight:400; font-size:12.5px;
    font-variant-numeric:tabular-nums; }
  .module > h3 .chev { margin-left:auto; color:var(--muted); font-size:12px;
    transform:rotate(90deg); }
  .module.closed > h3 .chev { transform:rotate(0); }
  .module.closed .rows { display:none; }

  .row { border-top:1px solid var(--line); }
  .row-main { display:grid; grid-template-columns:96px 1fr auto; gap:14px;
    align-items:start; padding:11px 16px; cursor:pointer; width:100%; text-align:left;
    background:none; border:none; }
  .row-main:hover { background:var(--inset); }
  .row.open .row-main { background:var(--inset); }
  .claim { font-size:14px; }
  .meta { color:var(--muted); font-size:12px; margin-top:3px; display:flex;
    gap:10px; flex-wrap:wrap; }
  .meta .k { color:var(--accent); }
  .aux { text-align:right; color:var(--muted); font-size:12px; white-space:nowrap;
    font-variant-numeric:tabular-nums; padding-top:2px; }
  .aux b { color:var(--ink); font-weight:550; }

  .status { display:inline-flex; align-items:center; gap:5px; border-radius:5px;
    font-size:11.5px; font-weight:600; padding:2.5px 8px; letter-spacing:.02em;
    white-space:nowrap; margin-top:1px; }
  .status .ic { font-size:10px; }
  .st-pass { background:var(--good-bg); color:var(--good); }
  .st-gate { background:var(--warn-bg); color:var(--warn); }
  .st-fail { background:var(--crit-bg); color:var(--crit); }
  .st-na   { background:var(--na-bg); color:var(--muted); }

  .row-detail { display:none; padding:4px 16px 16px 126px; }
  .row.open .row-detail { display:block; }
  .row-detail p { margin:6px 0; font-size:13.5px; max-width:72ch; }
  .cmd { display:flex; align-items:center; gap:10px; background:var(--inset);
    border:1px solid var(--line); border-radius:7px; padding:8px 12px;
    font-size:12.5px; overflow-x:auto; margin-top:8px; }
  .cmd code { white-space:nowrap; }
  .cmd button { border:1px solid var(--line); background:var(--panel); border-radius:5px;
    font-size:11.5px; padding:2px 9px; cursor:pointer; color:var(--muted); flex-shrink:0; }
  .cmd button:hover { color:var(--ink); }
  .detail-meta { display:flex; gap:18px; flex-wrap:wrap; margin-top:9px;
    font-size:12px; color:var(--muted); }
  .runnote { font-size:12px; color:var(--muted); font-style:italic; }

  .legend { display:flex; gap:14px; flex-wrap:wrap; margin:22px 0 8px; font-size:12.5px;
    color:var(--muted); align-items:center; }
  footer { color:var(--muted); font-size:12px; margin-top:26px; max-width:78ch; }

  #tip { position:fixed; pointer-events:none; z-index:10; display:none;
    background:var(--ink); color:var(--bg); font-size:12px; border-radius:6px;
    padding:5px 9px; max-width:280px; box-shadow:0 2px 8px rgba(0,0,0,.3); }

  @media (max-width:720px) {
    .row-main { grid-template-columns:86px 1fr; }
    .aux { display:none; }
    .row-detail { padding-left:16px; }
    .searchbox input { width:160px; }
  }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="wordmark mono">JunaCore <span class="dim">/ evidence</span></div>
    <div class="provenance mono" id="prov"></div>
    <div class="searchbox">
      <input id="q" type="search" placeholder="Filter suites&hellip;" aria-label="Filter suites">
      <span class="kbd">Ctrl-K</span>
    </div>
  </header>
  <p class="lede">Every registered test suite, the claim it proves about the JunaCore
  underwater-acoustic OFDM modem, and its latest recorded result. Read-only snapshot
  &mdash; runs execute in CI or the local workbench.
  <a href="https://github.com/GabrielARL/JunaCoreTests">Repository</a> &middot;
  <a href="./">Test symbol explorer</a></p>

  <section class="strip-card" aria-label="Suite overview">
    <div class="strip-head">
      <h2 id="strip-title"></h2>
      <div class="kpis" id="kpis"></div>
    </div>
    <div class="strip" id="strip" role="list"></div>
    <div class="strip-legend" id="strip-legend"></div>
  </section>

  <div class="controls" role="group" aria-label="Status filters">
    <button class="chipbtn" data-f="all" aria-pressed="true">All</button>
    <button class="chipbtn" data-f="pass" aria-pressed="false">Passed</button>
    <button class="chipbtn" data-f="fail" aria-pressed="false">Failed</button>
    <button class="chipbtn" data-f="gate" aria-pressed="false">Gated</button>
    <button class="chipbtn" data-f="notrun" aria-pressed="false">Not run</button>
    <span class="right" id="shown"></span>
  </div>

  <div id="modules"></div>

  <div class="legend">
    <span class="status st-pass"><span class="ic">&#10003;</span>passed</span>
    <span class="status st-fail"><span class="ic">&#10005;</span>failed</span>
    <span class="status st-gate"><span class="ic">&#9711;</span>gate off</span>
    <span class="status st-na"><span class="ic">&mdash;</span>not run</span>
    <span>Failed suites always lead their group. &ldquo;Gate off&rdquo; is an
    external-data or hours-scale gate that is deliberately opt-in; its enabling
    variable is shown. Nothing renders as a pass without a recorded passing run.</span>
  </div>

  <footer>Generated by <span class="mono">tools/build_evidence_page.py</span> from the
  suite registry in <span class="mono">test/runtests.jl</span> and the recorded run in
  <span class="mono">reports/evidence.json</span>. Served locally by the workbench, the
  same page gains per-suite Run buttons.</footer>
</div>
<div id="tip" role="tooltip"></div>

<script>
const DATA =
/*EVIDENCE*/
__EVIDENCE_JSON__
/*EVIDENCE*/
;
const STATUS_LABEL = {pass:"passed", fail:"failed", gate:"gate off", notrun:"not run"};
const STATUS_ICON = {pass:"✓", fail:"✕", gate:"◯", notrun:"—"};
const $ = (s, el=document) => el.querySelector(s);
const esc = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;");

const meta = DATA.meta || {};
const suites = DATA.suites;
const counts = {pass:0, fail:0, gate:0, notrun:0};
suites.forEach(s => { counts[s.status]++; });
const assertions = DATA.kpi_assertions || 0;

$("#prov").innerHTML = meta.commit
  ? "commit " + esc(meta.commit) +
    (meta.generated_at ? " <span class='sep'>&middot;</span> " + esc(meta.generated_at) : "") +
    (meta.julia ? " <span class='sep'>&middot;</span> julia " + esc(meta.julia) : "")
  : "no recorded run yet";
$("#strip-title").textContent = suites.length + " suites · one cell each";
$("#kpis").innerHTML =
  "<div class='kpi pass'><b>" + counts.pass + "</b><span>passed</span></div>" +
  "<div class='kpi " + (counts.fail ? "crit" : "zero") + "'><b>" + counts.fail +
    "</b><span>failed</span></div>" +
  "<div class='kpi'><b>" + counts.gate + "</b><span>gates off</span></div>" +
  (counts.notrun ? "<div class='kpi'><b>" + counts.notrun + "</b><span>not run</span></div>" : "") +
  "<div class='kpi'><b>" + assertions.toLocaleString() +
    "</b><span>assertions in passing suites</span></div>";
$("#strip-legend").innerHTML =
  "<span><i class='dotk' style='background:var(--cell-good)'></i>passed</span>" +
  (counts.fail ? "<span><i class='dotk' style='background:var(--cell-crit)'></i>failed</span>" : "") +
  "<span><i class='dotk' style='background:var(--cell-warn)'></i>opt-in gate off</span>" +
  (counts.notrun ? "<span><i class='dotk' style='background:var(--cell-na)'></i>not run</span>" : "") +
  "<span>hover a cell to identify it · click to jump to its claim</span>";

const strip = $("#strip"), tip = $("#tip");
suites.forEach(s => {
  const b = document.createElement("button");
  b.className = "cell" + (s.status === "pass" ? "" : " " + s.status);
  b.setAttribute("role", "listitem");
  b.setAttribute("aria-label", s.key + " — " + STATUS_LABEL[s.status]);
  b.addEventListener("mousemove", e => {
    tip.style.display = "block";
    tip.innerHTML = "<b>" + esc(s.key) + "</b> · " + STATUS_LABEL[s.status] +
      "<br>" + esc(s.title);
    tip.style.left = Math.min(e.clientX + 12, innerWidth - tip.offsetWidth - 8) + "px";
    tip.style.top = (e.clientY + 14) + "px";
  });
  b.addEventListener("mouseleave", () => tip.style.display = "none");
  b.addEventListener("click", () => { location.hash = s.key; openRow(s.key, true); });
  strip.appendChild(b);
});

function shortClaim(c) {
  return c.length > 120 ? c.slice(0, c.lastIndexOf(" ", 117)) + "…" : c;
}

function auxHtml(s) {
  if (s.status === "pass")
    return "<b>" + (s.passes || 0).toLocaleString() + "</b> assertions" +
      (s.seconds != null ? "<br>" + s.seconds.toFixed(1) + " s" : "");
  if (s.status === "fail")
    return "<b>" + (s.fails + s.errors) + "</b> failed · " +
      (s.passes || 0).toLocaleString() + " passed";
  if (s.status === "gate")
    return s.gate_env.length
      ? "opt-in<br><span class='mono'>" + esc(s.gate_env[0]) + "=1</span>"
      : "opt-in<br>" + (s.broken || 0) + " stage" + (s.broken === 1 ? "" : "s") + " skipped";
  return "—";
}

function detailMeta(s) {
  if (s.status === "gate") {
    const ran = s.passes ? s.passes.toLocaleString() +
      " cheap assertions passed; " : "";
    const skipped = s.broken ? s.broken + " opt-in stage" +
      (s.broken === 1 ? "" : "s") + " skipped. " : "";
    const how = s.gate_env.length
      ? "Each stage enables independently, e.g. <code class='mono'>" +
        esc(s.gate_env[0]) + "=1</code>" +
        (s.gate_env.length > 1 ? " (also: <code class='mono'>" +
          esc(s.gate_env.slice(1).join(", ")) + "</code>)" : "")
      : "See the suite file header for its enabling JUNA_* switches";
    return "<span>" + ran + skipped + how + ", with its data present.</span>";
  }
  if (s.status === "notrun")
    return "<span>no recorded run for this suite yet</span>";
  if (s.status === "fail")
    return "<span>" + s.fails + " failed, " + s.errors + " errored, " +
      (s.passes || 0) + " passed</span>";
  return "<span>" + (s.passes || 0).toLocaleString() + " assertions passed" +
    (s.seconds != null ? " in " + s.seconds.toFixed(1) + " s" : "") + "</span>";
}

const wrapEl = $("#modules");
DATA.modules.forEach((name, mi) => {
  const group = suites.filter(s => s.module === mi);
  if (!group.length) return;
  const passed = group.filter(s => s.status === "pass").length;
  const failed = group.filter(s => s.status === "fail").length;
  const sec = document.createElement("section");
  sec.className = "module";
  const label = failed ? passed + " passed · " + failed + " FAILED"
    : passed === group.length ? group.length + " / " + group.length + " passed"
    : passed + " passed · " + (group.length - passed) + " gated or not run";
  sec.innerHTML = "<h3><span>" + esc(name) + "</span><span class='count'>" + label +
    "</span><span class='chev'>▶</span></h3><div class='rows'></div>";
  $("h3", sec).addEventListener("click", () => sec.classList.toggle("closed"));
  const rowsEl = $(".rows", sec);
  group.forEach(s => rowsEl.appendChild(renderRow(s)));
  wrapEl.appendChild(sec);
});

function renderRow(s) {
  const row = document.createElement("div");
  row.className = "row"; row.id = s.key; row.dataset.status = s.status;
  row.innerHTML =
    "<button class='row-main' aria-expanded='false'>" +
      "<span><span class='status st-" + (s.status === "notrun" ? "na" : s.status) +
        "'><span class='ic'>" + STATUS_ICON[s.status] + "</span>" +
        STATUS_LABEL[s.status] + "</span></span>" +
      "<span><span class='claim'>" + esc(shortClaim(s.claim)) + "</span>" +
        "<span class='meta'><span class='k mono'>" + esc(s.key) + "</span><span>" +
        esc(s.title) + "</span></span></span>" +
      "<span class='aux'>" + auxHtml(s) + "</span>" +
    "</button>" +
    "<div class='row-detail'>" +
      "<p>" + esc(s.claim) + "</p>" +
      "<div class='cmd'><code class='mono'>julia --project=. test/runtests.jl " +
        esc(s.key) + "</code><button data-cmd='" + esc(s.key) + "'>copy</button></div>" +
      "<div class='detail-meta'>" + detailMeta(s) +
        "<span class='runnote'>Run button appears when served by the local workbench</span>" +
      "</div>" +
    "</div>";
  $(".row-main", row).addEventListener("click", () => {
    const open = row.classList.toggle("open");
    $(".row-main", row).setAttribute("aria-expanded", open);
  });
  const cp = $("[data-cmd]", row);
  cp.addEventListener("click", e => {
    e.stopPropagation();
    if (navigator.clipboard)
      navigator.clipboard.writeText("julia --project=. test/runtests.jl " + s.key);
    cp.textContent = "copied"; setTimeout(() => cp.textContent = "copy", 1200);
  });
  return row;
}

function openRow(key, scroll) {
  const row = document.getElementById(key);
  if (!row) return;
  row.closest(".module").classList.remove("closed");
  row.classList.add("open");
  $(".row-main", row).setAttribute("aria-expanded", "true");
  if (scroll) row.scrollIntoView({behavior: "smooth", block: "center"});
}

let activeFilter = "all";
document.querySelectorAll(".chipbtn").forEach(b => {
  b.addEventListener("click", () => {
    document.querySelectorAll(".chipbtn").forEach(x => x.setAttribute("aria-pressed", "false"));
    b.setAttribute("aria-pressed", "true");
    activeFilter = b.dataset.f;
    applyFilter();
  });
});
$("#q").addEventListener("input", applyFilter);
addEventListener("keydown", e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
    e.preventDefault(); $("#q").focus();
  }
});

function applyFilter() {
  const q = $("#q").value.trim().toLowerCase();
  let shown = 0;
  suites.forEach(s => {
    const row = document.getElementById(s.key);
    const ok = (activeFilter === "all" || s.status === activeFilter) &&
      (!q || (s.key + " " + s.title + " " + s.claim).toLowerCase().includes(q));
    row.style.display = ok ? "" : "none";
    if (ok) shown++;
  });
  document.querySelectorAll(".module").forEach(m => {
    const any = [...m.querySelectorAll(".row")].some(r => r.style.display !== "none");
    m.style.display = any ? "" : "none";
  });
  $("#shown").textContent = shown === suites.length ? "" : shown + " of " + suites.length + " suites";
}

if (location.hash) openRow(location.hash.slice(1), true);
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
