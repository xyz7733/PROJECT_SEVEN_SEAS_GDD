"""Run native Godot checks with all preferences and saves isolated in build/."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build" / "validation"


def run(engine: Path, name: str, args: list[str], env: dict[str, str], *, project: bool = True) -> None:
    log = OUT / f"{name}.log"
    command = [str(engine), "--headless"]
    if project:
        command += ["--path", str(ROOT / "game")]
    command += args
    print(f"Running {name} ...", flush=True)
    with log.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                                    stdout=output, stderr=subprocess.STDOUT, timeout=180,
                                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        except subprocess.TimeoutExpired:
            raise SystemExit(f"{name} timed out; see {log}") from None
    text = log.read_text(encoding="utf-8", errors="replace")
    problems = re.findall(r"^.*(?:SCRIPT ERROR:|^ERROR:|\[FAIL\]|TESTS FAIL:|^WARNING:.*leaked).*$",
                          text, re.MULTILINE)
    for line in text.splitlines()[-12:]:
        print(line)
    if result.returncode or problems:
        for line in problems[:12]:
            print(line)
        raise SystemExit(f"{name} failed ({result.returncode}); see {log}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=ROOT / "tools/godot/windows/Godot_v4.7.2-stable_win64.exe")
    parser.add_argument("--export", action="store_true", help="Export the verified Windows release")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--release-smoke-only", action="store_true",
                        help="Check an already exported release without rerunning source suites")
    args = parser.parse_args()
    engine = args.engine.resolve()
    if not engine.is_file():
        parser.error(f"Godot executable not found: {engine}")
    OUT.mkdir(parents=True, exist_ok=True)
    # Set environment values only for the child. Never touch the player's profile.
    env = os.environ.copy()
    for key, folder in (("APPDATA", "profile/roaming"), ("LOCALAPPDATA", "profile/local"),
                        ("XDG_DATA_HOME", "profile/data"), ("XDG_CONFIG_HOME", "profile/config"),
                        ("XDG_CACHE_HOME", "profile/cache")):
        path = OUT / folder
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    env["P7S_VALIDATION_ROOT"] = str(OUT)
    if args.release_smoke_only:
        run(ROOT / "build/windows/ProjectSevenSeas.exe", "release-smoke",
            ["--quit-after", "30"], env, project=False)
        return
    if not args.skip_import:
        run(engine, "import", ["--editor", "--import", "--quit"], env)
    run(engine, "tests", ["res://tests/test_main.tscn"], env)
    layout = ROOT / "game/tests/test_ui_layout.tscn"
    if layout.is_file():
        run(engine, "ui-layout", ["res://tests/test_ui_layout.tscn"], env)
    if args.export:
        # Use the already bundled templates; keep the isolated editor profile
        # independent of any templates installed in the player's real profile.
        templates = ROOT / "tools/godot/editor_data/export_templates/4.7.2.stable"
        target = Path(env["APPDATA"]) / "Godot/export_templates/4.7.2.stable"
        target.mkdir(parents=True, exist_ok=True)
        for name in ("windows_release_x86_64.exe", "windows_release_x86_64_console.exe"):
            shutil.copy2(templates / name, target / name)
        run(engine, "export", ["--export-release", "Windows Desktop",
                               str(ROOT / "build/windows/ProjectSevenSeas.exe")], env)
        run(ROOT / "build/windows/ProjectSevenSeas.exe", "release-smoke",
            ["--quit-after", "30"], env, project=False)
    print(f"Checks passed. Logs: {OUT}")


if __name__ == "__main__":
    main()
