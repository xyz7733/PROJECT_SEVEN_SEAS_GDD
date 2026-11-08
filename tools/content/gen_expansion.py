#!/usr/bin/env python3
"""Generate the Project Seven Seas content expansion.

Writes:
  game/data/bestiary.json      enemies, archetypes, skills, traits, variants, drops
  game/data/collections.json   relics, trophies, charts, lore, curios, sets, gear
  game/i18n/source/native_*.json  new English / Chinese keys

The generator is deterministic and does not touch existing keys. Re-running it
rewrites only the generated data files and adds/updates the generated i18n keys.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "data"
SRC = ROOT / "game" / "i18n" / "source"

RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]

# ------------------------------------------------------------------ regions
REGIONS = [
    {
        "id": "dawnwater", "en": "Dawnwater", "zh": "晨水湾", "tier": 1,
        "ingredient": "kelp_sprig", "specialty": "saltleaf_grain",
        "chartLoc": "driftplank_wreck",
        "relics": [
            ("relic_tide_compass", "Tide Compass", "潮汐罗盘",
             "A brass compass that always points toward the nearest safe harbour.",
             "黄铜罗盘，总是指向最近的安全港湾。", {"hpPct": 0.03, "foodSave": 1}),
            ("relic_saltglass_prism", "Saltglass Prism", "盐玻璃棱镜",
             "A cloudy prism that turns sea light into a warm, steady glow.",
             "浑浊的棱镜，把海光折成温暖而稳定的微光。", {"lootPct": 0.05}),
            ("relic_harbor_bell", "Harbor Bell", "港湾铜铃",
             "Its ring once guided fishing boats home through the fog.",
             "铃声曾在浓雾中指引渔船归港。", {"goldPct": 0.05}),
        ],
        "lore": [
            ("lore_dawnwater_1", "The First Landing", "初次登陆",
             "The first settlers found a sheltered bay and swore the tide would never take it.",
             "最初的定居者发现了一处避风湾，并立誓不让潮水夺走它。"),
            ("lore_dawnwater_2", "A Chart in the Rain", "雨中的海图",
             "A drowned cartographer's last map showed a route no living sailor remembers.",
             "一位溺亡制图师的最后一张海图，标着无人记得的航路。"),
        ],
        "curio": ("curio_dawnwater_1", "Saltglass Bead", "盐玻璃珠",
                  "A smooth bead worn by dock children for luck.", "码头孩子佩戴的光滑珠子，据说能带来好运。", 45),
        "boss": ("harbor_leviathan", "Harbor Leviathan", "港湾利维坦", "serpent",
                 ["armored", "berserk"], ["e_crush", "e_quake", "e_bulwark"],
                 "It has slept beneath the harbour for a hundred years, and the harbour has learned to sleep around it.",
                 "它在港湾之下沉睡百年，整座港湾都学会了绕着它入眠。"),
        "rare": ("golden_crab", "Golden Crab", "黄金蟹", "crab",
                 ["armored", "unyielding"], ["e_bulwark", "e_crush"], "alpha",
                 "A crab whose shell grew rich on shipwreck gold. It has never once been caught.",
                 "一只靠沉船金子养出金壳的蟹，从未被真正抓住。"),
        "monsters": [
            ("tide_jelly", "Tide Jelly", "潮汐水母", "caster", "jelly",
             ["venomous", "regen"], ["e_venom_spit", "e_mend"],
             "A drifting bell of translucent flesh. Its sting lingers long after the light fades.",
             "半透明的钟形身躯随潮漂流，螫伤在光芒消失后仍会作痛。"),
            ("shoal_ray", "Shoal Ray", "浅滩鳐", "lurker", "ray",
             ["elusive"], ["e_ambush"],
             "It glides a hand's breadth above the seabed, wings silent, eyes never closing.",
             "它贴着海床滑行，翼无声，眼不闭。"),
            ("brine_worm", "Brine Worm", "卤水蠕虫", "warden", "worm",
             ["armored"], ["e_bulwark", "e_crush"],
             "A segmented bulk that reshapes the wreck it nests in. The hull learned to fear it.",
             "分节的巨躯把栖身的沉船挤得变形，船骨学会了怕它。"),
        ],
    },
    {
        "id": "emberreach", "en": "Emberreach", "zh": "烬火峡", "tier": 2,
        "ingredient": "ember_salt", "specialty": "ember_ore",
        "chartLoc": "scorched_galleon",
        "relics": [
            ("relic_ember_lodestone", "Ember Lodestone", "烬火磁石",
             "Warm to the touch, it pulls blades toward an enemy's guard.",
             "触手温热，能把刀锋引向敌人的破绽。", {"atkPct": 0.03, "bossDmg": 0.02}),
            ("relic_cinder_lens", "Cinder Lens", "煤烬透镜",
             "Smoke-grey glass that reveals the weak points in armour.",
             "烟灰色的镜片，能映出甲胄的薄弱处。", {"crit": 0.03}),
            ("relic_forge_ember", "Forge Ember", "锻炉余烬",
             "An ember that has outlived every forge in the Reach.",
             "一粒比烬火峡所有锻炉都活得久的余烬。", {"atkPct": 0.02, "goldPct": 0.03}),
        ],
        "lore": [
            ("lore_emberreach_1", "The Vent That Sang", "歌唱的喷口",
             "Miners followed a singing vent and found a cavern full of molten glass.",
             "矿工追随歌唱的喷口，发现了一座装满熔玻璃的洞窟。"),
            ("lore_emberreach_2", "Ash and Iron", "灰与铁",
             "The old forge clans buried their dead with hammers, not coins.",
             "古老的锻造氏族用锤子而非钱币陪葬。"),
        ],
        "curio": ("curio_emberreach_1", "Slag Rosette", "矿渣玫瑰",
                  "A flower of cooled slag, prized by collectors for its colour.",
                  "冷却矿渣凝成的花，因色泽奇异而受收藏家追捧。", 60),
        "boss": ("magma_hydra", "Magma Hydra", "熔岩九头蛇", "serpent",
                 ["venomous", "splitter"], ["e_fire_breath", "e_crush", "e_enrage"],
                 "Cut one head from the molten dark and two more rise to take its place.",
                 "从熔岩的黑暗里斩下一颗头，会有两颗新的升起来。"),
        "rare": ("cinder_moth", "Cinder Moth", "烬翼蛾", "imp",
                 ["volatile", "elusive"], ["e_fire_breath", "e_ambush"], "feral",
                 "Its wings are made of cooled ash. Where it lands, the wood remembers fire.",
                 "双翼由冷却的灰烬构成。它落过的地方，木头会记起火焰。"),
        "monsters": [
            ("cinder_jelly", "Cinder Jelly", "烬火水母", "caster", "jelly",
             ["venomous", "volatile"], ["e_fire_breath", "e_venom_spit"],
             "A jelly lit from within by a coal that refuses to go out.",
             "体内燃着一块不肯熄灭的炭火。"),
            ("magma_ray", "Magma Ray", "熔岩鳐", "lurker", "ray",
             ["elusive", "berserk"], ["e_ambush", "e_enrage"],
             "It swims through molten stone as if the sea were only a rumour.",
             "它在熔石中游动，仿佛海水只是一个传闻。"),
            ("ash_worm", "Ash Worm", "灰烬蠕虫", "warden", "worm",
             ["armored", "venomous"], ["e_bulwark", "e_quake"],
             "Its rings are packed with ash from a hundred burned fleets.",
             "体环里塞满上百支被焚舰队的灰。"),
        ],
    },
    {
        "id": "verdant_maw", "en": "Verdant Maw", "zh": "翠喉", "tier": 3,
        "ingredient": "moss_sugar", "specialty": "verdant_resin",
        "chartLoc": "vine_wreck",
        "relics": [
            ("relic_thornwood_idol", "Thornwood Idol", "棘木神像",
             "A small idol carved from a tree that grew through a shipwreck.",
             "用穿透沉船生长的树木雕成的小神像。", {"hpPct": 0.04}),
            ("relic_sporeglass_vial", "Sporeglass Vial", "孢子玻璃瓶",
             "A vial of glowing spores that never settle.",
             "一瓶永不停歇的发光孢子。", {"lootPct": 0.05}),
            ("relic_rootheart_seed", "Rootheart Seed", "根心种子",
             "Still warm, still waiting for soil.", "仍有余温，仍在等待土壤。", {"hpPct": 0.02, "defPct": 0.02}),
        ],
        "lore": [
            ("lore_verdant_maw_1", "The Green Wreck", "绿色沉船",
             "A galleon swallowed by the jungle, its cannon now a planter.",
             "一艘被丛林吞没的大帆船，火炮成了花盆。"),
            ("lore_verdant_maw_2", "What the Roots Remember", "根的记忆",
             "The roots remember every sailor who fell in the Maw.",
             "根须记得每一个倒在翠喉的水手。"),
        ],
        "curio": ("curio_verdant_maw_1", "Amber Seedpod", "琥珀种荚",
                  "A seedpod that glows faintly when held to the ear.",
                  "贴近耳边时会发出微光的种荚。", 75),
        "boss": ("spore_matriarch", "Spore Matriarch", "孢子母后", "plant",
                 ["summoner", "regen"], ["e_curse", "e_venom_spit", "e_heal_all"],
                 "Every breath in the Maw carries her children. Every wreck is her nursery.",
                 "翠喉的每一口气都带着她的子嗣，每一艘沉船都是她的育婴房。"),
        "rare": ("elder_mossback", "Elder Mossback", "苔背长者", "beast",
                 ["armored", "regen"], ["e_bulwark", "e_venom_spit"], "elder",
                 "A beast so old that a forest has taken root on its back.",
                 "一头老到背上长出一片森林的巨兽。"),
        "monsters": [
            ("spore_jelly", "Spore Jelly", "孢子水母", "caster", "jelly",
             ["venomous", "splitter"], ["e_curse", "e_venom_spit"],
             "A breathing cloud of spores shaped like a bell. It is never alone.",
             "一团钟形的呼吸孢子云。它从不孤单。"),
            ("canopy_ray", "Canopy Ray", "林冠鳐", "lurker", "ray",
             ["elusive", "warded"], ["e_ambush", "e_barrage"],
             "It hunts beneath the mangrove canopy, where the water is green and blind.",
             "它在红树林冠下狩猎，那里的水是绿色而盲目的。"),
            ("mire_worm", "Mire Worm", "泥沼蠕虫", "warden", "worm",
             ["armored", "regen"], ["e_bulwark", "e_venom_spit"],
             "The swamp closes over its back and calls it ground.",
             "沼泽合拢在它背上，把它当作地面。"),
        ],
    },
    {
        "id": "glass_current", "en": "Glass Current", "zh": "玻璃洋流", "tier": 4,
        "ingredient": "frost_salt", "specialty": "prism_quartz",
        "chartLoc": "glassbound_hulk",
        "relics": [
            ("relic_prism_sextant", "Prism Sextant", "棱镜六分仪",
             "It measures the angle of light, not the stars.", "它测量的是光的夹角，而非星辰。",
             {"crit": 0.02, "spd": 2}),
            ("relic_refraction_shard", "Refraction Shard", "折射碎片",
             "A shard that shows a different horizon in each facet.",
             "每一面都映出不同地平线的碎片。", {"dodge": 0.03}),
            ("relic_mirror_sail", "Mirror Sail", "镜帆",
             "A scrap of sailcloth that reflects the sea instead of the sky.",
             "一块映海而不映天的帆布。", {"avoid": 0.02, "lootPct": 0.03}),
        ],
        "lore": [
            ("lore_glass_current_1", "The Fleet of Mirrors", "镜之舰队",
             "Sailors say a fleet of glass ships once crossed the Current and vanished.",
             "水手说，一支玻璃船队曾横渡洋流，随后消失。"),
            ("lore_glass_current_2", "The Queen's Reflection", "女王的倒影",
             "The refraction queen keeps every reflection she has ever stolen.",
             "折射女王收藏着她偷走的所有倒影。"),
        ],
        "curio": ("curio_glass_current_1", "Prism Marble", "棱镜弹珠",
                  "A marble that splits sunlight into seven thin blades.",
                  "把阳光劈成七道细刃的弹珠。", 90),
        "boss": ("prism_serpent", "Prism Serpent", "棱镜巨蛇", "serpent",
                 ["warded", "unyielding"], ["e_frost_breath", "e_shield_wall", "e_doom"],
                 "Its scales are mirrors. Look too long and you will see yourself losing.",
                 "鳞片是镜子。看得太久，你会看见自己落败的样子。"),
        "rare": ("mirror_ray", "Mirror Ray", "镜鳐", "ray",
                 ["warded", "elusive"], ["e_ambush", "e_barrage"], "swift",
                 "A ray with no colour of its own, only the sea it borrows.",
                 "没有自己颜色的鳐，只映出它借来的海。"),
        "monsters": [
            ("prism_jelly", "Prism Jelly", "棱镜水母", "caster", "jelly",
             ["venomous", "warded"], ["e_frost_breath", "e_shield_wall"],
             "Seven colours drift inside it, none of them its own.",
             "七种颜色在它体内漂浮，没有一种属于它。"),
            ("shard_ray", "Shard Ray", "碎片鳐", "lurker", "ray",
             ["elusive", "volatile"], ["e_ambush", "e_barrage"],
             "It is not one animal but a school of glass splinters keeping a shape.",
             "它不是一只动物，而是一群维持着形状的玻璃碎片。"),
            ("glass_worm", "Glass Worm", "玻璃蠕虫", "warden", "worm",
             ["armored", "vampiric"], ["e_bulwark", "e_drain"],
             "A living tube of clear glass. You see your own blood move inside it.",
             "一截活着的透明玻璃管。你能看见自己的血在里面流动。"),
        ],
    },
    {
        "id": "crown_shoals", "en": "Crown Shoals", "zh": "王冠浅滩", "tier": 5,
        "ingredient": "sun_amber", "specialty": "crown_silk",
        "chartLoc": "treasury_wreck",
        "relics": [
            ("relic_gilded_seal", "Gilded Seal", "鎏金印玺",
             "The seal of a merchant house that no longer exists.",
             "一个已不存在的商会的印玺。", {"goldPct": 0.08}),
            ("relic_silk_ledger", "Silk Ledger", "丝绸账本",
             "Every debt written in it is still owed.", "写在上面的每一笔债，至今仍有人偿还。",
             {"goldPct": 0.04, "lootPct": 0.03}),
            ("relic_crown_coin", "Crown Coin", "王冠币",
             "A coin stamped on both sides with the same face.", "两面都铸着同一张脸的硬币。",
             {"goldPct": 0.05}),
        ],
        "lore": [
            ("lore_crown_shoals_1", "The Family Debt", "家族债",
             "The founding families bought the shoals with a promise they never intended to keep.",
             "创始家族用一句从未打算兑现的承诺买下了浅滩。"),
            ("lore_crown_shoals_2", "A Coin for the Ferryman", "摆渡人的硬币",
             "The old crypt is said to hold a coin that always returns.",
             "据说旧墓穴里有一枚总会回到主人手中的硬币。"),
        ],
        "curio": ("curio_crown_shoals_1", "Gilded Shell", "鎏金贝壳",
                  "A shell plated in gold by a jeweller with more money than sense.",
                  "被一位钱多过脑的珠宝匠镀成金色的贝壳。", 110),
        "boss": ("gilded_kraken", "Gilded Kraken", "鎏金海妖", "crab",
                 ["armored", "bulwark"], ["e_quake", "e_bulwark", "e_barrage"],
                 "It wears the treasury it swallowed. Every coin is a scale.",
                 "它穿着自己吞下的宝库，每一枚金币都是一片鳞。"),
        "rare": ("coin_drake", "Coin Drake", "金币龙", "serpent",
                 ["vampiric", "armored"], ["e_drain", "e_bulwark"], "alpha",
                 "A serpent that hoards coins it cannot spend, in a nest it cannot leave.",
                 "一条囤积着花不出去的金币、守着一座离不开的巢的蛇。"),
        "monsters": [
            ("coin_jelly", "Coin Jelly", "金币水母", "caster", "jelly",
             ["venomous", "unyielding"], ["e_drain", "e_heal_all"],
             "It has swallowed so many coins that its bell rings when it moves.",
             "吞下太多金币，移动时伞盖会叮当作响。"),
            ("gilded_ray", "Gilded Ray", "鎏金鳐", "lurker", "ray",
             ["elusive", "armored"], ["e_ambush", "e_pierce_shot"],
             "Its underside is plated with stolen leaf and coin.",
             "它的腹面镶满偷来的金箔与钱币。"),
            ("vault_worm", "Vault Worm", "金库蠕虫", "warden", "worm",
             ["armored", "bulwark"], ["e_bulwark", "e_shield_wall"],
             "It nests inside a sunken vault and wears the door as a crown.",
             "它筑巢于沉没的金库，把库门当作王冠。"),
        ],
    },
    {
        "id": "stormbelt", "en": "Stormbelt", "zh": "风暴带", "tier": 6,
        "ingredient": "deep_coral", "specialty": "stormwood",
        "chartLoc": "stormwrack_hulk",
        "relics": [
            ("relic_storm_anchor", "Storm Anchor", "风暴锚",
             "An anchor that has held through nine typhoons.", "曾扛过九场台风的老锚。",
             {"defPct": 0.04, "hpPct": 0.02}),
            ("relic_thunder_feather", "Thunder Feather", "雷霆羽",
             "A feather that crackles before every storm.", "每场风暴来临前都会噼啪作响的羽毛。",
             {"spd": 3}),
            ("relic_squall_glass", "Squall Glass", "飑风玻璃",
             "A stormglass that fills with lightning instead of crystals.",
             "一块装满闪电而非晶体的风暴玻璃。", {"crit": 0.03}),
        ],
        "lore": [
            ("lore_stormbelt_1", "The Beacon That Would Not Die", "不灭的灯塔",
             "Three keepers drowned; the beacon still burns.", "三任守塔人溺亡，灯塔仍在燃烧。"),
            ("lore_stormbelt_2", "Squall's Log", "飑风日志",
             "A captain's log written in one hand, then another, then another.",
             "一本船长日志，先是几种笔迹，最后只剩一种。"),
        ],
        "curio": ("curio_stormbelt_1", "Stormglass Eye", "风暴玻璃眼",
                  "A glass eye that clouds before lightning strikes.",
                  "闪电落下前会起雾的玻璃眼。", 130),
        "boss": ("thunder_roc", "Thunder Roc", "雷霆巨鹏", "bird",
                 ["berserk", "elusive"], ["e_static_lash", "e_ambush", "e_barrage"],
                 "It nests in the eye of the storm and has never touched the sea.",
                 "它筑巢于风暴之眼，从未触碰过海面。"),
        "rare": ("storm_roc", "Storm Roc", "风暴巨鹏", "bird",
                 ["berserk", "elusive"], ["e_static_lash", "e_pierce_shot"], "feral",
                 "A younger roc with a longer temper and a shorter memory.",
                 "一头更年轻的巨鹏，脾气更长，记性更短。"),
        "monsters": [
            ("storm_jelly", "Storm Jelly", "风暴水母", "caster", "jelly",
             ["venomous", "berserk"], ["e_static_lash", "e_barrage"],
             "Its bell is a thunderhead. Its tendrils are rain that stings.",
             "伞盖是一团雷云，触须是会蜇人的雨。"),
            ("squall_ray", "Squall Ray", "飑风鳐", "lurker", "ray",
             ["elusive", "berserk"], ["e_ambush", "e_pierce_shot"],
             "It rides the underside of waves, faster than the wind above.",
             "它贴着浪底滑翔，比上方的风更快。"),
            ("thunder_worm", "Thunder Worm", "雷霆蠕虫", "warden", "worm",
             ["armored", "volatile"], ["e_bulwark", "e_quake"],
             "Each segment holds a charge. When it dies, the storm gets it back.",
             "每一节都蓄着电。它死去时，风暴会收回这些电。"),
        ],
    },
    {
        "id": "moonwake", "en": "Moonwake", "zh": "月醒海", "tier": 7,
        "ingredient": "void_pepper", "specialty": "moon_ink",
        "chartLoc": "moonlit_wreck",
        "relics": [
            ("relic_moon_lantern", "Moon Lantern", "月灯",
             "It burns with a light that only dreamers can see.", "它燃烧着只有做梦者能看见的光。",
             {"dodge": 0.04, "hpPct": 0.02}),
            ("relic_dream_marble", "Dream Marble", "梦弹珠",
             "A marble that rolls uphill when no one watches.", "没人看时会向坡上滚的弹珠。",
             {"lootPct": 0.04, "avoid": 0.01}),
        ],
        "lore": [
            ("lore_moonwake_1", "The Observatory Below", "地下天文台",
             "The observatory charts a sky that does not exist above the sea.",
             "天文台描绘着一片海面上不存在的星空。"),
        ],
        "curio": ("curio_moonwake_1", "Sleeping Pearl", "沉睡珍珠",
                  "A pearl that grows heavier with every nightmare it eats.",
                  "每吞下一个噩梦就重一分的珍珠。", 150),
        "boss": ("dream_eater", "Dream Eater", "噬梦者", "ghost",
                 ["vampiric", "summoner"], ["e_dream_lull", "e_drain", "e_void_gaze"],
                 "It has no face of its own, so it borrows the face of whoever is dreaming.",
                 "它没有自己的脸，于是借用每一个做梦者的脸。"),
        "rare": ("lunar_moth", "Lunar Moth", "月蛾", "imp",
                 ["warded", "unyielding"], ["e_dream_lull", "e_frost_breath"], "elder",
                 "Its wings hold the last light of a moon that set long ago.",
                 "双翼盛着一轮早已落下的月亮的最后的光。"),
        "monsters": [
            ("dream_jelly", "Dream Jelly", "梦水母", "caster", "jelly",
             ["venomous", "unyielding"], ["e_dream_lull", "e_drain"],
             "It drifts through sleep, and sleep drifts through it.",
             "它穿过梦，梦也穿过它。"),
            ("moon_ray", "Moon Ray", "月鳐", "lurker", "ray",
             ["elusive", "warded"], ["e_ambush", "e_frost_breath"],
             "Its wings are the colour of a cloud crossing the moon.",
             "双翼是云穿过月亮时的颜色。"),
            ("nightmare_worm", "Nightmare Worm", "梦魇蠕虫", "warden", "worm",
             ["armored", "vampiric"], ["e_bulwark", "e_dream_lull"],
             "It burrows through the space behind closed eyes.",
             "它在闭上的眼睛后面的空间里掘进。"),
        ],
    },
    {
        "id": "ashen_trench", "en": "Ashen Trench", "zh": "灰烬海沟", "tier": 8,
        "ingredient": "void_pepper", "specialty": "abyss_alloy",
        "chartLoc": "relic_hunter_wreck",
        "relics": [
            ("relic_abyss_ring", "Abyss Ring", "深渊指环",
             "Cold iron from a trench that has never seen daylight.", "取自从未见过日光的海沟的冷铁。",
             {"lifesteal": 0.03, "hpPct": 0.03}),
            ("relic_pale_compass", "Pale Compass", "苍白罗盘",
             "Its needle points down, always down.", "指针永远向下，向下。",
             {"defPct": 0.04, "avoid": 0.02}),
        ],
        "lore": [
            ("lore_ashen_trench_1", "The Sealed Door", "封印之门",
             "A door at the bottom of the trench is sealed from the inside.",
             "海沟底部的门，是从里面封住的。"),
        ],
        "curio": ("curio_ashen_trench_1", "Pale Alloy Ingot", "苍白合金锭",
                  "An ingot that drinks lamplight and gives back nothing.",
                  "一块吸走灯光却什么也不返还的合金。", 175),
        "boss": ("void_angler", "Void Angler", "虚空鮟鱇", "serpent",
                 ["venomous", "volatile"], ["e_void_gaze", "e_venom_spit", "e_doom"],
                 "Its lure is a small sun. The dark around it is not empty.",
                 "它的诱灯是一颗小太阳。它周围的黑暗并不空。"),
        "rare": ("pale_angler", "Pale Angler", "苍白鮟鱇", "serpent",
                 ["venomous", "vampiric"], ["e_venom_spit", "e_drain"], "corrupted",
                 "A deep angler that has eaten so much light it has become pale.",
                 "一条吃了太多光的深海鮟鱇，自己变得苍白。"),
        "monsters": [
            ("abyss_jelly", "Abyss Jelly", "深渊水母", "caster", "jelly",
             ["venomous", "volatile"], ["e_void_gaze", "e_curse"],
             "No light reaches it, so it makes its own.",
             "没有光能到达它，于是它自己造光。"),
            ("pale_ray", "Pale Ray", "苍白鳐", "lurker", "ray",
             ["elusive", "regen"], ["e_ambush", "e_drain"],
             "It has no shadow, because nothing down here casts one.",
             "它没有影子，因为这里没有什么能投下影子。"),
            ("trench_worm", "Trench Worm", "海沟蠕虫", "warden", "worm",
             ["armored", "splitter"], ["e_bulwark", "e_quake"],
             "It is longer than the wreck it circles and older than the trench.",
             "它比它环绕的沉船更长，比海沟更古老。"),
        ],
    },
    {
        "id": "leviathan_ring", "en": "Leviathan Ring", "zh": "利维坦环", "tier": 9,
        "ingredient": "deep_coral", "specialty": "leviathan_scale",
        "chartLoc": "behemoth_wreck",
        "relics": [
            ("relic_scale_talisman", "Scale Talisman", "鳞片护符",
             "A scale from the world serpent, still warm.", "世界海蛇的一片鳞，仍有余温。",
             {"hpPct": 0.05, "thorns": 0.05}),
            ("relic_leviathan_pearl", "Leviathan Pearl", "利维坦珍珠",
             "A pearl the size of a fist, heavy with drowned songs.", "拳头大的珍珠，盛满溺亡者的歌。",
             {"atkPct": 0.03, "lootPct": 0.03}),
        ],
        "lore": [
            ("lore_leviathan_ring_1", "The Ring of Bones", "骸骨之环",
             "The ring is not a reef; it is the ribs of something older than the sea.",
             "环礁不是礁，是比海更古老之物的肋骨。"),
        ],
        "curio": ("curio_leviathan_ring_1", "Leviathan Tooth", "利维坦之牙",
                  "A tooth worn smooth by a hundred years of tide.", "被百年潮水磨得光滑的牙。", 200),
        "boss": ("world_serpent", "World Serpent", "世界海蛇", "serpent",
                 ["armored", "regen", "berserk"], ["e_quake", "e_fire_breath", "e_enrage"],
                 "The ring is its body. The currents are its breath. The sea is its dream.",
                 "环礁是它的身体，洋流是它的呼吸，海是它的梦。"),
        "rare": ("island_whale", "Island Whale", "岛屿鲸", "beast",
                 ["armored", "bulwark"], ["e_bulwark", "e_quake"], "elder",
                 "Sailors have charted it as an island three times.",
                 "水手已经三次把它标成岛屿。"),
        "monsters": [
            ("leviathan_jelly", "Leviathan Jelly", "利维坦水母", "caster", "jelly",
             ["venomous", "regen"], ["e_venom_spit", "e_heal_all"],
             "A bell the size of a chapel, drifting with the world serpent's pulse.",
             "一座礼拜堂大小的伞盖，随世界海蛇的脉搏漂流。"),
            ("reef_ray", "Reef Ray", "礁鳐", "lurker", "ray",
             ["elusive", "armored"], ["e_ambush", "e_barrage"],
             "It carries a reef on its back, and the reef carries hunters.",
             "它背上驮着礁石，礁石上驮着猎手。"),
            ("shell_worm", "Shell Worm", "甲壳蠕虫", "warden", "worm",
             ["armored", "bulwark"], ["e_bulwark", "e_shield_wall"],
             "Its shell is made of the plates of things that tried to eat it.",
             "它的壳由试图吃掉它的东西的甲片拼成。"),
        ],
    },
    {
        "id": "grand_horizon", "en": "Grand Horizon", "zh": "大天际", "tier": 10,
        "ingredient": "sun_amber", "specialty": "horizon_glass",
        "chartLoc": "rival_flagship_wreck",
        "relics": [
            ("relic_horizon_compass", "Horizon Compass", "天际罗盘",
             "It points at the place where the sun is always rising.", "它指向太阳永远升起的地方。",
             {"spd": 3, "crit": 0.03}),
            ("relic_dawnglass", "Dawnglass", "黎明玻璃",
             "A pane of glass that holds the first light of morning.", "盛着清晨第一缕光的玻璃片。",
             {"hpPct": 0.03, "atkPct": 0.03}),
        ],
        "lore": [
            ("lore_grand_horizon_1", "The Last Gate", "最后之门",
             "Beyond the horizon gate, the sea ends and something else begins.",
             "天际门之后，海结束，别的东西开始。"),
        ],
        "curio": ("curio_grand_horizon_1", "First Light Prism", "初光棱镜",
                  "It splits dawn into colours no sailor has named.", "把黎明拆成水手尚未命名的颜色。", 250),
        "boss": ("dawn_titan", "Dawn Titan", "黎明泰坦", "golem",
                 ["armored", "unyielding", "bulwark"], ["e_quake", "e_shield_wall", "e_crush"],
                 "It was old when the first ship was built. It is still waiting at the gate.",
                 "第一艘船造好时它已古老。它仍在门前等待。"),
        "rare": ("aurora_wyrm", "Aurora Wyrm", "极光翼蛇", "serpent",
                 ["warded", "regen"], ["e_frost_breath", "e_ambush"], "swift",
                 "Its wake is a ribbon of colour across a sky that has no night.",
                 "它的尾迹是在没有夜晚的天空上划过的彩色缎带。"),
        "monsters": [
            ("star_jelly", "Star Jelly", "星水母", "caster", "jelly",
             ["venomous", "warded"], ["e_heal_all", "e_dream_lull"],
             "A jelly full of small lights, each one a place it has never been.",
             "一只装满小光点的水母，每一点都是它未曾到过的地方。"),
            ("horizon_ray", "Horizon Ray", "天际鳐", "lurker", "ray",
             ["elusive", "berserk"], ["e_ambush", "e_pierce_shot"],
             "It leaps farther than the eye can follow and lands on the other side of the light.",
             "它跃得比目光更远，落在光的另一侧。"),
            ("dawn_worm", "Dawn Worm", "黎明蠕虫", "warden", "worm",
             ["armored", "unyielding"], ["e_bulwark", "e_quake"],
             "Its rings are the colour of a sunrise seen from below the sea.",
             "体环是自海底仰望日出的颜色。"),
        ],
    },
]

# ------------------------------------------------------------------ skills
SKILLS = {
    "e_ambush": {"cat": "damage", "cd": 7, "scope": "enemy", "power": 1.9, "fx": {"reachAll": True, "mark": 3}},
    "e_bulwark": {"cat": "survival", "cd": 10, "scope": "self", "fx": {"shield": 0.22, "taunt": 4}},
    "e_swarm_call": {"cat": "support", "cd": 12, "scope": "allies", "fx": {"buffAtk": 0.15, "buffDur": 6, "meter": 8}},
    "e_venom_spit": {"cat": "damage", "cd": 7, "scope": "enemy", "power": 0.9, "fx": {"dot": 0.35, "dotDur": 4, "reachAll": True}},
    "e_quake": {"cat": "control", "cd": 11, "scope": "enemies", "power": 0.65, "fx": {"stun": 1.2}},
    "e_drain": {"cat": "damage", "cd": 9, "scope": "enemy", "power": 1.4, "fx": {"healSelf": 0.5}},
    "e_curse": {"cat": "control", "cd": 10, "scope": "enemy", "power": 0.7, "fx": {"slow": 3, "mark": 4, "sunder": 3, "reachAll": True}},
    "e_barrage": {"cat": "damage", "cd": 10, "scope": "enemies", "power": 0.5, "fx": {"hits": 3}},
    "e_frost_breath": {"cat": "damage", "cd": 10, "scope": "enemies", "power": 1.1, "fx": {"slow": 3, "reachAll": True}},
    "e_heal_all": {"cat": "support", "cd": 10, "scope": "allies", "heal": 1.2, "fx": {"cleanseAllies": True}},
    "e_enrage": {"cat": "support", "cd": 14, "scope": "self", "fx": {"buffAtk": 0.35, "buffDur": 8, "meter": 20}},
    "e_shield_wall": {"cat": "survival", "cd": 12, "scope": "front_allies", "fx": {"shield": 0.12}},
    "e_pierce_shot": {"cat": "damage", "cd": 8, "scope": "enemy", "power": 1.6, "fx": {"pierce": 0.35, "snipe": True, "reachAll": True}},
    "e_doom": {"cat": "control", "cd": 14, "scope": "enemy", "power": 0.8, "fx": {"windup": 3, "stun": 2, "dot": 0.25, "dotDur": 5}},
    "e_fire_breath": {"cat": "damage", "cd": 11, "scope": "enemies", "power": 1.2, "fx": {"dot": 0.3, "dotDur": 4, "reachAll": True}},
    "e_void_gaze": {"cat": "control", "cd": 10, "scope": "enemy", "power": 0.6, "fx": {"stun": 1.5, "mark": 4, "reachAll": True}},
    "e_dream_lull": {"cat": "control", "cd": 12, "scope": "enemies", "power": 0.35, "fx": {"stun": 1.8, "slow": 4}},
    "e_static_lash": {"cat": "damage", "cd": 8, "scope": "enemy_lane", "power": 1.0, "fx": {"stun": 0.5}},
}

ARCHETYPES = {
    "lurker": {"lane": "rear", "range": "melee", "base": {"hp": 56, "atk": 12, "def": 3, "spd": 15},
               "skills": ["e_ambush"], "tags": ["swift", "beast"]},
    "warden": {"lane": "front", "range": "melee", "base": {"hp": 135, "atk": 8, "def": 12, "spd": 6},
               "skills": ["e_bulwark"], "tags": ["armored", "construct"]},
    "swarm": {"lane": "front", "range": "melee", "base": {"hp": 38, "atk": 7, "def": 2, "spd": 12},
              "skills": ["e_swarm_call"], "tags": ["swarm"]},
}

TRAITS = {
    "armored": {"mods": {"flatReducePct": 0.12, "flatReduce": 2}},
    "venomous": {"onHit": {"dot": 0.12, "dur": 3}},
    "volatile": {"onDeath": {"aoe": 0.35}},
    "summoner": {"summon": {"enemyId": "swarmling", "every": 9.0, "cap": 3, "count": 1}},
    "splitter": {"onDeath": {"spawn": 2, "hp": 0.3}},
    "berserk": {"hpBelow": 0.4, "atk": 0.35},
    "warded": {"startShield": 0.18},
    "elusive": {"mods": {"dodge": 0.10}},
    "unyielding": {"surviveOnce": True},
    "vampiric": {"mods": {"lifesteal": 0.15}},
    "bulwark": {"mods": {"guard": 0.2, "intercept": 0.15}},
    "regen": {"mods": {"regenPct": 0.006}},
}

TRAIT_EN = {
    "armored": ("Armored", "Takes less damage from every hit."),
    "venomous": ("Venomous", "Attacks leave a lingering poison."),
    "volatile": ("Volatile", "Bursts for area damage when defeated."),
    "summoner": ("Summoner", "Calls lesser creatures into the fight."),
    "splitter": ("Splitter", "Splits into weaker copies when defeated."),
    "berserk": ("Berserk", "Grows stronger when badly wounded."),
    "warded": ("Warded", "Starts battle with a shield."),
    "elusive": ("Elusive", "Harder to hit."),
    "unyielding": ("Unyielding", "Survives one killing blow at 1 HP."),
    "vampiric": ("Vampiric", "Heals from the damage it deals."),
    "bulwark": ("Bulwark", "Guards the back line and intercepts attacks."),
    "regen": ("Regenerating", "Slowly recovers health in battle."),
}
TRAIT_ZH = {
    "armored": ("披甲", "每次受击时减免伤害。"),
    "venomous": ("剧毒", "攻击会留下持续毒素。"),
    "volatile": ("易爆", "被击败时对敌方全体造成伤害。"),
    "summoner": ("召唤者", "战斗中召唤弱小生物。"),
    "splitter": ("分裂", "被击败时分裂成较弱的复制体。"),
    "berserk": ("狂暴", "重伤时攻击力提升。"),
    "warded": ("护盾", "开局自带护盾。"),
    "elusive": ("灵巧", "更难被命中。"),
    "unyielding": ("不屈", "每场战斗可免疫一次致命伤，保留 1 点生命。"),
    "vampiric": ("吸血", "按造成的伤害恢复生命。"),
    "bulwark": ("壁垒", "保护后排并拦截攻击。"),
    "regen": ("再生", "战斗中缓慢恢复生命。"),
}

VARIANTS = {
    "alpha": {"mult": {"hp": 1.4, "atk": 1.2}, "trait": "bulwark", "tint": "#d8a25a", "drop": "trophy"},
    "elder": {"mult": {"hp": 1.8, "def": 1.3}, "trait": "regen", "tint": "#6fae8a", "drop": "lore"},
    "corrupted": {"mult": {"hp": 1.3, "atk": 1.3}, "trait": "volatile", "tint": "#9a5ac8", "drop": "curio"},
    "swift": {"mult": {"hp": 1.1, "spd": 1.5}, "trait": "elusive", "tint": "#6fd8e8", "drop": "materials"},
    "armored": {"mult": {"hp": 1.5, "def": 1.5}, "trait": "armored", "tint": "#a8b0c0", "drop": "materials"},
    "feral": {"mult": {"hp": 1.2, "atk": 1.4}, "trait": "berserk", "tint": "#d85a5a", "drop": "ingredient"},
}
VARIANT_EN = {"alpha": "Alpha", "elder": "Elder", "corrupted": "Corrupted", "swift": "Swift",
              "armored": "Armored", "feral": "Feral"}
VARIANT_ZH = {"alpha": "头目", "elder": "长者", "corrupted": "腐化", "swift": "迅捷",
              "armored": "重甲", "feral": "野性"}

# --------------------------------------------------------------- collectibles
COLLECTIBLES = {}
SETS = {}
MONSTERS = []
BOSSES = []
RARES = []
REGION_DATA = {}
I18N = {"en": {}, "zh_CN": {}}


def add_i18n(key, en, zh):
    I18N["en"][key] = en
    I18N["zh_CN"][key] = zh


def add_collectible(cid, kind, rarity, region_id, en, zh, desc_en, desc_zh, **kw):
    rec = {"id": cid, "kind": kind, "rarity": rarity, "regionId": region_id,
           "nameKey": "collectible.%s.name" % cid, "descKey": "collectible.%s.desc" % cid,
           "icon": "ui_" + kind if kind != "curio" else "ui_curio"}
    rec.update(kw)
    COLLECTIBLES[cid] = rec
    add_i18n("collectible.%s.name" % cid, en, zh)
    add_i18n("collectible.%s.desc" % cid, desc_en, desc_zh)


def add_enemy(rec, en, zh, lore_en, lore_zh):
    MONSTERS.append(rec)
    add_i18n("enemy.%s.name" % rec["id"], en, zh)
    add_i18n("bestiary.%s.lore" % rec["id"], lore_en, lore_zh)


def drop_set_for(region, kind):
    ing = region["ingredient"]
    if kind == "monster":
        return [
            {"kind": "materials", "qty": [2, 5], "chance": 1.0},
            {"kind": "ingredient", "id": ing, "chance": 0.3},
            {"kind": "collectible", "id": region["curio"][0], "chance": 0.012},
        ]
    if kind == "boss":
        return [
            {"kind": "materials", "qty": [8, 14], "chance": 1.0},
            {"kind": "trophy", "id": "trophy_" + region["boss"][0], "chance": 1.0, "firstOnly": True},
            {"kind": "relic", "id": region["relics"][0][0], "chance": 0.35},
            {"kind": "lore", "id": region["lore"][0][0], "chance": 0.2},
        ]
    return [
        {"kind": "materials", "qty": [4, 8], "chance": 1.0},
        {"kind": "trophy", "id": "trophy_" + region["rare"][0], "chance": 1.0, "firstOnly": True},
        {"kind": "chart", "id": "chart_" + region["id"], "chance": 0.15},
        {"kind": "collectible", "id": region["relics"][1][0], "chance": 0.08},
    ]


for region in REGIONS:
    rid = region["id"]
    # relics
    for i, (cid, en, zh, de, dz, mods) in enumerate(region["relics"]):
        rarity = "rare" if i == 0 else ("uncommon" if i == 1 else "epic")
        add_collectible(cid, "relic", rarity, rid, en, zh, de, dz, mods=mods)
    # lore
    for cid, en, zh, de, dz in region["lore"]:
        add_collectible(cid, "lore", "uncommon", rid, en, zh, de, dz)
    # curio
    cid, en, zh, de, dz, sell = region["curio"]
    add_collectible(cid, "curio", "common", rid, en, zh, de, dz, sell=sell)
    # boss trophy
    boss = region["boss"]
    add_collectible("trophy_" + boss[0], "trophy", "epic", rid,
                    boss[1] + " Crest", boss[2] + "之冠",
                    "Proof of defeating the " + boss[1] + ".", "击败" + boss[2] + "的证明。",
                    mods={"atkPct": 0.015 + 0.002 * region["tier"]})
    # rare trophy
    rare = region["rare"]
    add_collectible("trophy_" + rare[0], "trophy", "legendary", rid,
                    rare[1] + " Trophy", rare[2] + "战利品",
                    "Proof of defeating the elusive " + rare[1] + ".", "击败稀有怪物" + rare[2] + "的证明。",
                    mods={"lootPct": 0.02, "goldPct": 0.02})
    # chart
    loc_en = "the " + region["en"]
    add_collectible("chart_" + rid, "chart", "rare", rid,
                    "Chart of " + region["en"], region["zh"] + "海图",
                    "A chart marking a wreck in " + loc_en + ". Use it at the site to open the stash.",
                    "标出" + region["zh"] + "一处沉船的海图。抵达该处后使用可打开藏宝。",
                    locationId=region["chartLoc"], revealLocationId=region["chartLoc"],
                    stash=[
                        {"kind": "gold", "qty": 120 + 30 * region["tier"]},
                        {"kind": "materials", "qty": 8 + 3 * region["tier"]},
                        {"kind": "collectible", "id": region["relics"][1][0]},
                    ])
    # monsters
    for (mid, en, zh, arch, family, traits, skills, lore_en, lore_zh) in region["monsters"]:
        rec = {"id": mid, "regionId": rid, "archetype": arch, "family": family,
               "traits": traits, "skills": skills, "mult": 1.0,
               "loreKey": "bestiary.%s.lore" % mid, "drops": drop_set_for(region, "monster")}
        add_enemy(rec, en, zh, lore_en, lore_zh)
    # boss
    bid, ben, bzh, bplan, btraits, bskills, blore_en, blore_zh = boss
    brec = {"id": bid, "regionId": rid, "archetype": "boss", "family": bplan,
            "traits": btraits, "skills": bskills, "mult": 1.0 + 0.02 * region["tier"],
            "boss": True, "loreKey": "bestiary.%s.lore" % bid, "drops": drop_set_for(region, "boss")}
    BOSSES.append(brec)
    add_i18n("enemy.%s.name" % bid, ben, bzh)
    add_i18n("bestiary.%s.lore" % bid, blore_en, blore_zh)
    # rare
    rid2, ren, rzh, rplan, rtraits, rskills, rvariant, rlore_en, rlore_zh = rare
    rrec = {"id": rid2, "regionId": rid, "archetype": "warden" if rplan == "crab" else ("lurker" if rplan == "ray" else "brute"),
            "family": rplan, "traits": rtraits, "skills": rskills, "mult": 1.5,
            "rare": True, "variant": rvariant, "chance": 0.08,
            "loreKey": "bestiary.%s.lore" % rid2, "drops": drop_set_for(region, "rare")}
    RARES.append(rrec)
    add_i18n("enemy.%s.name" % rid2, ren, rzh)
    add_i18n("bestiary.%s.lore" % rid2, rlore_en, rlore_zh)
    REGION_DATA[rid] = {
        "roster": {
            "caster": [mid for (mid, *rest) in region["monsters"] if rest[2] == "caster"],
            "lurker": [mid for (mid, *rest) in region["monsters"] if rest[2] == "lurker"],
            "warden": [mid for (mid, *rest) in region["monsters"] if rest[2] == "warden"],
        },
        "seaMonsters": [m[0] for m in region["monsters"]],
        "rare": rid2,
        "boss": bid,
    }
    # regional set
    SETS["set_" + rid] = {
        "nameKey": "set.set_%s.name" % rid, "descKey": "set.set_%s.desc" % rid, "regionId": rid,
        "members": [region["relics"][0][0], "trophy_" + boss[0], region["lore"][0][0], region["curio"][0]],
        "bonus": {"mods": {"hpPct": 0.02 + 0.002 * region["tier"], "lootPct": 0.03},
                  "gold": 150 + 40 * region["tier"], "materials": 10 + 3 * region["tier"],
                  "shards": 2 + region["tier"] // 3},
    }
    add_i18n("set.set_%s.name" % rid, region["en"] + " Collection", region["zh"] + "收藏")
    add_i18n("set.set_%s.desc" % rid,
             "A complete record of " + region["en"] + ": one relic, one trophy, one memory, one curiosity.",
             "关于" + region["zh"] + "的完整记录：一件遗物、一件战利品、一段记忆、一件奇物。")

# summon-only swarmling
add_enemy({
    "id": "swarmling", "regionId": None, "archetype": "swarm", "family": "jelly",
    "traits": ["elusive"], "skills": ["e_ambush"], "mult": 0.62, "summonOnly": True,
    "loreKey": "bestiary.swarmling.lore",
    "drops": [{"kind": "materials", "qty": [1, 2], "chance": 1.0}],
}, "Swarmling", "群巢幼体",
   "A palm-sized hunter that only feels brave in a crowd.",
   "掌心大小的猎手，只有在成群时才觉得勇敢。")

# ------------------------------------------------------------------- sets
GRAND_SETS = [
    ("set_cartographer", "Cartographer's Round", "制图师之环",
     "Every chart in the known seas, bound by one patient hand.",
     "已知海域的每一张海图，被同一双耐心的手装订在一起。",
     {"avoid": 0.05, "foodSave": 1}, [c["id"] for c in COLLECTIBLES.values() if c["kind"] == "chart"],
     "x_a_cartographer_compass"),
    ("set_tidebound", "Tidebound Crown", "潮缚王冠",
     "The crests of every great beast that rules a region.",
     "统治每一片海域的巨兽之冠。",
     {"bossDmg": 0.08, "hpPct": 0.03}, [c["id"] for c in COLLECTIBLES.values() if c["kind"] == "trophy" and c["rarity"] == "epic"],
     "x_a_tidebound_sigil"),
    ("set_deep", "Deepwatcher's Hoard", "深望者之藏",
     "Trophies from the rarest things in the sea, and the patience it took to find them.",
     "来自海中极稀有之物的战利品，以及找到它们所需的耐心。",
     {"lootPct": 0.08, "goldPct": 0.08}, [c["id"] for c in COLLECTIBLES.values() if c["kind"] == "trophy" and c["rarity"] == "legendary"],
     "x_a_deepseeker_lens"),
    ("set_wild", "Wildheart Reliquary", "野性圣物匣",
     "One relic from each shore, carried until the brass wore smooth.",
     "来自每一片海岸的一件遗物，被带到黄铜磨得光滑。",
     {"atkPct": 0.05, "crit": 0.03}, [r["relics"][0][0] for r in REGIONS],
     "x_a_wildheart_charm"),
    ("set_storm", "Stormchaser's Cabinet", "逐风者陈列柜",
     "Every small strange thing the sea gave up after a storm.",
     "每一场风暴后，海归还的每一件小小奇物。",
     {"spd": 3, "dodge": 0.04}, [c["id"] for c in COLLECTIBLES.values() if c["kind"] == "curio"], None),
]
for sid, en, zh, de, dz, mods, members, item in GRAND_SETS:
    bonus = {"mods": mods, "gold": 900, "materials": 80, "shards": 12}
    if item:
        bonus["item"] = item
    SETS[sid] = {"nameKey": "set.%s.name" % sid, "descKey": "set.%s.desc" % sid,
                 "members": members, "bonus": bonus}
    add_i18n("set.%s.name" % sid, en, zh)
    add_i18n("set.%s.desc" % sid, de, dz)

# -------------------------------------------------------------------- gear
ITEMS = {}
SHOP_ITEMS = []


def add_item(item, en, zh):
    ITEMS[item["id"]] = item
    add_i18n("item.%s.name" % item["id"], en, zh)
    SHOP_ITEMS.append({"id": item["id"], "marketLevel": 3,
                       "regions": [item["regionId"], "grand_horizon"]})


add_item({"id": "x_w_blade_4", "slot": "weapon", "wtype": "blade", "tier": 4, "regionId": "leviathan_ring",
          "nameKey": "item.x_w_blade_4.name", "stats": {"atk": 17, "def": 0, "hp": 10, "spd": 2},
          "props": [], "mods": {"crit": 0.04}, "price": 520,
          "recipe": {"materials": 24, "specialty": ["abyss_alloy", 2]}},
         "Tidefang Blade", "潮牙刃")
add_item({"id": "x_w_gun_4", "slot": "weapon", "wtype": "gun", "tier": 4, "regionId": "stormbelt",
          "nameKey": "item.x_w_gun_4.name", "stats": {"atk": 17, "def": 0, "hp": 0, "spd": 1},
          "props": ["ranged"], "mods": {"bossDmg": 0.08}, "price": 520,
          "recipe": {"materials": 24, "specialty": ["stormwood", 2]}},
         "Stormcaller Gun", "唤雷铳")
add_item({"id": "x_w_staff_4", "slot": "weapon", "wtype": "staff", "tier": 4, "regionId": "moonwake",
          "nameKey": "item.x_w_staff_4.name", "stats": {"atk": 16, "def": 0, "hp": 16, "spd": 0},
          "props": ["splash"], "mods": {"lootPct": 0.05}, "price": 520,
          "recipe": {"materials": 24, "specialty": ["moon_ink", 2]}},
         "Dreamwood Staff", "梦木法杖")
add_item({"id": "x_w_banner_4", "slot": "weapon", "wtype": "banner", "tier": 4, "regionId": "grand_horizon",
          "nameKey": "item.x_w_banner_4.name", "stats": {"atk": 12, "def": 4, "hp": 24, "spd": 0},
          "props": ["aura"], "mods": {"auraAtk": 0.06, "crewSlot": 1}, "price": 560,
          "recipe": {"materials": 28, "specialty": ["horizon_glass", 2]}},
         "Dawn Banner", "黎明旗")
add_item({"id": "x_o_coat_4", "slot": "outfit", "otype": "coat", "tier": 4, "regionId": "moonwake",
          "nameKey": "item.x_o_coat_4.name", "stats": {"atk": 0, "def": 12, "hp": 60, "spd": 2},
          "props": [], "resist": [], "mods": {"avoid": 0.04}, "price": 460,
          "recipe": {"materials": 22, "specialty": ["moon_ink", 1]}},
         "Cartographer's Coat", "制图师外套")
add_item({"id": "x_o_armor_4", "slot": "outfit", "otype": "armor", "tier": 4, "regionId": "ashen_trench",
          "nameKey": "item.x_o_armor_4.name", "stats": {"atk": 0, "def": 18, "hp": 110, "spd": -1},
          "props": [], "resist": ["pressure"], "mods": {"flatReduce": 3}, "price": 640,
          "recipe": {"materials": 30, "specialty": ["abyss_alloy", 1]}},
         "Abyss Plate", "深渊甲")
add_item({"id": "x_o_tidecoat_4", "slot": "outfit", "otype": "coat", "tier": 4, "regionId": "leviathan_ring",
          "nameKey": "item.x_o_tidecoat_4.name", "stats": {"atk": 0, "def": 10, "hp": 72, "spd": 2},
          "props": [], "resist": ["tide"], "mods": {"hpPct": 0.05}, "price": 500,
          "recipe": {"materials": 24, "specialty": ["leviathan_scale", 1]}},
         "Tidebound Coat", "潮缚外套")
add_item({"id": "x_o_stormplate_4", "slot": "outfit", "otype": "armor", "tier": 4, "regionId": "stormbelt",
          "nameKey": "item.x_o_stormplate_4.name", "stats": {"atk": 0, "def": 16, "hp": 96, "spd": 0},
          "props": [], "resist": ["storm"], "mods": {"stunImmune": 1}, "price": 700,
          "recipe": {"materials": 28, "specialty": ["stormwood", 2]}},
         "Stormplate", "风暴铠")
add_item({"id": "x_a_cartographer_compass", "slot": "accessory", "tier": 4, "regionId": None,
          "nameKey": "item.x_a_cartographer_compass.name", "stats": {"atk": 0, "def": 0, "hp": 20, "spd": 1},
          "props": [], "mods": {"avoid": 0.04, "foodSave": 1}, "price": 0},
         "Cartographer's Compass", "制图师罗盘")
add_item({"id": "x_a_tidebound_sigil", "slot": "accessory", "tier": 4, "regionId": None,
          "nameKey": "item.x_a_tidebound_sigil.name", "stats": {"atk": 0, "def": 2, "hp": 30, "spd": 0},
          "props": [], "mods": {"bossDmg": 0.08, "hpPct": 0.03}, "price": 0},
         "Tidebound Sigil", "潮缚印记")
add_item({"id": "x_a_deepseeker_lens", "slot": "accessory", "tier": 4, "regionId": None,
          "nameKey": "item.x_a_deepseeker_lens.name", "stats": {"atk": 0, "def": 0, "hp": 20, "spd": 0},
          "props": [], "mods": {"lootPct": 0.08, "goldPct": 0.08}, "price": 0},
         "Deepseeker Lens", "深寻透镜")
add_item({"id": "x_a_wildheart_charm", "slot": "accessory", "tier": 4, "regionId": None,
          "nameKey": "item.x_a_wildheart_charm.name", "stats": {"atk": 4, "def": 0, "hp": 10, "spd": 1},
          "props": [], "mods": {"atkPct": 0.05, "crit": 0.03}, "price": 0},
         "Wildheart Charm", "野性护符")

# set accessories are rewards, not shop stock
for item_id in ("x_a_cartographer_compass", "x_a_tidebound_sigil", "x_a_deepseeker_lens", "x_a_wildheart_charm"):
    ITEMS[item_id]["unique"] = True
SHOP_ITEMS = [s for s in SHOP_ITEMS if not str(s["id"]).startswith("x_a_")]

INGREDIENTS = {
    "ember_salt": {"color": "red", "price": 16},
    "deep_coral": {"color": "blue", "price": 16},
    "moss_sugar": {"color": "green", "price": 16},
    "sun_amber": {"color": "yellow", "price": 16},
    "void_pepper": {"color": "purple", "price": 16},
    "frost_salt": {"color": "white", "price": 16},
}
ING_EN = {"ember_salt": "Ember Salt", "deep_coral": "Deep Coral", "moss_sugar": "Moss Sugar",
          "sun_amber": "Sun Amber", "void_pepper": "Void Pepper", "frost_salt": "Frost Salt"}
ING_ZH = {"ember_salt": "烬盐", "deep_coral": "深海珊瑚", "moss_sugar": "苔糖",
          "sun_amber": "日琥珀", "void_pepper": "虚空椒", "frost_salt": "霜盐"}
for k, en in ING_EN.items():
    add_i18n("ing.%s.name" % k, en, ING_ZH[k])

AFFIXES = {
    "hunter": {"bossDmg": 0.06},
    "tideward": {"hpPct": 0.05, "defPct": 0.03},
    "fleet": {"spd": 3},
    "gilded": {"goldPct": 0.08},
    "scavenger": {"lootPct": 0.08},
    "stormbound": {"crit": 0.04, "spd": 1},
    "beastbane": {"atkPct": 0.06},
    "runed": {"defPct": 0.06, "dodge": 0.02},
}
AFFIX_EN = {"hunter": "Hunter", "tideward": "Tideward", "fleet": "Fleet",
            "gilded": "Gilded", "scavenger": "Scavenger", "stormbound": "Stormbound",
            "beastbane": "Beastbane", "runed": "Runed"}
AFFIX_ZH = {"hunter": "猎手", "tideward": "潮护", "fleet": "疾行",
            "gilded": "鎏金", "scavenger": "拾荒", "stormbound": "缚雷",
            "beastbane": "克兽", "runed": "符文"}
for k, en in AFFIX_EN.items():
    add_i18n("affix.%s.name" % k, en, AFFIX_ZH[k])

# --------------------------------------------------------------- text keys
UI_TEXT = [
    ("codex.tab_collections", "Collections", "收集册"),
    ("codex.collection_sets", "Sets", "套装"),
    ("codex.collection_charts", "Charts", "海图"),
    ("codex.collection_shards", "Curio shards: {n}", "古物碎片：{n}"),
    ("codex.collection_progress", "{n} / {max} collected", "已收集 {n} / {max}"),
    ("codex.collection_claim", "Claim reward", "领取奖励"),
    ("codex.collection_claimed", "Claimed", "已领取"),
    ("codex.collection_incomplete", "Not yet complete", "尚未集齐"),
    ("codex.collection_use_chart", "Use chart here", "在此使用海图"),
    ("codex.collection_chart_used", "Chart already used", "海图已使用"),
    ("codex.collection_chart_here", "You must be at {place}.", "必须位于{place}。"),
    ("codex.bestiary_region", "{region}: {seen}/{total} seen, {defeated} defeated", "{region}：已见 {seen}/{total}，已击败 {defeated}"),
    ("codex.bestiary_claim_50", "Claim 50% reward", "领取 50% 奖励"),
    ("codex.bestiary_claim_100", "Claim 100% reward", "领取 100% 奖励"),
    ("codex.rare_enemy", "Rare", "稀有"),
    ("codex.variant_badge", "Variant: {name}", "变体：{name}"),
    ("codex.kills", "{n} kills", "击杀 {n} 次"),
    ("codex.no_collectibles", "No pieces collected yet.", "尚未收集到任何藏品。"),
    ("settle.new", "New", "新"),
    ("settle.duplicate_shards", "Owned — converted to {n} curio shards", "已拥有——转化为 {n} 枚古物碎片"),
    ("settle.duplicate_short", "Duplicate", "重复"),
    ("settle.collectible", "Collection", "收集品"),
    ("settle.collectibles", "Collectibles", "收集品"),
    ("settle.shards", "Curio shards", "古物碎片"),
    ("settle.rare_foe", "Rare foe", "稀有敌人"),
    ("settle.variant_foe", "Variant foe", "变体敌人"),
    ("port.curio_title", "Curio dealer", "古物商"),
    ("port.curio_offer", "Today's offers", "今日报价"),
    ("port.curio_exchange", "Exchange shards", "碎片兑换"),
    ("port.curio_buy", "Buy", "购买"),
    ("port.curio_exchange_btn", "Exchange", "兑换"),
    ("port.curio_shards", "Shards: {n}", "碎片：{n}"),
    ("port.curio_sold", "Purchased {item}.", "已购买{item}。"),
    ("port.curio_exchanged", "Exchanged for {item}.", "已兑换{item}。"),
    ("port.curio_none", "Nothing new today. Return another day.", "今日没有新货，改日再来。"),
    ("route.supplies_after", "Supplies {now} → {after}", "补给 {now} → {after}"),
    ("route.scout", "Scout", "斥候"),
    ("route.scout_yes", "Scout aboard: exact intel", "船上有斥候：情报精确"),
    ("route.scout_no", "No scout: intel unknown", "无斥候：情报未知"),
    ("route.scout_threats", "Threats: {list}", "威胁：{list}"),
    ("route.scout_rare", "Rare sighting: {name}", "稀有目击：{name}"),
    ("route.scout_hidden", "Unseen hidden rooms: {n}", "未发现的隐藏房间：{n}"),
    ("route.scout_sea", "Sea events: {list}", "海上事件：{list}"),
    ("err.chart_used", "This chart has already been used.", "这张海图已经使用过。"),
    ("err.chart_wrong_place", "You must use the chart at the marked wreck.", "必须在海图标记的沉船处使用。"),
    ("err.no_chart", "You do not own that chart.", "你没有这张海图。"),
    ("err.set_incomplete", "The set is not complete yet.", "套装尚未集齐。"),
    ("err.already_claimed", "That reward has already been claimed.", "该奖励已经领取过。"),
    ("err.not_ready", "You have not met the requirement yet.", "尚未达到要求。"),
    ("err.no_collectible", "That collectible does not exist.", "该收集品不存在。"),
    ("err.not_sold", "That item is not sold here.", "此处不出售该物品。"),
    ("err.no_shards", "You do not have enough curio shards.", "古物碎片不足。"),
    ("archetype.lurker", "Lurker", "潜伏者"),
    ("archetype.warden", "Warden", "守卫"),
    ("archetype.swarm", "Swarm", "虫群"),
    ("log.collectible_new", "New collection piece: {item}", "新收集品：{item}"),
    ("log.collectible_duplicate", "Duplicate {item} converted to {n} curio shards.", "重复的{item}转化为 {n} 枚古物碎片。"),
    ("log.bestiary_claim", "Bestiary reward claimed: {region} {pct}%", "图鉴奖励已领取：{region} {pct}%"),
    ("log.set_claim", "Collection set complete: {set}", "收集套装完成：{set}"),
    ("log.chart_used", "Chart used: {item}", "已使用海图：{item}"),
    ("log.curio_buy", "Bought {item} from the curio dealer.", "从古物商处购买{item}。"),
    ("log.curio_exchange", "Exchanged curio shards for {item}.", "用古物碎片兑换{item}。"),
    ("log.rare_sighted", "A rare {enemy} appears!", "稀有敌人{enemy}出现了！"),
]
for k, en, zh in UI_TEXT:
    add_i18n(k, en, zh)

for tid, (en, de) in TRAIT_EN.items():
    add_i18n("etrait.%s.name" % tid, en, TRAIT_ZH[tid][0])
    add_i18n("etrait.%s.desc" % tid, de, TRAIT_ZH[tid][1])
SKILL_ZH = {
    "e_ambush": "伏击", "e_bulwark": "壁垒", "e_swarm_call": "虫群召唤", "e_venom_spit": "毒液喷吐",
    "e_quake": "震地", "e_drain": "汲取", "e_curse": "诅咒", "e_barrage": "弹幕",
    "e_frost_breath": "霜息", "e_heal_all": "群体治疗", "e_enrage": "狂怒", "e_shield_wall": "盾墙",
    "e_pierce_shot": "穿甲射击", "e_doom": "厄运", "e_fire_breath": "火焰吐息", "e_void_gaze": "虚空凝视",
    "e_dream_lull": "沉眠之歌", "e_static_lash": "静电鞭击",
}
for sid in SKILLS:
    pretty = sid[2:].replace("_", " ").title()
    add_i18n("eskill.%s.name" % sid, pretty, SKILL_ZH.get(sid, pretty))
for vid, en in VARIANT_EN.items():
    add_i18n("variant.%s.name" % vid, en, VARIANT_ZH[vid])

# ------------------------------------------------------------------ output
BESTIARY = {
    "ARCHETYPES": ARCHETYPES, "SKILLS": SKILLS, "TRAITS": TRAITS, "VARIANTS": VARIANTS,
    "MONSTERS": MONSTERS, "BOSSES": BOSSES, "RARES": RARES, "REGIONS": REGION_DATA,
    "GROUPS": {
        "battle": [
            ["lurker", "warden", "caster"], ["skirmisher", "lurker", "healer"],
            ["warden", "shooter", "caster"], ["lurker", "lurker", "shooter"],
        ],
        "elite": [
            ["warden", "lurker", "caster", "healer"], ["brute", "warden", "shooter", "caster"],
        ],
        "boss": [
            ["warden", "lurker", "caster", "boss"], ["lurker", "warden", "healer", "boss"],
        ],
    },
}
COLLECTIONS = {
    "COLLECTIBLES": COLLECTIBLES, "SETS": SETS,
    "SHOP": {"items": SHOP_ITEMS, "curiosPerPort": 3},
    "ITEMS": ITEMS, "INGREDIENTS": INGREDIENTS, "AFFIXES": AFFIXES,
}

DATA.mkdir(parents=True, exist_ok=True)
(DATA / "bestiary.json").write_text(json.dumps(BESTIARY, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
(DATA / "collections.json").write_text(json.dumps(COLLECTIONS, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

for lang in ("en", "zh_CN"):
    path = SRC / ("native_%s.json" % lang)
    existing = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    existing.update(I18N[lang])
    path.write_text(json.dumps(existing, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

print("bestiary: %d monsters, %d bosses, %d rares, %d skills, %d traits, %d variants" % (
    len(MONSTERS), len(BOSSES), len(RARES), len(SKILLS), len(TRAITS), len(VARIANTS)))
print("collections: %d collectibles, %d sets, %d items, %d ingredients, %d affixes" % (
    len(COLLECTIBLES), len(SETS), len(ITEMS), len(INGREDIENTS), len(AFFIXES)))
print("i18n keys added: %d" % len(I18N["en"]))
