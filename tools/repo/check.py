#!/usr/bin/env python3
"""Check repository hygiene and release metadata without changing Git state.

By default inspect tracked and non-ignored untracked working files. --staged
inspects the complete index, including versions and file contents from blobs.
"""
from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

from version import validate_texts


MAX_BYTES = 20 * 1024 * 1024
VERSION_FILES = ("game/project.godot", "game/export_presets.cfg")
CACHE_DIRS = {".godot", "__pycache__", ".pytest_cache", ".mypy_cache",
              ".ruff_cache", ".venv", "venv", "node_modules"}
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".ogg",
                   ".wav", ".mp3", ".flac", ".otf", ".ttf", ".woff", ".woff2",
                   ".zip", ".gz", ".7z", ".pdf", ".translation"}
EXPORT_SUFFIXES = {".exe", ".pck", ".dll", ".pdb", ".so", ".dylib", ".apk", ".aab"}
CREDENTIAL_SUFFIXES = {".pem", ".key", ".p12", ".pfx", ".jks", ".keystore"}
ENV_EXAMPLES = {".env.example", ".env.sample", ".env.template"}
CONFLICT_LINE = re.compile(r"^(?:<{7}(?: .*)?|={7}|>{7}(?: .*)?|\|{7}(?: .*)?)$")


@dataclass(frozen=True)
class Entry:
    path: str
    oid: str = ""
    mode: str = ""


