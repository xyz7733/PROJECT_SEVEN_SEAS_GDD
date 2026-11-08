## Deterministic math helpers shared by the rules port.
## Mirrors the JavaScript reference: uint32 arithmetic, FNV-1a hashing,
## Mulberry32 generators and JS-style rounding.
class_name U
extends RefCounted

const M32 := 0xFFFFFFFF


## 32-bit multiply that keeps only the low 32 bits (Math.imul >>> 0).
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := a * (b & 0xFFFF)
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M32


## Mulberry32 output function on a uint32 state.
static func mix(s: int) -> int:
	var t := s & M32
	t = imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & M32)) & M32
	return (t ^ (t >> 14)) & M32


## FNV-1a over UTF-16 code units, like the JS reference (BMP text only).
static func hash32(text: String) -> int:
	var h := 0x811c9dc5
	for i in text.length():
		h ^= text.unicode_at(i)
		h = imul(h, 0x01000193)
	return h & M32


static func hash_hex(text: String) -> String:
	return "%08x" % hash32(text)


static func seed_of(text: String) -> int:
	return hash32(text)


## JavaScript Math.round: halves round toward positive infinity.
static func jround(x: float) -> int:
	return int(floor(x + 0.5))


static func round1(x: float) -> float:
	return floor(x * 10.0 + 0.5) / 10.0


static func round2(x: float) -> float:
	return floor(x * 100.0 + 0.5) / 100.0


## Recursively converts whole-number floats (from JSON) to ints so that
## Array.has() and equality checks behave like the JS reference.
static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floor(f) and abs(f) < 9.0e15:
				return int(f)
			return f
		TYPE_ARRAY:
			var out := []
			for e in v:
				out.append(normalize(e))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[String(k)] = normalize(v[k])
			return out
	return v


static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Missing data file: " + path)
		return {}
	return normalize(JSON.parse_string(text))


static func gv(d: Variant, key: String, fallback: Variant = null) -> Variant:
	if d is Dictionary and d.has(key) and d[key] != null:
		return d[key]
	return fallback


static func num(d: Variant, key: String) -> float:
	if d is Dictionary and d.has(key) and d[key] != null:
		return float(d[key])
	return 0.0


static func add_mods(target: Dictionary, mods: Variant, scale: float = 1.0) -> void:
	if not (mods is Dictionary):
		return
	for k in mods:
		var v = mods[k]
		if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
			target[k] = float(target.get(k, 0.0)) + float(v) * scale


static func arr_has(a: Array, v: Variant) -> bool:
	for e in a:
		if typeof(e) == typeof(v) and e == v:
			return true
		if (typeof(e) == TYPE_INT or typeof(e) == TYPE_FLOAT) and (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and float(e) == float(v):
			return true
	return false


static func max_of(values: Array, floor_value: float = 0.0) -> float:
	var m := floor_value
	for v in values:
		m = max(m, float(v))
	return m


static func sum_values(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s


static func pad4(n: int) -> String:
	return "%04d" % n


## Independent Mulberry32 generator for derived content.
class Rng:
	var s: int

	func _init(seed_value: int) -> void:
		s = seed_value & 0xFFFFFFFF

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xFFFFFFFF
		return float(U.mix(s)) / 4294967296.0

	func range_int(a: int, b: int) -> int:
		return a + int(floor(next() * float(b - a + 1)))

	func pick(list: Array) -> Variant:
		return list[int(floor(next() * float(list.size())))]
