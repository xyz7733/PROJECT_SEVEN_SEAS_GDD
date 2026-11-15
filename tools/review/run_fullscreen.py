"""Run an external review harness against the unmodified native release PCK."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import shutil
from datetime import datetime

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", choices=("preflight", "native-title", "native-startup", "title_quit", "window_close", "controls", "campaign", "campaign_guided", "postgame", "postgame_finale", "catalogue", "combat_focus", "r4_regression", "fixes_regression"), default="preflight")
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--locale", choices=("en", "zh_CN"), default="zh_CN")
    parser.add_argument("--audio", action="store_true", help="Request the default sound device for backend/shutdown checks; does not establish speaker listening")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--resume-profile", type=Path, help="Copy an earlier isolated review profile; the source is preserved")
    args = parser.parse_args()
    out = (args.out or ROOT / "build/review" / (datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + args.scenario)).resolve()
    out.mkdir(parents=True, exist_ok=True)
    # Keep the exact external driver with each run, including failed runs.
    # Later review-driver fixes must not change the provenance of old traces.
    driver = out / "driver"
    driver.mkdir(exist_ok=True)
    driver_hashes = {}
    for source_file in sorted(Path(__file__).parent.iterdir()):
        if source_file.suffix in (".gd", ".py"):
            shutil.copy2(source_file, driver / source_file.name)
            driver_hashes[source_file.name] = hashlib.sha256(source_file.read_bytes()).hexdigest()
    if args.resume_profile:
        source = args.resume_profile.resolve()
        review_root = (ROOT / "build/review").resolve()
        if not source.is_relative_to(review_root) or source == out / "profile":
            parser.error("Resume must copy an earlier isolated review profile")
        shutil.copytree(source, out / "profile", dirs_exist_ok=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = out / "profile" / key.lower()
        path.mkdir(parents=True, exist_ok=True)
        env[key] = str(path)
    exe = ROOT / "build/windows/ProjectSevenSeas.exe"
    pack = exe.with_suffix(".pck")
    engine = ROOT / "tools/godot/windows/Godot_v4.7.2-stable_win64_console.exe"
    command = [str(engine), "--main-pack", str(pack), "--fullscreen", "--audio-driver", "Dummy", "--script", str(driver / "bootstrap.gd"),
               "--", "--out", out.as_posix(), "--locale", args.locale]
    if args.scenario in ("native-title", "native-startup"):
        profile = Path(env["APPDATA"]) / "Godot/app_userdata/Project Seven Seas"
        profile.mkdir(parents=True, exist_ok=True)
        (profile / "settings.cfg").write_text('[settings]\nlocale="' + args.locale + '"\n', encoding="utf-8")
        command = [str(exe), "--resolution", "2560x1600", "--fullscreen", "--audio-driver", "Dummy", "--verbose", "--write-movie", str(out / "native.png"),
                   "--fixed-fps", "10", "--quit-after", "20"]
        if args.scenario == "native-startup":
            command = [str(exe), "--resolution", "2560x1600", "--fullscreen", "--audio-driver", "Dummy", "--verbose", "--max-fps", "60", "--quit-after", "120"]
    elif args.scenario != "preflight":
        command += ["--scenario", (driver / (args.scenario + ".gd")).as_posix()]
    if args.audio:
        audio_index = command.index("--audio-driver")
        del command[audio_index:audio_index + 2]
        if "--verbose" not in command:
            command.insert(1, "--verbose")
        if args.scenario not in ("native-title", "native-startup"):
            command += ["--audio-scope", "Default sound device requested; inspect verbose log for actual backend or fallback"]
    invocation = {"command": command, "exe_sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
                  "pck_sha256": hashlib.sha256(pack.read_bytes()).hexdigest(),
                  "runtime_sha256": hashlib.sha256(Path(command[0]).read_bytes()).hexdigest(),
                  "review_driver_sha256": driver_hashes,
                  "scope": "Matching Godot 4.7.2 Windows editor runtime loads the exact exported PCK with an external engine-side review harness. Fullscreen, isolated player profile, Dummy audio. No OS mouse automation. Export release executable does not expose --script."}
    if args.resume_profile:
        invocation["resumedReviewProfile"] = str(args.resume_profile.resolve())
    if args.scenario == "native-title":
        invocation["scope"] = "Actual shipped release executable, fullscreen requested, isolated profile, movie-mode title recording; no external script or OS mouse input. Dummy audio; forced CLI exit. The movie writer retains a 1280x720 capture buffer despite the display log reporting a 2560x1600 client; do not use its frames as full-window layout evidence."
    if args.scenario == "native-startup":
        invocation["scope"] = "Actual shipped release executable initializes the title and runs 120 frames capped at 60 FPS with fullscreen requested in an isolated profile. No external script, movie capture or OS mouse input. Dummy audio; forced CLI startup-only exit. Normal title Quit and window-close cleanup are tested separately against the same PCK."
    if args.audio:
        invocation["scope"] = invocation["scope"].replace("Dummy audio", "Default sound device requested (actual backend/fallback in verbose log)")
    (out / "invocation.json").write_text(json.dumps(invocation, indent=2), encoding="utf-8")
    print(f"Fullscreen review: {args.scenario}\nEvidence: {out}", flush=True)
    try:
        with (out / "runtime.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout,
                creationflags=subprocess.CREATE_NO_WINDOW)
        print("Exit:", result.returncode, flush=True)
        (out / "process-result.json").write_text(json.dumps({"exit_code": result.returncode, "timed_out": False}, indent=2) + "\n", encoding="utf-8")
    except subprocess.TimeoutExpired:
        (out / "process-result.json").write_text(json.dumps({"exit_code": None, "timed_out": True}, indent=2) + "\n", encoding="utf-8")
        print("Review timed out; partial log retained.", flush=True)
        raise SystemExit(2)
    text = (out / "runtime.log").read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    errors = [line for line in lines if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    print("\n".join(lines[-22:]))
    print("Error lines:", len(errors), flush=True)
    for line in errors[:20]: print(line)
    raise SystemExit(result.returncode or (1 if errors else 0))

if __name__ == "__main__": main()
