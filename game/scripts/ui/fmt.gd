## Text formatting shared by the HUD and windows (ported from the
## prototype's view helpers, now returning plain strings).
class_name Fmt
extends RefCounted


static func t(key: String, params: Variant = null) -> String:
	return I18n.t(key, params, Game.state if Game.has_game() else null)


static func loc(id: Variant) -> String:
	if id == null:
		return I18n.t("ui.unknown")
	return I18n.t("loc.%s.name" % id)


static func fac(id: String) -> String:
	return I18n.t("fac.%s.name" % id)


static func signed(v: Variant) -> String:
	var n := float(v)
	return ("+" if n > 0 else "") + I18n.fmt_num(v)


static func clock_text(clock: Variant) -> String:
	var c := int(clock)
	return I18n.t("hud.daytime", {"day": c / 24 + 1, "hour": "%02d" % (c % 24)})


static func can_afford(state: Dictionary, cost: Variant) -> bool:
	if cost == null:
		return true
	var inv: Dictionary = state.inventory
	for k in ["gold", "materials", "food", "supplies"]:
		if int(cost.get(k, 0)) > 0 and int(inv[k]) < int(cost[k]):
			return false
	if int(cost.get("stamina", 0)) > 0 and int(state.ship.stamina) < int(cost.stamina):
		return false
	var sp = cost.get("specialty")
	if sp is Array and int(inv.specialties.get(sp[0], 0)) < int(sp[1]):
		return false
	return true


static func mod_lines(mods: Variant) -> Array:
	var out := []
	if not (mods is Dictionary):
		return out
	for k in mods:
		var v = mods[k]
		if not v:
			continue
		var key := "mod." + String(k)
		if not I18n.has(key):
			continue
		out.append(I18n.t(key, {"pct": I18n.pct(float(v)), "n": I18n.fmt_num(v), "s": I18n.fmt_num(v)}))
	return out


static func fx_lines(fx: Variant) -> Array:
	var out := []
	if not (fx is Dictionary):
		return out
	for k in fx:
		var ks := String(k)
		if ks.ends_with("Dur") or ks.ends_with("Stun"):
			continue
		var key := "fx." + ks
		if not I18n.has(key):
			continue
		var v = fx[k]
		var dur = fx.get(ks + "Dur", fx.get("buffDur", fx.get("regenDur", fx.get("dotDur", 0))))
		var num: float = float(v) if (v is int or v is float) else 0.0
		out.append(I18n.t(key, {"n": I18n.fmt_num(num), "pct": I18n.pct(num), "secs": I18n.fmt_num(num), "dur": I18n.fmt_num(dur),
			"stun": I18n.fmt_num(fx.get("trapStun", 1))}))
	return out


static func skill_text(id: String) -> String:
	var sk = C.SKILLS.get(id)
	if sk == null:
		return ""
	var parts := [I18n.t("cat." + sk.cat), I18n.t("scope." + sk.scope)]
	if sk.get("power"):
		parts.append(I18n.t("skill.power", {"pct": I18n.pct(float(sk.power))}))
	if sk.get("heal"):
		parts.append(I18n.t("skill.heal", {"pct": I18n.pct(float(sk.heal))}))
	parts.append_array(fx_lines(sk.get("fx")))
	if sk.get("cond"):
		parts.append(I18n.t("skill.cond_" + sk.cond))
	parts.append(I18n.t("skill.cd", {"n": I18n.fmt_num(sk.cd)}))
	return " · ".join(parts)


static func passive_text(id: String) -> String:
	return " · ".join(mod_lines(C.PASSIVES.get(id)))


static func stats_line(s: Dictionary) -> String:
	var parts := []
	for k in ["hp", "atk", "def", "spd"]:
		if s.get(k, 0):
			parts.append(I18n.t("stat.%s_short" % k) + " " + signed(s[k]))
	return "  ".join(parts)


