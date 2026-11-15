# Development tools

Run commands from the repository root. Repository tooling requires Python 3.10+
and Git; Godot validation uses the project's Godot 4.7.2 editor.

| Directory | Purpose |
|---|---|
| `repo/` | Repository checks, version updates and local recovery snapshots |
| `artgen/` | Pixel/voxel artwork and preview generation |
| `audiogen/` | Original synthesized audio |
| `content/` | Content expansion and scene profiles |
| `i18n/` | Translation table generation and checks |
| `validation/` | Source, asset, Windows export and GPU checks |
| `review/` | [Fullscreen review drivers](review/README.md) |
| `shots/` | Screenshot scenarios and Linux runner |
| `data_export/` | Conversion from the preserved web prototype |
| `godot/`, `fonts/` | Ignored local engine, templates and downloaded fonts |

## Repository maintenance

```powershell
python tools/repo/check.py
python tools/repo/check.py --staged
python tools/repo/version.py --check
python tools/repo/snapshot.py --label before-update
python tools/repo/snapshot.py --verify build/repository-backups/SNAPSHOT
```

See [CONTRIBUTING](../CONTRIBUTING.md) for setup, commits, releases and recovery.

## Generated assets

Install the generator dependencies in a local environment:

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r tools/requirements.txt
.venv/Scripts/python tools/artgen/build_all.py
.venv/Scripts/python tools/i18n/build_strings.py
```

On Linux, use `.venv/bin/python`. Generation rewrites tracked assets, previews,
translations and inventories. Review those changes together with their generator
changes. `game/assets/gen/` and translations are committed so a clone can open
without running generators. Preserve `.gd.uid` and `.import` metadata.

## Validation

```powershell
python tools/validation/audit_scene_profiles.py
python tools/validation/audit_art_pack.py
python tools/validation/validate_windows.py
```

The Windows runner isolates player data in `build/validation/` and runs import,
core tests and UI layout tests. Use `--export` for a Windows release. Asset-pack
checks require an existing PCK and compare it with the current source files.

`package_world_art.py`, `package_review_fix.py`, `receipt_review_fix.py` and
`validate_review_fix.py` are checkpoint-specific tools with historical revision
values. Keep them for reproducing those records; do not use them to label a new
release. Use `version.py` and the current validation/export runner instead.
