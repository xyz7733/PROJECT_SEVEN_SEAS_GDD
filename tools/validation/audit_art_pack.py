"""Check a Godot 4 PCK directory, resource coverage and every file digest.

Reads the native artifact without starting a game or changing player data.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def audit(path: Path) -> dict:
    problems = []
    with path.open("rb") as f:
        header = f.read(104)
        if header[:4] != b"GDPC":
            raise ValueError("Not a Godot pack")
        version, major, minor, patch, flags = struct.unpack_from("<IIIII", header, 4)
        if version != 4 or flags & 1:
            raise ValueError("Expected the unencrypted Godot 4.7 format-4 export")
        base, directory = struct.unpack_from("<QQ", header, 24)
        f.seek(directory if flags & 2 else 104)
        count = struct.unpack("<I", f.read(4))[0]
        entries = []
        for _ in range(count):
            length = struct.unpack("<I", f.read(4))[0]
            name = f.read(length).rstrip(b"\0").decode("utf-8")
            offset, size = struct.unpack("<QQ", f.read(16))
            digest = f.read(16)
            file_flags = struct.unpack("<I", f.read(4))[0]
            entries.append((name, offset, size, digest, file_flags))
        for name, offset, size, digest, file_flags in entries:
            if file_flags or base + offset + size > path.stat().st_size:
                problems.append(f"Invalid/encrypted file extent: {name}")
                continue
            f.seek(base + offset)
            if hashlib.md5(f.read(size)).digest() != digest:
                problems.append(f"File digest mismatch: {name}")
    names = {x[0] for x in entries}
    directory_by_name = {entry[0].removeprefix("res://"): entry for entry in entries}
    required = ["data/scene_profiles.json", "assets/gen/env/landmarks.json",
                "assets/gen/env/landmarks.png.import"]
    profile = json.loads((ROOT / "game/data/scene_profiles.json").read_text(encoding="utf-8"))
    landmark_entries = json.loads((ROOT / "game/assets/gen/env/landmarks.json").read_text(encoding="utf-8"))["landmarks"]
    for loc_id, loc in profile["locations"].items():
        key = f"{loc['regionId']}:{loc['landmarkVariant']}"
        if key not in landmark_entries:
            problems.append(f"Missing authored landmark variant for {loc_id}: {key}")
    required += [f"assets/audio/ambience/regional/{rid}.wav.import"
                 for rid in [*profile["regions"], "cabin"]]
    for item in required:
        if not any(n.removeprefix("res://") == item for n in names):
            problems.append(f"Missing shipped resource: {item}")
    source_json_matches = 0
    for item in ("data/scene_profiles.json", "assets/gen/env/landmarks.json"):
        entry = directory_by_name.get(item)
        if entry is not None:
            source_path = ROOT / "game" / item
            if hashlib.md5(source_path.read_bytes()).digest() != entry[3]:
                problems.append(f"Packed JSON differs from current source: {item}")
            else:
                source_json_matches += 1
    if not any("scene_profiles" in n and "scripts/view/" in n for n in names):
        problems.append("Missing SceneProfiles script")
    for name in names:
        if name.startswith(("tests/", "i18n/source/", "art/source/")):
            problems.append(f"Development resource unexpectedly exported: {name}")
    return {"pack": str(path.relative_to(ROOT)), "packFormat": version,
            "engine": f"{major}.{minor}.{patch}", "files": count,
            "fileDigestsVerified": count - sum("digest mismatch" in p for p in problems),
            "requiredResourceCount": len(required),
            "currentSourceJsonMatches": source_json_matches,
            "locationLandmarkVariants": len([n for n in landmark_entries if ":" in n]),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "errors": problems, "runtimeStarted": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", nargs="?", type=Path, default=ROOT / "build/windows/ProjectSevenSeas.pck")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    report = audit(args.pack.resolve())
    rendered = json.dumps(report, indent=2)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)
    raise SystemExit(bool(report["errors"]))


if __name__ == "__main__":
    main()
