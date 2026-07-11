#!/usr/bin/env python3
"""
vfcommit_worker — warm NDJSON server for VarFont Studio.

Reads one JSON object per line from stdin; writes one CommitResult JSON line to stdout.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))


def _emit_error(code: str, message: str) -> dict:
    return {
        "schema_version": 1,
        "request_id": "",
        "ok": False,
        "output_path": None,
        "dry_run": True,
        "summary": None,
        "warnings": [],
        "errors": [{"code": code, "message": message}],
    }


def main() -> int:
    try:
        from vfcommit_lib.engine import run_commit  # noqa: E402
    except Exception as exc:  # noqa: BLE001
        result = _emit_error("import_error", f"{type(exc).__name__}: {exc}")
        sys.stdout.write(json.dumps(result) + "\n")
        sys.stdout.flush()
        return 1

    for line in sys.stdin:
        raw = line.strip()
        if not raw:
            continue
        try:
            request = json.loads(raw)
        except json.JSONDecodeError as exc:
            result = _emit_error("invalid_json", str(exc))
            sys.stdout.write(json.dumps(result) + "\n")
            sys.stdout.flush()
            continue

        if request.get("op") == "ping":
            sys.stdout.write(json.dumps({"ok": True, "op": "pong"}) + "\n")
            sys.stdout.flush()
            continue

        try:
            result = run_commit(request)
        except Exception as exc:  # noqa: BLE001
            result = _emit_error("helper_exception", f"{type(exc).__name__}: {exc}")

        sys.stdout.write(json.dumps(result) + "\n")
        sys.stdout.flush()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
