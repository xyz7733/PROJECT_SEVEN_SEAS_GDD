# Contributing and version management

The repository is licensed under [GPL v3](LICENSE), SPDX `GPL-3.0-only`, except
for third-party material and files with separate licence notices. Retain asset
provenance and licence files when changing or redistributing assets.

## Local setup

Clone the repository or add its local folder with GitHub Desktop's **File > Add
local repository**. Open `game/project.godot` in Godot 4.7.2. Install Python 3.10+
for maintenance tools. Generator dependencies are listed in
[tools/requirements.txt](tools/requirements.txt).

Enable the shared commit checks once per clone:

```powershell
git config --local core.hooksPath .githooks
git config --local commit.template .gitmessage
python tools/repo/check.py
```

These settings also apply to commits made in GitHub Desktop. Python must be on
the application's PATH; restart Desktop after installing Python if needed.
The hook checks staged content, so partially staged changes are checked exactly
as they will be committed. To undo local setup, use `git config --local --unset
core.hooksPath` and `git config --local --unset commit.template`.

## Branches and commits

Use `main` for integrated work and short branches such as `feat/crew-training`,
`fix/audio-exit` or `chore/repository`. Start from the intended base branch and
keep each commit focused. Keep gameplay changes separate from repository tooling.
Use prefixes such as `feat:`, `fix:`, `art:`, `docs:`, `test:` and `chore:`.

Before committing:

```powershell
git status --short
git diff
python tools/repo/check.py
git add -- path/to/changed-file
git diff --cached --stat
git diff --cached --check
python tools/repo/check.py --staged
git commit
```

The checker rejects build outputs, caches, credential paths, files over 20 MiB,
merge conflict markers, invalid Python tools and inconsistent application/export
versions. It does not replace gameplay tests or review generated images/audio.

Keep runtime assets, source references, `.gd.uid`, `.import` and generated
translations tracked. Keep engine downloads, `.godot`, `build/`, environments,
player saves and export credentials local. The archived web prototype remains a
data input for export/localization tools. Current asset sizes do not require Git
LFS; decide on LFS with collaborators before introducing much larger binaries.

## Releases

The application version lives in `game/project.godot`. Windows file/product
versions must match it with a fourth `.0` component. Update them together:

```powershell
python tools/repo/version.py --set 2.1.1 --revision crew-02
python tools/repo/version.py --check
```

Update the README current-release entry, CHANGELOG and new release notes. Leave
historical handoff and review manifests intact. Then run repository checks and
the isolated source/UI suites:

```powershell
python tools/repo/check.py
python tools/validation/validate_windows.py
python tools/validation/validate_windows.py --skip-import --export
```

Commit the reviewed source, notes and licensing before making an annotated
`v2.1.1` tag. Record the tested commit SHA, engine version, validation and exported
artifact SHA-256 values in the new release record. Do not tag an old commit while
the actual release source is still uncommitted. Never move an existing release
tag to different source.

Push only the intended branch and tag. Upload EXE/PCK/ZIP artifacts through GitHub
Releases; `build/` stays ignored. Binary redistribution must include the applicable
licences and provide the corresponding source as required by GPL v3.

## Recovery snapshots

Before large changes, run:

```powershell
python tools/repo/snapshot.py --label before-refactor
```

Snapshots under ignored `build/repository-backups/` contain Git history, a worktree
ZIP including untracked nonignored files, a binary patch and SHA-256 manifest.
Ignored untracked files (including local engines and build exports) are excluded;
tracked files are always backed up, even if they match an ignore rule. Verify
a snapshot with `python tools/repo/snapshot.py --verify SNAPSHOT_DIRECTORY`.

To recover, clone `history.bundle` into a **new empty directory**, check out the
manifest's recorded commit, then extract `worktree.zip` there. If the manifest
lists `missing_paths`, remove those tracked paths only in this recovery copy.
The ZIP preserves the working tree; `tracked.patch` records changes for review.
The snapshot does not recreate the original staging selection. Check the restored
files before replacing any working folder. Copy backups to another disk for
protection against disk loss.
