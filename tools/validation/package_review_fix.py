"""Freeze world-art-02 only after its source, pack and runtime receipt exists."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil

from audit_art_pack import audit

ROOT = Path(__file__).resolve().parents[2]
REVISION = "world-art-02"


def main():
    release = ROOT / "build/windows"
    checkpoint = ROOT / "build/windows-checkpoints" / REVISION
    if checkpoint.exists():
        raise SystemExit("Immutable checkpoint already exists: " + str(checkpoint))
    receipt_path = ROOT / "docs/WORLD_ART_02_VALIDATION.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    report = audit(release / "ProjectSevenSeas.pck")
    if report["errors"] or receipt["revision"] != REVISION or not receipt["passed"]:
        raise SystemExit("Validation receipt or pack audit failed")
    hashes = {name: hashlib.sha256((release / name).read_bytes()).hexdigest()
        for name in ("ProjectSevenSeas.exe", "ProjectSevenSeas.pck")}
    if hashes != receipt["artifact_sha256"]:
        raise SystemExit("Validation receipt does not describe the current binaries")
    licenses = release / "licenses"
    licenses.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "docs/AUDIO_LICENSES.md", licenses / "AUDIO_LICENSES.md")
    (licenses / "ART_PROVENANCE.md").write_text(
        "# Artwork provenance\n\nProject Seven Seas world-art-02 ships original code-authored "
        "pixel/voxel artwork. Ships, scenery, actors, interface and all 100 landmark compositions "
        "are produced by the repository's native pixel/voxel generators.\n\n"
        "Ten earlier AI-origin images are retained outside the shipped game as concept references "
        "only. No pixels from those images occur in the shipped landmark atlas. Their original "
        "prompts and hashes remain in art/source/landmarks/manifest.json. User reference screenshots "
        "are not shipped, sampled or traced.\n\nThe audio CC0 dedication does not apply to artwork. "
        "The bundled font retains its supplied licences. See AUDIO_LICENSES.md for sound credits.\n",
        encoding="utf-8")
    handoff = {"revision": REVISION, "version": "2.0.1", "status": "exported_regression_checked",
        "directory": checkpoint.relative_to(ROOT).as_posix(),
        "exe_sha256": hashes["ProjectSevenSeas.exe"], "pck_sha256": hashes["ProjectSevenSeas.pck"],
        "engine": "Godot 4.7.2 stable Windows x86-64 editor and release template",
        "verified_here": receipt["verified"], "known_issues": receipt["remaining_limits"],
        "review_document": "docs/WORLD_ART_02.md", "review_evidence": receipt_path.relative_to(ROOT).as_posix(),
        "previous_review": "docs/FULLSCREEN_REVIEW_20261114.md",
        "coverage": "docs/WORLD_ART_02_COVERAGE.json", "pack_audit": "build/validation/world-art-02/pack-audit.json",
        "handoff_doc": (checkpoint / "HANDOFF.md").relative_to(ROOT).as_posix()}
    checkpoint.mkdir(parents=True)
    for name in hashes:
        shutil.copy2(release / name, checkpoint / name)
    shutil.copytree(licenses, checkpoint / "licenses")
    (checkpoint / "HASHES.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    (checkpoint / "PACK_AUDIT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    offline_notes = (ROOT / "docs/WORLD_ART_02.md").read_text(encoding="utf-8")
    offline_notes = offline_notes.replace("[全屏试玩评审](FULLSCREEN_REVIEW_20261114.md)", "历史全屏试玩评审（源码工程 docs/FULLSCREEN_REVIEW_20261114.md）")
    offline_notes = offline_notes.replace("(WORLD_ART_02_VALIDATION.json)", "(VALIDATION.json)").replace("(WINDOWS_HANDOFF.json)", "(HANDOFF.json)")
    (checkpoint / "HANDOFF.md").write_text(offline_notes, encoding="utf-8")
    shutil.copy2(receipt_path, checkpoint / "VALIDATION.json")
    shutil.copy2(ROOT / "docs/WORLD_ART_02_COVERAGE.json", checkpoint / "COVERAGE.json")
    handoff_text = json.dumps(handoff, indent=2, ensure_ascii=False) + "\n"
    (ROOT / "docs/WINDOWS_HANDOFF.json").write_text(handoff_text, encoding="utf-8")
    (checkpoint / "HANDOFF.json").write_text(handoff_text, encoding="utf-8")
    archive = shutil.make_archive(str(ROOT / "build" / ("ProjectSevenSeas-" + REVISION)), "zip", checkpoint)
    print(json.dumps({"checkpoint": str(checkpoint), "archive": archive, "hashes": hashes}, indent=2))


if __name__ == "__main__":
    main()
