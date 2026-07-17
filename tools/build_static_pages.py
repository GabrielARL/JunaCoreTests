#!/usr/bin/env python3
"""Build the backend-free JUNA Explorer site for GitHub Pages."""

import argparse
from pathlib import Path


def build(source: Path, out_dir: Path) -> Path:
    if not source.is_file():
        raise FileNotFoundError(f"missing Explorer artifact: {source}")

    html = source.read_text(encoding="utf-8")
    required = ("DATA.served === true", "This is the static copy")
    for marker in required:
        if marker not in html:
            raise ValueError(f"Explorer is missing static-mode marker: {marker}")
    if '"served": true' in html:
        raise ValueError("refusing to publish an Explorer that advertises a live runner")

    out_dir.mkdir(parents=True, exist_ok=True)
    index = out_dir / "index.html"
    index.write_bytes(source.read_bytes())
    (out_dir / ".nojekyll").write_text("", encoding="ascii")
    return index


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    index = build(args.source.resolve(), args.out_dir.resolve())
    print(f"wrote static Explorer to {index}")


if __name__ == "__main__":
    main()
