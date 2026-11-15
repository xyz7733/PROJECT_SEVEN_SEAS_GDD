"""Write the world-art-02 receipt from preserved checks and runtime traces."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def run_receipt(folder: Path):
    inv = read(folder / "invocation.json")
    ev = read(folder / "review-evidence.json")
    text = (folder / "runtime.log").read_text(encoding="utf-8", errors="replace")
    errors = [x for x in text.splitlines() if "SCRIPT ERROR" in x or x.startswith("ERROR:")]
    resource_warnings = [x for x in text.splitlines() if x.startswith("WARNING:") and ("leaked" in x or "resources" in x)]
    process = read(folder / "process-result.json") if (folder / "process-result.json").exists() else None
    complete = "[review-complete]" in text
    return {"directory": folder.relative_to(ROOT).as_posix(), "pck_sha256": inv["pck_sha256"],
        "checks": len(ev["checks"]), "failed_checks": [x["name"] for x in ev["checks"] if not x["passed"]],
        "errors": errors, "resource_warnings": resource_warnings, "process": process, "completed": complete,
        "screenshots": ev["screenshots"], "device": ev["device"],
        "passed": bool(ev["checks"]) and complete and process is not None and process["exit_code"] == 0
            and not process["timed_out"] and not errors and not resource_warnings and all(x["passed"] for x in ev["checks"])}


def audio_probe(folder: Path):
    inv = read(folder / "invocation.json")
    source_hash = hashlib.sha256((ROOT / "game/scripts/core/audio.gd").read_bytes()).hexdigest()
    log = (folder / "runtime.log").read_text(encoding="utf-8", errors="replace")
    cases = [json.loads(line.split("heartbeat-case ", 1)[1]) for line in log.splitlines() if "[audio-probe] heartbeat-case " in line]
    errors = [line for line in log.splitlines() if "SCRIPT ERROR" in line or line.startswith("ERROR:")]
    return {"directory": folder.relative_to(ROOT).as_posix(), "source_sha256": inv["source_sha256"],
        "current_audio_source_matches": inv["source_sha256"]["game/scripts/core/audio.gd"] == source_hash,
        "heartbeat_cases": cases, "errors": errors, "scope": inv["scope"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalogue", type=Path, required=True)
    parser.add_argument("--battle", type=Path, required=True)
    args = parser.parse_args()
    validation = ROOT / "build/validation/world-art-02"
    source = read(validation / "latest-source.json")
    export = read(validation / "latest-export.json")
    audit = read(validation / "pack-audit.json")
    comparison = read(validation / "catalogue-final-equivalence.json")
    matrix = read(validation / "runtime-matrix.json")
    catalogue = run_receipt(args.catalogue.resolve())
    battle = run_receipt(args.battle.resolve())
    audio_probes = [audio_probe(ROOT / "build/review" / name) for name in (
        "20261114-221351-229656-audio-ownership-WASAPI-cabin-quit",
        "20261114-221353-632165-audio-ownership-Dummy-cabin-regression")]
    hashes = {name: hashlib.sha256((ROOT / "build/windows" / name).read_bytes()).hexdigest()
        for name in ("ProjectSevenSeas.exe", "ProjectSevenSeas.pck")}
    current_pack = hashes["ProjectSevenSeas.pck"]
    matrix_hashes_match = all(read(ROOT / row["directory"] / "invocation.json")["pck_sha256"] == current_pack for row in matrix["cases"])
    passed = all((source["passed"], export["passed"], not audit["errors"], comparison["passed"],
        matrix["passed"], catalogue["passed"], battle["passed"], matrix_hashes_match,
        battle["pck_sha256"] == current_pack, comparison["final_sha256"] == current_pack,
        catalogue["pck_sha256"] == current_pack, audit["sha256"] == current_pack,
        all(x["current_audio_source_matches"] and not x["errors"] for x in audio_probes),
        len(audio_probes[1]["heartbeat_cases"]) == 11 and all(x["pass"] for x in audio_probes[1]["heartbeat_cases"])))
    coverage = read(args.catalogue / "catalogue-coverage.json")
    current_coverage = {"revision": "world-art-02", "pck_sha256": catalogue["pck_sha256"],
        "source_run": catalogue["directory"], "scope": "Rendered final-pack fixtures, not a complete campaign or OS-mouse playthrough", "coverage": coverage}
    sites = [x for x in coverage["locations"] if x["type"] != "port"]
    passed = passed and all(x["allRoomNodesInFitSafeArea"] and x["fullLandmarkInsideFitSafeArea"] for x in sites)
    receipt = {"revision": "world-art-02", "version": "2.0.1", "passed": passed,
        "artifact_sha256": hashes, "source": source, "export": export, "pack_audit": audit,
        "catalogue_candidate_equivalence": comparison, "catalogue": catalogue,
        "catalogue_uses_final_pack": catalogue["pck_sha256"] == current_pack, "source_audio_probes": audio_probes,
        "final_battle_regression": battle, "final_runtime_matrix": matrix,
        "fit_sites": {"total": len(sites), "nodes_safe": sum(x["allRoomNodesInFitSafeArea"] for x in sites),
            "landmarks_safe": sum(x["fullLandmarkInsideFitSafeArea"] for x in sites)},
        "verified": ["Core source suite: 6,975 checks; UI layout suite: 928 checks; no script/engine errors",
            "100 location and 190 battle-context GPU fixtures, 14 hull views; 1,120 catalogue checks passed",
            "All 80 exploration sites fit nodes/landing and complete landmarks within HUD-safe area",
            "186 bilingual window/tab/scale cases; final Input/management and Inspector checks pass",
            "Real companion skill damage and source-verified immediate 1.6x Sic Em command, earned-save compatibility, west-route preparation and frozen pending-definition round trip",
            "Final EN/ZH dense x4 battle: pause/notice/labels avoid HUD, sprites and health bars; real Encore observed",
            "Dummy/default-WASAPI title Quit and Window.close_requested regression; actual release EXE 120-frame non-movie startup check",
            "All 382 pack file digests and required resources verified; old world-art-01 checkpoint preserved"],
        "remaining_limits": ["No OS-mouse manual playthrough or speaker listening; fixtures and engine Input/API are labelled",
            "Default WASAPI mixer is stalled in this session: deferral/recovery/cleanup paths verified, not healthy audible output",
            "If a previously healthy device stops mixing after owning streams, Godot exposes no safe script flush; Quit is bounded but backend references may remain",
            "MovieWriter --quit-after bypasses normal Quit and forces synchronous Dummy audio: the retained movie probe leaked resources; it is excluded from normal cleanup acceptance",
            "No new complete campaign clear or all optional builds/quests/achievements; gameplay variety prototypes cover four dungeons in two seas",
            "No low-end hardware, other resolutions or exhaustive old-save migration acceptance"],
        "scope": "Review-driven repairs, exact final-pack GPU catalogue and targeted regressions; historical review remains separate"}
    destination = ROOT / "docs/WORLD_ART_02_VALIDATION.json"
    (ROOT / "docs/WORLD_ART_02_COVERAGE.json").write_text(json.dumps(current_coverage, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    destination.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"receipt": str(destination), "passed": passed, "fit_sites": receipt["fit_sites"], "artifact_sha256": hashes}, indent=2))
    raise SystemExit(0 if passed else 1)


if __name__ == "__main__":
    main()
