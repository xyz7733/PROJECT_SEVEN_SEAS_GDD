"""Verify an earlier visual candidate differs only in Main's close handler."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct


def directory(path: Path, allow_battle: bool, allow_pet: bool):
    entries = {}
    with path.open("rb") as file:
        header = file.read(104)
        if header[:4] != b"GDPC":
            raise ValueError("Not a Godot PCK")
        flags = struct.unpack_from("<I", header, 20)[0]
        base, offset = struct.unpack_from("<QQ", header, 24)
        file.seek(offset if flags & 2 else 104)
        count = struct.unpack("<I", file.read(4))[0]
        for _ in range(count):
            length = struct.unpack("<I", file.read(4))[0]
            name = file.read(length).rstrip(b"\0").decode().removeprefix("res://")
            position, size = struct.unpack("<QQ", file.read(16))
            digest = file.read(16).hex()
            file_flags = struct.unpack("<I", file.read(4))[0]
            if file_flags:
                raise ValueError("Encrypted entry")
            entries[name] = {"offset": base + position, "size": size, "md5": digest}
        components = ["scripts/main"]
        if allow_battle:
            components.append("scripts/view/battle_view")
        if allow_pet:
            components.append("scripts/core/combat")
        main_files = set()
        for component in components:
            main_files.update(component + suffix for suffix in (".gd", ".gdc", ".gd.remap"))
            remap = entries.get(component + ".gd.remap")
            if remap:
                file.seek(remap["offset"])
                text = file.read(remap["size"]).decode()
                for match in re.findall(r'path="([^"]+)"', text):
                    main_files.add(match.removeprefix("res://"))
    return entries, main_files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("final", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--allow-battle-layout", action="store_true", help="Also allow the independently retested popup/body collision correction")
    parser.add_argument("--allow-pet-command", action="store_true", help="Also allow the independently retested Sic Em companion action correction")
    args = parser.parse_args()
    old, old_main = directory(args.candidate, args.allow_battle_layout, args.allow_pet_command)
    new, new_main = directory(args.final, args.allow_battle_layout, args.allow_pet_command)
    names = set(old) | set(new)
    changed = [name for name in sorted(names) if old.get(name, {}).get("md5") != new.get(name, {}).get("md5")]
    unexpected = [name for name in changed if name not in old_main | new_main]
    result = {"candidate": str(args.candidate), "final": str(args.final),
        "candidate_sha256": hashlib.sha256(args.candidate.read_bytes()).hexdigest(),
        "final_sha256": hashlib.sha256(args.final.read_bytes()).hexdigest(),
        "changed_files": changed, "unexpected_changes": unexpected,
        "identical_non_main_entries": sum(name not in old_main | new_main and name in old and name in new and old[name]["md5"] == new[name]["md5"] for name in names),
        "allowed_components": ["Main window-close handler"] + (["BattleView popup/body collision layout"] if args.allow_battle_layout else []) + (["Combat commanded pet action"] if args.allow_pet_command else []),
        "passed": not unexpected, "scope": "All resources outside the listed independently retested components are byte-identical to the visual-catalogue candidate."}
    args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    raise SystemExit(bool(unexpected))


if __name__ == "__main__":
    main()