static func item_lines(item_id: String, inst: Variant = null) -> Array:
	var it = C.ITEMS.get(item_id)
	var lines := []
	if it == null:
		return lines
	var st: Dictionary = it.get("stats", {}).duplicate()
	if inst != null and int(inst.get("reinforce", 0)) > 0:
		for k in ["atk", "def", "hp"]:
			if st.get(k, 0):
				st[k] = U.jround(float(st[k]) * (1.0 + 0.1 * int(inst.reinforce)))
	var sl := stats_line(st)
	if sl != "":
		lines.append(sl)
	var props: Array = it.get("props", []).duplicate()
	if it.get("wtype"):
		for p in C.data.WEAPON_TYPES[it.wtype].props:
			if not props.has(p):
				props.push_front(p)
	for p in props:
		lines.append(I18n.t("prop." + p))
	lines.append_array(mod_lines(it.get("mods")))
	for r in it.get("resist", []):
		lines.append(I18n.t("item.resist", {"hazard": "hazard.%s.name" % r}))
	if inst != null and inst.get("affix"):
		lines.append_array(mod_lines(C.data.AFFIXES.get(inst.affix)))
	return lines


static func item_tags(item_id: String) -> String:
	var it = C.ITEMS.get(item_id)
	if it == null:
		return ""
	var parts := [I18n.t("slot." + it.slot)]
	if it.get("wtype"):
		parts.append(I18n.t("wtype." + it.wtype))
	if it.get("tier"):
		parts.append(I18n.t("ui.tier", {"n": it.tier}))
	return " · ".join(parts)


static func item_icon(item_id: String) -> String:
	var it = C.ITEMS.get(item_id)
	if it == null:
		return "ui_chest"
	if it.get("wtype"):
		return "w_" + it.wtype
	return "w_outfit" if it.slot == "outfit" else "w_accessory"


static func contract_text(c: Dictionary) -> String:
	match String(c.type):
		"hunt":
			return t("contract.hunt", {"region": "region.%s.name" % c.regionId, "have": int(c.get("progress", 0)), "need": c.need, "port": "loc.%s.name" % c.portId})
		"supply":
			return t("contract.supply", {"need": c.need, "port": "loc.%s.name" % c.portId})
	return t("contract.haul", {"need": c.need, "item": "spec.%s.name" % c.specialtyId, "port": "loc.%s.name" % c.portId})


static func where_text(s: Dictionary) -> String:
	var lid: String = s.world.currentLocationId
	var lk := "loc.%s.name" % lid
	if s.encounter != null:
		return I18n.t("where.battle", {"location": lk})
	if s.voyage != null and s.voyage.event != null:
		return I18n.t("where.at_sea", {"location": "loc.%s.name" % s.voyage.route.to})
	if s.voyage != null and s.voyage.site != null:
		return I18n.t("where.site", {"location": lk})
	if Rules.at_port(s):
		return I18n.t("where.port", {"location": lk})
	return I18n.t("where.location", {"location": lk})


## Current main objective as {title, line, target, trial, done}.
static func objective(s: Dictionary) -> Dictionary:
	var ms := Rules.main_status(s)
	if ms.done:
		return {"done": true, "title": I18n.t(s.captain.titleKey), "line": I18n.t("obj.postgame"),
			"compact": I18n.t(s.captain.titleKey) + " · " + I18n.t("obj.postgame"),
			"target": I18n.t("obj.legends", {"n": s.captain.legendsWon.size(), "total": C.world.LEGENDS.size()}), "trial": "", "locationId": null}
	var q: Dictionary = ms.quest
	var reg: Dictionary = C.region(ms.regionId)
	var known := Rules.is_known(s, q.locationId)
	var target := I18n.t("obj.target", {"location": "loc.%s.name" % q.locationId}) if known else I18n.t("obj.target_hidden")
	if q.type == "deliver":
		target += " · " + I18n.t("obj.have", {"have": int(s.inventory.specialties.get(q.itemId, 0)), "need": q.count})
	var trial_state := "won" if ms.trialWon else ("open" if int(ms.step) >= 4 else "locked")
	var trial := I18n.t("obj.trial_" + trial_state, {"location": "loc.%s.name" % ms.trialLocationId, "rival": "enemy.%s.name" % reg.rivalId})
	var title := I18n.t(q.titleKey)
	var repeats_place: bool = known and q.type != "deliver" and title.contains(loc(q.locationId))
	var compact := title if repeats_place else title + " · " + target
	return {"done": false, "region": I18n.t("region.%s.name" % reg.id), "step": I18n.t("obj.step", {"n": int(ms.step) + 1, "total": C.world.MAIN_TEMPLATE.size()}),
		"arc": I18n.t("arc.%s.title" % reg.id), "title": title, "compact": compact, "why": I18n.t("arc.%s.%d" % [reg.id, int(ms.step)]),
		"target": target, "trial": trial, "locationId": q.locationId if known else null}


