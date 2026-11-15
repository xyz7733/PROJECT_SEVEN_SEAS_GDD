# Crew 01 — Sailor Attributes

Revision: `2.1.0 · crew-01`. Every sailor now has six personal attributes. They come from the
sailor's identity rather than a rarity roll, personality traits nudge them, and training points
earned through levels raise them. The world, catalogue and art from `world-art-02` are unchanged.

## The six attributes

10 is average. A sailor with 10 in every attribute has exactly the numbers they had before this
release. Every point above or below 10 adds the modifier below through `member_stats()`, after
collections and before equipment.

| Attribute | Per point away from 10 | Typical roles |
|---|---|---|
| **Might** | ATK ±1.2% | Duelist, spearfighter, brawler, beastkeeper |
| **Vigor** | Max HP ±1.5%, DEF ±0.8% | Guard, brawler, cook, quartermaster |
| **Agility** | SPD ±0.1; dodge +0.4% (above 10 only) | Duelist, gunner, navigator |
| **Focus** | Crit chance ±0.5%, control effects ±1.5% | Spearfighter, gunner, medic, tinkerer, mystic |
| **Will** | Healing ±1.5%, skill cooldowns ∓0.6% | Guard, medic, cook, beastkeeper, mystic |
| **Seamanship** | Ship-job efficiency ±3% | Anyone working aboard |

Values run from 1 to 30. Crit chance and dodge never drop below zero, and nobody gets a negative
dodge from low Agility. The chart scale and the bands (poor < 8, fair 8–11, good 12–14, great 15–19,
heroic 20+) are for display only.

## Where the numbers come from

**Base roll.** Each attribute starts at 6 and 22 points are dealt one at a time by weighted draw.
The sailor's origin leans toward two attributes, one random talent is favoured and one random
weakness is disfavoured, and a taper makes very high values rare (a single base value stops at 16).
In a simulation of 20,000 recruits the base values average 9.7, and 10.0 once traits are added
(standard deviation 2.7, range 4–19). About four in five sailors have one or two attributes at 13 or
more, and about four in five have one or two at 7 or less.

The roll uses its own random stream seeded from the sailor's identity seed, so the rest of the
recruit (class, origin, traits, aptitudes, name and look) is exactly what the same seed produced
before. There is no rarity ladder: every spread has strong and weak sides.

| Origin | Leans toward |
|---|---|
| Dawnwater fisher folk | Seamanship, Vigor |
| Ember forge clans | Might, Vigor |
| Verdant villages | Vigor, Will |
| Glass reef divers | Agility, Focus |
| Crown courts | Focus, Will |
| Storm harbors | Seamanship, Might |
| Moon isles | Will, Focus |
| Trench divers | Vigor, Focus |
| Ring nomads | Agility, Seamanship |
| Horizon wanderers | Agility, Might |

**Traits.** Each personality trait shifts two or three attributes by a net +1, so the pair a sailor
carries is visible in their spread (for example Stubborn: Vigor +2, Agility −1; Calm: Focus +1,
Will +1, Agility −1). The Attributes tab lists each trait's shifts.

**Training.** A sailor earns one training point every 4 levels, 15 by the level cap of 60. A point
goes into any attribute with the + button outside encounters and events. Retraining refunds every
spent point for 30 + 6 × level gold; it needs a port or a Class Hall aboard.

**Class keys.** Each base class names two attributes it relies on most (branches use their root
class). Key attributes are drawn in gold in the tab and on the chart. They guide choices; they do not
gate classes or equipment.

## Interface

- **Crew → Attributes** (new tab): a hexagon chart (rings at 5, 10, 15 and 20; the gold ring is
  average), one row per attribute with its value, bar, trained points and a + button, the points
  available and the level of the next point, Retrain with its cost, the net effect on stats, the
  class's key attributes, trait shifts and a short explanation. On narrow screens and the largest
  UI size the rows come first and a smaller chart sits beside the points.
- **Tooltips** on every attribute show the band, the base/trait/training breakdown, the current
  effect, the effect of one more point and whether it is a key attribute for the class.
- **Attribute strip** (six icons with values coloured by band) in Crew → Details, tavern cards, the
  post-battle recruit offer and the ship Inspector, so hiring decisions can weigh attributes.
- **Roster badge:** "+N" on a sailor's roster chip when they have unspent training points, and a
  log entry when a level-up earns a point.
- Six new original 16×16 icons (`at_might` … `at_seamanship`) from `tools/artgen/gen_ui.py`;
  the UI icon atlas grows from 159 to 165 icons. 59 new strings in each of English and Simplified
  Chinese.

## Saves

The save schema moves from 5 to 6. Loading an older save (schema 3 to 5) migrates it: every
existing sailor receives the attributes their stored identity seed and origin produce (the same
values a new hire with that seed would get) and an empty training record. Sailors who are already
level 4 or higher immediately have their earned training points to spend. Because attributes now
apply to everyone, a migrated sailor's HP, attack and other numbers shift slightly from the old save
in the direction of their spread; save hashes and transaction numbers are otherwise preserved.
Migration is idempotent and covered by a hand-written schema-5 save in the tests.

## Validation

- Core suite **7,226 checks** and UI layout suite **940 checks** pass (new `test_attrs.gd`; the
  layout suite now includes the Attributes tab in English and Chinese at UI sizes 1.0, 1.25 and
  1.5, and fails without the narrow layout).
- Existing combat, balance and replay tests pass unchanged; a sailor at 10 everywhere matches the
  pre-attribute numbers exactly.
- Offscreen screenshots of the Attributes tab, Details, tavern, recruit offer and Inspector in
  English (UI 1.0) and Chinese (UI 1.5).
- Windows: `tools/validation/validate_windows.py` import, tests and release export with smoke
  test; checksums in [Windows handoff](WINDOWS_HANDOFF.json).

## Known limits

- No manual campaign playthrough was made for this release; balance was checked by simulation and
  the existing combat tests. Strong spreads (for example Vigor 19 on a guard) are noticeable but
  stay within the ranges equipment and passives already reach.
- Enemy units do not have attributes; the system applies to the player's crew only.
