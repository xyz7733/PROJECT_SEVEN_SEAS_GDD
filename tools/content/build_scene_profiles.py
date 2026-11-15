"""Build the authored, presentation-only atlas of the hundred existing places.

The catalogue below is art direction, not a random world generator. Each entry
chooses a named landform, a landmark and a route composition. Gameplay graphs,
room identities, costs and encounters remain in world.json. Run from any folder.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORLD_PATH = ROOT / "game/data/world.json"
OUT_PATH = ROOT / "game/data/scene_profiles.json"
SERVICES = ["market", "tavern", "workshop", "quest_board", "house", "navigation"]
LANDMARK_FOOTPRINT = [144, 64]

# The ordering in each list is the existing room-template ordering. Coordinates
# are world pixels at the character's ground contact, never isometric cells.
# The approach is the boat landing's offset from the first room.
# id, coastal form, landmark, route points, landing approach, landmark offset
DESIGNS = {
    "dawnwater": [
        ("brightquay", "harbor", "working_harbor_beacon", [], (-128, 22), (54, -132)),
        ("saltmarsh_landing", "creek", "saltleaf_net_sheds", [], (-116, 44), (-56, -126)),
        ("gull_rock", "headland", "three_stacks_watch", [(-168, 8), (-16, -76), (-6, 84), (154, -14), (142, -138)], (-128, 32), (22, -144)),
        ("lantern_isle", "crescent", "lantern_keeper_garden", [(-170, 36), (-36, -48), (-22, 116), (138, 32), (110, -126)], (-122, 16), (-28, -136)),
        ("coral_steps", "reef", "coral_stair_fan", [(-164, -36), (-20, -116), (-10, 56), (148, -32), (132, 136)], (-116, 42), (48, -126)),
        ("old_lookout", "cliff", "broken_lantern_tower", [(-244, 20), (-82, -74), (-80, 112), (80, 18), (244, -30), (226, 144)], (-126, 18), (18, -156)),
        ("brine_cellars", "cellars", "crowned_salt_casks", [(-254, -20), (-92, -112), (-92, 68), (72, -18), (236, 24), (222, -146)], (-120, 36), (32, -140)),
        ("driftplank_wreck", "wreck_cove", "broken_trade_mast", [(-102, 38), (94, -20)], (-130, 28), (34, -130)),
        ("dawn_trial_ring", "ring", "harbor_charter_dais", [(14, 12)], (-144, 38), (20, -136)),
        ("tidefin_grotto", "lagoon", "tidefin_spring", [(-12, 28)], (-136, -12), (42, -124)),
    ],
    "emberreach": [
        ("cinderport", "foundry", "copper_furnace_wharf", [], (-126, 38), (50, -138)),
        ("ashfall_harbor", "shelter", "ash_roof_relief_store", [], (-144, 18), (-44, -142)),
        ("basalt_isle", "basalt", "split_basalt_crown", [(-174, 22), (-22, -96), (-26, 72), (142, -12), (126, -178)], (-126, 32), (28, -140)),
        ("smolder_key", "crescent", "smoking_copper_vents", [(-184, 46), (-36, -34), (-4, 128), (150, 46), (102, -122)], (-114, 26), (-48, -148)),
        ("obsidian_atoll", "atoll", "obsidian_mirror_pool", [(-190, 6), (-28, -94), (-18, 100), (152, 12), (116, -196)], (-136, 10), (56, -146)),
        ("magma_vents", "fissure", "great_copper_vent", [(-252, 40), (-90, -60), (-88, 126), (78, 30), (254, -16), (230, 160)], (-126, -4), (26, -162)),
        ("forge_depths", "forge", "hanging_foundry_crucible", [(-268, -22), (-100, -126), (-92, 60), (76, -32), (242, 14), (228, -158)], (-136, 24), (-34, -148)),
        ("scorched_galleon", "wreck_spit", "charred_galleon_ribs", [(-110, -18), (110, 40)], (-134, 34), (12, -150)),
        ("ember_crucible", "crater", "brazen_trial_crucible", [(28, -18)], (-150, 42), (-28, -144)),
        ("cinderback_nest", "hot_spring", "warm_basalt_nest", [(-26, 44)], (-128, 28), (24, -136)),
    ],
    "verdant_maw": [
        ("rootharbor", "root_bay", "giant_root_market", [], (-132, 28), (46, -144)),
        ("fernwater_post", "creek", "fern_canopy_boardwalk", [], (-116, 48), (-48, -132)),
        ("tanglewood_isle", "roots", "braided_root_arch", [(-188, 32), (-32, -70), (-16, 118), (150, 22), (118, -156)], (-124, 18), (34, -154)),
        ("orchid_cay", "garden", "orchid_water_garden", [(-176, -10), (-28, -120), (-18, 58), (138, -26), (120, 136)], (-128, 42), (-40, -128)),
        ("maw_shore", "jaws", "root_jaw_overlook", [(-188, 58), (-30, -26), (-12, 154), (158, 66), (132, -124)], (-136, -8), (46, -150)),
        ("overgrown_shrine", "root_hall", "root_embraced_shrine", [(-266, 26), (-106, -80), (-82, 114), (84, 24), (252, -20), (226, 162)], (-124, 28), (30, -164)),
        ("thornroot_caves", "root_cavern", "thornroot_water_chamber", [(-256, -36), (-92, -144), (-76, 50), (88, -42), (252, 8), (232, -176)], (-138, 40), (-36, -148)),
        ("vine_wreck", "wreck_creek", "vine_bound_rudder", [(-116, 38), (100, -28)], (-126, -4), (42, -134)),
        ("verdant_arena", "garden_ring", "living_root_dais", [(-24, 14)], (-138, 56), (32, -152)),
        ("moss_hollow", "hollow", "mossling_hollow_tree", [(24, -12)], (-142, 34), (-22, -144)),
    ],
    "glass_current": [
        ("prismhaven", "prism_bay", "white_prism_lantern", [], (-130, 20), (58, -138)),
        ("mirrorbay", "mirror_inlet", "glass_windbell_pier", [], (-124, 46), (-42, -136)),
        ("shard_reef", "shards", "shattered_prism_reef", [(-170, 26), (-12, -84), (-14, 102), (146, 10), (126, -164)], (-132, 36), (48, -148)),
        ("lens_isle", "lens", "great_glass_lens", [(-180, -16), (-32, -118), (-20, 72), (146, -16), (116, 148)], (-134, 28), (-32, -136)),
        ("quartz_spire", "spire", "split_quartz_spire", [(-192, 58), (-38, -44), (-16, 146), (154, 46), (124, -142)], (-120, 4), (34, -160)),
        ("crystal_vault", "crystal_hall", "prism_vault_dome", [(-260, 18), (-98, -96), (-78, 100), (90, 12), (254, -36), (232, 148)], (-134, 26), (36, -166)),
        ("refraction_maze", "mirror_hall", "angled_mirror_gate", [(-270, -34), (-98, -138), (-84, 58), (88, -38), (256, 6), (236, -172)], (-124, 40), (-24, -158)),
        ("glassbound_hulk", "wreck_reef", "crystal_locked_ribs", [(-108, 26), (104, -34)], (-142, 24), (28, -148)),
        ("prism_court", "prism_ring", "faceted_trial_canopy", [(36, 18)], (-152, 26), (38, -158)),
        ("glasswing_lagoon", "lagoon", "glasswing_reed_arbor", [(8, 46)], (-136, -24), (-30, -138)),
    ],
    "crown_shoals": [
        ("crownport", "arcade", "chartered_harbor_arcade", [], (-132, 24), (60, -142)),
        ("silkmarket", "market_cove", "striped_silk_market", [], (-118, 48), (-56, -138)),
        ("gilded_cay", "terrace", "gilded_courtyard", [(-184, 18), (-30, -100), (-26, 92), (144, 6), (120, -176)], (-134, 26), (36, -146)),
        ("heron_isle", "marsh", "heron_reed_pavilion", [(-174, -24), (-24, -122), (-10, 68), (148, -18), (120, 150)], (-124, 44), (-36, -136)),
        ("regent_bank", "bank", "regent_sea_stair", [(-192, 54), (-34, -48), (-16, 138), (154, 48), (126, -142)], (-132, 10), (44, -150)),
        ("charter_archive", "archive", "charter_seal_library", [(-264, 34), (-100, -76), (-84, 122), (88, 28), (256, -14), (234, 166)], (-136, 14), (28, -158)),
        ("old_family_crypt", "crypt", "ancestral_stone_gallery", [(-258, -42), (-98, -146), (-76, 50), (90, -42), (258, 4), (234, -180)], (-126, 36), (-32, -146)),
        ("treasury_wreck", "wreck_bank", "gilded_treasury_stern", [(-118, 26), (98, -38)], (-130, 42), (36, -142)),
        ("crown_tourney", "court", "silk_banner_tourney", [(-36, 22)], (-144, 36), (24, -148)),
        ("pearl_grotto", "pearl_pool", "pearl_shell_fountain", [(18, -28)], (-138, 48), (-26, -134)),
    ],
    "stormbelt": [
        ("gale_harbor", "breakwater", "storm_chain_harbor", [], (-138, 24), (52, -152)),
        ("beacon_rest", "shelter", "yellow_window_refuge", [], (-122, 52), (-46, -140)),
        ("thunder_rock", "cliff", "thunder_split_monolith", [(-186, 26), (-30, -90), (-14, 106), (148, 16), (116, -174)], (-138, 30), (42, -160)),
        ("squall_isle", "swept_spit", "wind_bent_signal_mast", [(-174, -28), (-22, -132), (-10, 64), (150, -26), (126, 146)], (-128, 44), (-42, -148)),
        ("lightning_reach", "headland", "lightning_copper_array", [(-198, 58), (-36, -46), (-14, 148), (158, 46), (126, -152)], (-136, 4), (38, -166)),
        ("drowned_beacon", "beacon_hall", "tilted_beacon_lens", [(-268, 30), (-104, -82), (-88, 118), (82, 20), (256, -26), (232, 160)], (-130, 22), (34, -168)),
        ("tempest_caverns", "storm_cave", "flooded_storm_chamber", [(-262, -44), (-96, -152), (-76, 48), (92, -42), (262, 0), (238, -188)], (-140, 38), (-40, -156)),
        ("stormwrack_hulk", "wreck_cliff", "storm_torn_crows_nest", [(-120, 32), (106, -32)], (-140, 16), (44, -154)),
        ("eye_of_storm", "storm_ring", "sheltered_eye_standards", [(42, -28)], (-156, 44), (-26, -154)),
        ("cloudray_aerie", "aerie", "cloudray_wind_arch", [(-34, 48)], (-140, -18), (28, -148)),
    ],
    "moonwake": [
        ("lanternport", "lantern_bay", "moon_lantern_balconies", [], (-130, 34), (54, -146)),
        ("dusk_mooring", "moon_inlet", "dusk_tea_pier", [], (-122, 48), (-48, -138)),
        ("nightbloom_isle", "garden", "nightbloom_lantern_arbor", [(-182, 24), (-26, -90), (-12, 100), (148, 12), (124, -168)], (-132, 38), (32, -150)),
        ("echo_atoll", "atoll", "echo_bell_crescent", [(-178, -28), (-28, -132), (-8, 64), (152, -20), (126, 150)], (-126, 42), (-38, -142)),
        ("starfall_key", "meteor", "starfall_glass_crater", [(-194, 60), (-32, -48), (-12, 152), (156, 54), (130, -146)], (-138, 4), (46, -154)),
        ("forgotten_observatory", "observatory", "open_dome_telescope", [(-266, 34), (-102, -80), (-82, 120), (88, 22), (258, -22), (234, 164)], (-136, 18), (24, -170)),
        ("dream_labyrinth", "dream_hall", "moon_phase_door_gallery", [(-268, -46), (-100, -148), (-78, 50), (92, -40), (262, 6), (236, -180)], (-130, 44), (-36, -152)),
        ("moonlit_wreck", "wreck_crescent", "lantern_reflected_stern", [(-114, 36), (108, -28)], (-136, 26), (32, -148)),
        ("moonwake_stage", "stage", "moonrise_curtain_dais", [(-40, -22)], (-150, 48), (28, -150)),
        ("dreammoth_glade", "glade", "dreammoth_silk_lanterns", [(32, 36)], (-144, -16), (-28, -142)),
    ],
    "ashen_trench": [
        ("ashport", "excavation_bay", "copper_mine_lanterns", [], (-138, 30), (52, -148)),
        ("relic_dock", "relic_cove", "relic_divers_scaffold", [], (-124, 52), (-50, -146)),
        ("cinder_shelf", "shelf", "cinder_terrace_cairns", [(-188, 28), (-30, -94), (-14, 104), (152, 14), (128, -178)], (-136, 34), (40, -152)),
        ("sunken_spires", "spires", "half_buried_spire_gate", [(-182, -30), (-26, -136), (-10, 62), (152, -24), (128, 154)], (-132, 42), (-36, -156)),
        ("abyss_ledge", "ledge", "abyss_chain_bridge", [(-200, 62), (-36, -50), (-16, 150), (160, 52), (132, -152)], (-140, 8), (44, -166)),
        ("sealed_ruins", "seal_hall", "great_ring_seal", [(-272, 32), (-108, -82), (-88, 120), (86, 20), (260, -24), (234, 168)], (-138, 20), (32, -174)),
        ("trench_sanctum", "sanctum", "abyssal_survey_altar", [(-270, -48), (-102, -154), (-80, 48), (94, -44), (266, 2), (242, -184)], (-136, 40), (-36, -162)),
        ("relic_hunter_wreck", "wreck_excavation", "survey_crane_wreck", [(-122, 30), (110, -34)], (-142, 28), (38, -154)),
        ("ashen_seal_arena", "seal_ring", "copper_ring_of_wards", [(46, 24)], (-160, 34), (-26, -164)),
        ("gloomjaw_den", "den", "gloomjaw_warm_vent", [(-42, -16)], (-142, 48), (32, -148)),
    ],
    "leviathan_ring": [
        ("ringhold", "bone_harbor", "great_rib_harbor_arch", [], (-136, 28), (62, -150)),
        ("migration_post", "shell_cove", "migration_watch_pavilion", [], (-128, 52), (-52, -142)),
        ("shell_isle", "shell", "shell_spiral_overlook", [(-186, 30), (-28, -90), (-10, 108), (154, 18), (126, -172)], (-138, 30), (38, -158)),
        ("bone_reef", "ribs", "titan_rib_causeway", [(-184, -32), (-28, -140), (-6, 64), (154, -24), (132, 156)], (-132, 44), (-40, -152)),
        ("titan_atoll", "titan_atoll", "leviathan_jaw_lagoon", [(-202, 62), (-38, -50), (-14, 154), (162, 54), (134, -156)], (-142, 6), (48, -164)),
        ("leviathan_gut", "rib_hall", "great_rib_vault", [(-274, 36), (-108, -80), (-86, 124), (88, 24), (264, -20), (240, 170)], (-140, 18), (30, -176)),
        ("coral_colossus", "colossus", "coral_heart_chamber", [(-272, -48), (-102, -158), (-78, 48), (94, -46), (270, 0), (246, -190)], (-136, 42), (-32, -164)),
        ("behemoth_wreck", "wreck_bones", "behemoth_broken_figurehead", [(-124, 34), (112, -36)], (-144, 24), (40, -158)),
        ("ring_arena", "bone_ring", "pearl_lit_rib_dais", [(-48, 28)], (-158, 42), (28, -160)),
        ("shellwarden_shoal", "shoal", "shellwarden_coral_cradle", [(40, -26)], (-148, 46), (-28, -152)),
    ],
    "grand_horizon": [
        ("horizon_gate", "ceremonial_harbor", "sunwheel_harbor_gate", [], (-140, 30), (64, -154)),
        ("conclave_harbor", "conclave_bay", "captains_banner_colonnade", [], (-130, 54), (-56, -148)),
        ("sunrise_isle", "sunrise", "sunrise_memorial_terrace", [(-190, 32), (-28, -94), (-10, 110), (158, 16), (130, -182)], (-140, 34), (42, -160)),
        ("zenith_cay", "zenith", "zenith_celestial_arch", [(-188, -34), (-28, -142), (-8, 62), (158, -28), (134, 158)], (-134, 46), (-38, -154)),
        ("dawnstar_reef", "star_reef", "dawnstar_compass_reef", [(-206, 64), (-40, -52), (-14, 158), (166, 56), (138, -160)], (-144, 8), (50, -168)),
        ("ancient_gatehouse", "gatehouse", "ancient_horizon_gate", [(-278, 38), (-110, -82), (-88, 126), (90, 24), (270, -22), (246, 174)], (-142, 20), (34, -180)),
        ("compass_vault", "compass_hall", "brass_armillary_compass", [(-276, -50), (-106, -162), (-82, 48), (96, -48), (274, 2), (248, -194)], (-140, 44), (-34, -168)),
        ("rival_flagship_wreck", "wreck_gate", "rival_gilded_transom", [(-128, 36), (116, -36)], (-146, 26), (42, -160)),
        ("horizon_arena", "sun_ring", "conclave_sunwheel_throne", [(52, -30)], (-164, 46), (30, -170)),
        ("starwake_haven", "star_lagoon", "starwake_celestial_cradle", [(-46, 40)], (-148, -22), (-30, -156)),
    ],
}

# One material language per sea. Night colours keep detail readable; warm light
# remains warm even in the volcanic, stormy and deep-water regions.
REGION_ART = {
    "dawnwater": ("painted_fishing_harbor", ["honey_wood", "cream_plaster", "red_blue_tiles", "sailcloth"], "broken_lantern_tower", "#fff4dd", "#929ac8", "#ffd69a", "harbor_bells", 3, 0.65, 0.35, [6, 14], [8, 4], "#ffe58a"),
    "emberreach": ("basalt_copper_foundry", ["black_basalt", "copper_pipe", "ochre_canvas", "warm_brick"], "great_copper_vent", "#ffdfbf", "#ac839b", "#ffb46b", "furnace_breath", 1, 0.35, 0.5, [10, 20], [7, 3], "#ffb367"),
    "verdant_maw": ("root_canopy_settlement", ["dark_wood", "woven_roof", "moss_stone", "fern_glass"], "root_embraced_shrine", "#e7f1d6", "#8eabb5", "#f8d49a", "canopy_drops", 1, 0.45, 0.15, [7, 16], [4, 2], "#d8f7a0"),
    "glass_current": ("white_stone_prism_arcade", ["white_limestone", "faceted_glass", "pale_quartz", "silver_blue_roof"], "prism_vault_dome", "#e6f7f6", "#8d9ac9", "#ffe4af", "glass_chimes", 2, 0.8, 0.25, [8, 18], [6, 3], "#bcefff"),
    "crown_shoals": ("stone_silk_merchant_port", ["honey_stone", "navy_tiles", "striped_silk", "brass_trim"], "charter_seal_library", "#fff0d3", "#9a9fc3", "#ffdc9a", "market_clock", 3, 0.55, 0.25, [6, 15], [5, 2], "#ffdeb0"),
    "stormbelt": ("storm_breakwater_refuge", ["slate_stone", "tarred_wood", "copper_roof", "yellow_glass"], "tilted_beacon_lens", "#d9e8e8", "#8996ba", "#ffdb88", "beacon_chain", 1, 0.25, 1.15, [12, 24], [16, 8], "#ffdc8a"),
    "moonwake": ("moon_lantern_observatory", ["indigo_tiles", "violet_wood", "cream_stone", "star_brass"], "open_dome_telescope", "#eee7fa", "#9397c4", "#ffce9a", "night_windbells", 1, 0.7, 0.15, [10, 22], [4, 2], "#c3c4ff"),
    "ashen_trench": ("relic_excavation_camp", ["dark_sealstone", "copper_lantern", "reclaimed_metal", "ash_canvas"], "great_ring_seal", "#e9dbd6", "#948baf", "#ffc28a", "relic_vent", 0, 0.25, 0.4, [14, 26], [6, 3], "#e7b7ca"),
    "leviathan_ring": ("shell_bone_coral_harbor", ["pearl_shell", "bleached_bone", "teal_canvas", "coral_stone"], "coral_heart_chamber", "#e4f3df", "#88b0be", "#ffddb0", "pearl_tide", 3, 0.6, 0.4, [4, 11], [8, 4], "#b0f1dd"),
    "grand_horizon": ("sunwheel_conclave_city", ["ivory_stone", "gold_brass", "white_canvas", "horizon_glass"], "brass_armillary_compass", "#fff4d9", "#9ba5c9", "#ffe2a5", "horizon_carillon", 3, 0.75, 0.35, [6, 14], [8, 3], "#ffe7a6"),
}

# Service order and rearward setbacks are deliberately authored per port.
# Setbacks are terrain-cell distances from the quay (positive, away from sea).
PORTS = {
    "brightquay": ("town", [0, 1, 3, 4, 2, 5], [8, 9, 8, 10, 9, 9]),
    "saltmarsh_landing": ("outpost", [1, 0, 2, 5, 4, 3], [9, 8, 10, 8, 11, 9]),
    "cinderport": ("fort", [2, 0, 3, 5, 1, 4], [9, 8, 10, 9, 8, 10]),
    "ashfall_harbor": ("outpost", [5, 1, 0, 4, 2, 3], [8, 10, 8, 11, 9, 10]),
    "rootharbor": ("market", [0, 3, 1, 4, 5, 2], [8, 10, 9, 11, 9, 8]),
    "fernwater_post": ("outpost", [2, 4, 0, 1, 5, 3], [10, 9, 8, 10, 9, 11]),
    "prismhaven": ("town", [5, 0, 4, 3, 2, 1], [10, 8, 9, 10, 9, 8]),
    "mirrorbay": ("market", [0, 1, 5, 2, 3, 4], [9, 8, 11, 9, 10, 9]),
    "crownport": ("fort", [5, 3, 0, 1, 4, 2], [10, 10, 8, 9, 11, 9]),
    "silkmarket": ("market", [0, 4, 1, 3, 2, 5], [8, 10, 9, 10, 8, 11]),
    "gale_harbor": ("fort", [5, 2, 0, 3, 1, 4], [9, 9, 8, 10, 11, 10]),
    "beacon_rest": ("outpost", [1, 5, 4, 0, 2, 3], [9, 8, 11, 9, 10, 10]),
    "lanternport": ("town", [1, 0, 5, 4, 3, 2], [8, 9, 10, 11, 10, 9]),
    "dusk_mooring": ("outpost", [5, 4, 1, 0, 3, 2], [9, 11, 8, 9, 10, 10]),
    "ashport": ("fort", [2, 5, 0, 4, 3, 1], [9, 10, 8, 11, 10, 9]),
    "relic_dock": ("outpost", [2, 0, 5, 1, 4, 3], [10, 8, 9, 11, 10, 9]),
    "ringhold": ("town", [5, 1, 0, 3, 4, 2], [10, 9, 8, 10, 11, 9]),
    "migration_post": ("outpost", [0, 5, 2, 4, 1, 3], [8, 9, 10, 11, 9, 10]),
    "horizon_gate": ("fort", [5, 3, 1, 0, 2, 4], [11, 10, 9, 8, 10, 11]),
    "conclave_harbor": ("town", [3, 5, 0, 4, 1, 2], [10, 11, 8, 10, 9, 9]),
}

# Service positions use berth-relative horizontal fractions and absolute terrain
# rows. Unlike the original single service street, these are actual two-axis
# street plans. Connections refer to service-list indices, never service IDs.
# family, service positions, skyline anchor, plaza, homes, land lobes, inlets
PORT_GEOMETRY = {
    "brightquay": ("crescent", [[0,-10],[.2,-16],[.4,-20],[.6,-20],[.8,-16],[1,-10]], [.52,-32], [.5,-13], [[0,.3,-26,5],[.7,1,-26,5]], [[.3,-24,8],[.75,-24,8]], [[.5,-8,2.5]]),
    "saltmarsh_landing": ("canal", [[0,-9],[0,-21],[.4,-13],[.4,-25],[.86,-9],[.86,-21]], [1.18,-27], [.45,-18], [[-.1,.25,-30,6],[.65,1,-31,5]], [[0,-20,7],[.85,-22,8]], [[.5,-6,3],[.5,-31,2.8]]),
    "cinderport": ("terraced", [[0,-9],[.2,-15],[.4,-21],[.6,-27],[.8,-21],[1,-15]], [.7,-38], [.42,-15], [[-.1,.2,-29,5],[.7,1,-32,5]], [[.5,-30,10],[.15,-21,8]], [[1.15,-11,3]]),
    "ashfall_harbor": ("split_quays", [[0,-9],[.18,-19],[.34,-29],[.7,-9],[.87,-19],[1.04,-29]], [.53,-34], [.5,-20], [[-.1,.25,-35,6],[.8,1.1,-35,5]], [[.1,-25,8],[.94,-25,8]], [[.5,-9,3.4]]),
    "rootharbor": ("fan", [[.05,-12],[.22,-24],[.45,-12],[.65,-25],[.84,-12],[1.04,-23]], [.52,-35], [.53,-19], [[-.1,.25,-32,5],[.75,1.1,-32,6]], [[.25,-27,9],[.82,-28,9]], [[-.2,-12,3],[1.15,-14,2.8]]),
    "fernwater_post": ("canal", [[0,-10],[.22,-23],[.44,-10],[.66,-23],[.9,-10],[1.12,-23]], [-.18,-29], [.57,-16], [[0,.3,-30,6],[.7,1.1,-31,5]], [[.12,-20,7],[.87,-21,8]], [[.5,-5,3.2],[.52,-31,2.8]]),
    "prismhaven": ("radial", [[0,-16],[.2,-27],[.4,-9],[.6,-25],[.8,-13],[1,-24]], [.52,-37], [.5,-17], [[-.12,.2,-34,5],[.8,1.12,-32,5]], [[.3,-29,9],[.8,-28,8]], [[.5,-7,2.6]]),
    "mirrorbay": ("basin", [[0,-10],[.4,-10],[.8,-10],[0,-26],[.4,-26],[.8,-26]], [.43,-38], [.4,-18], [[-.15,.15,-33,5],[.7,1,-33,5]], [[0,-22,8],[.8,-23,8]], [[.4,-18,3.5]]),
    "crownport": ("arcades", [[0,-11],[.2,-23],[.4,-11],[.6,-23],[.8,-11],[1,-23]], [.5,-36], [.5,-17], [[0,.3,-32,5],[.7,1,-32,5]], [[.25,-25,10],[.8,-25,9]], [[-.2,-9,2.8],[1.2,-10,3]]),
    "silkmarket": ("market_court", [[0,-10],[0,-26],[.43,-10],[.43,-26],[.88,-10],[.88,-26]], [1.16,-31], [.43,-18], [[-.12,.2,-33,5],[.58,.95,-35,5]], [[.2,-25,9],[.8,-25,9]], [[-.2,-12,2.5]]),
    "gale_harbor": ("breakwater", [[-.05,-10],[.15,-20],[.35,-30],[.62,-30],[.83,-20],[1.04,-10]], [.48,-40], [.5,-22], [[-.15,.18,-33,5],[.8,1.1,-34,5]], [[.2,-24,9],[.85,-24,9]], [[.5,-8,3.4]]),
    "beacon_rest": ("sheltered_court", [[0,-9],[.2,-18],[.4,-27],[.65,-27],[.84,-18],[1,-9]], [-.2,-32], [.52,-16], [[.2,.5,-35,5],[.75,1.05,-31,5]], [[.5,-28,10],[.85,-20,8]], [[-.12,-9,2.8]]),
    "lanternport": ("moon_crescent", [[0,-24],[.14,-14],[.4,-9],[.6,-9],[.8,-14],[1,-24]], [.53,-35], [.5,-18], [[-.1,.22,-31,5],[.78,1.1,-32,5]], [[.2,-26,8],[.8,-26,8]], [[.5,-5,2.8]]),
    "dusk_mooring": ("split_quays", [[-.05,-10],[.15,-22],[.35,-31],[.7,-10],[.9,-22],[1.1,-31]], [.52,-38], [.5,-21], [[-.1,.2,-36,6],[.8,1.1,-36,5]], [[.1,-26,8],[.95,-26,8]], [[.5,-9,3.8]]),
    "ashport": ("excavation_terraces", [[0,-10],[.2,-18],[.4,-28],[.65,-34],[.85,-22],[1.05,-12]], [.55,-42], [.53,-22], [[-.15,.15,-33,5],[.82,1.12,-34,5]], [[.45,-31,11],[.9,-22,8]], [[1.2,-11,3.2]]),
    "relic_dock": ("divers_basin", [[0,-10],[.4,-10],[.8,-10],[.15,-28],[.55,-28],[.95,-28]], [-.18,-34], [.5,-19], [[0,.3,-35,5],[.7,1.05,-36,5]], [[.15,-25,8],[.88,-25,8]], [[.45,-18,3.4]]),
    "ringhold": ("bone_arcades", [[0,-11],[.2,-24],[.4,-11],[.6,-24],[.8,-11],[1,-24]], [.5,-38], [.5,-18], [[-.1,.2,-33,5],[.8,1.1,-33,5]], [[.2,-26,9],[.82,-26,9]], [[-.22,-10,3],[1.2,-12,3]]),
    "migration_post": ("shell_fan", [[0,-13],[.2,-27],[.4,-13],[.62,-28],[.84,-13],[1.06,-26]], [1.23,-35], [.51,-20], [[-.1,.2,-34,5],[.55,.85,-36,5]], [[.2,-28,9],[.8,-28,9]], [[.5,-7,3]]),
    "horizon_gate": ("ceremonial_axis", [[0,-10],[.2,-22],[.4,-10],[.6,-22],[.8,-10],[1,-22]], [.5,-38], [.5,-17], [[-.12,.18,-32,5],[.82,1.12,-32,5]], [[.5,-30,11],[.1,-21,8],[.9,-21,8]], [[.5,-6,2.5]]),
    "conclave_harbor": ("conclave_court", [[0,-10],[.4,-10],[.8,-10],[0,-28],[.4,-28],[.8,-28]], [.43,-41], [.4,-19], [[-.1,.2,-35,5],[.65,.95,-35,5]], [[0,-25,9],[.8,-25,9]], [[.4,-18,3.6]]),
}

# Non-linear room arrangements are individually composed around their subject.
# The graph is unchanged: only its embedding changes. Landings are subsequently
# kept west of the whole route graph to preserve the existing rowboat corridor.
# family, room coordinates, landmark offset from the objective room
SITE_COMPOSITIONS = {
    "gull_rock": ("clifftop_fork", [(-230,80),(-110,-120),(-20,180),(130,-10),(-260,-260)], [126,-136]),
    "lantern_isle": ("keeper_horseshoe", [(-220,120),(-250,-100),(30,140),(-20,-170),(-390,-210)], [150,-126]),
    "coral_steps": ("stepped_reef", [(-190,160),(-30,-20),(80,190),(190,20),(-110,-210)], [-158,-142]),
    "old_lookout": ("tower_switchback", [(-260,150),(-290,-40),(-20,180),(-20,-100),(150,-280),(180,20)], [150,-130]),
    "brine_cellars": ("salt_store_courts", [(-290,-10),(-130,-130),(-140,170),(40,20),(40,280),(220,-140)], [160,-138]),
    "basalt_isle": ("basalt_diagonal", [(-240,150),(-70,-90),(80,110),(160,-170),(-210,-260)], [156,-140]),
    "smolder_key": ("vent_spiral", [(80,180),(-130,40),(170,-50),(10,-240),(-310,80)], [-162,-144]),
    "obsidian_atoll": ("atoll_arms", [(-250,130),(-270,-100),(30,220),(170,-80),(-100,-290)], [156,-136]),
    "magma_vents": ("fissure_zigzag", [(-290,170),(-180,-80),(-10,230),(50,-40),(230,-260),(290,110)], [-160,-152]),
    "forge_depths": ("forge_return_gallery", [(-270,110),(-20,120),(-210,-100),(90,-100),(20,-320),(300,-160)], [168,-140]),
    "tanglewood_isle": ("root_meander", [(-210,170),(-130,-30),(80,210),(150,-50),(-290,-220)], [144,-148]),
    "orchid_cay": ("garden_enclosure", [(-260,110),(-110,-120),(-20,200),(170,100),(-80,-300)], [-150,-134]),
    "maw_shore": ("jaw_causeway", [(-280,150),(-170,-60),(30,220),(180,-10),(-320,-230)], [162,-142]),
    "overgrown_shrine": ("root_gate_loop", [(-260,170),(-310,-60),(-10,170),(-90,-130),(110,-320),(180,-50)], [158,-140]),
    "thornroot_caves": ("root_cave_return", [(-230,100),(40,160),(-180,-120),(60,-100),(-60,-340),(290,-110)], [-156,-148]),
    "shard_reef": ("shard_diagonal", [(-230,180),(-60,-80),(110,220),(210,-90),(-190,-300)], [146,-150]),
    "lens_isle": ("lens_horseshoe", [(-260,100),(-270,-130),(20,180),(40,-190),(-410,-250)], [170,-138]),
    "quartz_spire": ("spire_approach", [(-200,180),(-50,-10),(100,240),(210,20),(-90,-220)], [-166,-150]),
    "crystal_vault": ("prism_four_courts", [(-290,160),(-300,-70),(-10,170),(-100,-150),(100,-350),(190,-90)], [160,-140]),
    "refraction_maze": ("mirror_double_turn", [(-250,140),(0,190),(-200,-110),(100,-110),(20,-350),(300,-180)], [-170,-148]),
    "gilded_cay": ("courtyard_fork", [(-260,160),(-100,-80),(20,230),(200,70),(-150,-290)], [-166,-138]),
    "heron_isle": ("marsh_reed_loop", [(-250,90),(-280,-150),(30,160),(70,-180),(-420,-260)], [172,-136]),
    "regent_bank": ("bank_steps", [(-210,190),(-30,-20),(140,210),(230,-40),(-110,-250)], [-168,-146]),
    "charter_archive": ("archive_cross_courts", [(-280,180),(-320,-50),(0,190),(-70,-120),(140,-330),(230,-10)], [170,-140]),
    "old_family_crypt": ("crypt_return_aisle", [(-240,110),(40,190),(-200,-140),(90,-110),(-50,-350),(310,-150)], [-164,-144]),
    "thunder_rock": ("broken_cliff_fork", [(-250,180),(-130,-90),(80,250),(210,-10),(-300,-280)], [162,-150]),
    "squall_isle": ("wind_shelter_loop", [(-270,110),(-300,-140),(20,200),(30,-210),(-440,-250)], [176,-138]),
    "lightning_reach": ("copper_switchback", [(-230,210),(-30,0),(140,270),(240,30),(-110,-240)], [-176,-152]),
    "drowned_beacon": ("beacon_curved_ascent", [(-280,190),(-330,-60),(-10,210),(-100,-140),(130,-360),(240,-60)], [178,-144]),
    "tempest_caverns": ("storm_cave_loop", [(-250,140),(50,200),(-210,-150),(110,-130),(-20,-380),(330,-180)], [-170,-156]),
    "nightbloom_isle": ("lantern_garden_fork", [(-260,170),(-100,-80),(30,250),(220,50),(-180,-300)], [-168,-144]),
    "echo_atoll": ("echo_crescent", [(-280,120),(-300,-160),(40,180),(60,-220),(-450,-290)], [176,-146]),
    "starfall_key": ("meteor_broken_steps", [(-220,210),(-20,-10),(150,250),(260,10),(-90,-260)], [-180,-148]),
    "forgotten_observatory": ("observatory_courts", [(-290,200),(-340,-50),(0,220),(-100,-150),(150,-360),(250,-10)], [178,-150]),
    "dream_labyrinth": ("dream_return_corridor", [(-260,150),(40,210),(-220,-140),(110,-120),(-40,-380),(340,-170)], [-178,-156]),
    "cinder_shelf": ("shelf_diagonal", [(-270,190),(-100,-80),(80,270),(240,40),(-200,-320)], [176,-150]),
    "sunken_spires": ("spire_basin_loop", [(-290,130),(-320,-170),(20,210),(80,-230),(-470,-310)], [180,-148]),
    "abyss_ledge": ("ledge_return_walk", [(-240,230),(-30,0),(160,290),(270,40),(-120,-260)], [-182,-158]),
    "sealed_ruins": ("seal_inner_courts", [(-300,210),(-360,-60),(0,230),(-110,-170),(150,-390),(270,-20)], [182,-152]),
    "trench_sanctum": ("sanctum_double_turn", [(-270,160),(50,220),(-230,-150),(120,-150),(-40,-400),(350,-190)], [-184,-160]),
    "shell_isle": ("spiral_shell_fork", [(-270,180),(-110,-80),(90,270),(250,50),(-210,-310)], [178,-150]),
    "bone_reef": ("rib_horseshoe", [(-300,140),(-340,-170),(30,220),(90,-240),(-490,-320)], [184,-150]),
    "titan_atoll": ("great_jaw_steps", [(-250,240),(-30,10),(160,300),(280,50),(-120,-270)], [-184,-160]),
    "leviathan_gut": ("rib_vault_chambers", [(-310,220),(-370,-60),(0,240),(-100,-170),(160,-400),(290,-30)], [186,-154]),
    "coral_colossus": ("colossus_return_gallery", [(-280,170),(50,230),(-240,-160),(130,-150),(-40,-420),(360,-190)], [-186,-164]),
    "sunrise_isle": ("sun_terrace_fork", [(-280,200),(-110,-80),(100,290),(260,50),(-230,-330)], [182,-154]),
    "zenith_cay": ("zenith_crescent", [(-310,150),(-350,-180),(40,220),(90,-260),(-510,-330)], [188,-154]),
    "dawnstar_reef": ("compass_reef_steps", [(-260,250),(-30,10),(170,310),(290,40),(-130,-280)], [-188,-164]),
    "ancient_gatehouse": ("gatehouse_procession", [(-320,230),(-380,-60),(10,250),(-110,-180),(170,-420),(300,-30)], [190,-158]),
    "compass_vault": ("compass_double_gallery", [(-290,180),(60,240),(-250,-170),(140,-160),(-40,-440),(380,-200)], [-190,-168]),
}

# The approach direction is a regional part of the composition, independent of
# the isometric tile projection. Rotating the route embedding creates vertical
# ascents, return galleries and lateral courts rather than ten copies of the
# same left-to-right branch graph. Sprites themselves remain upright.
REGION_ROUTE_AXES = {
    "dawnwater": (1, 0, 0, 1),
    "emberreach": (1, 0, 0, -1),
    "verdant_maw": (0, 1, -1, 0),
    "glass_current": (-1, 0, 0, 1),
    "crown_shoals": (0, -1, 1, 0),
    "stormbelt": (-1, 0, 0, -1),
    "moonwake": (0, 1, 1, 0),
    "ashen_trench": (0, -1, -1, 0),
    "leviathan_ring": (1, 0, 0, -1),
    "grand_horizon": (0, -1, 1, 0),
}

REGIONAL_PIECES = {
    "dawnwater": ["ruin_arch", "barrels", "palm"],
    "emberreach": ["rock_big", "brazier", "ore"],
    "verdant_maw": ["tree_b", "mushroom", "herb"],
    "glass_current": ["crystal", "pillar", "crystal"],
    "crown_shoals": ["statue", "standard", "ruin_arch"],
    "stormbelt": ["sea_stack", "brazier", "dead_tree"],
    "moonwake": ["tree_b", "crystal", "lamp"],
    "ashen_trench": ["obelisk", "brazier", "pillar_broken"],
    "leviathan_ring": ["ribs", "coral", "bone_pile"],
    "grand_horizon": ["statue", "pillar", "standard"],
}


def coast_for(form: str, nodes: dict, landmark: list) -> dict:
    """Art-directed landform overlays, applied after essential route reserves."""
    points = list(nodes.values())
    left = min(p[0] for p in points)
    right = max(p[0] for p in points)
    top = min(p[1] for p in points)
    bottom = max(p[1] for p in points)
    cx = (left + right) // 2
    lobes = [[landmark[0], landmark[1] + 14, 4.0]]
    cuts = []
    if form in {"atoll", "titan_atoll", "lens", "mirror_inlet", "lagoon", "star_lagoon", "pearl_pool"}:
        lobes += [[cx - 104, top - 66, 5.0], [cx + 126, top - 54, 4.6], [right + 86, bottom + 28, 3.8]]
        cuts += [[cx + 16, bottom + 156, 3.4], [left - 76, top - 76, 2.8]]
    elif form in {"headland", "cliff", "spire", "spires", "ledge", "shelf", "basalt", "zenith"}:
        lobes += [[right + 102, top - 88, 4.8], [right + 196, top - 134, 3.6], [left - 64, bottom + 68, 3.2]]
        cuts += [[left - 116, top - 64, 3.2], [right + 126, bottom + 124, 3.6]]
    elif form in {"creek", "roots", "root_bay", "marsh", "garden", "glade", "hollow", "root_cavern", "root_hall"}:
        lobes += [[left - 72, top - 58, 4.2], [cx + 18, top - 104, 4.6], [right + 72, bottom + 78, 4.2]]
        cuts += [[cx - 54, bottom + 138, 3.2], [right + 154, top - 24, 3.0]]
    elif form.startswith("wreck"):
        lobes += [[left - 54, top - 84, 4.0], [right + 116, top - 56, 4.8]]
        cuts += [[cx + 8, bottom + 124, 4.2], [left - 144, top - 6, 3.4]]
    elif form.endswith("hall") or form in {"cellars", "forge", "crypt", "archive", "observatory", "sanctum", "colossus", "gatehouse", "fissure", "beacon_hall", "storm_cave"}:
        lobes += [[left - 72, top - 68, 4.2], [right + 88, top - 68, 4.6], [cx + 36, top - 128, 4.8]]
        cuts += [[cx - 12, bottom + 172, 2.5]]
    else:
        lobes += [[left - 64, top - 82, 4.6], [right + 90, top - 58, 4.2], [cx + 24, bottom + 88, 3.8]]
        cuts += [[left - 126, bottom + 74, 3.2], [right + 126, bottom + 132, 3.0]]
    return {"form": form, "lobes": lobes, "cuts": cuts}


def segment_distance(p: list, a: list, b: list) -> float:
    dx, dy = b[0] - a[0], b[1] - a[1]
    denominator = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / max(0.001, denominator)))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dy * t)


def orient_route(points: list, axes: tuple, kind: str) -> list:
    """Keep each authored courtyard planar while giving it a western entrance.

    The first four template nodes form a cycle: entry, upper branch, lower
    branch, reunion. Rotating that cycle, rather than dragging one room across
    its interior, preserves non-crossing paths. Optional rooms project away
    from the courtyard, so their paths do not accidentally cross an entry lane.
    """
    ax, ay, bx, by = axes
    oriented = [[ax*x + ay*y, bx*x + by*y] for x, y in points]
    ring = [oriented[i] for i in (0, 1, 3, 2)]
    entry = min(range(4), key=lambda i: (ring[i][0], ring[i][1]))
    ring = ring[entry:] + ring[:entry]
    center = [sum(p[0] for p in ring) / 4, sum(p[1] for p in ring) / 4]
    result = [ring[0], ring[1], ring[3], ring[2]]
    branch = result[1] if kind == "island" else result[3]
    dx, dy = branch[0] - center[0], branch[1] - center[1]
    scale = max(1.0, math.hypot(dx, dy))
    ux, uy = dx / scale, dy / scale
    if kind == "island":
        extension = min(260, max(170, math.dist(points[4], points[1])))
        result.append([round(branch[0] + ux*extension), round(branch[1] + uy*extension)])
    else:
        guardian_length = min(260, max(190, math.dist(points[4], points[3])))
        vault_length = min(230, max(170, math.dist(points[5], points[3])))
        result.append([round(branch[0] + ux*guardian_length - uy*90), round(branch[1] + uy*guardian_length + ux*90)])
        result.append([round(branch[0] + ux*vault_length + uy*130), round(branch[1] + uy*vault_length - ux*130)])
    return result


def safe_landmark_position(nodes: dict, rooms: list, desired: list) -> list:
    """Bake SiteView's conservative route/room clearance into the source data.

    A cutout's foundation is 144x64 world pixels. Its clearance from the
    route uses the foundation's half diagonal plus the party's 30px margin;
    individual room pads additionally reserve 34px around the foundation.
    Include the boat-to-first-room route, which is not a gameplay graph edge.
    """
    result = desired.copy()
    if not rooms:
        return result
    half_w, half_h = (n * 0.5 for n in LANDMARK_FOOTPRINT)
    route_radius = math.hypot(half_w, half_h) + 30.0
    edges = [(nodes[r["id"]], nodes[n]) for r in rooms for n in r["next"]]
    edges.append((nodes["_landing"], nodes[rooms[0]["id"]]))
    for _ in range(40):
        pads_clear = all(abs(p[0] - result[0]) > half_w + 34.0 or abs(p[1] - result[1]) > half_h + 34.0 for p in nodes.values())
        routes_clear = all(segment_distance(result, a, b) >= route_radius for a, b in edges)
        if pads_clear and routes_clear:
            return result
        result[1] -= 16
    raise ValueError("No clear landmark foundation within forty rearward steps")


def build_profiles(world: dict) -> dict:
    profiles = {"version": 1, "coordinates": "world_pixels_at_ground_contact", "regions": {}, "locations": {}, "battleRooms": {}}
    for rid, entries in DESIGNS.items():
        art = REGION_ART[rid]
        architecture, materials, landmark, day, night, warm, motif, gulls, glints, whitecaps, fish, wind, fly = art
        profiles["regions"][rid] = {
            "architecture": architecture, "materials": materials, "landmark": landmark,
            "light_day": day, "light_night": night, "warm_light": warm,
            "ambience": {"gulls": gulls, "glints": glints, "whitecaps": whitecaps,
                         "fish_every": fish, "wind": wind, "cloud_alpha": 0.08 if rid != "stormbelt" else 0.14, "fly_color": fly},
            "audio": {"motif": motif},
        }
        for landmark_variant, (loc_id, form, focal, points, approach, offset) in enumerate(entries):
            loc = world["LOCATIONS"][loc_id]
            rooms = world["ROOM_TEMPLATES"].get(loc["type"], [])
            composition_family = form
            if loc_id in SITE_COMPOSITIONS:
                composition_family, points, offset = SITE_COMPOSITIONS[loc_id]
                points = orient_route(points, REGION_ROUTE_AXES[rid], loc["type"])
            if len(points) != len(rooms):
                raise ValueError(f"{loc_id}: {len(points)} authored points for {len(rooms)} rooms")
            nodes = {room["id"]: list(p) for room, p in zip(rooms, points)}
            first = points[0] if points else (0, 0)
            west_edge = min((p[0] for p in points), default=first[0])
            nodes["_landing"] = [west_edge - max(140, abs(approach[0])), first[1] + approach[1]]
            objective = next((room for room in rooms if room.get("objective")), rooms[-1] if rooms else None)
            obj = nodes[objective["id"]] if objective else [0, 0]
            focal_pos = [obj[0] + offset[0], obj[1] + offset[1]]
            focal_pos = safe_landmark_position(nodes, rooms, focal_pos)
            pieces = REGIONAL_PIECES[rid]
            set_pieces = [
                [pieces[0], focal_pos[0] - 84, focal_pos[1] + 14, True],
                [pieces[1], focal_pos[0] + 78, focal_pos[1] + 18, True],
                [pieces[2], focal_pos[0] + 122, focal_pos[1] - 30, True],
            ]
            record = {
                "regionId": rid, "compositionId": loc_id + ":" + form, "compositionFamily": composition_family, "landmark": focal,
                "landmarkAsset": rid, "landmarkVariant": landmark_variant,
                "landmarkPosition": focal_pos, "landmarkFootprint": LANDMARK_FOOTPRINT.copy(),
                "nodes": nodes, "coast": coast_for(form, nodes, focal_pos), "setPieces": set_pieces,
                "lighting": {"focus": focal_pos, "color": warm},
            }
            if loc_id in PORTS:
                style, order, setbacks = PORTS[loc_id]
                geometry_family, services, anchor, plaza, home_bands, scallops, inlets = PORT_GEOMETRY[loc_id]
                connections = [[i, i+1] for i in range(5)]
                if geometry_family in {"basin", "market_court", "divers_basin", "conclave_court"}:
                    connections = [[0,1],[1,2],[3,4],[4,5],[0,3],[2,5]]
                elif geometry_family in {"canal", "fan", "shell_fan", "arcades", "bone_arcades", "ceremonial_axis"}:
                    connections = [[0,1],[2,3],[4,5],[0,2],[2,4],[1,3],[3,5]]
                record["port"] = {"order": [SERVICES[i] for i in order], "setbacks": [-n for n in setbacks],
                                  "style": style, "landmarkOffset": [-18,-24] if loc["portIndex"] == 0 else [20,-18], "district": focal,
                                  "geometryFamily": geometry_family, "servicePositions": services,
                                  "serviceConnections": connections, "homeBands": home_bands,
                                  "plazaPosition": plaza, "landmarkAnchor": anchor,
                                  "coastScallops": scallops, "coastInlets": inlets}
            profiles["locations"][loc_id] = record
            for room in rooms:
                if room["kind"] not in {"battle", "elite", "boss", "trial"}:
                    continue
                tier = room["kind"]
                # The fight band is reserved; the skyline is behind it. Room
                # roles change the supporting silhouette, not only its tint.
                if tier in {"boss", "trial"}:
                    bprops = [["pillar", -164, -116, True], ["pillar", 266, -124, True],
                              ["brazier", -90, -110, True], ["brazier", 206, -112, True]]
                    landmark_offset = [72, -156]
                elif tier == "elite":
                    bprops = [[pieces[0], -154, -118, True], ["standard", 258, -120, True],
                              [pieces[1], 202, -110, True]]
                    landmark_offset = [108, -150]
                else:
                    bprops = [[pieces[0], -160, -122, True], [pieces[2], 254, -124, True],
                              ["barrels", 192, -108, False]]
                    landmark_offset = [90 if room["id"] in {"landing", "gate"} else 130, -148]
                # A room retains the destination's landmark side: left wings,
                # central dais and right skyline compositions are visually
                # distinct while all foundations remain behind the fight band.
                landmark_offset[0] = max(-132, min(246, offset[0] + (28 if tier in {"boss", "trial"} else 54)))
                landmark_offset[1] = -max(144, min(190, abs(offset[1])))
                profiles["battleRooms"][f"{loc_id}:{room['id']}"] = {
                    "regionId": rid, "locationId": loc_id, "roomId": room["id"], "tier": tier,
                    "compositionId": f"{loc_id}:{room['id']}:{form}", "landmark": focal,
                    "landmarkAsset": rid, "landmarkVariant": landmark_variant,
                    "landmarkOffset": landmark_offset, "landmarkFootprint": LANDMARK_FOOTPRINT.copy(),
                    "motif": form, "compositionFamily": composition_family, "setPieces": bprops, "warm_light": warm,
                }
    return profiles


def audit_spatial_compositions(profiles: dict, world: dict) -> dict:
    """Reject crossed map routes and missing two-axis port plans at build time."""
    errors = []
    checked_sites, checked_edges = 0, 0
    port_families = set()
    port_plans = set()

    def turn(a: list, b: list, c: list) -> float:
        return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])

    for loc_id, loc in world["LOCATIONS"].items():
        rec = profiles["locations"][loc_id]
        rooms = world["ROOM_TEMPLATES"][loc["type"]]
        if not rooms:
            port = rec["port"]
            pos = port["servicePositions"]
            if len(pos) != 6 or len({p[1] for p in pos}) < 2:
                errors.append(f"{loc_id}: requires six services on multiple street rows")
            if not all(0 <= i < 6 and 0 <= j < 6 for i, j in port["serviceConnections"]):
                errors.append(f"{loc_id}: invalid service lane indices")
            signature = tuple(tuple(p) for p in pos)
            if signature in port_plans:
                errors.append(f"{loc_id}: repeated service geometry")
            port_plans.add(signature)
            port_families.add(port["geometryFamily"])
            continue
        checked_sites += 1
        nodes = rec["nodes"]
        if nodes["_landing"][0] > min(nodes[r["id"]][0] for r in rooms) - 140:
            errors.append(f"{loc_id}: western boat corridor is not clear")
        edges = [(r["id"], n) for r in rooms for n in r["next"]]
        edges.append(("_landing", rooms[0]["id"]))
        checked_edges += len(edges)
        for a, b in edges:
            for name, p in nodes.items():
                if name not in {a,b} and segment_distance(p, nodes[a], nodes[b]) < 48:
                    errors.append(f"{loc_id}: {a}->{b} passes through unrelated room {name}")
        for i, (a,b) in enumerate(edges):
            for c,d in edges[i+1:]:
                if len({a,b,c,d}) != 4:
                    continue
                if turn(nodes[a], nodes[b], nodes[c])*turn(nodes[a], nodes[b], nodes[d]) < 0 and turn(nodes[c], nodes[d], nodes[a])*turn(nodes[c], nodes[d], nodes[b]) < 0:
                    errors.append(f"{loc_id}: non-linked routes cross: {a}->{b}, {c}->{d}")
    if errors:
        raise ValueError("\n".join(errors))
    return {"ports": len(port_plans), "portGeometryFamilies": len(port_families), "nonCrossingSites": checked_sites, "clearRouteEdges": checked_edges}


def main() -> None:
    world = json.loads(WORLD_PATH.read_text(encoding="utf-8"))
    profiles = build_profiles(world)
    if set(profiles["locations"]) != set(world["LOCATIONS"]):
        raise ValueError("The authored place catalogue does not cover the world exactly")
    geometry = audit_spatial_compositions(profiles, world)
    OUT_PATH.write_text(json.dumps(profiles, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(profiles['regions'])} seas, {len(profiles['locations'])} places and {len(profiles['battleRooms'])} combat contexts to {OUT_PATH.relative_to(ROOT)}")
    print(json.dumps(geometry, sort_keys=True))


if __name__ == "__main__":
    main()
