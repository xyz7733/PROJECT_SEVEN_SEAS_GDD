/*
 * Project Seven Seas — English locale table.
 *
 * Every display string lives here under a stable key. Placeholders use
 * {name} tokens filled by the translator; numbers arrive pre-formatted.
 * Data-driven families (classes, locations, enemies, ...) are written as
 * compact id → text maps and expanded into full keys at load time.
 */
(function (root) {
  'use strict';

  const S = {};
  const put = (prefix, map, suffix) => { for (const k of Object.keys(map)) S[prefix + k + (suffix || '')] = map[k]; };
  const pair = (prefix, map, a, b) => { for (const k of Object.keys(map)) { S[prefix + k + a] = map[k][0]; S[prefix + k + b] = map[k][1]; } };

  // ------------------------------------------------------------- app shell
  Object.assign(S, {
    'app.title': 'Project Seven Seas',
    'app.short': 'Seven Seas',
    'app.tagline': 'Build one ship, raise a crew, and become the strongest captain on the seven seas.',
    'lang.choose': 'Choose your language',
    'lang.note': 'You can change the language later from System. The game restarts to apply it; saves are shared between languages.',

    'nav.label': 'Main navigation',
    'nav.home': 'Overview', 'nav.ship': 'Ship', 'nav.map': 'Sea Chart', 'nav.crew': 'Crew',
    'nav.port': 'Port', 'nav.pets': 'Pet Lab', 'nav.codex': 'Codex', 'nav.system': 'System',

    'status.gold': 'Gold', 'status.food': 'Food', 'status.supplies': 'Supplies', 'status.materials': 'Materials',
    'status.stamina': 'Stamina', 'status.ledger': 'Unbanked', 'status.time': 'Time', 'status.location': 'Location',
    'status.ledger_hint': 'Gold and materials earned on this voyage. They are banked when you dock at a port; a defeat loses 25% of them.',
    'status.clock': '{hour}:00', 'status.saved': 'Saved', 'status.save_failed': 'Save failed',
    'status.stun': 'Stunned', 'status.slow': 'Slowed', 'status.mark': 'Marked', 'status.taunt': 'Taunting',
    'status.evade': 'Evading', 'status.shield': 'Shielded', 'status.buffAtk': 'ATK up', 'status.buffDef': 'DEF up',
    'status.regen': 'Regenerating', 'status.dot': 'Burning', 'status.sunder': 'Sundered',

    'ui.confirm': 'Confirm', 'ui.cancel': 'Cancel', 'ui.yes': 'Yes', 'ui.no': 'No', 'ui.delete': 'Delete',
    'ui.day': 'Day {n}', 'ui.lv': 'Lv {n}', 'ui.tier': 'Tier {n}', 'ui.free': 'Free', 'ui.unknown': 'Unknown',
    'ui.former_crew': 'Former crew member',

    'title.continue': 'Continue', 'title.new_game': 'New game', 'title.load': 'Load a save',
    'title.language': 'Language: {lang}', 'title.no_slots': 'No manual saves yet.',
    'title.footer': 'Offline game · progress is saved in this browser · all art is generated in code',
    'title.unknown_captain': 'Unknown Captain', 'title.strongest': 'Strongest Captain of the Seven Seas',

    'where.port': 'Docked at {location}', 'where.location': 'Anchored at {location}', 'where.site': 'Exploring {location}',
    'where.at_sea': 'At sea, bound for {location}', 'where.battle': 'In battle near {location}',

    'save.reason_auto': 'Autosave', 'save.reason_port': 'Docked at port', 'save.reason_battle': 'After battle',
    'save.reason_trial': 'Captain trial', 'save.reason_hull': 'Hull upgrade', 'save.reason_loaded': 'Loaded',
    'save.reason_manual': 'Manual save', 'save.reason_new_game': 'New game',

    'confirm.return_title': 'Emergency Return?',
    'confirm.return_body': 'Sail straight back to {location}. It costs no food, gold, or stamina and takes 12 hours. Your unbanked {gold} gold and {materials} materials are banked on arrival.',
    'confirm.unreachable_title': 'Some facilities are unreachable',
    'warn.confirm_unreachable': '{n} optional facilities cannot be reached and will not work on this voyage. Depart anyway?',
    'warn.deck_no_stair': 'No stair reaches deck {deck}.',
    'warn.facility_unreachable': 'Not connected to the walkway on deck {deck}.',
    'warn.facility_stowed': 'Stowed in the hold.'
  });

  // --------------------------------------------------------------- overview
  Object.assign(S, {
    'home.objective': 'Current objective', 'home.log': 'Captain\'s log', 'home.quests': 'Quests', 'home.no_quests': 'No side quests accepted.',
    'home.ship': 'Ship', 'home.hull': 'Hull', 'home.crew_cap': 'Crew berths', 'home.crew_cap_value': '{n} / {max}',
    'home.formation': 'Battle formation', 'home.stamina': 'Ship stamina', 'home.stamina_value': '{n} / {max}',
    'home.stamina_rule': 'Optional challenges cost stamina. Sailing, forced fights, retreating, cleared rooms, and returning to port are free. Only food rations and supplies restore stamina.',
    'home.serve_ration': 'Serve a ration (+{n})', 'home.use_supply': 'Use supplies (+{n})',
    'home.ledger': '{gold} gold · {materials} materials', 'home.ledger_short': 'Unbanked cargo',
    'home.damage': 'Hull damage', 'home.facility_damaged': '{facility} is damaged.',
    'home.missing_required': 'Required facility missing or unreachable: {facility}.',
    'home.over_capacity': 'More crew than berths. Build or upgrade Crew Quarters before departing.',
    'home.ship_ready': 'Ship is ready to sail.', 'home.aid_available': 'Free emergency aid is available at this port.',
    'home.open_ship': 'Open ship', 'home.open_crew': 'Open crew', 'home.open_port': 'Open port', 'home.open_chart': 'Open sea chart',
    'home.explore_site': 'Continue exploring', 'home.resume_battle': 'Resume battle',
    'home.emergency_return': 'Emergency Return', 'home.emergency_hint': 'Always available: return to your last safe port for free.',
    'home.last_safe': 'Last safe port: {location}',

    'obj.step': 'Step {n} of {total}', 'obj.target': 'Target: {location}', 'obj.target_hidden': 'Target: an uncharted location — explore to reveal it',
    'obj.have': '{have} / {need} in the hold', 'obj.show_on_chart': 'Show on chart',
    'obj.trial_locked': 'Captain trial at {location} opens after the main arc. Rival: {rival}.',
    'obj.trial_open': 'Captain trial open at {location}. Rival: {rival}.',
    'obj.trial_won': 'Captain trial won against {rival}.',
    'obj.postgame': 'You hold the title. Legendary challenges are open in the late seas.',
    'obj.legends': 'Legends defeated: {n} / {total}'
  });

  // ------------------------------------------------------------------- ship
  Object.assign(S, {
    'ship.decks': '{n} decks', 'ship.edit_ok': 'Docked: layout editing open', 'ship.edit_port_only': 'Layout can only be edited at a port',
    'ship.layout': 'Layout check', 'ship.capacity': 'Crew berths', 'ship.food_cap': 'Food storage', 'ship.supply_cap': 'Supply storage',
    'ship.equip_cap': 'Equipment storage', 'ship.stamina_max': 'Max stamina', 'ship.departure': 'Departure',
    'ship.depart_ok': 'Ready', 'ship.depart_blocked': 'Blocked',
    'ship.deck_n': 'Deck {n}', 'ship.cell': 'Cell {x},{y}',
    'ship.legend_walk': 'Walkway', 'ship.legend_entry': 'Entry', 'ship.legend_door': 'Door', 'ship.legend_stair': 'Stair', 'ship.legend_disabled': 'Unreachable',
    'ship.fixed_hull': 'Hull frame', 'ship.fixed_mast': 'Mast', 'ship.fixed_bulkhead': 'Bulkhead',
    'ship.mode_select': 'Select', 'ship.mode_stair': 'Place stair', 'ship.rotate': 'Rotate',
    'ship.build_hint': 'Click a free cell to place {facility}. Press R to rotate.',
    'ship.move_hint': 'Click a free cell to move {facility}.',
    'ship.stair_hint': 'Click a free cell to place a stair between decks {a} and {b}.',
    'ship.select_hint': 'Select a facility, door, or stair on the deck plan.',
    'ship.selection': 'Selection', 'ship.category': 'Category', 'ship.level': 'Level', 'ship.size': 'Size', 'ship.status': 'Status',
    'ship.status_active': 'Working', 'ship.status_damaged': 'Damaged (half effect)', 'ship.status_disabled': 'Unreachable (no effect)', 'ship.status_stowed': 'Stowed',
    'ship.disabled_effect': 'It has no effect until it is connected again.',
    'ship.damaged_effect': 'Damaged: works at half effect until repaired.',
    'ship.jobs': 'Workers {n} / {max}', 'ship.assign_worker': 'Assign a worker…', 'ship.unassign': 'Unassign',
    'ship.efficiency': 'efficiency {pct}', 'ship.staff_bonus': 'Staff bonus: +{pct}', 'ship.pet_helpers': 'Pet helpers: {names}',
    'ship.upgrade': 'Upgrade', 'ship.max_level': 'Max level', 'ship.move': 'Move', 'ship.stow': 'Stow', 'ship.place': 'Place',
    'ship.stow_hint': 'Store it in the hold. Stowed facilities keep their level but have no effect.',
    'ship.stowed': 'Stowed facilities', 'ship.demolish': 'Dismantle', 'ship.demolish_confirm': 'Dismantle {facility}?',
    'ship.refund': 'You get back {gold} gold and {materials} materials.', 'ship.required': 'Required',
    'ship.build_palette': 'Build facilities', 'ship.owned': 'built {n} / {max}', 'ship.build': 'Build',
    'ship.bulkhead': 'Bulkhead', 'ship.bulkhead_info': 'Bulkhead wall on deck {deck}, row {y}. Add a door to walk through it.',
    'ship.door_info': 'Door in the bulkhead on deck {deck}, row {y}.', 'ship.add_door': 'Add door', 'ship.remove_door': 'Remove door',
    'ship.stair': 'Stair', 'ship.stair_info': 'Stair between decks {a} and {b} at {x},{y}.', 'ship.remove_stair': 'Remove stair',
    'ship.stair_up': 'Stair up', 'ship.stair_down': 'Stair down',
    'ship.presets': 'Layout presets', 'ship.presets_hint': 'Save the current layout and restore it later. Applying a preset only moves facilities you own.',
    'ship.preset_n': 'Preset {n}', 'ship.preset_info': '{n} facilities', 'ship.preset_empty': 'Empty', 'ship.preset_save': 'Save here', 'ship.preset_apply': 'Apply',
    'ship.hulls': 'Hulls', 'ship.current_hull': 'Current', 'ship.hull_owned': 'Outgrown', 'ship.upgrade_hull': 'Upgrade hull',
    'ship.hull_confirm': 'Upgrade to the {hull}?', 'ship.hull_confirm_body': 'Facilities are moved to the hold and can be placed again on the larger decks. Crew, cargo, and progress carry over.',
    'ship.tier': 'Tier {n}', 'ship.services': 'Repairs & production', 'ship.repair': 'Repair', 'ship.damaged_facilities': 'Damaged facilities',
    'ship.damage_penalty': 'Heavy damage: departures cost extra food until repaired.',
    'ship.produce_food': 'Cook food (+{n})', 'ship.produce_supplies': 'Make supplies',
    'ship.production_hint': 'Galley turns gold into food and the Workshop turns materials into supplies, even at sea.',
    'ship.cannot_afford': 'Not enough resources.'
  });

  // ------------------------------------------------------------------- crew
  Object.assign(S, {
    'crew.title': 'Crew', 'crew.roster': 'Roster', 'crew.formation': 'Formation', 'crew.reserve': 'Reserve', 'crew.none': 'Select a crew member.',
    'crew.formation_hint': 'Six battle slots: two front, two center, two rear. Lanes decide who gets hit first.',
    'crew.empty_slot': '— empty —', 'crew.slot_n': 'Slot {n}',
    'crew.tactics': 'Default tactics', 'crew.tactics_hint': 'Used when an encounter starts. You can change them any time in the battle pause menu.',
    'crew.origin': 'Origin', 'crew.traits': 'Traits', 'crew.aptitudes': 'Aptitudes', 'crew.affinity': 'Pet affinity',
    'crew.event': 'Personal story', 'crew.event_done': 'Completed', 'crew.event_deliver': 'Deliver keepsake',
    'crew.injured': 'Injured', 'crew.injury_note': 'Injured: stats −{pct} until treated.', 'crew.treat': 'Treat',
    'crew.xp': 'XP {n} / {max}', 'crew.power': 'Power {n}', 'crew.branch_of': 'branch of {base}', 'crew.rename': 'Rename',
    'crew.dismiss': 'Dismiss', 'crew.dismiss_confirm': 'Dismiss {name}?', 'crew.dismiss_body': 'They leave the crew for good. Their equipment returns to the hold.',
    'crew.stats': 'Stats', 'crew.equipment': 'Equipment', 'crew.weapons_allowed': 'Usable weapons: {list}',
    'crew.choose_item': 'Choose an item…', 'crew.no_items_owned': 'No items for this slot', 'crew.no_item': 'Nothing equipped',
    'crew.incompatible': 'class cannot use', 'crew.unequip': 'Unequip',
    'crew.skills': 'Active skills', 'crew.passives': 'Passives', 'crew.class_passive': 'Class passive',
    'crew.legacy': 'Legacy passives', 'crew.legacy_n': 'Legacy {n}', 'crew.legacy_none': '— none —', 'crew.legacy_locked': 'Master a class to unlock',
    'crew.legacy_hint': 'Choose up to two passives from classes this sailor mastered (mastery {n}).',
    'crew.classes': 'Classes', 'crew.respec_rule': 'Changing class keeps level, mastery, and qualifications. Only the current class grants active skills.',
    'crew.current_class': 'Current', 'crew.change_class': 'Change class', 'crew.mastered': 'Mastered', 'crew.mastery': 'Mastery {n} / {max}',
    'crew.need_mastery': 'Needs {cls} mastery {n}', 'crew.respec_confirm': 'Change {name} to {cls}?',
    'crew.respec_body': 'Equipment the new class cannot use is moved to the hold.',
    'crew.job': 'Ship job', 'crew.job_current': '{facility} · efficiency {pct}', 'crew.job_none': 'No job assigned.',
    'crew.jobs_preferred': 'Preferred jobs: {list}', 'crew.companion': 'Companion: {pet}', 'crew.no_companion': 'No companion pet.'
  });

  // --------------------------------------------------------------- sea chart
  Object.assign(S, {
    'map.title': 'Sea Chart', 'map.locations': 'Locations', 'map.here': 'You are here', 'map.hidden_count': '{n} uncharted locations remain',
    'map.uncharted': '{n} uncharted', 'map.level': 'Lv {n}', 'map.pet_family': 'Pets: {family}', 'map.specialty': 'Specialty: {item}',
    'map.specialty_label': 'Specialty', 'map.hazard': 'Hazard: {hazard}', 'map.region_locked_n': 'Sea {n} — locked',
    'map.region_locked_hint': 'Win the previous sea\'s captain trial to open this sea.',
    'map.route': 'Route', 'map.route_to': 'Route to {location}', 'map.select_hint': 'Select a revealed location on the chart to plan a voyage.',
    'map.you_are_here': 'You are here.', 'map.voyage': 'Current voyage', 'map.origin': 'Departed from',
    'map.rooms_cleared': 'Rooms cleared: {n} / {total}', 'map.objective': 'objective', 'map.secret': 'secret',
    'map.port_services': 'Services: {list}', 'map.emergency_hint': 'Emergency Return takes you to your last safe port for free, even with no food or gold.',

    'route.distance': 'Sailing time', 'route.hours': '{n} h', 'route.food': 'Food', 'route.food_value': '{n} (left after: {after})',
    'route.return': 'Nearest return', 'route.return_value': '{n} food to {port}', 'route.no_return': 'No known port to return to',
    'route.stamina': 'Planned stamina', 'route.stamina_value': '{need} needed / {have} available', 'route.hazards': 'Hazards',
    'route.unknown': 'Unknown', 'route.none': 'None', 'route.capability': 'Recommended roles', 'route.level': 'Enemy level',
    'route.events_exact': 'Sea event forecast', 'route.events_rough': 'Sea event forecast (rough)',
    'route.return_warning': 'After this leg you may not have enough food to sail back. Emergency Return is always free.',
    'route.first_discovery': 'First visit: reveals nearby locations.',
    'route.sail': 'Sail', 'route.fast': 'Fast travel', 'route.fast_hint': 'Fast travel works between visited ports on a charted route and skips sea events.',

    'site.title': 'Explore {location}', 'site.fight': 'Fight', 'site.search': 'Search', 'site.move': 'Pass through', 'site.move_free': 'Cleared rooms are free to cross.',
    'site.repeat': 'Fight again', 'site.repeat_hint': 'Optional repeat battle for extra rewards.',
    'site.stamina_rule': 'Entering a new room costs stamina. Cleared rooms, retreating, and leaving are free.',
    'legend.challenge': 'Challenge the legend', 'legend.title': 'Legend of {region}', 'legend.won': 'Legend defeated'
  });

  // ------------------------------------------------------------------- port
  Object.assign(S, {
    'port.title': 'Port', 'port.not_docked': 'Not docked', 'port.not_docked_hint': 'Sail to a port to trade, recruit, and invest. Your last safe port is {location}.',
    'port.tab_invest': 'Invest', 'port.tab_market': 'Market', 'port.tab_tavern': 'Tavern', 'port.tab_workshop': 'Workshop', 'port.tab_board': 'Quest board', 'port.tab_services': 'Services',
    'port.reputation': 'Standing: {list}',
    'port.invest_title': 'Port investment', 'port.invest_hint': 'Each level permanently unlocks the listed service at this port.',
    'port.track_level': 'Level {n} / 3', 'port.track_max': 'Fully developed', 'port.invest_to': 'Invest to level {n}',
    'port.goods': 'Provisions', 'port.food_rule': 'Food is charged once when you depart and is never refunded.', 'port.stock': '{n} / {max}',
    'port.ingredients': 'Pet ingredients', 'port.specialties': 'Regional specialties', 'port.local_specialty': 'Local specialty',
    'port.specialty_rule': 'Specialties are used for quests, contracts, crafting, and egg recipes. Selling far from home pays more.',
    'port.owned': 'owned {n}', 'port.sell_price': 'sells for {n}', 'port.sell_one': 'Sell 1', 'port.buy': 'Buy',
    'port.eggs': 'Eggs', 'port.egg_offer': '{family} egg', 'port.buy_egg': 'Buy egg',
    'port.equipment_shop': 'Equipment', 'port.equip_stock': 'Storage {n} / {max}', 'port.no_equipment': 'No equipment on sale at this market level.',
    'port.tavern_title': 'Tavern', 'port.tavern_hint': 'New sailors arrive on day {day}. Tavern level {level}.', 'port.recruit': 'Recruit',
    'port.hired': 'Hired', 'port.aptitudes_hidden': 'Aptitudes hidden (tavern level 2)', 'port.qualified': 'Qualified: {cls}',
    'port.workshop_title': 'Workshop', 'port.workshop_ok': 'Crafting available here.', 'port.affix': 'Affix', 'port.no_affix': 'No affix',
    'port.no_recipes': 'No recipes known. Recipes come from side quests and bosses.', 'port.craft': 'Craft',
    'port.inventory': 'Inventory {n} / {max}', 'port.reinforce': 'Reinforce', 'port.salvage': 'Salvage (+{n} materials)', 'port.equipped_by': 'Equipped by {name}',
    'port.usable_by': 'Usable by: {list}',
    'port.main_quest': 'Main quest', 'port.quest_done': 'Done', 'port.quest_active': 'Accepted', 'port.deliver': 'Deliver {n} {item}',
    'port.side_quests': 'Side quests', 'port.no_side': 'No side quests at this port.', 'port.accept': 'Accept', 'port.complete': 'Complete',
    'port.reward': 'Reward: {gold} gold · {xp} XP · {extra}',
    'port.contracts': 'Contracts', 'port.contract_hint': 'Contracts rotate every three days. Up to three can be active.',
    'port.contract_reward': 'Reward: {gold} gold · {materials} materials', 'port.contracts_elsewhere': 'Active contracts elsewhere',
    'port.aid_title': 'Emergency aid', 'port.aid_hint': 'Free help when you cannot afford the basics. You can always recover.',
    'port.dock_work': 'Dock work (+{n} gold)', 'port.dock_work_hint': 'Crew take a shift on the docks. Takes 4 hours, costs nothing.',
    'port.dock_work_locked': 'Dock work is only offered when you are short on gold.',
    'port.treatment': 'Treatment', 'port.no_injured': 'No injured crew.', 'port.recovery_room': 'Recovery Room: {n} free treatments left today',
    'port.repair': 'Ship repair', 'port.wait_title': 'Rest', 'port.wait': 'Wait 6 hours', 'port.wait_hint': 'Pass time to rotate taverns and contracts.'
  });

  // ---------------------------------------------------------------- pet lab
  Object.assign(S, {
    'pets.title': 'Pet Lab', 'pets.count': 'Pets {n} / {max}', 'pets.eggs_count': 'Eggs {n} / {max}',
    'pets.hatchery_level': 'Hatchery Lv {n}', 'pets.lab_level': 'Pet Lab Lv {n}', 'pets.no_hatchery': 'No Hatchery aboard', 'pets.no_lab': 'No Pet Lab aboard',
    'pets.eggs': 'Eggs', 'pets.no_eggs': 'No eggs.', 'pets.no_eggs_hint': 'Eggs come from secret rooms, island hollows, side quests, and port markets (level 3).',
    'pets.egg_sources': 'Egg sources', 'pets.grade': 'Grade {n}',
    'pets.feed_title': 'Feed the {family} egg', 'pets.feed_title_none': 'Select an egg',
    'pets.feed_rule': 'Feed up to three ingredients or specialties in order. The same egg with the same order always hatches the same pet.',
    'pets.feed_n': 'Input {n}', 'pets.empty_slot': 'empty', 'pets.clear': 'Clear', 'pets.max_inputs': 'Three inputs at most.',
    'pets.no_inputs': 'No ingredients or specialties owned.', 'pets.inputs': 'Inputs', 'pets.nothing_queued': 'Nothing queued yet.',
    'pets.predicted_role': 'Leaning', 'pets.known_outcome': 'Recorded result', 'pets.unrecorded': 'Not yet recorded',
    'pets.signatures': 'Family signatures', 'pets.signature_hint': 'Find this family\'s clue to learn its recipe signatures.',
    'pets.hatch': 'Hatch', 'pets.hatch_level': 'Requires a Hatchery', 'pets.prime': 'Prime hatch!', 'pets.none_left': 'All inputs used.',
    'pets.roster': 'Pets', 'pets.no_pets': 'No pets yet.', 'pets.detail': 'Pet details', 'pets.roles': 'Roles', 'pets.ability': 'Ability', 'pets.power': 'Power',
    'pets.affinity': 'Affinity: {color}',
    'pets.target_enemy': 'Hits an enemy', 'pets.target_owner': 'Helps its owner', 'pets.target_allies': 'Helps all allies',
    'pets.ab_power': '{pct} ATK', 'pets.ab_heal': 'heals {pct} ATK', 'pets.ab_shield': 'shield {pct} max HP',
    'pets.assignment': 'Assignment', 'pets.unassigned': 'Unassigned', 'pets.unassign': 'Unassign', 'pets.with': 'with {name}', 'pets.at': 'at {facility}',
    'pets.helper_half': 'Not a helper by nature: works at half effect.', 'pets.send_explore': 'Send exploring', 'pets.recall': 'Recall',
    'pets.evolution': 'Evolution', 'pets.evolve': 'Evolve', 'pets.evolve_hint': 'Needs a Pet Lab and pet level {level}.', 'pets.evolved': 'Evolved',
    'pets.evolved_note': 'Evolution is permanent and keeps every assignment.'
  });

  // ------------------------------------------------------------------ codex
  Object.assign(S, {
    'codex.title': 'Codex', 'codex.captain': '{title} · trials won {n}',
    'codex.tab_locations': 'Seas', 'codex.tab_enemies': 'Enemies', 'codex.tab_classes': 'Classes', 'codex.tab_pets': 'Pets', 'codex.tab_items': 'Items', 'codex.tab_clues': 'Clues',
    'codex.region_locked': 'Locked sea', 'codex.arc': 'Main arc', 'codex.hazard': 'Hazard', 'codex.mechanic': 'Battle rule', 'codex.pet_family': 'Pet family',
    'codex.trial': 'Captain trial', 'codex.trial_won': 'Won', 'codex.trial_pending': 'Not yet won', 'codex.none_value': '—',
    'codex.unknown_location': 'Uncharted', 'codex.unknown_enemy': 'Unknown enemy', 'codex.unknown_class': 'Unknown class', 'codex.unknown_pet': 'Unknown',
    'codex.defeated': 'Defeated {n}', 'codex.boss': 'Boss', 'codex.rival': 'Rival captain', 'codex.classes_hint': 'Classes appear once a crew member trains in them.',
    'codex.hatch_log': 'Hatch log', 'codex.hatch_hint': 'Every hatch is recorded: the same family and input order give the same pet.',
    'codex.no_hatches': 'No hatches recorded yet.', 'codex.family': 'Family', 'codex.order': 'Input order', 'codex.result': 'Result',
    'codex.items_seen': 'Items seen', 'codex.recipes': 'Recipes', 'codex.recipe_known': 'Known', 'codex.recipe_cost': '{n} materials · {k} {item}',
    'codex.blueprints': 'Blueprints', 'codex.uniques': 'Unique gear', 'codex.none': 'Nothing yet.', 'codex.no_clues': 'No clues found yet.'
  });

  // ----------------------------------------------------------------- system
  Object.assign(S, {
    'system.title': 'System', 'system.storage_local': 'Browser storage', 'system.storage_memory': 'Temporary storage',
    'system.storage_memory_hint': 'This browser blocks local storage, so saves last only until the page closes. Export a save file to keep progress.',
    'system.last_saved': 'Saved {time}', 'system.last_save_failed': 'Last save failed',
    'system.manual': 'Manual saves', 'system.manual_hint': 'Manual slots are only written when you choose to.',
    'system.slot_n': 'Slot {n}', 'system.slot_empty': 'Empty', 'system.slot_corrupt': 'Damaged save (cannot load)',
    'system.save_here': 'Save', 'system.load': 'Load', 'system.delete': 'Delete',
    'system.overwrite_title': 'Overwrite save?', 'system.overwrite_body': 'Slot {n} will be replaced with your current game.',
    'system.load_title': 'Load this save?', 'system.load_body': 'Unsaved progress since your last autosave will be lost.',
    'system.load_recovery_body': 'Load this recovery save? Newer progress stays in the other recovery slots.',
    'system.delete_title': 'Delete save?', 'system.delete_body': 'Slot {n} will be erased.',
    'system.recovery': 'Recovery saves', 'system.recovery_hint': 'The game keeps the {n} most recent automatic saves: at ports, after battles, trials, and hull upgrades.',
    'system.recovery_latest': 'Latest', 'system.recovery_older': '{n} older', 'system.no_recovery': 'No recovery saves yet.',
    'system.transfer': 'Export & import', 'system.transfer_hint': 'Save files are plain JSON and work in either language.',
    'system.export': 'Export save', 'system.import': 'Import save', 'system.exported': 'Save exported.',
    'system.import_title': 'Import this save?', 'system.import_body': 'Your current game is replaced. Recovery saves keep the previous state.',
    'system.settings': 'Settings', 'system.text_scale': 'Text size', 'system.battle_speed': 'Battle speed', 'system.reduce_motion': 'Reduce motion',
    'system.pause_start': 'Pause when a battle starts',
    'system.language': 'Language', 'system.language_hint': 'Changing the language restarts the game. Saves are not affected.',
    'system.language_current': 'This is the current language.', 'system.restart_language': 'Restart in this language',
    'system.restart_title': 'Restart the game?', 'system.restart_body': 'Your game is saved, then the game restarts in {lang}.',
    'system.captain': 'Captain', 'system.profile': 'Profile', 'system.seed': 'World seed', 'system.transactions': 'Transactions',
    'system.battles': 'Battles', 'system.battles_value': '{w} won · {l} lost · {r} retreats', 'system.voyages': 'Voyages', 'system.postgame': 'Postgame',
    'system.title_screen': 'Title screen', 'system.new_game': 'New game', 'system.new_title': 'Start a new game?',
    'system.new_body': 'Your current game stays in its manual slots, but recovery saves are cleared.',
    'system.new_started': 'A new voyage begins.', 'system.saved_slot': 'Saved to slot {n}.', 'system.loaded': 'Save loaded.',
    'system.crew_n': '{n} crew', 'system.trials_n': '{n} trials',
    'system.shortcuts': 'Keyboard shortcuts',
    'system.shortcuts_list': '1–8 switch views · In battle: Space/P pause, 1/2/4 speed, R retreat, S skip, Enter continue · Ship editor: R rotate, Esc cancel'
  });

  // ----------------------------------------------------------------- battle
  Object.assign(S, {
    'battle.title_sea': '{kind} near {location}', 'battle.title_room': '{room} · {location}', 'battle.title_legend': 'Legend of {region}',
    'battle.wave': 'Wave {n}/{max}', 'battle.time': '{n}s / {max}s', 'battle.allies': 'Your crew', 'battle.enemies': 'Enemies',
    'battle.pause': 'Pause', 'battle.resume': 'Resume', 'battle.paused': 'Paused — adjust tactics, then resume.',
    'battle.skip': 'Skip to end', 'battle.skip_hint': 'Resolve the rest of the battle instantly with the current tactics.',
    'battle.retreat': 'Retreat', 'battle.retreating': 'Retreating… {n}s', 'battle.retreat_hint': 'The crew needs {n}s to withdraw. Retreating is free but forfeits rewards.',
    'battle.stance': 'Stance', 'battle.priority': 'Skill priority', 'battle.focus': 'Focus target', 'battle.focus_auto': 'Automatic',
    'battle.focus_hint': 'Click to focus this enemy.', 'battle.status': '{stance} · {priority} · focus: {focus}',
    'battle.log': 'Battle log', 'battle.winding': 'Winding up {skill} ({n}s)', 'battle.interrupted': 'Interrupted!', 'battle.miss': 'Miss',
    'battle.basic_attack': 'Attack', 'battle.mod_trial': 'Captain trial',
    'battle.ev_wave': 'Wave {n} of {max}.', 'battle.ev_hit': '{src} hits {tgt} with {skill} for {n}.', 'battle.ev_crit': 'Critical! {src} hits {tgt} with {skill} for {n}.',
    'battle.ev_absorbed': '({n} absorbed)', 'battle.ev_miss': '{tgt} dodges {src}.', 'battle.ev_heal': '{src} heals {tgt} for {n}.',
    'battle.ev_ko': '{tgt} is knocked out.', 'battle.ev_skill': '{src} uses {skill}.', 'battle.ev_windup': '{src} winds up {skill} at {tgt}!',
    'battle.ev_interrupt': '{tgt}\'s {skill} is interrupted.', 'battle.ev_stun': '{tgt} is stunned for {n}s.',
    'battle.ev_intercept': '{src} takes the hit for {tgt}.', 'battle.ev_thorns': '{tgt} takes {n} thorn damage from {src}.',
    'battle.ev_trap': 'A trap springs on {tgt} for {n}.', 'battle.ev_resist': '{tgt} resists.', 'battle.ev_dot': '{tgt} burns for {n}.',
    'battle.ev_pet': '{src} uses {ability}.', 'battle.ev_hazard': 'Hazard: {hazard} strikes.', 'battle.ev_encore': 'The legend rises again for an encore!',
    'battle.ev_command_focus': 'Order: focus {value}.', 'battle.ev_command_stance': 'Order: stance {value}.',
    'battle.ev_command_priority': 'Order: priority {value}.', 'battle.ev_command_retreat': 'Order: retreat!',
    'battle.ev_end_victory': 'Victory!', 'battle.ev_end_defeat': 'Defeat.', 'battle.ev_end_retreat': 'The crew withdraws.',
    'battle.outcome_victory': 'Victory', 'battle.outcome_defeat': 'Defeat', 'battle.outcome_defeat_timeout': 'Defeat — time ran out', 'battle.outcome_retreat': 'Retreated',
    'battle.result_time': '{n}s · crew HP {hp}', 'battle.result_error': 'The battle could not be resolved. Your game was not changed.',
    'battle.r_gold': '+{n} gold', 'battle.r_materials': '+{n} materials', 'battle.r_food': '+{n} food', 'battle.r_supplies': '+{n} supplies',
    'battle.r_item': 'Found: {item}', 'battle.r_specialty': '+{n} {item}', 'battle.r_ingredients': 'Ingredients: {list}', 'battle.r_egg': 'Egg: {family} (grade {n})',
    'battle.r_clue': 'Clue: {clue}', 'battle.r_xp': '+{n} XP', 'battle.r_ledger': 'Gold and materials go to the unbanked ledger until you dock.',
    'battle.r_arrived': 'Arrived at {location}.',
    'battle.retreat_result': 'You withdrew safely. Nothing was lost and no stamina was spent.',
    'battle.defeat_result': 'Lost {gold} unbanked gold and {materials} materials. The crew was carried back to {location}.',
    'battle.defeat_injured': 'Injured: {list}', 'battle.defeat_facility': 'Damaged: {facility}',
    'battle.defeat_keep': 'Levels, mastery, equipment, pets, and charts are never lost.', 'battle.continue': 'Continue'
  });

  // ------------------------------------------------------------- sea events
  Object.assign(S, {
    'sea.continue': 'Continue', 'sea.vessel.help': 'Share 2 food', 'sea.vessel.ignore': 'Sail on', 'sea.inspection.pay': 'Pay the toll', 'sea.inspection.refuse': 'Refuse',
    'sea.pirate.title': 'Pirate raid', 'sea.pirate.desc': 'Black sails close in across {region}. They mean to board.', 'sea.pirate.effect': 'A boarding battle begins.',
    'sea.monster.title': 'Sea monster', 'sea.monster.desc': 'Something huge rises from the waters of {region}.', 'sea.monster.effect': 'A battle begins.',
    'sea.cache.title': 'Floating cache', 'sea.cache.desc': 'A sealed crate bobs in the swell of {region}.', 'sea.cache.effect': 'You gain supplies and materials.',
    'sea.vessel.title': 'Stranded vessel', 'sea.vessel.desc': 'A small crew from {region} signals for help.', 'sea.vessel.effect': 'Helping costs 2 food and earns gold and goodwill.',
    'sea.shortcut.title': 'Hidden current', 'sea.shortcut.desc': 'Your navigator spots a fast current through {region}.', 'sea.shortcut.effect': 'Routes in this sea cost 1 less food; an uncharted place may be revealed.',
    'sea.weather.title': 'Squall', 'sea.weather.desc': 'A sudden squall sweeps over {region}.', 'sea.weather.effect': 'Without a Navigator or Barricade Room, the hull takes damage and you lose 2 hours.',
    'sea.inspection.title': 'Pennant inspection', 'sea.inspection.desc': 'A patrol flying red pennants hails you in {region}.', 'sea.inspection.effect': 'Pay {n} gold, or refuse and lose 6 hours.',
    'sea.clue.title': 'Message in a bottle', 'sea.clue.desc': 'A bottle drifts by with a note about the creatures of {region}.', 'sea.clue.effect': 'You may learn a pet family clue.'
  });

  // ------------------------------------------------------------------ errors
  Object.assign(S, {
    'err.unknown': 'That cannot be done right now.', 'err.internal': 'Something went wrong. Your game was not changed.',
    'err.in_encounter': 'Finish the current battle first.', 'err.no_encounter': 'There is no battle in progress.', 'err.no_event': 'There is no sea event to resolve.',
    'err.event_pending': 'Resolve the sea event first.', 'err.need_port': 'Only possible while docked at a port.', 'err.wrong_port': 'Not available at this port.',
    'err.already_docked': 'You are already docked.', 'err.same_location': 'You are already here.', 'err.unknown_location': 'Unknown location.',
    'err.not_revealed': 'That location is not charted yet.', 'err.region_locked': 'This sea is still locked.', 'err.not_at_site': 'You are not at that location.',
    'err.room_locked': 'Clear an adjacent room first.', 'err.room_depleted': 'This room has nothing left.', 'err.trial_locked': 'The captain trial opens after the main arc.',
    'err.fast_ports_only': 'Fast travel only connects ports.', 'err.fast_not_visited': 'Fast travel needs both ports visited.', 'err.fast_not_charted': 'This route is not charted yet.',
    'err.no_food': 'Needs {need} food.', 'err.no_food_route': 'Not enough food for this route.', 'err.no_gold': 'Needs {need} gold.',
    'err.no_materials': 'Needs {need} materials.', 'err.no_supplies': 'Needs {need} supplies.', 'err.no_specialty': 'Needs {need} {item}.',
    'err.no_input': 'You have no {item}.', 'err.no_stamina': 'Needs {need} stamina (you have {have}).', 'err.stamina_full': 'Stamina is already full.',
    'err.food_full': 'Food storage is full.', 'err.supplies_full': 'Supply storage is full.', 'err.equip_full': 'Equipment storage is full.',
    'err.empty_formation': 'Put at least one crew member in the formation.', 'err.layout_blocked': 'The ship layout blocks departure.',
    'err.over_capacity': 'More crew than berths.', 'err.need_facility': 'Needs {facility}.', 'err.need_infirmary': 'Needs an Infirmary aboard or a port.',
    'err.need_workshop': 'Needs a Workshop aboard or a port workshop.', 'err.need_workshop2': 'Needs a level 2 workshop.',
    'err.need_bench': 'Needs a Material Bench.', 'err.need_class_hall': 'Needs a Class Hall.', 'err.need_muster': 'Needs a Muster Deck.',
    'err.need_explorer': 'Needs an exploring pet.', 'err.market_level': 'Needs market level {level}.', 'err.board_level': 'Needs quest board level {level}.',
    'err.max_level': 'Already at max level.', 'err.build_limit': 'Build limit reached.', 'err.hull_tier': 'Needs hull tier {tier}.',
    'err.cannot_demolish_cabin': 'The Captain\'s Cabin cannot be dismantled.', 'err.out_of_bounds': 'Outside the deck.', 'err.cell_blocked': 'That cell is blocked.',
    'err.cell_occupied': 'That cell is occupied.', 'err.cell_door': 'Keep doorways clear.', 'err.cell_entry': 'Keep the deck entry clear.',
    'err.cell_stair': 'A stair is there.', 'err.bad_cell': 'Not a valid cell.', 'err.no_lower_deck': 'There is no deck below.',
    'err.no_preset': 'That preset is empty.', 'err.nothing_to_repair': 'Nothing needs repair.',
    'err.hull_owned': 'You already have this hull or a better one.', 'err.hull_previous': 'Upgrade to the previous hull first.',
    'err.hull_region': 'Unlocks when you reach {region}.', 'err.hull_blueprint': 'Needs the Legend Keel blueprint.', 'err.hull_required': 'Needs a hull upgrade.',
    'err.job_full': 'No free job slot.', 'err.no_job_slots': 'This facility has no jobs.', 'err.last_crew': 'You cannot dismiss your last crew member.',
    'err.already_hired': 'Already hired.', 'err.not_injured': 'Not injured.', 'err.not_qualified': 'Not qualified for {cls}.',
    'err.not_mastered': 'Master the class first.', 'err.same_class': 'Already this class.', 'err.legacy_duplicate': 'That passive is already chosen.',
    'err.weapon_incompatible': '{cls} cannot use this weapon.', 'err.wrong_slot': 'Wrong equipment slot.', 'err.equipped': 'Unequip it first.',
    'err.no_recipe': 'Recipe unknown.', 'err.not_sold': 'Not sold here.', 'err.nothing_to_deliver': 'Nothing to deliver.',
    'err.already_accepted': 'Already accepted.', 'err.contract_limit': 'Three contracts are already active.', 'err.contract_incomplete': 'Not finished yet ({have}/{need}).',
    'err.aid_not_needed': 'You can afford this yourself.', 'err.pet_full': 'No room for more pets.', 'err.pet_level': 'Needs pet level {level}.',
    'err.pet_role': 'This pet cannot be a {role}.', 'err.pet_owner': 'That crew member is not in the formation.', 'err.already_evolved': 'Already evolved.',
    'err.hatch_inputs': 'Feed the egg between one and three inputs.', 'err.no_legend': 'No legend here.', 'err.postgame_only': 'Available after you hold the title.',
    'err.save_write_failed': 'The game could not be saved. Free some storage or export your save.', 'err.save_missing': 'No save found.',
    'err.save_corrupt': 'This save is damaged and cannot be loaded.', 'err.save_newer': 'This save comes from a newer version.', 'err.save_old': 'This save is from an unsupported version.'
  });

  // --------------------------------------------------------------------- log
  Object.assign(S, {
    'log.empty': 'Nothing logged yet.', 'log.new_game': 'You take command of a small ship at Brightquay.',
    'log.arrived': 'Arrived at {location}.', 'log.revealed': 'Charted {location}.', 'log.cleared': 'Cleared {location}.',
    'log.banked': 'Banked {gold} gold and {materials} materials.', 'log.defeat': 'Defeated. Lost {gold} gold and {materials} materials.',
    'log.retreated': 'The crew retreated.', 'log.emergency_return': 'Emergency Return to {location}.', 'log.boarded': 'Encounter: {kind}.',
    'log.weather_damage': 'A squall damaged the hull.', 'log.waited': 'Rested for 6 hours.', 'log.repaired': 'Ship repaired.',
    'log.built': 'Built {facility}.', 'log.upgraded': '{facility} upgraded to level {level}.', 'log.demolished': 'Dismantled {facility} (+{gold} gold, +{materials} materials).',
    'log.hull_upgraded': 'Hull upgraded to {hull}.', 'log.recruited': '{crew} joined the crew.', 'log.level_up': '{crew} reached level {level}.',
    'log.respec': '{crew} changed class from {from} to {to}.', 'log.treated': '{crew} was treated.', 'log.unequipped': '{item} returned to the hold from {crew}.',
    'log.crew_event_done': '{crew} completed "{event}".', 'log.aid': 'Received emergency aid: {kind}.', 'log.dock_work': 'Dock work paid {gold} gold.',
    'log.invested': 'Invested in {track} at {port} (level {level}).', 'log.crafted': 'Crafted {item}.', 'log.blueprint': 'Blueprint found: {item}.',
    'log.equip_overflow': 'No room for {item}; sold it for {n} gold.', 'log.food_overflow': '{n} food did not fit in the pantry.',
    'log.supply_overflow': '{n} supplies did not fit in the hold.', 'log.quest_accepted': 'Accepted: {quest}.', 'log.side_done': 'Completed: {quest}.',
    'log.main_done': 'Main quest step complete: {quest}.', 'log.contract_done': 'Contract complete (+{gold} gold).', 'log.clue': 'New clue: {clue}',
    'log.egg_found': 'Found a {family} egg.', 'log.hatched': 'Hatched {species}.', 'log.hatched_prime': 'Prime hatch: {species}!',
    'log.evolved': 'Evolved into {species}.', 'log.pet_found_secret': 'Your explorer pet found a secret place.',
    'log.trial_won': 'Captain trial won in {region} against {rival}.', 'log.region_unlocked': 'New sea opened: {region}.',
    'log.legend_won': 'Defeated the legend of {region}.', 'log.postgame': 'You are now the Strongest Captain of the Seven Seas.'
  });

  // --------------------------------------------------- generic small families
  Object.assign(S, {
    'stat.hp': 'HP', 'stat.atk': 'ATK', 'stat.def': 'DEF', 'stat.spd': 'SPD', 'stat.crit': 'Crit', 'stat.dodge': 'Dodge',
    'stat.hp_short': 'HP', 'stat.atk_short': 'ATK', 'stat.def_short': 'DEF', 'stat.spd_short': 'SPD',
    'skill.power': '{pct} ATK', 'skill.heal': 'heals {pct} ATK', 'skill.cd': '{n}s cooldown', 'skill.cond_critical': 'only when an ally is below 35% HP',
    'item.set_format': '{tier} {type}', 'item.affix_format': '{affix} {name}', 'item.resist': 'Resists {hazard}',
    'pet.species_format': '{family} {form}', 'blueprint.legend_keel': 'Legend Keel blueprint',
    'odds.high': 'likely', 'odds.mid': 'possible', 'odds.low': 'rare',
    'contract.hunt': 'Defeat {need} foes in {region} ({have}/{need}), then report to {port}.', 'contract.supply': 'Deliver {need} supplies to {port}.',
    'contract.haul': 'Haul {need} {item} to {port}.', 'contract.hunt.title': 'Bounty hunt', 'contract.supply.title': 'Supply run', 'contract.haul.title': 'Cargo haul'
  });
  put('role.', { vanguard: 'Vanguard', striker: 'Striker', controller: 'Controller', support: 'Support', scout: 'Scout' });
  pair('lane.', { front: ['Front', 'Takes most hits.'], center: ['Center', 'Covered by the front line.'], rear: ['Rear', 'Safest; best for ranged and support.'] }, '', '.desc');
  pair('loctype.', {
    port: ['Port', 'Safe harbor: trade, recruit, invest, and bank cargo.'], island: ['Island', 'Rooms with resources, battles, and a hidden hollow.'],
    dungeon: ['Dungeon', 'A deeper site guarded by a boss.'], wreck: ['Wreck', 'A short salvage dive.'], arena: ['Arena', 'Home of the captain trial.'],
    secret: ['Secret', 'A hidden place tied to the sea\'s pet family.']
  }, '', '.desc');
  put('know.', { hidden: 'Hidden', revealed: 'Revealed', visited: 'Visited', cleared: 'Cleared' });
  put('cat.', { damage: 'Damage', control: 'Control', support: 'Support', survival: 'Survival' });
  put('slot.', { weapon: 'Weapon', outfit: 'Outfit', accessory: 'Accessory' });
  put('range.', { melee: 'Melee', ranged: 'Ranged' });
  put('scope.', { enemy: 'one enemy', self: 'self', front_allies: 'front allies', enemy_lane: 'an enemy lane', enemies: 'all enemies', ally: 'one ally', allies: 'all allies' });
  put('color.', { red: 'Red', blue: 'Blue', green: 'Green', yellow: 'Yellow', purple: 'Purple', white: 'White' });
  put('archetype.', { skirmisher: 'Skirmisher', brute: 'Brute', shooter: 'Shooter', caster: 'Caster', healer: 'Healer', boss: 'Boss', captain: 'Captain', decoy: 'Decoy' });
  put('roomkind.', { battle: 'Battle', resource: 'Resources', elite: 'Elite battle', boss: 'Boss', event: 'Event', trial: 'Captain trial' });
  put('reward.family.', { materials: 'materials', specialty: 'specialty', gold: 'gold', ingredients: 'ingredients', egg: 'egg', supplies: 'supplies', equipment: 'equipment' });
  put('reward.kind.', { recipe: 'a recipe', supplies: 'supplies', ingredients: 'ingredients', clue: 'a pet clue', egg: 'a pet egg' });
  put('qtype.', {
    clear: 'Clear {location}', visit: 'Visit {location}', deliver: 'Deliver {count} {item} at {location}',
    trial: 'Win the captain trial at {location}', discover: 'Discover {location}'
  });
  pair('side.', {
    survey: ['Survey {location}', 'The Harbor League wants {location} charted room by room.'],
    salvage: ['Salvage {location}', 'Recover what the wreck at {location} still holds.'],
    outpost: ['Secure {location}', 'Clear {location} so the League can build an outpost.'],
    legend: ['Legend of {location}', 'Old songs speak of a hidden place: find {location}.'],
    depths: ['Into {location}', 'The Tidebound Society wants samples from deep inside {location}.']
  }, '.title', '.desc');
  put('faction.', { conclave: 'Horizon Conclave', league: 'Harbor League', tidebound: 'Tidebound Society', pennants: 'Red Pennants' }, '.name');
  put('rank.', { 0: 'Stranger', 1: 'Known', 2: 'Trusted', 3: 'Honored' });
  pair('aid.', {
    meal: ['Free meal', 'Enough food for the next leg when you cannot afford it.'],
    treatment: ['Free treatment', 'Basic care for injured crew.'],
    repair: ['Free patch-up', 'Essential repairs so the ship can sail.']
  }, '', '.desc');
  put('legend.restriction.', { double_hazard: 'Double hazard', no_healing: 'No healing', four_crew: 'Four crew only', endless_waves: 'Endless waves', encore: 'Encore' });
  pair('stance.', {
    aggressive: ['Aggressive', 'More damage, less defense; skills fire as soon as possible.'],
    balanced: ['Balanced', 'No modifiers.'],
    defensive: ['Defensive', 'Less damage taken, slower offense; heals earlier.'],
    escape: ['Escape', 'Crew dodge more and focus on staying alive.']
  }, '.name', '.desc');
  pair('priority.', {
    auto: ['Automatic', 'Each crew member picks the best skill for the moment.'],
    survival: ['Survival', 'Prefer shields, taunts, and heals.'],
    control: ['Control', 'Prefer stuns and slows; interrupt wind-ups.'],
    damage: ['Damage', 'Prefer damage skills.'],
    support: ['Support', 'Prefer buffs and healing.']
  }, '.name', '.desc');
  pair('track.', {
    market: ['Market', 'Goods for sale and better prices.'], tavern: ['Tavern', 'More and stronger recruits.'],
    workshop: ['Workshop', 'Crafting, reinforcement, and hull work.'], quest_board: ['Quest board', 'Side quests and contracts.'],
    navigation: ['Navigation office', 'Forecasts, charted routes, and maps.']
  }, '.name', '.desc');
  Object.assign(S, {
    'track.market.l1': 'Supplies, pet ingredients, and basic gear', 'track.market.l2': 'Local specialty and the regional equipment shop', 'track.market.l3': 'Pet eggs, a regional accessory, 10% off, better sale prices',
    'track.tavern.l1': 'Three recruits from eight classes', 'track.tavern.l2': 'Four recruits, every class and origin, aptitudes shown', 'track.tavern.l3': 'Five recruits of higher level',
    'track.workshop.l1': 'Craft known recipes', 'track.workshop.l2': 'Reinforce gear, add affixes, upgrade hulls', 'track.workshop.l3': 'Master smiths: crafting and reinforcing cost 25% less',
    'track.quest_board.l1': 'Side quests', 'track.quest_board.l2': 'Rotating contracts', 'track.quest_board.l3': 'Reveals this sea\'s secret place',
    'track.navigation.l1': 'Exact sea forecasts and hazards for this sea', 'track.navigation.l2': 'Charts the route between this sea\'s ports', 'track.navigation.l3': 'Reveals every non-secret location in this sea'
  });

  // ----------------------------------------------------------- modifiers etc.
  put('mod.', {
    defPct: 'DEF +{pct}', intercept: '{pct} chance to take hits for allies', hpPct: 'Max HP +{pct}', thorns: 'Reflects {pct} of melee damage',
    crit: 'Crit chance +{pct}', spd: 'SPD +{n}', dodge: 'Dodge +{pct}', bossDmg: '+{pct} damage to bosses', defIgnore: 'Ignores {pct} of DEF',
    markedDmg: '+{pct} damage to marked foes', atkPct: 'ATK +{pct}', cdr: 'Skill cooldowns −{pct}', controlPct: 'Control effects +{pct}',
    healPct: 'Healing +{pct}', auraRegen: 'Team regenerates HP each second', foodSave: 'Saves {n} food per departure', supplyPct: 'Supplies restore +{pct} stamina',
    xpPct: 'XP +{pct}', avoid: 'Sea events −{pct}', lootPct: 'Battle loot +{pct}', auraDodge: 'Team dodge +{pct}', jobPct: 'Ship job efficiency +{pct}',
    teamShield: 'Team starts battles with a {pct} max-HP shield', petPct: 'Pet power +{pct}', hazardResist: 'Immune to regional hazards',
    goldPct: 'Battle gold +{pct}', auraAtk: 'Team ATK +{pct}', masteryPct: 'Class mastery +{pct}', firstAid: 'Once per battle, heals {pct} max HP when low',
    quickStart: 'Starts battles with {n} skill meter', focusDmg: '+{pct} damage to the focus target', stunImmune: 'Immune to stuns',
    lifesteal: 'Lifesteal {pct}', escape: 'Retreats take half as long'
  });
  put('fx.', {
    stun: 'stun {secs}s', taunt: 'taunt {secs}s', shield: 'shield {pct} max HP', slow: 'slow {secs}s', evade: 'evade {secs}s',
    boss: '+{pct} vs bosses', mark: 'mark {secs}s', pierce: 'ignores {pct} DEF', reachAll: 'reaches any lane', snipe: 'snipes the weakest foe',
    execute: 'bonus damage to wounded foes', sunder: 'sunders armor', cleanse: 'removes debuffs', regen: 'regenerate {pct} max HP/s for {dur}s',
    buffAtk: 'ATK +{pct} for {dur}s', buffDef: 'DEF +{pct} for {dur}s', meter: 'skill meter +{n}', trap: 'sets a trap ({pct} ATK, stun {stun}s)',
    dot: 'burn {pct} ATK/s for {dur}s', pet: 'companion pet strikes (×{n})', dispel: 'strips enemy shields and buffs', cleanseAllies: 'cleanses all allies',
    plunder: 'plunders extra gold', windup: '{secs}s wind-up, can be interrupted'
  });
  put('prop.', {
    guard: 'Guard: may intercept hits for allies', reach: 'Reach: strikes past the front line', ranged: 'Ranged: attacks any lane',
    double: 'Double strike: two hits at 60%', mend: 'Mend: basic attacks heal wounded allies', nourish: 'Nourish: attacks also heal the weakest ally',
    splash: 'Splash: hits others in the same lane', sunder: 'Sunder: attacks wear down armor', pet: 'Pet bond: companion acts faster and hits harder',
    aura: 'Aura: raises team ATK', chill: 'Chill: attacks slow the target', pierce: 'Pierce: ignores 25% DEF', crit: 'Keen: +10% crit chance',
    lifesteal: 'Lifesteal: heals 15% of damage dealt'
  });

  // ------------------------------------------------------------ hulls/facil.
  pair('hull.', {
    starter: ['Driftling Sloop', 'A small single-deck sloop with just enough room for the essentials.'],
    voyager: ['Voyager Brig', 'Adds a second deck behind a bulkhead door, with room for production and training.'],
    adventurer: ['Adventurer Frigate', 'A long hull built for the stormy middle seas.'],
    legend: ['Legend Galleon', 'A four-deck flagship worthy of the strongest captain.']
  }, '.name', '.desc');
  put('faccat.', { command: 'Command', living: 'Living', training: 'Training', medical: 'Medical', production: 'Production', navigation: 'Navigation', storage: 'Storage', pet: 'Pets', social: 'Social', defense: 'Defense' });
  pair('fac.', {
    captains_cabin: ['Captain\'s Cabin', 'Required. Command center; upgrades raise max stamina.'],
    chart_table: ['Chart Table', 'Exact sea forecasts, known hazards, and fewer pirates.'],
    muster_deck: ['Muster Deck', 'Crew start every battle with extra skill meter.'],
    crew_quarters: ['Crew Quarters', 'Required. Berths for the crew.'],
    mess_hall: ['Mess Hall', 'Rations restore more stamina and voyages use less food.'],
    practice_deck: ['Practice Deck', 'Crew outside the formation still gain XP.'],
    class_hall: ['Class Hall', 'Faster class mastery.'],
    infirmary: ['Infirmary', 'Treat injuries at sea and limit injuries from defeats.'],
    recovery_room: ['Recovery Room', 'Free treatments at port each day.'],
    galley: ['Galley', 'Cook food from gold, even at sea.'],
    workshop: ['Workshop', 'Craft gear and make supplies from materials.'],
    material_bench: ['Material Bench', 'More materials from battles and salvage.'],
    lookout: ['Lookout', 'Reveals neighboring locations on arrival.'],
    compass_room: ['Compass Room', 'Cheaper voyages between seas and known hazards.'],
    tide_archive: ['Tide Archive', 'More XP for the whole crew.'],
    pantry: ['Pantry', 'Required. Food storage.'],
    cargo_hold: ['Cargo Hold', 'More room for supplies and equipment.'],
    secure_locker: ['Secure Locker', 'Extra equipment storage.'],
    hatchery: ['Hatchery', 'Hatch pet eggs and store more of them.'],
    pet_lab: ['Pet Lab', 'Evolve pets and keep more of them.'],
    creature_pens: ['Creature Pens', 'Room for many more pets.'],
    tavern_corner: ['Tavern Corner', 'One more recruit in every tavern and cheaper hiring.'],
    story_deck: ['Story Deck', 'Personal stories reward more XP.'],
    music_room: ['Music Room', 'More XP for the whole crew.'],
    boarding_gate: ['Boarding Gate', 'Crew start boarding battles with a large skill meter.'],
    barricade_room: ['Barricade Room', 'Less damage in boarding battles; protects against squalls.'],
    guard_post: ['Guard Post', 'Front-line crew start boarding battles shielded.']
  }, '.name', '.desc');

  // ------------------------------------------------------------- classes etc.
  pair('class.', {
    guard: ['Guard', 'Front-line protector with shields and taunts.'],
    duelist: ['Duelist', 'Fast blade fighter who punishes single targets.'],
    spearfighter: ['Spearfighter', 'Reach fighter who strikes past the front line.'],
    gunner: ['Gunner', 'Ranged damage from the back line.'],
    brawler: ['Brawler', 'Close-range bruiser who breaks armor.'],
    medic: ['Medic', 'Keeps the crew alive with heals and cleansing.'],
    cook: ['Cook', 'Feeds the crew in battle and saves food at sea.'],
    navigator: ['Navigator', 'Reads the sea: marks targets and avoids trouble.'],
    tinkerer: ['Tinkerer', 'Barriers, traps, and gadgets.'],
    beastkeeper: ['Beastkeeper', 'Fights alongside companion pets.'],
    mystic: ['Mystic', 'Elemental caster with area attacks.'],
    quartermaster: ['Quartermaster', 'Banners, buffs, and better loot.'],
    guardian: ['Guardian', 'Guard branch: unbreakable wall for the whole line.'],
    bulwark: ['Bulwark', 'Guard branch: heavy armor that slams back.'],
    blade_dancer: ['Blade Dancer', 'Duelist branch: whirling strikes across a lane.'],
    challenger: ['Challenger', 'Duelist branch: calls out and topples bosses.'],
    harpooner: ['Harpooner', 'Spearfighter branch: drags foes into reach.'],
    dragoon: ['Dragoon', 'Spearfighter branch: leaping strikes from above.'],
    sharpshooter: ['Sharpshooter', 'Gunner branch: precise shots at weak points.'],
    skirmisher: ['Skirmisher', 'Gunner branch: volleys that cover every lane.'],
    breaker: ['Breaker', 'Brawler branch: shatters armor and shields.'],
    grappler: ['Grappler', 'Brawler branch: holds and throws.'],
    surgeon: ['Surgeon', 'Medic branch: powerful emergency healing.'],
    lifekeeper: ['Lifekeeper', 'Medic branch: steady regeneration for all.'],
    provisioner: ['Provisioner', 'Cook branch: supplies and stamina at sea.'],
    feastmaster: ['Feastmaster', 'Cook branch: grand feasts that lift the crew.'],
    pathfinder: ['Pathfinder', 'Navigator branch: shortcuts and ambushes.'],
    tide_reader: ['Tide Reader', 'Navigator branch: turns the tide of battle.'],
    engineer: ['Engineer', 'Tinkerer branch: turrets and plating.'],
    trapper: ['Trapper', 'Tinkerer branch: nets and snares.'],
    beastwarden: ['Beastwarden', 'Beastkeeper branch: pets that guard the pack.'],
    wildspeaker: ['Wildspeaker', 'Beastkeeper branch: unleashes the wild.'],
    stormcaller: ['Stormcaller', 'Mystic branch: chain lightning.'],
    hexbreaker: ['Hexbreaker', 'Mystic branch: dispels and wards.'],
    purser: ['Purser', 'Quartermaster branch: more gold from every fight.'],
    standard_bearer: ['Standard Bearer', 'Quartermaster branch: holds the colors high.']
  }, '.name', '.desc');
  put('skill.', {
    shield_bash: 'Shield Bash', hold_the_line: 'Hold the Line', guardian_wall: 'Guardian Wall', quake_slam: 'Quake Slam', lunge: 'Lunge', riposte: 'Riposte',
    whirling_blades: 'Whirling Blades', call_out: 'Call Out', piercing_thrust: 'Piercing Thrust', sweep_spear: 'Spear Sweep', harpoon_pull: 'Harpoon Pull',
    sky_dive: 'Sky Dive', aimed_shot: 'Aimed Shot', smoke_shell: 'Smoke Shell', headshot: 'Headshot', scatter_volley: 'Scatter Volley', haymaker: 'Haymaker',
    brawl: 'Brawl', armor_crush: 'Armor Crush', suplex: 'Suplex', first_aid: 'First Aid', cleanse: 'Cleanse', emergency_surgery: 'Emergency Surgery',
    renewal: 'Renewal', hearty_snack: 'Hearty Snack', spice_bomb: 'Spice Bomb', supply_drop: 'Supply Drop', grand_feast: 'Grand Feast', mark_target: 'Mark Target',
    quick_read: 'Quick Read', shortcut_strike: 'Shortcut Strike', ebb_tide: 'Ebb Tide', deploy_barrier: 'Deploy Barrier', spring_trap: 'Spring Trap',
    turret: 'Turret', snare_net: 'Snare Net', sic_em: 'Sic \'Em', soothing_call: 'Soothing Call', pack_guard: 'Pack Guard', call_of_wild: 'Call of the Wild',
    frost_bolt: 'Frost Bolt', arc_burst: 'Arc Burst', chain_lightning: 'Chain Lightning', dispel_hex: 'Dispel Hex', rally_banner: 'Rally Banner', brace: 'Brace',
    tribute: 'Tribute', hold_colors: 'Hold the Colors', e_slash: 'Slash', e_crush: 'Crush', e_volley: 'Volley', e_hex: 'Hex', e_mend: 'Mend',
    e_roar: 'Roar', e_charge: 'Charge', e_shell: 'Shell Up', e_stun_all: 'Shockwave'
  }, '.name');
  put('passive.', {
    steadfast: 'Steadfast', sentinel: 'Sentinel', iron_hide: 'Iron Hide', keen_edge: 'Keen Edge', flowing_step: 'Flowing Step', giant_slayer: 'Giant Slayer',
    armor_breaker: 'Armor Breaker', tidebreaker: 'Tidebreaker', momentum: 'Momentum', steady_aim: 'Steady Aim', eagle_eye: 'Eagle Eye', quick_reload: 'Quick Reload',
    thick_skin: 'Thick Skin', shatter: 'Shatter', iron_grip: 'Iron Grip', bedside_manner: 'Bedside Manner', precise_hands: 'Precise Hands', life_ward: 'Life Ward',
    thrifty_kitchen: 'Thrifty Kitchen', ration_master: 'Ration Master', comfort_food: 'Comfort Food', weather_eye: 'Weather Eye', trailblazer: 'Trailblazer',
    foresight: 'Foresight', handy: 'Handy', reinforced_plating: 'Reinforced Plating', hidden_blades: 'Hidden Blades', beast_bond: 'Beast Bond',
    alpha_bond: 'Alpha Bond', wild_heart: 'Wild Heart', attunement: 'Attunement', static_field: 'Static Field', warding: 'Warding',
    ledger_keeper: 'Ledger Keeper', deep_pockets: 'Deep Pockets', inspiring_presence: 'Inspiring Presence'
  }, '.name');

  // --------------------------------------------------------- crew identity
  put('origin.', {
    dawnwater_fishers: 'Dawnwater fisher folk', ember_forges: 'Ember forge clans', verdant_villages: 'Verdant villages', glass_reefs: 'Glass reef divers',
    crown_courts: 'Crown court families', storm_harbors: 'Storm harbor crews', moon_isles: 'Moon isle dreamers', trench_divers: 'Trench salvagers',
    ring_nomads: 'Ring nomads', horizon_wanderers: 'Horizon wanderers'
  });
  put('trait.', { brave: 'Brave', cautious: 'Cautious', cheerful: 'Cheerful', stubborn: 'Stubborn', curious: 'Curious', loyal: 'Loyal', thrifty: 'Thrifty', calm: 'Calm', reckless: 'Reckless', kind: 'Kind', proud: 'Proud', sleepy: 'Sleepy' });
  put('apt.', { quick_learner: 'Quick Learner', devoted: 'Devoted', deckhand: 'Deckhand', brawny: 'Brawny', sharp: 'Sharp', nimble: 'Nimble', tough: 'Tough', beast_friend: 'Beast Friend' }, '.name');
  pair('event.', {
    homesick: ['Homesick', 'Dock at a port in their home waters ({origin}) after time away.'],
    proving: ['Proving Ground', 'Win battles with them in the formation ({n}/5).'],
    feast: ['A Proper Feast', 'Serve rations to the crew ({n}/5).'],
    collector: ['Keepsake', 'Deliver one specialty from their home waters ({origin}) at any port.']
  }, '.title', '.desc');

  // ------------------------------------------------------------- equipment
  put('wtype.', { blade: 'Blade', shield: 'Shield', spear: 'Spear', gun: 'Gun', fist: 'Knuckles', kit: 'Med Kit', ladle: 'Ladle', staff: 'Staff', tool: 'Tool', whip: 'Whip', banner: 'Banner' });
  put('otype.', { coat: 'Coat', armor: 'Armor' });
  put('itemtier.', { 1: 'Driftwood', 2: 'Harbor', 3: 'Emberforged', 4: 'Verdant', 5: 'Prismatic', 6: 'Crowned', 7: 'Stormbound', 8: 'Moonlit', 9: 'Abyssal', 10: 'Horizon' });
  put('affix.', { sturdy: 'Sturdy', keen: 'Keen', swift: 'Swift', warded: 'Warded', mighty: 'Mighty' }, '.name');
  put('item.', {
    a_lucky_shell: 'Lucky Shell', a_ember_charm: 'Ember Charm', a_vine_band: 'Vine Band', a_prism_lens: 'Prism Lens', a_crown_seal: 'Crown Seal',
    a_storm_anchor: 'Storm Anchor', a_moon_lantern: 'Moon Lantern', a_abyss_ring: 'Abyss Ring', a_scale_talisman: 'Scale Talisman', a_horizon_compass: 'Horizon Compass',
    a_escape_rope: 'Escape Rope', a_work_gloves: 'Work Gloves',
    u_gullfeather_saber: 'Gullfeather Saber', u_mira_spyglass: 'Mira\'s Spyglass', u_cinder_maul: 'Cinder Maul', u_flint_heartstone: 'Flint\'s Heartstone',
    u_fernwhip: 'Fernwhip', u_rook_mask: 'Rook\'s Mask', u_prism_rifle: 'Prism Rifle', u_selene_mirror: 'Selene\'s Mirror', u_crest_rapier: 'Crest Rapier',
    u_cassian_signet: 'Cassian\'s Signet', u_gale_harpoon: 'Gale Harpoon', u_nessa_stormcloak: 'Nessa\'s Stormcloak', u_lantern_staff: 'Lantern Staff',
    u_orin_charm: 'Orin\'s Charm', u_abyss_cleaver: 'Abyss Cleaver', u_vale_ring: 'Vale\'s Ring', u_leviathan_tooth: 'Leviathan Tooth',
    u_brakka_shell: 'Brakka\'s Shell', u_dawnbreaker: 'Dawnbreaker', u_aurelia_crown: 'Aurelia\'s Crown', u_storm_crown: 'Storm Crown',
    u_moonveil: 'Moonveil', u_trench_seal: 'Trench Seal', u_ringbreaker: 'Ringbreaker', u_horizon_star: 'Horizon Star'
  }, '.name');

  // ------------------------------------------------------------------ goods
  put('spec.', {
    saltleaf_grain: 'Saltleaf Grain', ember_ore: 'Ember Ore', verdant_resin: 'Verdant Resin', prism_quartz: 'Prism Quartz', crown_silk: 'Crown Silk',
    stormwood: 'Stormwood', moon_ink: 'Moon Ink', abyss_alloy: 'Abyss Alloy', leviathan_scale: 'Leviathan Scale', horizon_glass: 'Horizon Glass'
  }, '.name');
  put('ing.', { fire_pepper: 'Fire Pepper', sea_pearl: 'Sea Pearl', kelp_sprig: 'Kelp Sprig', sun_honey: 'Sun Honey', dusk_ink: 'Dusk Ink', salt_crystal: 'Salt Crystal' }, '.name');

  // ------------------------------------------------------------------- pets
  put('petfam.', {
    tidefin: 'Tidefin', cinderback: 'Cinderback', mossling: 'Mossling', glasswing: 'Glasswing', pearlcub: 'Pearlcub',
    cloudray: 'Cloudray', dreammoth: 'Dreammoth', gloomjaw: 'Gloomjaw', shellwarden: 'Shellwarden', starwake: 'Starwake'
  }, '.name');
  put('petform.', { companion: 'Scrapper', helper: 'Tender', explorer: 'Scout', companion_evo: 'Champion', helper_evo: 'Keeper', explorer_evo: 'Wayfinder' });
  pair('petrole.', {
    companion: ['Companion', 'Fights beside one crew member in battle.'],
    helper: ['Ship helper', 'Works a ship facility, boosting it.'],
    explorer: ['Explorer', 'Scouts new places and finds secrets.']
  }, '', '.desc');
  put('petability.', { splash: 'Splash', burn: 'Ember Breath', mend: 'Mend', mark: 'Spotlight', shell: 'Shell Guard', gust: 'Gust', lull: 'Lullaby', maul: 'Maul', ward: 'Ward', radiance: 'Radiance' });

  // ------------------------------------------------------------- the world
  const REGIONS = {
    dawnwater: ['Dawnwater Shallows', 'Warm, calm waters where new captains learn the ropes.', 'The Gull\'s Wager', [
      'Gull raiders have taken Gull Rock. Clear them out and the harbor will take you seriously.',
      'Word of your win reaches Saltmarsh Landing. Sail there and meet the dockmasters.',
      'Something stirs in the Brine Cellars beneath the old lookout. Clear the cellars.',
      'Brightquay needs Saltleaf Grain to restock after the raids. Bring it home.',
      'Captain Mira Gull waits at the Trial Ring. Win her wager and the next sea opens.']],
    emberreach: ['Emberreach', 'Volcanic isles of forges and smoke, where decks catch fire.', 'Fire Beneath the Keel', [
      'Imps swarm Basalt Isle. Clear the island so the forges can breathe.',
      'Ashfall Harbor has gone quiet. Sail there and find out why.',
      'The Forge Depths are erupting with golems. Clear them.',
      'Cinderport needs Ember Ore to relight its great forge.',
      'Flint Cinder holds the Crucible. Beat him in the captain trial.']],
    verdant_maw: ['Verdant Maw', 'A jungle sea of spores and roots that drains the unwary.', 'The Rooted Shrine', [
      'Vine stalkers hold Tanglewood Isle. Clear a path.',
      'Fernwater Post sends a call for help. Answer it.',
      'Roots are choking the Thornroot Caves. Cut them back.',
      'Rootharbor needs Verdant Resin to seal its hulls.',
      'Rook Fern waits in the Verdant Arena. Prove yourself.']],
    glass_current: ['Glass Current', 'Crystal reefs that dazzle the eye and hide decoys.', 'Mirror, Mirror', [
      'Shard fencers guard Lens Isle. Clear them.',
      'Mirrorbay\'s lights have dimmed. Visit the harbor.',
      'The Refraction Maze bends light and sense. Clear it.',
      'Prismhaven needs Prism Quartz for its lighthouse.',
      'Selene Prism awaits at the Prism Court. Shatter her illusions.']],
    crown_shoals: ['Crown Shoals', 'Rich shoals ruled by old families and their mixed retinues.', 'The Lost Charter', [
      'Cutpurses run Heron Isle. Clear them out.',
      'The Silkmarket guilds want a word. Visit them.',
      'An old family crypt hides the stolen charter. Clear it.',
      'Crownport needs Crown Silk for the charter ceremony.',
      'Cassian Crest challenges you at the Crown Tourney.']],
    stormbelt: ['Stormbelt', 'A band of endless storms where lightning finds every mast.', 'Eye of the Gale', [
      'Squall runners raid Squall Isle. Clear it.',
      'Beacon Rest has lost its light. Sail there.',
      'The Tempest Caverns roar with wind. Clear them.',
      'Gale Harbor needs Stormwood to rebuild its piers.',
      'Nessa Gale waits in the Eye of the Storm.']],
    moonwake: ['Moonwake', 'Silver waters where dreams drift and foes telegraph their blows.', 'The Dreaming Stage', [
      'Night stalkers haunt Echo Atoll. Clear it.',
      'Dusk Mooring\'s sailors have fallen asleep. Visit them.',
      'The Dream Labyrinth shifts with every step. Clear it.',
      'Lanternport needs Moon Ink to rewrite its charts.',
      'Orin Lantern holds the Moonwake Stage. Wake him from his dream.']],
    ashen_trench: ['Ashen Trench', 'Crushing depths over sealed ruins that silence skills.', 'What the Seal Keeps', [
      'Relic thieves pick over Sunken Spires. Clear them.',
      'Relic Dock\'s divers have news. Visit the dock.',
      'The Trench Sanctum hides what the seal keeps. Clear it.',
      'Ashport needs Abyss Alloy to reinforce the seal.',
      'Vale Ash waits at the Ashen Seal. Break through.']],
    leviathan_ring: ['Leviathan Ring', 'A ring of reefs around a sleeping titan; enemies come in waves.', 'Inside the Behemoth', [
      'Ring raiders nest on Bone Reef. Clear them.',
      'The Migration Post tracks the titan. Visit it.',
      'The Coral Colossus has woken. Clear it.',
      'Ringhold needs Leviathan Scale for its sea wall.',
      'Brakka Reef waits in the Ring Arena.']],
    grand_horizon: ['Grand Horizon', 'The last sea, where only elite crews survive.', 'The Strongest Captain', [
      'Gate duelists guard Zenith Cay. Defeat them.',
      'The Conclave Harbor invites you. Answer the summons.',
      'The Compass Vault holds the way to the final trial. Clear it.',
      'Horizon Gate needs Horizon Glass for the final beacon.',
      'Aurelia Dawn, the reigning champion, waits at the Horizon Arena.']]
  };
  for (const [id, [name, desc, title, lines]] of Object.entries(REGIONS)) {
    S['region.' + id + '.name'] = name; S['region.' + id + '.desc'] = desc; S['arc.' + id + '.title'] = title;
    lines.forEach((l, i) => { S['arc.' + id + '.' + i] = l; });
  }
  put('mechanic.', {
    burning: 'Burning decks', disruptor: 'Disruptors', decoys: 'Decoys', mixed: 'Mixed retinues', intent: 'Telegraphed blows',
    sealed: 'Sealed skills', waves: 'Wave assault', elite: 'Elite foes'
  }, '.name');
  put('hazard.', { heat: 'Heat', poison: 'Spores', glare: 'Glare', storm: 'Lightning', dream: 'Dream haze', pressure: 'Pressure', tide: 'Riptide' }, '.name');
  // Pet clues quote one real Prime signature; the Pet Lab then lists all three.
  put('clue.pet.', {
    tidefin: 'Tidefin notes: red, blue, blue hatches a Prime companion. All signatures are now in the Pet Lab.',
    cinderback: 'Cinderback notes: red, red, yellow hatches a Prime companion. All signatures are now in the Pet Lab.',
    mossling: 'Mossling notes: green, green, blue hatches a Prime ship helper. All signatures are now in the Pet Lab.',
    glasswing: 'Glasswing notes: blue, blue, yellow hatches a Prime ship helper. All signatures are now in the Pet Lab.',
    pearlcub: 'Pearlcub notes: white, white, green hatches a Prime explorer. All signatures are now in the Pet Lab.',
    cloudray: 'Cloudray notes: yellow, blue, yellow hatches a Prime companion. All signatures are now in the Pet Lab.',
    dreammoth: 'Dreammoth notes: purple, purple, yellow hatches a Prime explorer. All signatures are now in the Pet Lab.',
    gloomjaw: 'Gloomjaw notes: red, purple, red hatches a Prime companion. All signatures are now in the Pet Lab.',
    shellwarden: 'Shellwarden notes: green, blue, green hatches a Prime ship helper. All signatures are now in the Pet Lab.',
    starwake: 'Starwake notes: white, yellow, purple hatches a Prime explorer. All signatures are now in the Pet Lab.'
  });
  put('room.', {
    landing: 'Landing', grove: 'Grove', ridge: 'Ridge', heart: 'Island Heart', hollow: 'Hidden Hollow', gate: 'Gate', west: 'West Hall', east: 'East Hall',
    depths: 'Depths', guardian: 'Guardian\'s Chamber', vault: 'Secret Vault', hold: 'Cargo Hold', cabin: 'Captain\'s Quarters', sanctum: 'Sanctum', trial: 'Trial Ring'
  }, '.name');
  put('loc.', {
    brightquay: 'Brightquay', saltmarsh_landing: 'Saltmarsh Landing', gull_rock: 'Gull Rock', lantern_isle: 'Lantern Isle', coral_steps: 'Coral Steps',
    old_lookout: 'Old Lookout', brine_cellars: 'Brine Cellars', driftplank_wreck: 'Driftplank Wreck', dawn_trial_ring: 'Dawn Trial Ring', tidefin_grotto: 'Tidefin Grotto',
    cinderport: 'Cinderport', ashfall_harbor: 'Ashfall Harbor', basalt_isle: 'Basalt Isle', smolder_key: 'Smolder Key', obsidian_atoll: 'Obsidian Atoll',
    magma_vents: 'Magma Vents', forge_depths: 'Forge Depths', scorched_galleon: 'Scorched Galleon', ember_crucible: 'Ember Crucible', cinderback_nest: 'Cinderback Nest',
    rootharbor: 'Rootharbor', fernwater_post: 'Fernwater Post', tanglewood_isle: 'Tanglewood Isle', orchid_cay: 'Orchid Cay', maw_shore: 'Maw Shore',
    overgrown_shrine: 'Overgrown Shrine', thornroot_caves: 'Thornroot Caves', vine_wreck: 'Vine-choked Wreck', verdant_arena: 'Verdant Arena', moss_hollow: 'Moss Hollow',
    prismhaven: 'Prismhaven', mirrorbay: 'Mirrorbay', shard_reef: 'Shard Reef', lens_isle: 'Lens Isle', quartz_spire: 'Quartz Spire',
    crystal_vault: 'Crystal Vault', refraction_maze: 'Refraction Maze', glassbound_hulk: 'Glassbound Hulk', prism_court: 'Prism Court', glasswing_lagoon: 'Glasswing Lagoon',
    crownport: 'Crownport', silkmarket: 'Silkmarket', gilded_cay: 'Gilded Cay', heron_isle: 'Heron Isle', regent_bank: 'Regent Bank',
    charter_archive: 'Charter Archive', old_family_crypt: 'Old Family Crypt', treasury_wreck: 'Treasury Wreck', crown_tourney: 'Crown Tourney', pearl_grotto: 'Pearl Grotto',
    gale_harbor: 'Gale Harbor', beacon_rest: 'Beacon Rest', thunder_rock: 'Thunder Rock', squall_isle: 'Squall Isle', lightning_reach: 'Lightning Reach',
    drowned_beacon: 'Drowned Beacon', tempest_caverns: 'Tempest Caverns', stormwrack_hulk: 'Stormwrack Hulk', eye_of_storm: 'Eye of the Storm', cloudray_aerie: 'Cloudray Aerie',
    lanternport: 'Lanternport', dusk_mooring: 'Dusk Mooring', nightbloom_isle: 'Nightbloom Isle', echo_atoll: 'Echo Atoll', starfall_key: 'Starfall Key',
    forgotten_observatory: 'Forgotten Observatory', dream_labyrinth: 'Dream Labyrinth', moonlit_wreck: 'Moonlit Wreck', moonwake_stage: 'Moonwake Stage', dreammoth_glade: 'Dreammoth Glade',
    ashport: 'Ashport', relic_dock: 'Relic Dock', cinder_shelf: 'Cinder Shelf', sunken_spires: 'Sunken Spires', abyss_ledge: 'Abyss Ledge',
    sealed_ruins: 'Sealed Ruins', trench_sanctum: 'Trench Sanctum', relic_hunter_wreck: 'Relic Hunter\'s Wreck', ashen_seal_arena: 'Ashen Seal Arena', gloomjaw_den: 'Gloomjaw Den',
    ringhold: 'Ringhold', migration_post: 'Migration Post', shell_isle: 'Shell Isle', bone_reef: 'Bone Reef', titan_atoll: 'Titan Atoll',
    leviathan_gut: 'Leviathan\'s Gut', coral_colossus: 'Coral Colossus', behemoth_wreck: 'Behemoth Wreck', ring_arena: 'Ring Arena', shellwarden_shoal: 'Shellwarden Shoal',
    horizon_gate: 'Horizon Gate', conclave_harbor: 'Conclave Harbor', sunrise_isle: 'Sunrise Isle', zenith_cay: 'Zenith Cay', dawnstar_reef: 'Dawnstar Reef',
    ancient_gatehouse: 'Ancient Gatehouse', compass_vault: 'Compass Vault', rival_flagship_wreck: 'Rival Flagship Wreck', horizon_arena: 'Horizon Arena', starwake_haven: 'Starwake Haven'
  }, '.name');
  put('enemy.', {
    gull_raider: 'Gull Raider', reef_crab: 'Reef Crab', spray_gunner: 'Spray Gunner', brine_witch: 'Brine Witch', kelp_tender: 'Kelp Tender',
    lookout_warden: 'Lookout Warden', cellar_king: 'Cellar King',
    cinder_imp: 'Cinder Imp', magma_golem: 'Magma Golem', ash_slinger: 'Ash Slinger', flame_seer: 'Flame Seer', ember_monk: 'Ember Monk',
    vent_tyrant: 'Vent Tyrant', forge_colossus: 'Forge Colossus',
    vine_stalker: 'Vine Stalker', bark_brute: 'Bark Brute', thorn_archer: 'Thorn Archer', spore_shaman: 'Spore Shaman', bloom_nurse: 'Bloom Nurse',
    shrine_tyrant: 'Shrine Tyrant', root_mother: 'Root Mother',
    shard_fencer: 'Shard Fencer', quartz_knight: 'Quartz Knight', prism_sniper: 'Prism Sniper', mirror_mage: 'Mirror Mage', lens_cleric: 'Lens Cleric',
    vault_sentinel: 'Vault Sentinel', refraction_queen: 'Refraction Queen',
    cutpurse: 'Cutpurse', crown_enforcer: 'Crown Enforcer', musket_noble: 'Musket Noble', court_hexer: 'Court Hexer', gilded_medic: 'Gilded Medic',
    archive_keeper: 'Archive Keeper', family_patriarch: 'Family Patriarch',
    squall_runner: 'Squall Runner', thunder_brute: 'Thunder Brute', gale_harpooner: 'Gale Harpooner', storm_witch: 'Storm Witch', beacon_keeper: 'Beacon Keeper',
    drowned_keeper: 'Drowned Keeper', tempest_wyrm: 'Tempest Wyrm',
    night_stalker: 'Night Stalker', dream_ogre: 'Dream Ogre', star_archer: 'Star Archer', moon_oracle: 'Moon Oracle', lull_spirit: 'Lull Spirit',
    observatory_ghost: 'Observatory Ghost', labyrinth_dreamer: 'Labyrinth Dreamer',
    relic_thief: 'Relic Thief', abyss_brute: 'Abyss Brute', trench_gunner: 'Trench Gunner', ash_hexer: 'Ash Hexer', deep_priest: 'Deep Priest',
    seal_guardian: 'Seal Guardian', trench_horror: 'Trench Horror',
    ring_raider: 'Ring Raider', shell_titan: 'Shell Titan', bone_spitter: 'Bone Spitter', tide_shaman: 'Tide Shaman', reef_mender: 'Reef Mender',
    gut_leviathan: 'Gut Leviathan', colossus_core: 'Colossus Core',
    gate_duelist: 'Gate Duelist', horizon_knight: 'Horizon Knight', sky_gunner: 'Sky Gunner', dawn_mage: 'Dawn Mage', conclave_medic: 'Conclave Medic',
    gate_warden: 'Gate Warden', compass_guardian: 'Compass Guardian',
    pennant_deckhand: 'Pennant Deckhand', pennant_bosun: 'Pennant Bosun', pennant_gunner: 'Pennant Gunner', pennant_hexer: 'Pennant Hexer', pennant_surgeon: 'Pennant Surgeon',
    crystal_decoy: 'Crystal Decoy',
    mira_gull: 'Captain Mira Gull', flint_cinder: 'Captain Flint Cinder', rook_fern: 'Captain Rook Fern', selene_prism: 'Captain Selene Prism',
    cassian_crest: 'Captain Cassian Crest', nessa_gale: 'Captain Nessa Gale', orin_lantern: 'Captain Orin Lantern', vale_ash: 'Captain Vale Ash',
    brakka_reef: 'Captain Brakka Reef', aurelia_dawn: 'Captain Aurelia Dawn'
  }, '.name');

  const L = {
    meta: { code: 'en', nativeName: 'English', htmlLang: 'en', numberLocale: 'en-US' },
    names: {
      format: '{given} {family}',
      given: ['Ada', 'Bram', 'Corin', 'Dara', 'Elio', 'Fen', 'Greta', 'Hollis', 'Ivo', 'Juno', 'Kestrel', 'Lio', 'Marlo', 'Nell', 'Oskar', 'Pia',
        'Quill', 'Rhea', 'Soren', 'Tamsin', 'Ulla', 'Vero', 'Wren', 'Xan', 'Yara', 'Zev', 'Bastian', 'Cleo', 'Dorian', 'Esme', 'Arlo', 'Brin'],
      family: ['Brine', 'Saltwick', 'Harrow', 'Kettle', 'Marsh', 'Pike', 'Rowe', 'Tallow', 'Weller', 'Cobb', 'Driftwood', 'Finch', 'Gannet', 'Hook',
        'Larkin', 'Morrow', 'Netley', 'Oakes', 'Quay', 'Reed', 'Stoke', 'Tarr', 'Voss', 'Wick']
    },
    strings: S
  };
  root.P7S = root.P7S || {};
  root.P7S.LOCALES = root.P7S.LOCALES || {};
  root.P7S.LOCALES.en = L;
  if (typeof module !== 'undefined' && module.exports) module.exports = L;
})(typeof globalThis !== 'undefined' ? globalThis : this);
