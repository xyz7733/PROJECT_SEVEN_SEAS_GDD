"""Run the dedicated source-audio ownership probe with an isolated profile."""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("stop", "quit", "regression"), default="stop")
    parser.add_argument("--sequence", choices=("title", "cabin"), default="title")
    parser.add_argument("--audio", choices=("Dummy", "WASAPI"), default="Dummy")
    parser.add_argument("--windowed", action="store_true", help="Explicitly opt into a graphical run; coordinate with other review workers")
    args = parser.parse_args()
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    out = ROOT / "build/review" / f"{stamp}-audio-ownership-{args.audio}-{args.sequence}-{args.mode}"
    out.mkdir(parents=True)
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        path = out / "profile" / key.lower()
        path.mkdir(parents=True)
        env[key] = str(path)
    command = [str(ROOT / "tools/godot/windows/Godot_v4.7.2-stable_win64_console.exe"),
               "--path", str(ROOT / "game"), "--verbose", "--audio-driver", args.audio,
               "--script", str(ROOT / "tools/review/audio_cleanup_probe.gd")]
    if not args.windowed:
        command.insert(1, "--headless")
    command += ["--", "--mode", args.mode, "--sequence", args.sequence]
    sources = out / "source"
    sources.mkdir()
    hashes = {}
    for source in (ROOT / "game/scripts/core/audio.gd", Path(__file__), Path(__file__).with_name("audio_cleanup_probe.gd")):
        shutil.copy2(source, sources / source.name)
        hashes[source.relative_to(ROOT).as_posix()] = hashlib.sha256(source.read_bytes()).hexdigest()
    (out / "invocation.json").write_text(json.dumps({"command": command, "source_sha256": hashes,
        "scope": "Source audio ownership probe; no main scene or save progress"}, indent=2), encoding="utf-8")
    print(out.relative_to(ROOT), flush=True)
    with (out / "runtime.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                stdin=subprocess.DEVNULL, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
    lines = (out / "runtime.log").read_text(encoding="utf-8", errors="replace").splitlines()
    for line in lines:
        if "[audio-probe]" in line:
            marker, payload = line.split(" {", 1)
            data = json.loads("{" + payload)
            if "players" in data:
                data = {"backend": data["backend"], "mixer_ready": data["mixer_ready"], "since_last_mix": data["since_last_mix"],
                        "playing": sum(player["playing"] for player in data["players"]),
                        "live_playbacks": sum(ref["playback_alive"] for ref in data["tracked"]),
                        "live_streams": len({ref["id"] for ref in data["tracked"] if ref["stream_alive"]})}
            print(marker, json.dumps(data))
        elif "ERROR" in line or "WARNING" in line or "WASAPI:" in line:
            print(line)
    print("Exit:", result.returncode)
    raise SystemExit(result.returncode or int(any("ERROR" in line for line in lines)))


if __name__ == "__main__":
    main()
