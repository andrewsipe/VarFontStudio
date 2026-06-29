#!/usr/bin/env python3
"""
vfcommit — VarFontStudio write helper.

Reads CommitRequest JSON from stdin (or a file path argument) and writes
CommitResult JSON to stdout.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as `python vfcommit.py` without installing the package.
_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

from vfcommit_lib.engine import run_commit  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="VarFontStudio commit helper")
    parser.add_argument(
        "request",
        nargs="?",
        help="Path to CommitRequest JSON (default: read stdin)",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print CommitResult JSON",
    )
    args = parser.parse_args(argv)

    try:
        if args.request:
            raw = Path(args.request).read_text(encoding="utf-8")
        else:
            raw = sys.stdin.read()
        request = json.loads(raw)
    except json.JSONDecodeError as exc:
        _emit_error("invalid_json", str(exc))
        return 2
    except OSError as exc:
        _emit_error("io_error", str(exc))
        return 2

    result = run_commit(request)
    indent = 2 if args.pretty else None
    json.dump(result, sys.stdout, indent=indent)
    sys.stdout.write("\n")
    return 0 if result.get("ok") else 1


def _emit_error(code: str, message: str) -> None:
    json.dump(
        {
            "schema_version": 1,
            "request_id": "",
            "ok": False,
            "output_path": None,
            "dry_run": True,
            "summary": None,
            "warnings": [],
            "errors": [{"code": code, "message": message}],
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    raise SystemExit(main())
