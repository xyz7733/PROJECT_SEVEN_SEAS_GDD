## Natural coastline for an island site or a port. The land is shaped in
## ground (cell) units, so a disk of radius r cells reads as a 2:1 ellipse
## on screen like everything else in the iso view:
##
##  1. union/cut shapes (disks and capsules for masses, coves and headlands)
##     under a low-frequency domain warp plus fine roughness;
##  2. forced cells: `force_land` (room pads, trails, the town), `build`
##     (quays, jetties with their own ground and side tiles) and
##     `force_water` (boat lanes, the ship's berth);
##  3. clean-up: specks become offshore rocks, small lakes are filled,
##     one-cell spurs, notches and diagonal pinches are removed;
##  4. elevation: raised land (8px) and low beach ledges (4px). Beach width
##     follows exposure (open coasts become cliffs and shingle, sheltered
##     bays get wide sand and lagoon shallows) and a slow noise;
##  5. tiles: ground by level, exposure and noise patches; per-face cliff
##     sides; water by distance to land (lagoon, shallows, reef, sea, deep).
##
## paint() fills the view's terrain layers; make_foam() returns an animated
## surf line along every land/water edge. Forced land is always raised, so
## walkers on room pads, trails and the quay keep the raised-ground lift.
class_name Coast
extends RefCounted

const WATER := 0
const LOW := 1
const HIGH := 2
const F_CORE := 1
const F_WATER := 2
const F_BUILT := 4
## Ground lift in px of each level; the low and high ground layers are
## offset up by these amounts.
const LIFT := [0.0, 4.0, 8.0]
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Default tile names; a view overrides some of them per location kind.
const STYLE := {
	"base": "grass0", "alt": "sand0", "lush": "grass3", "meadow": "meadow", "trail": "path", "pad": "dirt",
	"beach": "sand0", "beach2": "sand1", "wet": "wetsand", "shingle": "shingle", "cliff": "cliff", "dune": "dune",
	"side": "rock", "low_side": "sandside", "shingle_side": "rock",
}

## Region tweaks of the default style: regions without green land use their
## own ground for the lush and meadow patches.
const REGION_STYLE := {
	"emberreach": {"lush": "rubble", "meadow": "dirt"},
	"glass_current": {"lush": "stone0", "meadow": "grass3"},
	"stormbelt": {"meadow": "grass3", "lush": "rubble"},
	"moonwake": {"lush": "forest", "meadow": "grass3"},
	"ashen_trench": {"lush": "rubble", "meadow": "dirt", "dune": "rubble"},
	"leviathan_ring": {"lush": "grass3", "meadow": "dune"},
}

var rect := Rect2i()
var seed := 1
## Domain-warp strength in cells and the fine edge roughness.
var warp_amp := 1.5
var rough := 0.45
## Added to every coast cell's beach width (+ more sand, - more cliffs).
var beach_bias := 0.0
## Water from this many cells off the coast (plus noise) is open deep sea.
var deep_from := 6.5
var style: Dictionary = STYLE.duplicate()
## Ground for forced cells (trails, pads, streets): Vector2i -> name.
var paint_names: Dictionary = {}
## Reef patches: [Vector2 centre, radius].
var reefs: Array = []
## Offshore rocks produced by generate(): [Vector2 cell position, prop name].
var rocks: Array = []

var _shapes: Array = []
var _built: Dictionary = {}
var _w := 0
var _h := 0
var lvl := PackedByteArray()
var flags := PackedByteArray()
## Land: chamfer distance to water; water: distance to land (both in cells).
var dist := PackedFloat32Array()
## Fraction of water within 4 cells (0 enclosed .. 1 open sea).
var openness := PackedFloat32Array()
var ground := PackedStringArray()
var side := PackedStringArray()
var water := PackedStringArray()
var _nx := FastNoiseLite.new()
var _ny := FastNoiseLite.new()
var _nr := FastNoiseLite.new()
var _nb := FastNoiseLite.new()
var _np := FastNoiseLite.new()


