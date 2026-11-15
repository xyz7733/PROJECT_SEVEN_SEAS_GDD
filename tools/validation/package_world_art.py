"""Freeze the audited native world-art-01 build without launching the game."""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from audit_art_pack import audit

ROOT = Path(__file__).resolve().parents[2]
REVISION = "world-art-01"


def main():
    release = ROOT / "build/windows"
    checkpoint = ROOT / "build/windows-checkpoints" / REVISION
    if checkpoint.exists():
        raise SystemExit(f"Immutable checkpoint already exists: {checkpoint}")
    report = audit(release / "ProjectSevenSeas.pck")
    if report["errors"]:
        raise SystemExit("Pack audit failed: " + "; ".join(report["errors"]))
    licenses = release / "licenses"
    licenses.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "docs/AUDIO_LICENSES.md", licenses / "AUDIO_LICENSES.md")
    provenance = (
        "# Artwork provenance\n\n"
        "Project Seven Seas world-art-01 combines original code-authored pixel/voxel artwork "
        "with ten AI-origin regional landmark masters generated using the built-in OpenAI "
        "image tool. Its exact backend model was not exposed and is not asserted.\n\n"
        "One hundred location vignette compositions reuse those masters and the original "
        "regional scenery kit. The source project preserves prompts, source masters, hashes "
        "and deterministic packing in art/source/landmarks/ and tools/artgen/gen_landmarks.py. "
        "User reference screenshots are not included or sampled.\n\n"
        "The CC0 audio dedication does not apply to artwork. The bundled pixel font retains "
        "its supplied font licenses. See AUDIO_LICENSES.md for sound credits.\n"
    )
    (licenses / "ART_PROVENANCE.md").write_text(provenance, encoding="utf-8")
    checkpoint.mkdir(parents=True)
    for name in ("ProjectSevenSeas.exe", "ProjectSevenSeas.pck"):
        shutil.copy2(release / name, checkpoint / name)
    shutil.copytree(licenses, checkpoint / "licenses")
    hashes = {name: hashlib.sha256((checkpoint / name).read_bytes()).hexdigest()
              for name in ("ProjectSevenSeas.exe", "ProjectSevenSeas.pck")}
    (checkpoint / "HASHES.json").write_text(json.dumps(hashes, indent=2) + "\n", encoding="utf-8")
    handoff = {
        "revision": REVISION, "status": "exported_pending_manual_visual_review",
        "directory": checkpoint.relative_to(ROOT).as_posix(),
        "exe_sha256": hashes["ProjectSevenSeas.exe"], "pck_sha256": hashes["ProjectSevenSeas.pck"],
        "engine": "Godot 4.7.2 stable Windows x86-64 editor and release template",
        "verified_here": [
            "Complete offline artwork rebuild; 10 preserved AI-origin masters and 100 location vignette variants",
            "Static catalogue audit: 10 seas, 100 locations, 310 rooms, 190 combat contexts; all 80 site foundations clear routes",
            "Godot headless editor import and native release export; no SCRIPT ERROR or ERROR lines in logs",
            f"All {report['files']} packed-file digests verified; required resources present and source JSON matches pack",
            "Selected native-size landmark, architecture, interior, actor and layout-catalogue previews inspected",
            "Eleven original sound-loop waveform metrics and provenance recorded; audio credits synchronized",
        ],
        "not_verified_here": "No runtime game instance or gameplay/layout suite launched. Native rendered scenes, mouse interaction, animation, UI scales, old-save runtime behavior, frame pacing, speaker mix and ordinary sound-device shutdown require manual review.",
        "changes": [
            "Ten regional architecture/material/lighting/wildlife/audio identities; authored location and battle profiles",
            "Four refined hulls, 27 facilities, paired interior furniture, distinct class/rival/boss/pet details",
            "Quieter water/terrain, regional chart vignettes, navy/brass/cream UI and compact expandable deck list",
            "Ten regional atmosphere loops and cabin bed, sheltered mixing and explicit audio cleanup on Quit",
        ],
        "windows_checks": [
            "Confirm title revision world-art-01. Review English and Simplified Chinese at UI 1.0/1.25/1.5, 16:9 and 16:10.",
            "Inspect all ten seas in day, dusk, night and representative weather; follow the source coverage catalogue.",
            "Review all four hulls and interiors in motion, ladders, building/moving/rotating facilities and expandable deck selector.",
            "Visit islands, ruins, wrecks, trials and secret sites; check actor contact, landmark occlusion, landing and return routes.",
            "Fight normal, elite, boss and boarding encounters with pause/speed/Reduce Motion; inspect framing and scene-entry pacing.",
            "Listen to regional/cabin transitions and mixing; quit through title/System and normal window close.",
        ],
        "handoff_doc": (checkpoint / "HANDOFF.md").relative_to(ROOT).as_posix(),
        "coverage": "docs/WORLD_ART_COVERAGE.json", "pack_audit": "build/validation/world-art-01/pack-audit.json",
        "known_issues": ["Runtime visual, interaction, motion, listening and performance acceptance remain pending; earlier craft measurements do not validate this revision."],
    }
    text = json.dumps(handoff, indent=2) + "\n"
    (ROOT / "docs/WINDOWS_HANDOFF.json").write_text(text, encoding="utf-8")
    (checkpoint / "HANDOFF.json").write_text(text, encoding="utf-8")
    shutil.copy2(ROOT / "docs/WORLD_ART_01.md", checkpoint / "HANDOFF.md")
    (checkpoint / "PACK_AUDIT.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    archive = shutil.make_archive(str(ROOT / "build" / f"ProjectSevenSeas-{REVISION}"), "zip", checkpoint)
    print(json.dumps({"checkpoint": str(checkpoint), "archive": archive, "hashes": hashes}, indent=2))


if __name__ == "__main__":
    main()
