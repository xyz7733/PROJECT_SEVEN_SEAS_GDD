"""Render craft scenarios in a real Windows window with an isolated player profile.

This is an automated source-project rendering probe, not a mouse playtest or a
listening review. Audio output is disabled unless --audio is supplied.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=ROOT / "tools/godot/windows/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--out", type=Path, help="New output directory; defaults to a timestamp under build/validation/gpu-craft")
    parser.add_argument("--audio", action="store_true", help="Use the normal audio device for a human listening review")
    parser.add_argument("--locale", choices=("en", "zh_CN"), default="en")
    parser.add_argument("--ui", choices=(1.0, 1.25, 1.5), type=float, default=1.0)
    parser.add_argument("--screen", type=int, help="Godot display index; otherwise use the engine default")
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("This runner is for Windows; use tools/shots/run_linux.sh on Linux")
    engine = args.engine.resolve()
    if not engine.is_file():
        parser.error(f"Godot executable not found: {engine}")
    out = (args.out or ROOT / "build/validation/gpu-craft" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")).resolve()
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    for key, folder in (("APPDATA", "profile/roaming"), ("LOCALAPPDATA", "profile/local"),
                        ("XDG_DATA_HOME", "profile/data"), ("XDG_CONFIG_HOME", "profile/config"),
                        ("XDG_CACHE_HOME", "profile/cache")):
        path = out / folder
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    command = [str(engine), "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility",
               "--resolution", "1280x720", "--windowed"]
    if not args.audio:
        command += ["--audio-driver", "Dummy"]
    if args.screen is not None:
        command += ["--screen", str(args.screen)]
    command += ["res://tests/shots.tscn", "--", "--out", out.as_posix(), "--scenario",
                (ROOT / "tools/shots/scenarios/gpu_craft.gd").as_posix(),
                "--locale", args.locale, "--ui", str(args.ui)]
    (out / "invocation.json").write_text(json.dumps({"command": command, "audio_output": args.audio,
        "scope": "Automated source rendering; no OS input, human motion review, or speaker listening implied"}, indent=2), encoding="utf-8")
    log = out / "gpu-craft.log"
    print(f"Running real-window GPU probe ({'audio enabled' if args.audio else 'silent Dummy audio'}).", flush=True)
    print(f"Output: {out}", flush=True)
    try:
        with log.open("w", encoding="utf-8") as output:
            result = subprocess.run(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                stdout=output, stderr=subprocess.STDOUT, timeout=args.timeout,
                creationflags=subprocess.CREATE_NO_WINDOW)
    except subprocess.TimeoutExpired:
        print(f"GPU probe timed out; see {log}", file=sys.stderr)
        return 1
    text = log.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if line.startswith(("Godot", "OpenGL", "[gpu]", "[gpu-check]", "[gpu-sample]", "shots done", "SCRIPT ERROR", "ERROR:", "WARNING:")):
            print(line)
    errors = re.findall(r"^.*(?:SCRIPT ERROR:|^ERROR:|^WARNING:.*leaked).*$", text, re.MULTILINE)
    metrics_path = out / "metrics.json"
    if result.returncode or errors or not metrics_path.is_file():
        print(f"GPU probe failed ({result.returncode}); see {log}", file=sys.stderr)
        return 1
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    if not metrics.get("checks") or any(not check["passed"] for check in metrics["checks"]):
        print(f"GPU checks failed; see {metrics_path}", file=sys.stderr)
        return 1
    print(f"GPU probe passed. Frame intervals include VSync/presentation and are not GPU timer measurements.\nMetrics: {metrics_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
