"""Regenerate every original art asset and write docs/ASSET_INVENTORY.md.

Usage (from the repository root):
    tools/artgen/.venv/bin/python tools/artgen/build_all.py
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from lib.common import INVENTORY  # noqa: E402

import gen_ambient  # noqa: E402
import gen_chars  # noqa: E402
import gen_chart  # noqa: E402
import gen_creatures  # noqa: E402
import gen_dressing  # noqa: E402
import gen_env  # noqa: E402
import gen_facilities  # noqa: E402
import gen_landmarks  # noqa: E402
import gen_ship  # noqa: E402
import gen_title  # noqa: E402
import gen_ui  # noqa: E402

ROOT = HERE.parent.parent

STEPS = [
    ("ship hulls + parts", gen_ship.main),
    ("facilities", gen_facilities.main),
    ("interior dressing", gen_dressing.main),
    ("characters", gen_chars.build),
    ("creatures", gen_creatures.build),
    ("environment", gen_env.build),
    ("native regional monuments", gen_landmarks.build),
    ("ambient life", gen_ambient.build),
    ("sea chart", gen_chart.build),
    ("ui", gen_ui.build),
    ("title emblem", gen_title.build),
]

THIRD_PARTY = [
    ("game/assets/fonts/fusion-pixel-12px-zh_hans.otf", "Fusion Pixel Font 12px (zh_hans)", "SIL Open Font License 1.1",
     "game/assets/fonts/OFL-fusion-pixel.txt (bundled with the upstream licences of the fonts it merges: "
     "OFL-ark-pixel.txt, OFL-cubic-11.txt, LICENSE-galmuri.txt)"),
]


def write_inventory():
    lines = [
        "# Asset Inventory",
        "",
        "The shipped game artwork is original code-authored pixel/voxel art.",
        "The voxel renderer (`lib/vox.py`) and pixel canvas (`lib/pix.py`) build the ships, facilities, actors,",
        "terrain, regional monuments and interface. `gen_landmarks.py` uses the same native renderer",
        "and material rules for all 100 location landmark compositions. Ten AI-origin images remain",
        "in `art/source/landmarks/` as concept references only; no pixels from those images occur in",
        "the shipped landmark atlas. Their provenance and prompts remain in `manifest.json`.",
        "Rebuilding is offline and never overwrites those concept references.",
        "",
        "The two user reference screenshots in `art/reference/` set the art direction only. They are not",
        "shipped, sampled or traced, and their UI and watermarks are not reproduced.",
        "",
        "Regenerate everything with:",
        "",
        "```",
        "tools/artgen/.venv/bin/python tools/artgen/build_all.py",
        "```",
        "",
        "Preview sheets (not shipped) are written to `art/previews/`.",
        "",
        "## Generated assets",
        "",
        "| Path | Dimensions | Frames / contents | Origin / method | Used for |",
        "|---|---|---|---|---|",
    ]
    for r in INVENTORY:
        def esc(s):
            return str(s).replace("|", "\\|")
        lines.append(f"| `{esc(r['path'])}` | {esc(r['size'])} | {esc(r['frames'])} | {esc(r['method'])} | "
                     f"{esc(r['usage'])}{(' — ' + esc(r['notes'])) if r.get('notes') else ''} |")
    lines += [
        "",
        "Each atlas has a JSON sidecar beside it (rects, anchors/origins, frame lists, animation tables). The",
        "Godot scripts read these at runtime to build `AtlasTexture` regions, `TileSet` sources and animations.",
        "",
        "## Animation summary",
        "",
        "- **Crew / NPC puppets** (`chars/`): 24×32 frames in 21 poses: idle ×2, walk ×4, work ×2, attack ×3,",
        "  hit, down, cheer ×2, back-idle ×2 and back-walk ×4. They are layered as outfit, skin/head, hair",
        "  (back and front, tinted at runtime), hat and weapon, so any crew member's class, gear and looks",
        "  combine without per-character sheets.",
        "- **Monsters / bosses / pets** (`creatures/`): 11 frames each. Idle ×2, move ×4, attack ×3, hit and",
        "  defeat.",
        "- **Facilities** (`facilities/`): idle and working states for each footprint rotation.",
        "- **Water** (`env/terrain_*`): 4-frame animated deep, open and shallow tiles per region.",
        "- **FX** (`ui/fx.png`): steam, smoke, sparks, notes, bubbles, hearts, sleep, heal, hit, slash, splash,",
        "  fire, dust, sparkle, coin, orb, bullet, arrow and wake.",
        "- **Ambient life** (`env/ambient.png`): gull ×4 (flap and glide), sea glint ×5, whitecap ×6, leaping",
        "  fish ×8 with a ripple ×4, bow spray ×5 and butterfly ×2, plus three still cloud shadows.",
        "",
        "## Third-party resources",
        "",
        "| Path | Resource | Licence | Licence file |",
        "|---|---|---|---|",
    ]
    for p, n, lic, f in THIRD_PARTY:
        lines.append(f"| `{p}` | {n} | {lic} | {f} |")
    lines += [
        "",
        "## Audio",
        "",
        "Audio lives in `game/assets/audio/`. The music, ambience and most effects are third-party **CC0 1.0** files:",
        "",
        "- music from OpenGameArt by Thimras, beardalaxy and Eldritch Grim;",
        "- ambience field recordings from BigSoundBank;",
        "- effects from Kenney (Interface Sounds, Impact Sounds, RPG Audio, Music Jingles) and from Thimras's \"Battle at sea\".",
        "",
        "The victory and defeat stingers, the rain and storm beds, the two thunder claps and the boss horn are original. They are synthesised by `tools/audiogen/gen_stingers.py` and `tools/audiogen/gen_weather.py`.",
        "Ten regional texture loops and one sheltered cabin loop are original CC0 synthesis from `tools/audiogen/gen_regional.py`; their manifest records waveform statistics and pending listening review.",
        "",
        "Every file's source URL, creator, original filename and licence is listed in `docs/AUDIO_LICENSES.md`.",
        "That file, the CC0 legal code and the Kenney pack licence notes are distributed in `build/windows/licenses/`.",
        "",
        "| Folder | Files | Contents | Licence |",
        "|---|---|---|---|",
        "| `audio/music/` | 3 | Sailing/title loop, port loop, battle drum loop | CC0 1.0 |",
        "| `audio/ambience/` | 7 | Open sea (masts), harbour gulls, coast waves, cave, rowing, rain loop, storm loop | CC0 1.0 (rain and storm loops original) |",
        "| `audio/ambience/regional/` | 11 | Ten quiet regional texture loops and a sheltered cabin bed | Original CC0 1.0 |",
        "| `audio/sfx/` | 56 | UI cues, wood/plank/door/creak/coins/cloth/bell, combat swings, hits, knockouts, jingles, cannon, ram, two stingers, near and far thunder, boss horn | CC0 1.0 (stingers, thunder and boss horn original) |",
        "",
        "## Code-drawn scene elements",
        "",
        "Some scene dressing is drawn at runtime with Godot's 2D drawing API rather than from textures. All of it is original:",
        "",
        "| Element | Script | What it draws |",
        "|---|---|---|",
        "| Landing rowboat (`SiteView.RowBoat`) | `scripts/view/site_view.gd` | Two halves around the seated crew, with animated oars and wake. Also used for boats moored at ports. |",
        "| Market stalls (`ShipView.Stall`) | `scripts/view/ship_view.gd` | Striped canopy stalls. |",
        "| Bunting and laundry lines (`ShipView.StringLine`) | `scripts/view/ship_view.gd` | Pennants and washing between buildings. |",
        "| Net racks (`ShipView.NetRack`) | `scripts/view/ship_view.gd` | Fishing nets hung on poles. |",
        "| Chimney smoke | `scripts/view/ship_view.gd` | Particle puffs over houses. |",
        "| Boarding planks and grapnel ropes | `scripts/view/battle_view.gd` | Lines spanning the two hulls. |",
        "| Impact bursts (`BattleView.Burst`) | `scripts/view/battle_view.gd` | Shapes for critical hits, skills and knockouts. |",
        "| Wake and bow wave (`SailFx`) | `scripts/view/sail_fx.gd` | Foam flecks along the waterline, the stern trail and the two bow-wave arms while under way. The spray sprites come from `env/ambient.png`. |",
        "| Lighthouse beam and fireflies (`Ambience`) | `scripts/view/ambience.gd` | The rotating additive beam at night and the firefly glows. Gulls, glints, whitecaps, fish, butterflies and cloud shadows are sprites from `env/ambient.png`. |",
        "| Weather (`WeatherLayer`) | `scripts/view/weather_layer.gd` | The overcast tint, rain streaks and the splashes where they land, dithered fog banks, falling ash and embers, and lightning flashes. |",
        "| Boss aura and boss bar (`BattleView.BossAura`, `BattleView.BossBar`) | `scripts/view/battle_view.gd` | The pulsing red ring under a boss and the boss health gauge with its trailing chip. |",
        "| Stage sweep (`Curtain`) | `scripts/view/curtain.gd` | The dithered diagonal sweep between stages, drawn by a shader over a frozen frame. |",
        "",
        "The font and the CC0 audio are the only third-party files the game ships. Godot Engine itself is MIT-licensed.",
        "The export templates come from the official Godot release and are not part of this repository's assets.",
        "",
    ]
    out = ROOT / "docs" / "ASSET_INVENTORY.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def main():
    t0 = time.time()
    for name, fn in STEPS:
        t = time.time()
        fn()
        print(f"[artgen] {name}: {time.time() - t:.1f}s", flush=True)
    out = write_inventory()
    print(f"[artgen] inventory -> {out.relative_to(ROOT)} ({len(INVENTORY)} rows) in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
