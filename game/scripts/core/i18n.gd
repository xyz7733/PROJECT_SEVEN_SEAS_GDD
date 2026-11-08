## Autoload "I18n": display text for locale-independent keys.
##
## Game state stores only stable IDs, string keys and parameters. Strings
## live in res://i18n/strings.csv, which Godot imports into Translation
## resources registered with the TranslationServer. Parameter values that
## are themselves keys are translated recursively, numbers are formatted, and
## a few families of names (set equipment, pet species, main-quest steps) are
## composed from smaller translated parts so both languages share one shape.
extends Node

const SUPPORTED := ["en", "zh_CN"]
const DEFAULT := "en"

var names: Dictionary = {}
var missing: Dictionary = {}
var _re_param := RegEx.new()
var _re_item := RegEx.new()
var _re_species := RegEx.new()
var _re_main := RegEx.new()
var _re_key := RegEx.new()


func _init() -> void:
	_re_param.compile("\\{([a-zA-Z0-9_]+)\\}")
	_re_item.compile("^item\\.(w|o)_([a-z]+)\\.t(\\d+)$")
	_re_species.compile("^pet\\.([a-z]+)_(companion|helper|explorer)(_evo)?\\.name$")
	_re_main.compile("^quest\\.([a-z_]+)\\.(\\d)$")
	_re_key.compile("^[a-z][a-zA-Z0-9_]*\\.[a-zA-Z0-9_.]+$")
	names = U.load_json("res://i18n/names.json")


func set_locale(code: String) -> String:
	var c := code if SUPPORTED.has(code) else DEFAULT
	TranslationServer.set_locale(c)
	return c


func locale() -> String:
	var l := TranslationServer.get_locale()
	return "zh_CN" if l.begins_with("zh") else "en"


## The language's own name, read from that language's table.
func language_name(code: String) -> String:
	var tr_obj := TranslationServer.get_translation_object(code)
	if tr_obj:
		var s := String(tr_obj.get_message("lang.self"))
		if s != "":
			return s
	return code


func _direct(key: String) -> Variant:
	var s := String(TranslationServer.translate(key))
	if s != key:
		return s
	return null


func fill(tpl: String, params: Dictionary) -> String:
	var out := ""
	var last := 0
	for m in _re_param.search_all(tpl):
		out += tpl.substr(last, m.get_start() - last)
		var name := m.get_string(1)
		out += str(params[name]) if params.has(name) and params[name] != null else m.get_string()
		last = m.get_end()
	return out + tpl.substr(last)


func fmt_num(n: Variant) -> String:
	if not (n is int or n is float):
		return "" if n == null else str(n)
	var cents := U.jround(absf(float(n)) * 100.0)
	var neg := float(n) < 0.0 and cents > 0
	var ip := cents / 100
	var fr := cents % 100
	var s := str(ip)
	var grouped := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		grouped = s[i] + grouped
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			grouped = "," + grouped
	if fr > 0:
		var dec := "%02d" % fr
		if dec.ends_with("0"):
			dec = dec.substr(0, 1)
		grouped += "." + dec
	return ("-" if neg else "") + grouped


func pct(x: float) -> String:
	return fmt_num(U.jround(x * 100.0)) + "%"


func compose(key: String) -> Variant:
	var m := _re_item.search(key)
	if m:
		var type_key := ("wtype." if m.get_string(1) == "w" else "otype.") + m.get_string(2)
		var ty = _direct(type_key)
		var tier = _direct("itemtier." + m.get_string(3))
		var fmt = _direct("item.set_format")
		if ty != null and tier != null and fmt != null:
			return fill(fmt, {"tier": tier, "type": ty})
	m = _re_species.search(key)
	if m:
		var fam = _direct("petfam." + m.get_string(1) + ".name")
		var form = _direct("petform." + m.get_string(2) + ("_evo" if m.get_string(3) != "" else ""))
		var fmt = _direct("pet.species_format")
		if fam != null and form != null and fmt != null:
			return fill(fmt, {"family": fam, "form": form})
	m = _re_main.search(key)
	if m:
		var q = C.QUESTS.get("main." + m.get_string(1) + "." + m.get_string(2))
		if q != null:
			var item_name := ""
			if q.get("itemId"):
				var n = _direct("spec." + q.itemId + ".name")
				item_name = n if n != null else q.itemId
			var loc = _direct("loc." + str(q.locationId) + ".name")
			var tpl = _direct("qtype." + q.type)
			if tpl != null:
				return fill(tpl, {"location": loc if loc != null else str(q.locationId), "count": fmt_num(q.get("count")), "item": item_name})
	return null