func setup(r: Rect2i, s: int) -> void:
	rect = r
	seed = s
	_w = r.size.x
	_h = r.size.y
	var n := _w * _h
	lvl.resize(n)
	lvl.fill(WATER)
	flags.resize(n)
	flags.fill(0)
	_shapes.clear()
	_built.clear()
	rocks.clear()
	var k := 0
	for nz in [_nx, _ny, _nr, _nb, _np]:
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.seed = s + k * 977
		k += 1
	for nz in [_nx, _ny]:
		nz.frequency = 0.085
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
		nz.fractal_octaves = 2
		nz.fractal_lacunarity = 2.8
		nz.fractal_gain = 0.38
	_nr.frequency = 0.33
	_nr.fractal_type = FastNoiseLite.FRACTAL_NONE
	_nb.frequency = 0.12
	_nb.fractal_type = FastNoiseLite.FRACTAL_NONE
	_np.frequency = 0.1
	_np.fractal_type = FastNoiseLite.FRACTAL_FBM
	_np.fractal_octaves = 2


## Base and patch ground from the region (ShipView.REGION_GROUND) plus the
## region's tweaks; call before applying per-location overrides.
func use_region(rid: String) -> void:
	var rg: Array = ShipView.REGION_GROUND.get(rid, ["grass0", "sand0"])
	style.base = String(rg[0])
	style.alt = String(rg[1])
	var tw: Dictionary = REGION_STYLE.get(rid, {})
	for k in tw:
		style[k] = tw[k]


# ------------------------------------------------------------ authoring
func add_disk(c: Vector2, r: float) -> void:
	_shapes.append([1, c, c, r])


func add_capsule(a: Vector2, b: Vector2, r: float) -> void:
	_shapes.append([1, a, b, r])


func cut_disk(c: Vector2, r: float) -> void:
	_shapes.append([-1, c, c, r])


func cut_capsule(a: Vector2, b: Vector2, r: float) -> void:
	_shapes.append([-1, a, b, r])


func add_reef(c: Vector2, r: float) -> void:
	reefs.append([c, r])


## Raised land that generation may not remove (and may not turn into
## beach); `ground_name` paints it (a trail, a pad, a street).
func force_land(c: Vector2i, ground_name := "") -> void:
	var i := idx(c)
	if i < 0:
		return
	flags[i] = (flags[i] | F_CORE) & ~F_WATER
	if ground_name != "":
		paint_names[c] = ground_name


## Water that generation may not fill (boat lanes, the ship's berth).
func force_water(c: Vector2i) -> void:
	var i := idx(c)
	if i >= 0 and flags[i] & (F_CORE | F_BUILT) == 0:
		flags[i] |= F_WATER


## A built raised cell (quay, jetty) with its own ground and side tiles.
func build(c: Vector2i, ground_name: String, side_kind: String) -> void:
	var i := idx(c)
	if i < 0:
		return
	flags[i] = (flags[i] | F_BUILT | F_CORE) & ~F_WATER
	_built[c] = [ground_name, side_kind]


