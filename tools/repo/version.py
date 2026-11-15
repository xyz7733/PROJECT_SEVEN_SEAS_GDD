"""Check or update the release version in Godot's project and Windows preset.

The project file is the version source. Historical handoff records are immutable.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import tempfile
from typing import NamedTuple


ROOT = Path(__file__).resolve().parents[2]
PROJECT = Path("game/project.godot")
PRESETS = Path("game/export_presets.cfg")
VERSION_PATTERN = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", re.ASCII)
REVISION_PATTERN = re.compile(r"[A-Za-z0-9]+(?:[._-][A-Za-z0-9]+)*", re.ASCII)


class Release(NamedTuple):
    version: str
    revision: str


class Field(NamedTuple):
    value: str
    start: int
    end: int


def _field(text: str, key: str, section: str, label: str) -> Field:
    """Find exactly one assignment, including duplicates in other sections."""
    assignment = re.compile(r"[ \t]*" + re.escape(key) + r"[ \t]*=")
    quoted = re.compile(r'[ \t]*' + re.escape(key) + r'[ \t]*=[ \t]*"([^"\r\n]*)"[ \t]*(?:;.*)?')
    matches = []
    current_section = ""
    offset = 0
    for line in text.splitlines(keepends=True):
        content = line.rstrip("\r\n")
        header = re.fullmatch(r"\[([^\]]+)\][ \t]*(?:;.*)?", content.lstrip("\ufeff").strip())
        if header:
            current_section = header.group(1)
        if assignment.match(content):
            matches.append((current_section, content, offset))
        offset += len(line)
    if len(matches) != 1:
        raise ValueError(f"{label}: expected exactly one {key} assignment, found {len(matches)}")
    found_section, content, offset = matches[0]
    if found_section != section:
        raise ValueError(f"{label}: {key} must be in [{section}]")
    match = quoted.fullmatch(content)
    if match is None:
        raise ValueError(f"{label}: {key} must be a quoted string")
    return Field(match.group(1), offset + match.start(1), offset + match.end(1))


def _validate_values(version: str, revision: str) -> Release:
    if VERSION_PATTERN.fullmatch(version) is None:
        raise ValueError("Version must be N.N.N without leading zeroes, for example 2.1.1")
    # Compare strings first so an arbitrarily long input cannot exceed int's limit.
    if any(len(part) > 5 or int(part) > 65535 for part in version.split(".")):
        raise ValueError("Each version component must be between 0 and 65535")
    if REVISION_PATTERN.fullmatch(revision) is None:
        raise ValueError("Revision must be a nonempty slug, for example crew-02 (letters, digits, . _ -)")
    return Release(version, revision)


def _project_release(project_text: str) -> Release:
    version = _field(project_text, "config/version", "application", str(PROJECT)).value
    revision = _field(project_text, "config/build_revision", "application", str(PROJECT)).value
    return _validate_values(version, revision)


def validate_texts(project_text: str, presets_text: str) -> Release:
    """Validate worktree or index texts; raise ValueError on inconsistency."""
    release = _project_release(project_text)
    expected = release.version + ".0"
    for key in ("application/file_version", "application/product_version"):
        value = _field(presets_text, key, "preset.0.options", str(PRESETS)).value
        if value != expected:
            raise ValueError(f"{PRESETS}: {key} is {value!r}; expected {expected!r}")
    return release


def _read(path: Path) -> str:
    with path.open(encoding="utf-8", newline="") as stream:
        return stream.read()


def read_release(root: Path = ROOT) -> Release:
    """Read and validate the authoritative project version and revision."""
    return _project_release(_read(Path(root) / PROJECT))


def validate_release(root: Path = ROOT) -> Release:
    """Read and validate the project together with its Windows resource version."""
    root = Path(root)
    return validate_texts(_read(root / PROJECT), _read(root / PRESETS))


def _replace(text: str, changes: list[tuple[Field, str]]) -> str:
    for field, value in sorted(changes, key=lambda change: change[0].start, reverse=True):
        text = text[:field.start] + value + text[field.end:]
    return text


def _atomic_write(path: Path, text: str) -> None:
    """Replace one file without exposing a partially written configuration."""
    descriptor, name = tempfile.mkstemp(prefix="." + path.name + ".", suffix=".tmp", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
            stream.write(text)
        os.chmod(temporary, path.stat().st_mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def set_release(root: Path, version: str, revision: str) -> Release:
    """Validate every replacement before updating either configuration file."""
    release = _validate_values(version, revision)
    root = Path(root)
    project_path, presets_path = root / PROJECT, root / PRESETS
    project_text, presets_text = _read(project_path), _read(presets_path)
    project_changes = [
        (_field(project_text, "config/version", "application", str(PROJECT)), version),
        (_field(project_text, "config/build_revision", "application", str(PROJECT)), revision),
    ]
    preset_changes = [
        (_field(presets_text, key, "preset.0.options", str(PRESETS)), version + ".0")
        for key in ("application/file_version", "application/product_version")
    ]
    new_project = _replace(project_text, project_changes)
    new_presets = _replace(presets_text, preset_changes)
    validate_texts(new_project, new_presets)
    if new_project == project_text and new_presets == presets_text:
        return release
    _atomic_write(project_path, new_project)
    try:
        _atomic_write(presets_path, new_presets)
    except OSError:
        _atomic_write(project_path, project_text)
        raise
    return release


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Check versions without changing files (default)")
    mode.add_argument("--set", metavar="N.N.N", dest="new_version", help="Set the project and Windows resource versions")
    parser.add_argument("--revision", help="Build revision slug, required with --set")
    args = parser.parse_args()
    if (args.new_version is None) != (args.revision is None):
        parser.error("--set and --revision must be provided together")
    try:
        release = (set_release(ROOT, args.new_version, args.revision)
                   if args.new_version is not None else validate_release(ROOT))
    except (OSError, ValueError) as error:
        parser.exit(1, f"Version check failed: {error}\n")
    action = "Updated" if args.new_version is not None else "Checked"
    print(f"{action}: {release.version} / {release.revision}")
    print("Update README, CHANGELOG and release notes manually when preparing a release.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