func has(key: Variant) -> bool:
	if not (key is String or key is StringName):
		return false
	return _direct(key) != null or compose(key) != null


func raw(key: String) -> Variant:
	var s = _direct(key)
	if s != null:
		return s
	var c = compose(key)
	if c != null:
		return c
	missing[key] = true
	return null


## Translates a key with parameters. Parameter strings that are keys are
## translated too; numbers are formatted; `crew`/`pet` params resolve through
## the optional state context to display names.
func t(key: Variant, params: Variant = null, ctx: Variant = null, depth: int = 0) -> String:
	if key == null:
		return ""
	var k := String(key)
	var tpl = raw(k)
	if tpl == null:
		return "⟦" + k + "⟧"
	if params == null or not (params is Dictionary) or params.is_empty():
		return tpl
	var out := ""
	var last := 0
	for m in _re_param.search_all(tpl):
		out += tpl.substr(last, m.get_start() - last)
		var name := m.get_string(1)
		if params.has(name) and params[name] != null:
			out += _param(name, params[name], ctx, params, depth)
		else:
			out += m.get_string()
		last = m.get_end()
	return out + tpl.substr(last)


func _param(name: String, v: Variant, ctx: Variant, all: Dictionary, depth: int) -> String:
	if v is bool:
		return t("ui.yes") if v else t("ui.no")
	if v is int or v is float:
		return fmt_num(v)
	if v is Dictionary and v.has("key"):
		return t(v.key, v.get("params"), ctx, depth + 1)
	if not (v is String or v is StringName):
		return str(v)
	var s := String(v)
	if name == "crew" and ctx is Dictionary and ctx.has("crew"):
		for c in ctx.crew:
			if c.id == s:
				return crew_name(c)
		return t("ui.former_crew")
	if name == "pet" and ctx is Dictionary and ctx.has("pets"):
		for p in ctx.pets:
			if p.id == s:
				return pet_name(p)
		return s
	if depth < 3 and _re_key.search(s) and has(s):
		var sib: Dictionary = all.duplicate()
		sib.erase(name)
		return t(s, sib, ctx, depth + 1)
	return s


## Default crew names derive from the stable seed through the active
## locale's name pool, so one sailor keeps one identity in each language.
func crew_name(m: Variant) -> String:
	if m == null:
		return ""
	if m.get("nickname"):
		return m.nickname
	var pool: Dictionary = names.get(locale(), names.en)
	var s := int(m.seed) & U.M32
	var given: String = pool.given[s % pool.given.size()]
	var family: String = pool.family[(U.hash32(str(s)) >> 3) % pool.family.size()]
	return fill(pool.format, {"given": given, "family": family})


func pet_name(p: Variant) -> String:
	if p == null:
		return ""
	return p.nickname if p.get("nickname") else t("pet." + p.speciesId + ".name")


func item_key(item_id: String) -> String:
	var it = C.ITEMS.get(item_id)
	if it == null:
		return "ui.unknown"
	if it.get("nameKey"):
		return it.nameKey
	return "item." + ("w_" + it.wtype if it.get("wtype") else "o_" + it.otype) + ".t" + str(it.tier)


func item_name(item_id: String, inst: Variant = null) -> String:
	var n := t(item_key(item_id))
	if inst != null and inst.get("affix"):
		n = fill(t("item.affix_format"), {"affix": t("affix." + inst.affix + ".name"), "name": n})
	if inst != null and int(inst.get("reinforce", 0)):
		n += " +" + str(inst.reinforce)
	return n


func reason(r: Variant) -> String:
	if r == null:
		return ""
	return t(r.get("reasonKey", "err.unknown"), r.get("reasonParams", {}), Game.state if Game.state else null)


func log_line(entry: Dictionary, ctx: Variant = null) -> String:
	return t(entry.key, entry.get("params", {}), ctx)