# --------------------------------------------------------------- queries
## Cheap deterministic hash of a cell and a salt (0 .. 2^31-1), for
## per-cell choices where formatting a string per cell would be slow.
static func ihash(x: int, y: int, salt: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff


func idx(c: Vector2i) -> int:
	var x := c.x - rect.position.x
	var y := c.y - rect.position.y
	if x < 0 or y < 0 or x >= _w or y >= _h:
		return -1
	return x + y * _w


func cell_of(i: int) -> Vector2i:
	return Vector2i(rect.position.x + i % _w, rect.position.y + i / _w)


func level(c: Vector2i) -> int:
	var i := idx(c)
	return WATER if i < 0 else int(lvl[i])


func is_land(c: Vector2i) -> bool:
	return level(c) != WATER


func is_built(c: Vector2i) -> bool:
	return _built.has(c)


func is_forced(c: Vector2i) -> bool:
	var i := idx(c)
	return i >= 0 and flags[i] & (F_CORE | F_BUILT | F_WATER) != 0


## Drawn ground height in px at a cell (0 on water).
func lift(c: Vector2i) -> float:
	return LIFT[level(c)]


## Land cell under a world point (the raised surface is drawn 8px up, so
## a point on raised ground belongs to the cell whose centre is 8px below).
func cell_at(p: Vector2) -> Vector2i:
	var g := Art.uniso(p + Vector2(0, 8))
	return Vector2i(roundi(g.x), roundi(g.y))


func ground_name(c: Vector2i) -> String:
	var i := idx(c)
	return "" if i < 0 else ground[i]


func water_name(c: Vector2i) -> String:
	var i := idx(c)
	if i < 0:
		return "deep" if deep_from < 99.0 else "sea"
	return water[i]


func land_rect() -> Rect2i:
	var r := Rect2i()
	var any := false
	for i in lvl.size():
		if lvl[i] != WATER:
			var c := cell_of(i)
			r = Rect2i(c, Vector2i.ONE) if not any else r.merge(Rect2i(c, Vector2i.ONE))
			any = true
	return r


func land_count() -> int:
	var n := 0
	for i in lvl.size():
		if lvl[i] != WATER:
			n += 1
	return n


# ------------------------------------------------------------ generation
func generate() -> void:
	_shape()
	_clean_land()
	_distances()
	_elevate()
	_classify()
	_place_rocks()


## Signed distance from p to a capsule a-b of radius r (a disk when a == b).
func _sdf(a: Vector2, b: Vector2, r: float, p: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) - r


func _shape() -> void:
	# Each shape only matters inside its box (grown by the warp and the
	# roughness): outside it an added shape is farther than any land edge
	# and a cut leaves the distance as it is.
	var boxes: Array[Rect2] = []
	for s in _shapes:
		var a: Vector2 = s[1]
		var b: Vector2 = s[2]
		var g: float = float(s[3]) + warp_amp + rough + 1.0
		boxes.append(Rect2(a.min(b) - Vector2(g, g), (a - b).abs() + Vector2(g, g) * 2.0))
	for i in lvl.size():
		var c := cell_of(i)
		var p := Vector2(c)
		var q := p + Vector2(_nx.get_noise_2dv(p), _ny.get_noise_2dv(p)) * warp_amp
		var d := 1e9
		for k in _shapes.size():
			if not boxes[k].has_point(p):
				continue
			var s: Array = _shapes[k]
			var sd := _sdf(s[1], s[2], s[3], q)
			if int(s[0]) > 0:
				d = minf(d, sd)
			else:
				d = maxf(d, -sd)
		d += rough * _nr.get_noise_2dv(p)
		var f := flags[i]
		var land := d < 0.0
		if f & (F_CORE | F_BUILT):
			land = true
		elif f & F_WATER:
			land = false
		lvl[i] = HIGH if land else WATER


func _n4(i: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := i % _w
	var y := i / _w
	if x + 1 < _w:
		out.append(i + 1)
	if x > 0:
		out.append(i - 1)
	if y + 1 < _h:
		out.append(i + _w)
	if y > 0:
		out.append(i - _w)
	return out


## Number of land 4-neighbours (outside the rect counts as water).
func _land_n(i: int) -> int:
	var n := 0
	for j in _n4(i):
		if lvl[j] != WATER:
			n += 1
	return n


func _components(want_land: bool) -> Array:
	var seen := PackedByteArray()
	seen.resize(lvl.size())
	seen.fill(0)
	var comps := []
	for i in lvl.size():
		if seen[i] or (lvl[i] != WATER) != want_land:
			continue
		var comp := PackedInt32Array([i])
		seen[i] = 1
		var k := 0
		var border := false
		while k < comp.size():
			var j := comp[k]
			k += 1
			var x := j % _w
			var y := j / _w
			if x == 0 or y == 0 or x == _w - 1 or y == _h - 1:
				border = true
			for m in _n4(j):
				if not seen[m] and (lvl[m] != WATER) == want_land:
					seen[m] = 1
					comp.append(m)
		comps.append([comp, border])
	return comps


func _clean_land() -> void:
	for it in 2:
		# one-cell spurs and notches
		for i in lvl.size():
			if flags[i] & (F_CORE | F_BUILT | F_WATER):
				continue
			var n := _land_n(i)
			if lvl[i] != WATER and n <= 1:
				lvl[i] = WATER
			elif lvl[i] == WATER and n >= 3:
				lvl[i] = HIGH
		_fix_pinches()
	# specks of land become rocks; small enclosed lakes are filled
	for comp in _components(true):
		var cells: PackedInt32Array = comp[0]
		if cells.size() >= 6:
			continue
		var forced := false
		var centre := Vector2.ZERO
		for j in cells:
			forced = forced or flags[j] & (F_CORE | F_BUILT) != 0
			centre += Vector2(cell_of(j))
		if forced:
			continue
		for j in cells:
			lvl[j] = WATER
		rocks.append([centre / cells.size(), "sea_rock" if cells.size() >= 3 else "sea_rock_s"])
	for comp in _components(false):
		var cells: PackedInt32Array = comp[0]
		if comp[1] or cells.size() > 30:
			continue
		var keep := false
		for j in cells:
			keep = keep or flags[j] & F_WATER != 0
		if not keep:
			for j in cells:
				lvl[j] = HIGH


## Two land cells touching only at a corner (or two water cells doing the
## same) read as a pinch: fill one of the open cells.
func _fix_pinches() -> void:
	for y in _h - 1:
		for x in _w - 1:
			var a := x + y * _w
			var b := a + 1
			var c := a + _w
			var d := c + 1
			var la := lvl[a] != WATER
			var lb := lvl[b] != WATER
			var lc := lvl[c] != WATER
			var ld := lvl[d] != WATER
			if la == ld and lb == lc and la != lb:
				# land on one diagonal, water on the other: fill an
				# unprotected water cell
				var pick := (b if flags[b] & F_WATER == 0 else c) if la else (a if flags[a] & F_WATER == 0 else d)
				if flags[pick] & F_WATER == 0:
					lvl[pick] = HIGH


## Chamfer distances: land cells to the nearest water, water cells to the
## nearest land (outside the rect is water).
func _distances() -> void:
	var n := lvl.size()
	dist.resize(n)
	var big := 1e6
	for i in n:
		var land := lvl[i] != WATER
		dist[i] = big
		# a cell next to the other kind (or the rect edge for land) is 1 away
		var x := i % _w
		var y := i / _w
		if land and (x == 0 or y == 0 or x == _w - 1 or y == _h - 1):
			dist[i] = 1.0
		for j in _n4(i):
			if (lvl[j] != WATER) != land:
				dist[i] = 1.0
				break
	var w1 := 1.0
	var w2 := 1.414
	for y in _h:
		for x in _w:
			var i := x + y * _w
			var land := lvl[i] != WATER
			var v := dist[i]
			if x > 0 and (lvl[i - 1] != WATER) == land:
				v = minf(v, dist[i - 1] + w1)
			if y > 0:
				if (lvl[i - _w] != WATER) == land:
					v = minf(v, dist[i - _w] + w1)
				if x > 0 and (lvl[i - _w - 1] != WATER) == land:
					v = minf(v, dist[i - _w - 1] + w2)
				if x < _w - 1 and (lvl[i - _w + 1] != WATER) == land:
					v = minf(v, dist[i - _w + 1] + w2)
			dist[i] = v
	for y in range(_h - 1, -1, -1):
		for x in range(_w - 1, -1, -1):
			var i := x + y * _w
			var land := lvl[i] != WATER
			var v := dist[i]
			if x < _w - 1 and (lvl[i + 1] != WATER) == land:
				v = minf(v, dist[i + 1] + w1)
			if y < _h - 1:
				if (lvl[i + _w] != WATER) == land:
					v = minf(v, dist[i + _w] + w1)
				if x < _w - 1 and (lvl[i + _w + 1] != WATER) == land:
					v = minf(v, dist[i + _w + 1] + w2)
				if x > 0 and (lvl[i + _w - 1] != WATER) == land:
					v = minf(v, dist[i + _w - 1] + w2)
			dist[i] = v
	# openness: share of water in the 9x9 cells around (outside the rect is
	# water), from an integral image of land cells
	openness.resize(n)
	var sw := _w + 1
	var integ := PackedInt32Array()
	integ.resize(sw * (_h + 1))
	integ.fill(0)
	for y in _h:
		var row := 0
		for x in _w:
			if lvl[x + y * _w] != WATER:
				row += 1
			integ[(x + 1) + (y + 1) * sw] = integ[(x + 1) + y * sw] + row
	for i in n:
		var x := i % _w
		var y := i / _w
		var x0 := maxi(0, x - 4)
		var y0 := maxi(0, y - 4)
		var x1 := mini(_w, x + 5)
		var y1 := mini(_h, y + 5)
		var land_n := integ[x1 + y1 * sw] - integ[x0 + y1 * sw] - integ[x1 + y0 * sw] + integ[x0 + y0 * sw]
		openness[i] = float(81 - land_n) / 81.0


func _beach_width(i: int) -> int:
	var c := Vector2(cell_of(i))
	var e := clampf((openness[i] - 0.32) / 0.42, 0.0, 1.0)
	return clampi(roundi(lerpf(2.7, -0.4, e) + beach_bias + 1.3 * _nb.get_noise_2dv(c)), 0, 3)


func _elevate() -> void:
	var n := lvl.size()
	var done := PackedByteArray()
	done.resize(n)
	done.fill(0)
	var queue := PackedInt32Array()
	var widths := PackedInt32Array()
	for i in n:
		if lvl[i] == WATER or flags[i] & (F_CORE | F_BUILT) or dist[i] > 1.0:
			continue
		done[i] = 1
		var w := _beach_width(i)
		if w >= 1:
			lvl[i] = LOW
			queue.append(i)
			widths.append(w)
	var k := 0
	while k < queue.size():
		var i := queue[k]
		var w := widths[k]
		k += 1
		for j in _n4(i):
			if done[j] or lvl[j] == WATER or flags[j] & (F_CORE | F_BUILT):
				continue
			if dist[j] <= float(w) + 0.01:
				done[j] = 1
				lvl[j] = LOW
				queue.append(j)
				widths.append(w)
	# tidy: lone raised cells on a beach drop, beach pits rise
	for it in 2:
		for i in n:
			if lvl[i] == WATER or flags[i] & (F_CORE | F_BUILT):
				continue
			var hi := 0
			var wet := 0
			for j in _n4(i):
				if lvl[j] == HIGH:
					hi += 1
				elif lvl[j] == WATER:
					wet += 1
			if lvl[i] == HIGH and hi <= 1:
				lvl[i] = LOW
			elif lvl[i] == LOW and wet == 0 and hi >= 3:
				lvl[i] = HIGH
		# raised cells touching only at a corner across a beach
		for y in _h - 1:
			for x in _w - 1:
				var a := x + y * _w
				var b := a + 1
				var c := a + _w
				var d := c + 1
				var ha := lvl[a] == HIGH
				var hb := lvl[b] == HIGH
				var hc := lvl[c] == HIGH
				var hd := lvl[d] == HIGH
				if ha == hd and hb == hc and ha != hb:
					for m in ([b, c] if ha else [a, d]):
						if lvl[m] == LOW:
							lvl[m] = HIGH
							break


func _classify() -> void:
	var n := lvl.size()
	ground.resize(n)
	side.resize(n)
	water.resize(n)
	for i in n:
		var c := cell_of(i)
		var p := Vector2(c)
		ground[i] = ""
		side[i] = ""
		water[i] = ""
		if lvl[i] == WATER:
			water[i] = _water_kind(i, p)
			continue
		if _built.has(c):
			ground[i] = String(_built[c][0])
			side[i] = String(_built[c][1])
			continue
		var wet_n := 0
		var low_n := 0
		for j in _n4(i):
			if lvl[j] == WATER:
				wet_n += 1
			elif lvl[j] == LOW:
				low_n += 1
		var pn := _np.get_noise_2dv(p)
		var h32 := ihash(c.x, c.y, seed)
		if lvl[i] == LOW:
			if wet_n > 0:
				ground[i] = style.shingle if openness[i] > 0.62 else style.wet
			else:
				ground[i] = style.beach if pn > -0.15 else style.beach2
			side[i] = style.shingle_side if ground[i] == style.shingle else style.low_side
			continue
		side[i] = style.side
		if paint_names.has(c):
			ground[i] = String(paint_names[c])
		elif wet_n > 0 and (openness[i] > 0.42 or h32 % 3 == 0):
			ground[i] = style.cliff
		elif low_n > 0 and h32 % 2 == 0:
			ground[i] = style.dune
		elif pn > 0.36:
			ground[i] = style.meadow
		elif pn < -0.38:
			ground[i] = style.lush
		elif _nb.get_noise_2dv(p * 1.3 + Vector2(40, 40)) > 0.42:
			ground[i] = style.alt
		else:
			ground[i] = style.base


func _in_reef(p: Vector2) -> bool:
	for rf in reefs:
		if p.distance_to(rf[0]) <= float(rf[1]) + 0.6 * _nr.get_noise_2dv(p * 1.7):
			return true
	return false


func _water_kind(i: int, p: Vector2) -> String:
	var d := dist[i]
	if _in_reef(p) and d <= 4.5:
		return "reef"
	var sheltered := openness[i] < 0.55
	if d <= 1.0:
		return "lagoon" if openness[i] < 0.5 else "shallow"
	if d <= 2.0 and sheltered:
		return "shallow"
	if deep_from < 99.0 and d >= deep_from + 2.5 * _nb.get_noise_2dv(p * 0.7):
		return "deep"
	return "sea"


## Rocks in the surf off exposed coasts and on reefs; never in forced water
## (boat lanes, berths) or next to it.
func _place_rocks() -> void:
	var kept := []
	for r in rocks:
		if not _near_forced_water(Vector2i(roundi(r[0].x), roundi(r[0].y))):
			kept.append(r)
	rocks = kept
	for i in lvl.size():
		if lvl[i] != WATER:
			continue
		var d := dist[i]
		var reef := water[i] == "reef"
		var exposed := openness[i] > 0.7 and d >= 1.2 and d <= 3.2
		if not (reef or exposed):
			continue
		var c := cell_of(i)
		var h := ihash(c.x, c.y, seed + 7) % 1000
		if ((reef and h < 160) or (exposed and h < 45)) and not _near_forced_water(c):
			var jitter := Vector2(float(h % 7) - 3.0, float(h % 5) - 2.0) * 0.08
			var nm := "sea_rock_s" if (reef or h % 3 != 0) else "sea_rock"
			if exposed and d >= 2.2 and h % 11 == 0:
				nm = "sea_stack"
			rocks.append([Vector2(c) + jitter, nm])


func _near_forced_water(c: Vector2i) -> bool:
	for oy in range(-2, 3):
		for ox in range(-2, 3):
			var j := idx(c + Vector2i(ox, oy))
			if j >= 0 and flags[j] & F_WATER:
				return true
	return false


# -------------------------------------------------------------- painting
## Fills the terrain layers: `layers` holds sea, sides, low, band and high
## TileMapLayers (all aligned with Art.align_layer, low/high offset up by
## 4/8px); `info` is the align info. Water outside the rect is left to the
## caller (water_name() answers for any cell).
func paint(layers: Dictionary, info: Dictionary) -> void:
	var sea: TileMapLayer = layers.sea
	var sides: TileMapLayer = layers.sides
	var low: TileMapLayer = layers.low
	var band: TileMapLayer = layers.band
	var high: TileMapLayer = layers.high
	for i in lvl.size():
		var c := cell_of(i)
		var mc := Art.layer_cell(info, c.x, c.y)
		var l := lvl[i]
		if l == WATER:
			sea.set_cell(mc, 0, Art.water_tile(water[i]))
			continue
		var front_l := c + Vector2i(0, 1)
		var front_r := c + Vector2i(1, 0)
		if l == HIGH:
			high.set_cell(mc, 0, Art.ground_tile(ground[i]))
			var fl := level(front_l) != HIGH
			var fr := level(front_r) != HIGH
			if fl or fr:
				var faces := "LR" if fl and fr else ("L" if fl else "R")
				sides.set_cell(mc, 0, Art.side_tile(side[i], "high", faces))
				band.set_cell(mc, 0, Art.side_tile(side[i], "band", faces))
		else:
			low.set_cell(mc, 0, Art.ground_tile(ground[i]))
			var wl := level(front_l) == WATER
			var wr := level(front_r) == WATER
			if wl or wr:
				var faces2 := "LR" if wl and wr else ("L" if wl else "R")
				sides.set_cell(mc, 0, Art.side_tile(side[i], "low", faces2))


## Animated surf: a steady line and a lapping line along every land edge
## that faces water (front edges at the waterline, back edges just above
## the land's silhouette) and small rings around offshore rocks.
func make_foam() -> Foam:
	var f := Foam.new()
	f.z_index = -16
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var kind := PackedByteArray()
	var ph := PackedFloat32Array()
	for i in lvl.size():
		if lvl[i] == WATER:
			continue
		var c := cell_of(i)
		if _built.has(c) and String(_built[c][1]) == "wood":
			continue
		var o := Art.iso(c.x, c.y)
		var lf: float = LIFT[lvl[i]]
		var h := float(ihash(c.x, c.y, 31) % 628) / 100.0
		if level(c + Vector2i(1, 0)) == WATER:
			a.append(o + Vector2(0, 8)); b.append(o + Vector2(16, 0)); kind.append(0); ph.append(h)
		if level(c + Vector2i(0, 1)) == WATER:
			a.append(o + Vector2(-16, 0)); b.append(o + Vector2(0, 8)); kind.append(0); ph.append(h + 1.3)
		if level(c + Vector2i(-1, 0)) == WATER:
			a.append(o + Vector2(-16, -lf)); b.append(o + Vector2(0, -8 - lf)); kind.append(1); ph.append(h + 2.1)
		if level(c + Vector2i(0, -1)) == WATER:
			a.append(o + Vector2(0, -8 - lf)); b.append(o + Vector2(16, -lf)); kind.append(1); ph.append(h + 0.7)
	f.seg_a = a
	f.seg_b = b
	f.seg_kind = kind
	f.seg_phase = ph
	var rp := PackedVector2Array()
	for r in rocks:
		rp.append(Art.iso(r[0].x, r[0].y))
	f.rock_pts = rp
	return f


class Foam:
	extends Node2D
	var seg_a := PackedVector2Array()
	var seg_b := PackedVector2Array()
	var seg_kind := PackedByteArray()
	var seg_phase := PackedFloat32Array()
	var rock_pts := PackedVector2Array()
	var _t := 0.0
	var _acc := 0.0

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _acc >= 0.1:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in seg_a.size():
			var a := seg_a[i]
			var b := seg_b[i]
			var w := 0.5 + 0.5 * sin(_t * 1.6 + seg_phase[i])
			# trim the ends a little so adjacent edges read as broken surf
			var ta := a.lerp(b, 0.12)
			var tb := a.lerp(b, 0.88)
			if seg_kind[i] == 0:
				pts.append(ta + Vector2(0, 2)); pts.append(tb + Vector2(0, 2))
				cols.append(Color(1, 1, 1, 0.42 + 0.18 * w))
				var off := Vector2(0, roundf(3.0 + 2.0 * w))
				pts.append(a.lerp(b, 0.25 + 0.1 * w) + off); pts.append(a.lerp(b, 0.75 - 0.1 * w) + off)
				cols.append(Color(1, 1, 1, 0.12 + 0.3 * (1.0 - w)))
			else:
				pts.append(ta + Vector2(0, -1)); pts.append(tb + Vector2(0, -1))
				cols.append(Color(1, 1, 1, 0.3 + 0.2 * w))
				var off2 := Vector2(0, -roundf(2.0 + 1.5 * w))
				pts.append(a.lerp(b, 0.3) + off2); pts.append(a.lerp(b, 0.7) + off2)
				cols.append(Color(1, 1, 1, 0.1 + 0.2 * (1.0 - w)))
		for i in rock_pts.size():
			var p := rock_pts[i] + Vector2(0, 2)
			var w2 := 0.5 + 0.5 * sin(_t * 1.9 + float(i) * 1.7)
			var rx := 6.0 + 2.0 * w2
			var ry := rx * 0.5
			pts.append(p + Vector2(-rx, 0)); pts.append(p + Vector2(0, ry))
			cols.append(Color(1, 1, 1, 0.35 + 0.2 * (1.0 - w2)))
			pts.append(p + Vector2(0, ry)); pts.append(p + Vector2(rx, 0))
			cols.append(Color(1, 1, 1, 0.35 + 0.2 * (1.0 - w2)))
		if pts.size():
			draw_multiline_colors(pts, cols, 1.0)
