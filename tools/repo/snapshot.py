"""Save or verify a local recovery snapshot without changing the Git index.

Run from the repository (or one of its subdirectories):
    python tools/repo/snapshot.py --label before-content-update
    python tools/repo/snapshot.py --verify build/repository-backups/SNAPSHOT

Snapshots include history, all tracked working files, non-ignored untracked files,
and a binary patch for tracked changes. Ignored untracked builds and downloads
are excluded. Restore into a separate directory; this tool never restores files.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile


def git(root: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", *args], cwd=root, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        reason = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(f"git {args[0]} failed: {reason}")
    return result.stdout


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def backup_directory(root: Path, candidate: Path) -> Path:
    """Restrict snapshot access to this repository's backup directory."""
    base = (root / "build/repository-backups").resolve()
    target = candidate.resolve()
    if target == base or not target.is_relative_to(base):
        raise ValueError(f"Snapshot must be inside {base}")
    return target


def safe_archive_path(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(path.parts) and name == path.as_posix() and not path.is_absolute() and not any(
        part == ".." or part.casefold() == ".git" or ":" in part or "\\" in part
        for part in path.parts
    )


def verify_snapshot(root: Path, directory: Path) -> int:
    directory = backup_directory(root, directory)
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    files = manifest["files"]
    if not isinstance(files, dict):
        raise ValueError("Invalid snapshot file manifest")
    if any(not safe_archive_path(name) for name in files):
        raise ValueError("Unsafe path in snapshot manifest")
    missing = manifest.get("missing_paths", [])
    if not isinstance(missing, list) or any(
        not isinstance(name, str) or not safe_archive_path(name) or name in files
        for name in missing
    ):
        raise ValueError("Invalid missing paths in snapshot manifest")
    artifacts = manifest.get("artifacts", {})
    for name, expected in artifacts.items():
        if name not in {"worktree.zip", "history.bundle", "tracked.patch", "status-before.txt"}:
            raise ValueError(f"Unexpected snapshot artifact: {name}")
        if digest(directory / name) != expected:
            raise ValueError(f"Snapshot artifact digest mismatch: {name}")
    with zipfile.ZipFile(directory / "worktree.zip") as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or set(names) != set(files):
            raise ValueError("Snapshot ZIP entries differ from its manifest")
        corrupt = archive.testzip()
        if corrupt:
            raise ValueError(f"Snapshot ZIP checksum mismatch: {corrupt}")
        for name, expected in files.items():
            value = hashlib.sha256()
            with archive.open(name) as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    value.update(chunk)
            if value.hexdigest() != expected:
                raise ValueError(f"Snapshot file digest mismatch: {name}")
    # --all creates a self-contained bundle. Verification only reads the repo.
    git(root, "bundle", "verify", str(directory / "history.bundle"))
    return len(files)


def create_snapshot(root: Path, label: str) -> Path:
    now = datetime.now().astimezone()
    suffix = re.sub(r"[^A-Za-z0-9._-]+", "-", label).strip(".-_")[:64]
    if label and not suffix:
        raise ValueError("Label must contain a letter or number")
    stamp = now.strftime("%Y%m%d-%H%M%S-%f")
    directory = backup_directory(
        root, root / "build/repository-backups" / (stamp + (f"-{suffix}" if suffix else "")),
    )
    # Capture the candidate set before creating the output directory. A temporary
    # repo need not have a /build/ ignore rule for the backup to exclude itself.
    names = sorted(set(
        name for name in git(root, "ls-files", "-c", "-o", "--exclude-standard", "-z")
        .decode("utf-8").split("\0") if name
    ))
    directory.mkdir(parents=True, exist_ok=False)
    incomplete = directory / "INCOMPLETE.txt"
    incomplete.write_text("Snapshot creation has not completed successfully.\n", encoding="utf-8")
    try:
        head = git(root, "rev-parse", "HEAD").decode("ascii").strip()
        branch = git(root, "rev-parse", "--abbrev-ref", "HEAD").decode("utf-8").strip()
        (directory / "status-before.txt").write_bytes(
            git(root, "status", "--porcelain=v1", "-uall"),
        )
        (directory / "tracked.patch").write_bytes(git(root, "diff", "--binary", "HEAD"))
        git(root, "bundle", "create", str(directory / "history.bundle"), "--all", "HEAD")
        files: dict[str, str] = {}
        missing: list[str] = []
        with zipfile.ZipFile(directory / "worktree.zip", "x", zipfile.ZIP_DEFLATED) as archive:
            for name in names:
                if not safe_archive_path(name):
                    raise ValueError(f"Unsupported repository path: {name!r}")
                path = root / name
                if not path.exists():
                    missing.append(name)
                    continue
                if path.is_symlink() or not path.resolve().is_relative_to(root):
                    raise ValueError(f"Snapshot does not support symlinks: {name}")
                if not path.is_file():
                    raise ValueError(f"Snapshot does not support submodules/directories: {name}")
                value = hashlib.sha256()
                with path.open("rb") as source, archive.open(name, "w", force_zip64=True) as target:
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        target.write(chunk)
                        value.update(chunk)
                files[name] = value.hexdigest()
        artifact_names = ("worktree.zip", "history.bundle", "tracked.patch", "status-before.txt")
        manifest = {
            "schema": 1, "created_at": now.isoformat(), "head": head,
            "branch": branch, "label": suffix, "files": files, "missing_paths": missing,
            "artifacts": {name: digest(directory / name) for name in artifact_names},
        }
        (directory / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
        )
        verify_snapshot(root, directory)
        # A marker is removed only after every artifact has passed verification.
        incomplete.unlink()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile):
        print(f"Incomplete snapshot retained at: {directory}", file=sys.stderr)
        raise
    return directory


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--label", default="", help="Optional descriptive snapshot label")
    mode.add_argument("--verify", type=Path, metavar="DIR", help="Verify an existing snapshot")
    args = parser.parse_args()
    try:
        root = Path(git(Path.cwd(), "rev-parse", "--show-toplevel").decode("utf-8").strip()).resolve()
        if args.verify is not None:
            directory = args.verify if args.verify.is_absolute() else Path.cwd() / args.verify
            count = verify_snapshot(root, directory)
            print(f"Snapshot verified: {directory.resolve()} ({count} files)")
        else:
            directory = create_snapshot(root, args.label)
            print(f"Snapshot created and verified: {directory}")
        return 0
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print(f"Snapshot failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
