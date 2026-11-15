"""Run isolated source checks or export the review-fix Windows build."""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "tools/godot/windows/Godot_v4.7.2-stable_win64_console.exe"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=("source", "export"), default="source")
    args = parser.parse_args()
    base = ROOT / "build/validation/world-art-02"
    out = base / (datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + args.phase)
    out.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    profile = out / "profile"
    for name in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        folder = profile / name.lower()
        folder.mkdir(parents=True, exist_ok=True)
        env[name] = str(folder)
    env["P7S_VALIDATION_ROOT"] = profile.as_posix()
    if args.phase == "export":
        # Isolate player/editor state while reusing the already-installed
        # matching official templates; no global settings are modified.
        templates = ROOT / "tools/godot/editor_data/export_templates/4.7.2.stable"
        destination = Path(env["APPDATA"]) / "Godot/export_templates/4.7.2.stable"
        destination.mkdir(parents=True, exist_ok=True)
        for filename in ("windows_debug_x86_64.exe", "windows_release_x86_64.exe"):
            shutil.copy2(templates / filename, destination / filename)
    commands = [("import", ["--editor", "--import", "--quit"])]
    if args.phase == "source":
        commands += [("core", ["res://tests/test_main.tscn"]),
                     ("layout", ["res://tests/test_ui_layout.tscn"])]
    else:
        commands += [("export", ["--export-release", "Windows Desktop",
                                  str(ROOT / "build/windows/ProjectSevenSeas.exe")])]
    records = []
    for name, extra in commands:
        command = [str(ENGINE), "--headless", "--audio-driver", "Dummy", "--path", str(ROOT / "game"), *extra]
        log_path = out / (name + ".log")
        with log_path.open("w", encoding="utf-8") as log:
            proc = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                stderr=subprocess.STDOUT, timeout=300, creationflags=subprocess.CREATE_NO_WINDOW)
        content = log_path.read_text(encoding="utf-8", errors="replace")
        errors = [line for line in content.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
        matches = re.findall(r"TESTS PASS: (\d+) checks", content)
        row = {"name": name, "command": command, "exit": proc.returncode,
            "errors": errors, "checks": int(matches[-1]) if matches else None,
            "log": log_path.relative_to(ROOT).as_posix()}
        records.append(row)
        failed = proc.returncode != 0 or bool(errors) or (name in ("core", "layout") and not matches)
        (out / "result.json").write_text(json.dumps({"phase": args.phase, "steps": records,
            "passed": not failed, "profile": profile.as_posix()}, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: row[k] for k in ("name", "exit", "checks", "errors", "log")}), flush=True)
        if failed:
            print(content[-8000:])
            raise SystemExit(1)
    (base / ("latest-" + args.phase + ".json")).write_text(json.dumps({"directory": out.relative_to(ROOT).as_posix(),
        "passed": True, "steps": records}, indent=2) + "\n", encoding="utf-8")
    print("Validated:", out, flush=True)


if __name__ == "__main__":
    main()
