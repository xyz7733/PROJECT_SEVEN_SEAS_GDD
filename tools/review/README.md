# Native fullscreen review drivers

These external drivers review `build/windows/ProjectSevenSeas.pck` without
changing or re-exporting the game. The Windows Godot 4.7.2 editor runtime is
required because the shipped release template does not expose `--script`.
The actual release executable is separately exercised by `native-title`.

Audio uses Dummy by default. `--audio` requests the default sound device and
verbose backend/fallback logging for a separate shutdown check; it still
does not establish that anyone listened through speakers.

Run from the repository root on Windows with Python 3:

```powershell
python tools/review/run_fullscreen.py --scenario preflight --timeout 40
python tools/review/run_fullscreen.py --scenario controls --timeout 180
python tools/review/run_fullscreen.py --scenario catalogue --timeout 600
python tools/review/run_fullscreen.py --scenario combat_focus --timeout 180
python tools/review/run_fullscreen.py --scenario campaign --timeout 1000
python tools/review/run_fullscreen.py --scenario native-title --timeout 40
python tools/review/run_fullscreen.py --scenario title_quit --timeout 40
```

Run one graphical scenario at a time. Each creates a timestamped directory
under `build/review/`, redirects player-data environment variables into its
own `profile/`, and records the invocation, artifact hashes, runtime log,
PNG frames, checks and scenario evidence. Later invocations also retain an
exact `driver/` source snapshot and its hashes. Earlier run directories
predate that addition; their traces remain unchanged.

Fullscreen is requested and checked through `DisplayServer`. Screenshots
come from the real rendered root viewport on the local GPU. Godot Input
events and normal action/UI callbacks supply interaction. This is distinct
from desktop mouse automation, and Dummy audio provides no listening evidence.
The input helper takes physical window coordinates; Control centers must
be transformed by the viewport's screen transform as well as their canvas
transform.

| Scenario | Scope |
|---|---|
| `preflight` | Title, fresh port and first interior; fullscreen/device evidence |
| `controls` | Deck/guide/chart/camera input, management transactions, save round trip, EN/ZH windows at 1.0/1.25/1.5 UI scale |
| `catalogue` | Direct fixtures for all locations, combat contexts, hull views, and bounded frame samples; not normal campaign progression |
| `combat_focus` | Two bounded real-time ×1 fights, pause/orders, settled actor framing, HUD Fit, shelter transitions, explicitly outdoor night/weather fixtures |
| `campaign` | Seed-7 normal-rules progression with a deliberately bounded simple strategy; action APIs and normal Skip settlement |
| `campaign_guided` | Resume a copied manual checkpoint; normal promotions, gear/crafting, inventory salvage, earned rewards and battle orders |
| `postgame` | Resume a completed main-campaign manual save; attempt the five legendary rule variants once each, through normal rules |
| `postgame_finale` | Resume the four-Legend-win save; adjacent-port travel, earned unique gear, at most two attempts at the remaining Grand Horizon challenge |
| `native-title` | Actual release EXE, fullscreen display log and fixed 1280×720 movie frames, forced CLI exit; movie output is not full-window layout evidence |
| `title_quit` | Click the shipped title Quit through Godot Input and inspect the process shutdown log |

The guided continuation requires an earlier isolated review profile:

```powershell
python tools/review/run_fullscreen.py --scenario campaign_guided --resume-profile build/review/PRIOR-RUN/profile --timeout 1450
```

The source profile is copied and preserved. No XP grants, invulnerability,
resource edits or direct progress edits are used in either campaign driver.
The guided strategy detaches an offensive pet through the normal assignment
action to avoid the reviewed pet-skill defect. Combat uses the normal Skip
control after sampled live observation. This establishes rule progression,
not a complete real-time mouse playthrough or a human completion-time estimate.

After the main run has ten trial victories and unlocked postgame, use the same
`--resume-profile` argument with `--scenario postgame --timeout 400`. The driver
records five attempts separately from victories; it does not promise all five
will be won. Each challenge costs normal stamina and settles normal losses or
rewards. `postgame_result.json` records its results and save verification.

`postgame_finale` uses the same copied-profile argument and a 400-second
external timeout. It makes at most two further attempts with earned gear,
preserves defeat consequences, and writes `postgame_finale_result.json`.
`summarize.py RUN_DIRECTORY ... --out SUMMARY.json` collects raw trace counts,
release hashes and the canonical save chain without modifying those traces.

Scenario checks can fail without terminating the game; inspect JSON and logs,
not only the process exit code. The runner returns nonzero for runtime error
lines. `title_quit` exits before the common finalizer: it writes
`quit-ui-evidence.json` before clicking, and completion is evidenced by the
external process status and shutdown log. `native-title` has movie frames and
a runtime log instead of common harness evidence.

Frame samples explicitly marked `screenshotsExcluded` exclude capture work.
They measure VSync-inclusive process-frame wall intervals, not GPU execution
time. Whole-run maximum intervals include PNG encoding and stage construction
and must not be presented as ordinary gameplay hitches.

The final review records corrections to early driver assumptions, including
port services versus the boarding plank, persistent interior view levels,
physical click coordinates and camera-entry transients. A fixture-only or
driver failure is not a game defect.