static func crew_sub(s: Dictionary, m: Dictionary) -> String:
	return I18n.t("class.%s.name" % m.classId) + " · " + I18n.t("ui.lv", {"n": m.level})


static func pet_assign_text(s: Dictionary, p: Dictionary) -> String:
	var a = p.get("assignment")
	if a == null:
		return I18n.t("pets.unassigned")
	match String(a.kind):
		"companion":
			var m = Rules.member(s, a.target)
			return I18n.t("pets.with", {"name": I18n.crew_name(m) if m else "—"})
		"helper":
			for f in s.ship.facilities:
				if f.uid == a.target:
					return I18n.t("pets.at", {"facility": "fac.%s.name" % f.id})
			return I18n.t("pets.at", {"facility": "—"})
	return I18n.t("petrole.explorer")


static func input_label(inp: String) -> String:
	var parts := inp.split(":")
	return I18n.t(("ing." if parts[0] == "ing" else "spec.") + parts[1] + ".name")


static func color_of(tag: String) -> Color:
	match tag:
		"red":
			return Color("d8483e")
		"blue":
			return Color("3f7fd8")
		"green":
			return Color("5aa84a")
		"yellow":
			return Color("e8c040")
		"purple":
			return Color("9a5ad0")
		"white":
			return Color("e8e4dc")
	return Color("888888")


## Reward lines for room/sea rewards dictionaries.
static func reward_lines(got: Variant) -> Array:
	var out := []
	if not (got is Dictionary):
		return out
	if int(got.get("gold", 0)) > 0:
		out.append(["gold", I18n.t("battle.r_gold", {"n": got.gold})])
	if int(got.get("materials", 0)) > 0:
		out.append(["materials", I18n.t("battle.r_materials", {"n": got.materials})])
	if int(got.get("food", 0)) > 0:
		out.append(["food", I18n.t("battle.r_food", {"n": got.food})])
	if int(got.get("supplies", 0)) > 0:
		out.append(["supplies", I18n.t("battle.r_supplies", {"n": got.supplies})])
	if int(got.get("xp", 0)) > 0:
		out.append(["xp", I18n.t("battle.r_xp", {"n": got.xp})])
	var sp = got.get("specialty")
	if sp is Array and sp.size() >= 2:
		out.append(["sp_" + String(sp[0]), I18n.t("battle.r_specialty", {"n": sp[1], "item": "spec.%s.name" % sp[0]})])
	var ings = got.get("ingredients")
	if ings is Array and ings.size():
		var names := []
		for i in ings:
			names.append(I18n.t("ing.%s.name" % (i[0] if i is Array else i)))
		out.append(["ing_" + String(ings[0][0] if ings[0] is Array else ings[0]), I18n.t("battle.r_ingredients", {"list": ", ".join(names)})])
	var items = got.get("items")
	if items is Array:
		for it in items:
			var iid: String = it if it is String else String(it.get("itemId", ""))
			out.append([item_icon(iid), I18n.t("battle.r_item", {"item": I18n.item_name(iid)})])
	var egg = got.get("egg")
	if egg != null:
		var fam: String = egg if egg is String else String(egg.get("familyId", egg.get("family", "")))
		out.append(["ui_egg", I18n.t("battle.r_egg", {"family": "petfam.%s.name" % fam, "n": int(egg.get("grade", 1)) if egg is Dictionary else 1})])
	var clue = got.get("clue")
	if clue != null and String(clue) != "":
		out.append(["ui_quest", I18n.t("battle.r_clue", {"clue": clue})])
	return out


