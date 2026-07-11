import json
import subprocess
import sys
from pathlib import Path


TOOLS_DIR = Path(__file__).resolve().parents[1]
WORKER = TOOLS_DIR / "vfcommit_worker.py"


def test_worker_ping_round_trip():
    process = subprocess.Popen(
        [sys.executable, str(WORKER)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=TOOLS_DIR,
        text=True,
    )
    stdout, stderr = process.communicate('{"op":"ping"}\n', timeout=30)
    assert process.returncode == 0, stderr
    payload = json.loads(stdout.strip().splitlines()[-1])
    assert payload["ok"] is True
    assert payload["op"] == "pong"
