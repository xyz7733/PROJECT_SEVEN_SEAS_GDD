"""Collect preserved fullscreen review evidence; never rewrite raw traces."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def frame_summary(samples):
    if not samples:
        return {}
    return {
        "samples": len(samples), "frames": sum(x["frames"] for x in samples),
        "mean_fps_range": [min(x["meanFps"] for x in samples), max(x["meanFps"] for x in samples)],
        "p95_frame_ms_range": [min(x["p95FrameMs"] for x in samples), max(x["p95FrameMs"] for x in samples)],
        "max_sampled_interval_ms": max(x["maxFrameMs"] for x in samples),
        "scope": "VSync-inclusive process-frame wall intervals; captures excluded; not GPU execution or loading time",
    }


def collect_run(path: Path):
    inv = read_json(path / "invocation.json")
    text = (path / "runtime.log").read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    result = {
        "directory": path.relative_to(ROOT).as_posix(),
        "method": inv["scope"], "exe_sha256": inv["exe_sha256"], "pck_sha256": inv["pck_sha256"],
        "runtime_log": (path / "runtime.log").relative_to(ROOT).as_posix(),
        "script_error_lines": sum("SCRIPT ERROR" in x for x in lines),
        "engine_error_lines": sum(x.startswith("ERROR:") for x in lines),
        "warning_lines": sum(x.startswith("WARNING:") for x in lines),
        "wasapi_output_activated": "WASAPI: Activated output_device" in text,
        "pet_target_error_lines": sum("SCRIPT ERROR" in x and "Invalid access" in x and "target" in x and "Dictionary" in x for x in lines),
        "empty_tween_error_lines": sum("started with no Tweeners" in x for x in lines),
        "png_files": len(list(path.glob("*.png"))),
    }
    for filename in ("review-evidence.json", "quit-ui-evidence.json"):
        if (path / filename).exists():
            ev = read_json(path / filename)
            checks = ev.get("checks", [])
            result.update({"checks": len(checks), "checks_passed": sum(x["passed"] for x in checks),
                "failed_checks": [x["name"] for x in checks if not x["passed"]], "device": ev.get("device", {})})
            if "elapsed_seconds" in ev:
                result["elapsed_seconds"] = ev["elapsed_seconds"]
    if (path / "campaign_result.json").exists():
        camp = read_json(path / "campaign_result.json")
        result["campaign"] = {k: camp[k] for k in ("normal_campaign_complete", "stop_reason", "elapsed_seconds", "battles_exercised", "final", "regions")}
    if (path / "postgame_result.json").exists():
        result["postgame"] = read_json(path / "postgame_result.json")
    if (path / "postgame_finale_result.json").exists():
        result["postgame_finale"] = read_json(path / "postgame_finale_result.json")
    if (path / "catalogue-coverage.json").exists():
        cat = read_json(path / "catalogue-coverage.json")
        result["catalogue"] = {k: len(cat[k]) for k in ("locations", "battleContexts", "hullLevels")}
        result["catalogue"]["stable_frames"] = frame_summary(cat["stableFrameSamples"])
        result["catalogue"]["caveat"] = "Direct fixtures. Service-count/lightning assertions have documented driver errors; night/weather view level corrected in combat_focus."
    if (path / "combat-focus.json").exists():
        cases = read_json(path / "combat-focus.json")["cases"]
        outdoor = [x for x in cases if "frameSample" in x]
        result["combat_focus"] = {
            "case_records": len(cases), "outdoor_cases": len(outdoor),
            "outdoor_preconditions_all_pass": all(x["exposedPrecondition"] for x in outdoor),
            "night_frames": frame_summary([x["frameSample"] for x in outdoor if x["name"].startswith("night_outdoor")]),
            "weather_frames": frame_summary([x["frameSample"] for x in outdoor if x["name"].startswith("weather_outdoor")]),
            "natural_x1_results": [x for x in cases if "x1NaturalCompletion" in x],
            "caveat": "One battle Fit input failure is an unavailable-control driver error. Only site Fit inputs succeeded. Entry movement is not persistent framing failure.",
        }
    movies = sorted(path.glob("native*.png"))
    if movies:
        with movies[0].open("rb") as handle:
            header = handle.read(24)
        result["movie"] = {"frames": len(movies), "capture_size": list(struct.unpack(">II", header[16:24])),
            "caveat": "Movie buffer differs from fullscreen client. Not full-window layout evidence."}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", nargs="+", type=Path)
    parser.add_argument("--out", type=Path, default=ROOT / "docs/FULLSCREEN_REVIEW_20261114.json")
    args = parser.parse_args()
    runs = [collect_run(path.resolve()) for path in args.runs]
    artifacts = {name: hashlib.sha256((ROOT / "build/windows" / name).read_bytes()).hexdigest()
        for name in ("ProjectSevenSeas.exe", "ProjectSevenSeas.pck")}
    handoff = read_json(ROOT / "docs/WINDOWS_HANDOFF.json")
    unchanged = (artifacts["ProjectSevenSeas.exe"] == handoff["exe_sha256"] and
        artifacts["ProjectSevenSeas.pck"] == handoff["pck_sha256"] and
        all(x["exe_sha256"] == handoff["exe_sha256"] and x["pck_sha256"] == handoff["pck_sha256"] for x in runs))
    output = {"date": "2026-11-14", "revision": "world-art-01", "report": "docs/FULLSCREEN_REVIEW_20261114.md",
        "analysis_tool_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "artifact_sha256": artifacts, "release_exe_and_pack_unchanged": unchanged,
        "runs": runs, "scope": "Windows fullscreen GPU review; engine input/API progression and explicitly labelled fixtures",
        "not_verified": ["OS mouse manual playthrough", "Speaker listening", "OS window-close exit and other sound devices", "Other resolutions and low-end hardware", "Exhaustive old-save migrations"],
        "adjudication": {
            "confirmed": ["R1 offensive pet target lookup", "R2 exploration HUD Fit geometry", "R3 Inspector objective overlap and EN overflow", "R4 pause banner overlaps actors", "R5 defeat report empty Tween", "R6 Dummy/WASAPI shutdown resources"],
            "driver_corrections": ["Initial clicks needed physical screen coordinates", "Port boarding plank is not a seventh service", "Interior level persists across fixtures", "Battle HUD Fit is hidden", "Entry actor motion is transient", "Guided gear-capacity loop was a driver policy omission", "Sailing needs actual stage readiness rather than a fixed timer", "Committed report may close before observer checks its pointer", "Legend dialog click needs the rowboat entry to finish"],
        }}
    canonical = [x for x in runs if "campaign" in x or "postgame_finale" in x or
        x.get("postgame", {}).get("contexts_attempted", 0) > 0]
    output["canonical_save_chain"] = [x["directory"] for x in canonical]
    if canonical:
        last = canonical[-1]
        state = (last.get("postgame_finale") or last.get("postgame") or last.get("campaign"))["final"]
        output["canonical_final_state"] = {"main_trials": len(state["trials"]),
            "legend_victories": state.get("legends", []), "stats": state["stats"],
            "scope": "One continuous earned save chain; excludes fixture and failed branched-driver runs"}
    output["selection"] = "Meaningful review runs and relevant driver failures; early compile/coordinate iterations remain under build/review but are excluded from these counts. Earlier runs predate driver source snapshots."
    args.out.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"summary": str(args.out), "runs": len(runs), "png_files": sum(x["png_files"] for x in runs),
        "release_unchanged": unchanged}, ensure_ascii=False))
    if not unchanged:
        raise SystemExit("Artifact hash mismatch")


if __name__ == "__main__":
    main()
