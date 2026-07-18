#!/usr/bin/env python3
"""Build the backend-free JUNA Explorer site for GitHub Pages."""

import argparse
import os
import re
from pathlib import Path


def build(source: Path, out_dir: Path, deploy_commit: str | None = None) -> Path:
    if not source.is_file():
        raise FileNotFoundError(f"missing Explorer artifact: {source}")

    html = source.read_text(encoding="utf-8")
    required = ("DATA.served === true", "This is the static copy")
    for marker in required:
        if marker not in html:
            raise ValueError(f"Explorer is missing static-mode marker: {marker}")
    if '"served": true' in html:
        raise ValueError("refusing to publish an Explorer that advertises a live runner")

    if deploy_commit:
        # the artifact embeds the commit that GENERATED it, one commit older
        # than the commit that DEPLOYS it (the artifact itself was still
        # uncommitted at generation time). Re-stamp the display commit with
        # the deploy SHA; the checklist key is the suite fingerprint, which
        # is deliberately left untouched.
        html, stamped = re.subn(
            r'"build": \{"commit": (?:"[^"]*"|null), "dirty": (?:true|false)',
            '"build": {"commit": "%s", "dirty": false' % deploy_commit[:7],
            html)
        if stamped != 1:
            raise ValueError("could not stamp the deploy commit into the Explorer build field")

    out_dir.mkdir(parents=True, exist_ok=True)
    index = out_dir / "index.html"
    index.write_bytes(html.encode("utf-8") if deploy_commit else source.read_bytes())
    (out_dir / ".nojekyll").write_text("", encoding="ascii")
    return index


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--deploy-commit", default=os.environ.get("GITHUB_SHA"),
                        help="SHA to stamp as the deployed commit (defaults to $GITHUB_SHA)")
    args = parser.parse_args()

    index = build(args.source.resolve(), args.out_dir.resolve(),
                  deploy_commit=args.deploy_commit or None)
    print(f"wrote static Explorer to {index}")


if __name__ == "__main__":
    main()
