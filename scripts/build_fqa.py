#!/usr/bin/env python3
"""Build the Fibaro QuickApp .fqa bundle from the Lua sources in src/.

The .fqa file is a JSON document with QuickApp metadata plus a `files` array
containing each Lua file's source. This script keeps the QuickApp metadata
(quickAppVariables, viewLayout, etc.) from a "template" .fqa and re-injects
the current contents of src/*.lua.

Usage:
    python3 scripts/build_fqa.py             # write the .fqa
    python3 scripts/build_fqa.py --check     # exit non-zero if .fqa is stale
    python3 scripts/build_fqa.py --output-path other.fqa
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "src"
DEFAULT_FQA = REPO_ROOT / "hc3_to_mqtt_bridge-1.0.235-fork-6.fqa"

# (fqa_file_name, source_file_name, is_main)
FILE_LAYOUT = [
    ("main", "main.lua", True),
    ("tools", "tools.lua", False),
    ("mqtt_convention_api", "mqtt_convention_api.lua", False),
    ("device_api", "device_api.lua", False),
    ("device_helper", "device_helper.lua", False),
]


def load_template(template_path: Path) -> dict:
    if not template_path.exists():
        raise FileNotFoundError(
            f"Template .fqa not found at {template_path}. Pass --template if "
            f"the file lives elsewhere."
        )
    with template_path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def read_source(name: str) -> str:
    path = SRC_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"Source file {path} is missing")
    return path.read_text(encoding="utf-8")


def build_fqa(template: dict) -> dict:
    """Return a new .fqa dict with files[] replaced by current src/ content."""
    new = dict(template)
    new["files"] = [
        {
            "name": fqa_name,
            "isMain": is_main,
            "isOpen": True,
            "content": read_source(src_name),
        }
        for fqa_name, src_name, is_main in FILE_LAYOUT
    ]
    return new


def serialize(fqa: dict) -> str:
    # The Fibaro UI accepts standard JSON with Unix-style newlines inside the
    # embedded source files. We keep `ensure_ascii=False` so the Cyrillic
    # transliteration table in tools.lua stays human-readable.
    return json.dumps(fqa, ensure_ascii=False, indent=2)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--template",
        type=Path,
        default=DEFAULT_FQA,
        help="Existing .fqa to copy QuickApp metadata from (default: %(default)s)",
    )
    parser.add_argument(
        "--output-path",
        type=Path,
        default=None,
        help="Where to write the new .fqa. Defaults to the template path.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with non-zero status if the on-disk .fqa would change.",
    )
    args = parser.parse_args(argv)

    template = load_template(args.template)
    new_fqa = build_fqa(template)
    new_text = serialize(new_fqa)

    output_path = args.output_path or args.template

    if args.check:
        if not output_path.exists():
            print(f"[FAIL] {output_path} is missing", file=sys.stderr)
            return 1
        existing_text = output_path.read_text(encoding="utf-8")
        # Re-serialize the existing .fqa using the same writer so we compare
        # logical structure rather than incidental formatting.
        try:
            existing_normalized = serialize(json.loads(existing_text))
        except json.JSONDecodeError as exc:
            print(f"[FAIL] {output_path} is not valid JSON: {exc}", file=sys.stderr)
            return 1
        if existing_normalized == new_text:
            print(f"[OK] {output_path} is in sync with src/")
            return 0
        print(
            f"[FAIL] {output_path} is out of sync with src/. "
            f"Run `python3 scripts/build_fqa.py` to rebuild.",
            file=sys.stderr,
        )
        return 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(new_text, encoding="utf-8")
    print(f"Wrote {output_path} ({os.path.getsize(output_path)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