def git(root: Path, *args: str, input_data: bytes | None = None) -> bytes:
    result = subprocess.run(["git", "-C", str(root), *args], input=input_data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(f"git {' '.join(args)} failed: {message}")
    return result.stdout


def forbidden(path: str) -> str | None:
    """Classify by path only: never open a possible credentials file."""
    parts = PurePosixPath(path.lower()).parts
    name = parts[-1]
    suffix = PurePosixPath(name).suffix
    if any(part in CACHE_DIRS for part in parts[:-1]):
        return "cache or local dependency directory"
    if parts[0] in {"build", "dist"} or parts[:2] in {("tools", "godot"), ("tools", "fonts")}:
        return "local build or downloaded tool directory"
    if suffix in {".pyc", ".pyo"}:
        return "Python cache"
    if suffix in EXPORT_SUFFIXES:
        return "exported executable or resource pack"
    if suffix == ".p7s":
        return "local player save (contents were not read)"
    if (name == "export_credentials.cfg" or name in {"id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"}
            or suffix in CREDENTIAL_SUFFIXES
            or (name not in ENV_EXAMPLES and (name == ".env" or name.startswith(".env.")))):
        return "credentials file (contents were not read)"
    return None


def entries(root: Path, staged: bool, errors: list[str]) -> list[Entry]:
    if not staged:
        names = git(root, "ls-files", "-c", "-o", "--exclude-standard", "-z").split(b"\0")
        return [Entry(name.decode("utf-8", errors="surrogateescape"))
                for name in sorted(set(names)) if name]
    result = []
    conflicted = set()
    for record in git(root, "ls-files", "--stage", "-z").split(b"\0"):
        if not record:
            continue
        metadata, raw_path = record.split(b"\t", 1)
        mode, oid, stage = metadata.decode("ascii").split()
        path = raw_path.decode("utf-8", errors="surrogateescape")
        if stage != "0":
            conflicted.add(path)
        else:
            result.append(Entry(path, oid, mode))
    errors.extend(f"{path}: unresolved index merge" for path in sorted(conflicted))
    return result


def index_sizes(root: Path, candidates: list[Entry]) -> dict[str, int]:
    oids = sorted({entry.oid for entry in candidates})
    if not oids:
        return {}
    output = git(root, "cat-file", "--batch-check", input_data=("\n".join(oids) + "\n").encode("ascii"))
    sizes = {}
    for line in output.splitlines():
        oid, kind, size = line.decode("ascii").split()
        if kind != "blob":
            raise ValueError(f"index object {oid}: expected blob, got {kind}")
        sizes[oid] = int(size)
    return sizes


def index_contents(root: Path, candidates: list[Entry]) -> dict[str, bytes]:
    oids = sorted({entry.oid for entry in candidates})
    if not oids:
        return {}
    output = git(root, "cat-file", "--batch", input_data=("\n".join(oids) + "\n").encode("ascii"))
    contents = {}
    offset = 0
    for expected in oids:
        end = output.index(b"\n", offset)
        oid, kind, raw_size = output[offset:end].decode("ascii").split()
        if oid != expected or kind != "blob":
            raise ValueError(f"cannot read index blob {expected}")
        size = int(raw_size)
        offset = end + 1
        contents[oid] = output[offset:offset + size]
        offset += size + 1
    return contents


def check(root: Path, staged: bool) -> tuple[list[str], int, str]:
    errors: list[str] = []
    candidates = []
    for entry in entries(root, staged, errors):
        path = root / entry.path
        if not staged and not path.exists() and not path.is_symlink():
            # Tracked deletions have no working file to inspect.
            continue
        reason = forbidden(entry.path)
        if reason:
            errors.append(f"{entry.path}: {reason}")
            continue
        if (staged and entry.mode not in {"100644", "100755"}) or (not staged and path.is_symlink()):
            errors.append(f"{entry.path}: symlinks and submodules need an explicit repository policy")
            continue
        candidates.append(entry)

    sizes = index_sizes(root, candidates) if staged else {}
    texts = []
    for entry in candidates:
        try:
            size = sizes[entry.oid] if staged else (root / entry.path).stat().st_size
            if size > MAX_BYTES:
                errors.append(f"{entry.path}: {size:,} bytes exceeds the 20 MiB per-file limit")
            elif PurePosixPath(entry.path).suffix.lower() not in BINARY_SUFFIXES:
                texts.append(entry)
        except OSError as exc:
            errors.append(f"{entry.path}: {exc}")
    blobs = index_contents(root, texts) if staged else {}
    versions = {}
    for entry in texts:
        try:
            raw = blobs[entry.oid] if staged else (root / entry.path).read_bytes()
            if entry.path.startswith("tools/") and entry.path.endswith(".py"):
                try:
                    ast.parse(raw, filename=entry.path)
                except (SyntaxError, ValueError) as exc:
                    errors.append(f"{entry.path}: invalid Python syntax: {exc}")
            if b"\0" in raw:
                continue
            try:
                text = raw.decode("utf-8-sig")
            except UnicodeDecodeError:
                if entry.path in VERSION_FILES:
                    errors.append(f"{entry.path}: release configuration must be UTF-8")
                continue
            for number, line in enumerate(text.splitlines(), 1):
                if CONFLICT_LINE.fullmatch(line):
                    errors.append(f"{entry.path}:{number}: unresolved merge conflict marker")
            if entry.path in VERSION_FILES:
                versions[entry.path] = text
        except OSError as exc:
            errors.append(f"{entry.path}: {exc}")
    for name in VERSION_FILES:
        if name not in versions:
            errors.append(f"{name}: required release configuration missing from {'index' if staged else 'working tree'}")
    release = ""
    if all(name in versions for name in VERSION_FILES):
        try:
            metadata = validate_texts(*(versions[name] for name in VERSION_FILES))
            release = f"{metadata.version} / {metadata.revision}"
        except ValueError as exc:
            errors.append(f"release metadata: {exc}")
    return errors, len(candidates), release


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staged", action="store_true", help="inspect index blobs instead of working files")
    args = parser.parse_args()
    try:
        root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel").decode("utf-8").strip())
        errors, count, release = check(root, args.staged)
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"Repository check failed: {exc}", file=sys.stderr)
        return 1
    if errors:
        print(f"Repository check failed ({len(errors)} issue(s)):", file=sys.stderr)
        for message in errors:
            print(f"  {message}", file=sys.stderr)
        return 1
    source = "index" if args.staged else "working tree"
    print(f"Repository check passed: {count} files in {source}; release {release}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