# ------------------------------------------------------------ attributes
## Order in which attribute effects are listed.
const ATTR_FX_ORDER := ["atkPct", "hpPct", "defPct", "spd", "dodge", "crit", "controlPct", "healPct", "cdr", "jobPct"]


static func signed_pct1(x: float) -> String:
	var n := U.round1(absf(x) * 100.0)
	if n == 0.0:
		return "0%"
	return ("+" if x > 0.0 else "−") + I18n.fmt_num(n) + "%"


static func signed_dec(x: float) -> String:
	var n := U.round2(absf(x))
	if n == 0.0:
		return "0"
	return ("+" if x > 0.0 else "−") + I18n.fmt_num(n)


## One attribute modifier as [text, helps]. Cooldown reduction reads as a
## shorter cooldown ("Skill cooldowns −1.2%").
static func attr_fx(k: String, v: float) -> Array:
	var shown := -v if k == "cdr" else v
	var txt := signed_dec(shown) if k == "spd" else signed_pct1(shown)
	return [I18n.t("attrfx." + k, {"v": txt}), v > 0.0]


## Effect lines for a merged attribute modifier map, in display order.
static func attr_fx_lines(mods: Dictionary) -> Array:
	var out := []
	for k in ATTR_FX_ORDER:
		var v := float(mods.get(k, 0.0))
		if absf(v) >= 0.0005:
			out.append(attr_fx(k, v))
	return out


## Per-point description of one attribute ("ATK +1.2%, ...").
static func attr_per_point(id: String) -> String:
	var parts := []
	var fx: Dictionary = Attrs.EFFECTS.get(id, {})
	for k in ATTR_FX_ORDER:
		if fx.has(k):
			var line: String = attr_fx(k, float(fx[k]))[0]
			if Attrs.ABOVE_ONLY.has(k):
				line += " " + I18n.t("attrfx.dodge_above")
			parts.append(line)
	return ", ".join(parts)


static func attr_name(id: String) -> String:
	return I18n.t("attr.%s.name" % id)


## Trait shift as "Vigor +2, Agility −1".
static func shift_text(sh: Dictionary) -> String:
	var parts := []
	for a in Attrs.IDS:
		var n := int(sh.get(a, 0))
		if n != 0:
			parts.append(attr_name(a) + " " + ("+" if n > 0 else "−") + str(absi(n)))
	return ", ".join(parts)


## Tooltip for one attribute of one sailor.
static func attr_tip(m: Dictionary, id: String) -> String:
	var b := Attrs.breakdown(m, id)
	var lines := [attr_name(id) + "  " + str(b.total) + "  ·  " + I18n.t("attr.band." + Attrs.band(int(b.total))),
		I18n.t("attr.%s.desc" % id),
		I18n.t("attr.breakdown", {"base": b.base, "traits": signed_int(int(b.traits)), "train": signed_int(int(b.train))})]
	var fx := Attrs.effect_of(id, int(b.total))
	var now := []
	for e in attr_fx_lines(fx):
		now.append(e[0])
	if now.size():
		lines.append(", ".join(now))
	lines.append(I18n.t("attr.per_point") + " " + attr_per_point(id))
	if Attrs.class_keys(String(m.get("classId", ""))).has(id):
		lines.append(I18n.t("attr.key_for", {"cls": "class.%s.name" % m.classId}))
	return "\n".join(lines)


static func signed_int(n: int) -> String:
	return ("+" if n > 0 else ("−" if n < 0 else "")) + str(absi(n))


## Label variation for an attribute value band.
static func attr_variation(v: int) -> String:
	match Attrs.band(v):
		"poor":
			return "BadLabel"
		"good":
			return "GoodLabel"
		"great", "heroic":
			return "GoldLabel"
	return ""
