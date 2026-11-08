## Merged world sea chart: geometry and exploration fog.
##
## tools/artgen/gen_chart.py lays all ten seas out on one illustrated sheet
## in progression order: seas 1-5 run left to right along the top row,
## seas 6-10 run right to left along the bottom row, the mainland lies
## between the rows and a strait cuts it at the east end. chart.json gives
## each sea's tile, each location's position and island sprite, and the fog
## art. This script turns that data and the game state into chart
## positions, route polylines and the exploration fog texture.
##
## Fog rules (one texture, half the chart's resolution):
## - a locked sea is under a dense cloud bank (the painted puffs), including
##   its half of the mainland; the bank's edge follows whole puffs, so it is
##   a soft cloud line, not a straight tile seam;
## - an open sea's coast and land are clear;
## - its water is clear around every charted location (wider around visited
##   ones and the ship) and along charted routes, and under a light flat haze
##   elsewhere, with a dithered, noise-broken edge;
## - where an open sea meets a locked one the bank thickens over a short
##   dithered band, so no sliver of the locked sea shows;
## - the chart's frame is never fogged.
class_name SeaChart
extends RefCounted

const JSON_PATH := "res://assets/gen/env/chart.json"

## Fog alpha over a locked sea.
const FOG_DENSE := 244
## Fog alpha over unexplored water in an open sea.
const FOG_HAZE := 104
## Clear radius in chart pixels around locations, by knowledge, and along
## charted routes.
const R_CURRENT := 84.0
const R_VISITED := 70.0
const R_REVEALED := 46.0
const R_ROUTE := 15.0
## Edge band of the clearing field: clear above HI, hazed below LO,
## ordered dither between.
const EDGE_LO := 0.02
const EDGE_HI := 0.22
## Width (fog pixels) of the dithered bank where an open sea meets a locked one.
const BANK := 10.0
## Flat tint of the haze over unexplored open water (the puff art would make
## the water busy).
const HAZE_RGB := [238, 233, 219]
const BAYER := [0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0]

const TYPE_COLORS := {"port": Color8(38, 58, 104), "island": Color8(70, 138, 74), "dungeon": Color8(92, 84, 104),
	"wreck": Color8(138, 86, 52), "arena": Color8(176, 78, 60), "secret": Color8(128, 100, 190)}
const PAPER := Color8(236, 224, 192)
const INK := Color8(58, 44, 42)

static var _data: Dictionary = {}
static var _fog_src := PackedByteArray()
static var _key := PackedByteArray()
static var _fog_tex: ImageTexture
static var _fog_sig := ""
static var _task := -1
static var _task_box: Array = []
static var _task_sig := ""
static var _task_t0 := 0
## Milliseconds the last fog build took, from start to collection.
static var last_build_ms := 0


static func data() -> Dictionary:
	if _data.is_empty():
		_data = U.load_json(JSON_PATH)
	return _data


static func chart_size() -> Vector2:
	var d := data()
	return Vector2(float(d.size[0]), float(d.size[1]))


static func sea_size() -> Vector2:
	var d := data()
	return Vector2(float(d.sea[0]), float(d.sea[1]))


static func has_loc(id: Variant) -> bool:
	return id != null and data().locs.has(String(id))


static func loc_pos(id: String) -> Vector2:
	var l = data().locs.get(id)
	if l == null:
		return Vector2.ZERO
	return Vector2(float(l.pos[0]), float(l.pos[1]))


static func sea_index(region_id: String) -> int:
	var r = data().regions.get(region_id)
	return int(r.index) if r != null else -1


## The sea's tile on the chart.
static func sea_rect(region_id: String) -> Rect2:
	var r = data().regions.get(region_id)
	if r == null:
		return Rect2(Vector2.ZERO, chart_size())
	return Rect2(Vector2(float(r.origin[0]), float(r.origin[1])), sea_size())


static func sea_row(region_id: String) -> int:
	var d := data()
	return 1 if sea_rect(region_id).position.y > float(d.band[0]) else 0


## Polyline from one location to another as a ship sails it: straight
## within a row of seas, and through the strait between the rows.
static func route_points(a: String, b: String) -> PackedVector2Array:
	var pa := loc_pos(a)
	var pb := loc_pos(b)
	var la = C.location(a)
	var lb = C.location(b)
	if la == null or lb == null:
		return PackedVector2Array([pa, pb])
	var ra := sea_row(String(la.regionId))
	var rb := sea_row(String(lb.regionId))
	if ra == rb:
		return PackedVector2Array([pa, pb])
	var s: Array = data().strait
	var north := Vector2(float(s[0]), float(s[1]) - 18.0)
	var south := Vector2(float(s[0]), float(s[2]) + 18.0)
	if ra == 0:
		return PackedVector2Array([pa, north, south, pb])
	return PackedVector2Array([pa, south, north, pb])


## Island sprite of a location: {tex, src, dst} in chart pixels, or {}.
static func isle(id: String) -> Dictionary:
	var l = data().locs.get(id)
	if l == null:
		return {}
	var src := Rect2(float(l.rect[0]), float(l.rect[1]), float(l.rect[2]), float(l.rect[3]))
	var dst := Rect2(loc_pos(id) - Vector2(float(l.anchor[0]), float(l.anchor[1])), src.size)
	return {"src": src, "dst": dst}


static func mark_rect(name: String) -> Rect2:
	var i: int = maxi(0, (data().markNames as Array).find(name))
	return Rect2(float(i * 16), 0.0, 16.0, 16.0)


static func mark_tex(name: String) -> AtlasTexture:
	return Art.region(String(data().marks), mark_rect(name))


## Marker name for a location: the full disc once visited, the light
## "charted, not visited" disc before.
static func mark_for(state: Dictionary, id: String) -> String:
	var l = C.location(id)
	var t: String = String(l.type) if l != null else "island"
	return t if Rules.is_visited(state, id) else t + "_r"


# ------------------------------------------------------------------ fog
## Inputs for the fog from the game state: which seas are open, the
## clearings and the charted lanes, plus a signature for caching.
static func fog_inputs(state: Dictionary) -> Dictionary:
	var open := PackedByteArray()
	open.resize(10)
	var sig := PackedStringArray()
	for r in C.REGIONS:
		var i := sea_index(String(r.id))
		if i >= 0 and i < open.size() and Rules.region_unlocked(state, String(r.id)):
			open[i] = 1
	sig.append(open.hex_encode())
	var cur: String = state.world.currentLocationId
	var circles: Array = []
	var ids: Array = data().locs.keys()
	ids.sort()
	for id in ids:
		var k := Rules.knowledge(state, id)
		if k == "hidden":
			continue
		var r := R_REVEALED
		if id == cur:
			r = R_CURRENT
		elif k == "visited" or k == "cleared":
			r = R_VISITED
		var p := loc_pos(id)
		circles.append(Vector3(p.x, p.y, r))
		sig.append("%s:%d" % [id, int(r)])
	var lanes: Array = []
	var keys: Array = state.world.chartedRoutes.duplicate()
	keys.sort()
	for key in keys:
		var pr: PackedStringArray = String(key).split("|")
		if pr.size() != 2 or not Rules.is_known(state, pr[0]) or not Rules.is_known(state, pr[1]):
			continue
		var pts := route_points(pr[0], pr[1])
		for j in pts.size() - 1:
			lanes.append([pts[j], pts[j + 1], R_ROUTE])
		sig.append(String(key))
	return {"open": open, "circles": circles, "lanes": lanes, "sig": "/".join(sig)}


## The fog texture for the state, or null while it is being built. The
## build (0.1-0.2 s of per-pixel work) runs on a worker thread whenever the
## inputs change; callers show the plain cloud art (fog_placeholder) until
## poll() hands back the finished texture.
static func fog_texture(state: Dictionary) -> ImageTexture:
	var inp := fog_inputs(state)
	poll()
	if _fog_tex != null and inp.sig == _fog_sig:
		return _fog_tex
	if _task == -1:
		_load_fog_src()
		var box := [null]
		var open: PackedByteArray = inp.open
		var circles: Array = inp.circles
		var lanes: Array = inp.lanes
		_task_box = box
		_task_sig = inp.sig
		_task_t0 = Time.get_ticks_msec()
		var job := func() -> void:
			var img := build_fog(open, circles, lanes)
			img.generate_mipmaps()
			box[0] = img
		_task = WorkerThreadPool.add_task(job, true, "sea chart fog")
	return null


## Collects a finished background build. True when a new texture is ready.
static func poll() -> bool:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var img: Image = _task_box[0]
	_task_box = []
	if img == null:
		return false
	if _fog_tex != null and _fog_tex.get_size() == Vector2(img.get_size()):
		_fog_tex.update(img)
	else:
		_fog_tex = ImageTexture.create_from_image(img)
	_fog_sig = _task_sig
	last_build_ms = Time.get_ticks_msec() - _task_t0
	return true


## The cloud art at full strength: shown until the first fog is built, so
## nothing of a locked sea flashes up while the chart opens.
static func fog_placeholder() -> Texture2D:
	return Art.tex(String(data().fog))


static func _load_fog_src() -> void:
	if not _fog_src.is_empty():
		return
	var d := data()
	var a: Image = (load(String(d.fog)) as Texture2D).get_image()
	var k: Image = (load(String(d.fogKey)) as Texture2D).get_image()
	if a.is_compressed():
		a.decompress()
	if k.is_compressed():
		k.decompress()
	a.convert(Image.FORMAT_RGBA8)
	k.convert(Image.FORMAT_RGBA8)
	_fog_src = a.get_data()
	_key = k.get_data()


## Builds the fog image. `open` holds one flag per sea index (1 = open);
## `circles` are Vector3(x, y, radius) clearings and `lanes` are
## [from, to, radius] capsules, all in chart pixels. It reads no game
## state, so a probe can render it offline.
static func build_fog(open: PackedByteArray, circles: Array, lanes: Array) -> Image:
	_load_fog_src()
	var d := data()
	var fs := float(d.fogScale)
	var fw: int = int(d.fogSize[0])
	var fh: int = int(d.fogSize[1])
	# The clearing field is kept at half the fog resolution: it is smooth,
	# and the per-pixel noise below adds the fine detail.
	var gw := (fw + 1) / 2
	var gh := (fh + 1) / 2
	var field := PackedFloat32Array()
	field.resize(gw * gh)
	field.fill(-1.0)
	var gs := fs * 2.0
	for c in circles:
		_stamp_circle(field, gw, gh, c.x / gs, c.y / gs, c.z / gs)
	for l in lanes:
		_stamp_lane(field, gw, gh, (l[0] as Vector2) / gs, (l[1] as Vector2) / gs, float(l[2]) / gs)
	var out := _fog_src.duplicate()
	var key := _key
	var m: int = maxi(1, int(ceil(float(d.margin) / fs)))
	var span := EDGE_HI - EDGE_LO
	# Which sea a pixel lies in, and how far it is from the edge it shares
	# with each locked neighbour (left, right, across the mainland). Seas are
	# numbered along the chart: 0-4 left to right on top, 5-9 right to left
	# below, so the sea below column c is 9 - c.
	var sw := float(d.sea[0]) / fs
	var x0 := float(d.margin) / fs
	var ymid := (float(d.band[0]) + float(d.band[1])) / 2.0 / fs
	var cols := PackedInt32Array()
	var dl := PackedFloat32Array()
	var dr := PackedFloat32Array()
	cols.resize(fw)
	dl.resize(fw)
	dr.resize(fw)
	for x in fw:
		var c := clampi(int(floor((float(x) + 0.5 - x0) / sw)), 0, 4)
		cols[x] = c
		dl[x] = float(x) + 0.5 - (x0 + sw * c)
		dr[x] = x0 + sw * (c + 1) - float(x) - 0.5
	var sea := PackedInt32Array()
	var flags := PackedInt32Array()
	sea.resize(10)
	flags.resize(10)
	for row in 2:
		for c in 5:
			var me := c if row == 0 else 9 - c
			sea[row * 5 + c] = me
			var f := 0
			if c > 0 and open[(c - 1) if row == 0 else 9 - (c - 1)] == 0:
				f |= 1
			if c < 4 and open[(c + 1) if row == 0 else 9 - (c + 1)] == 0:
				f |= 2
			if open[(9 - c) if row == 0 else c] == 0:
				f |= 4
			flags[row * 5 + c] = f
	for y in fh:
		var row := y * fw
		var grow := (y >> 1) * gw
		var by := (y & 3) * 4
		var edge_y := y < m or y >= fh - m
		var tile0 := 0 if float(y) + 0.5 < ymid else 5
		var dv := absf(float(y) + 0.5 - ymid)
		for x in fw:
			var i := (row + x) * 4
			var a := 0
			if not (edge_y or x < m or x >= fw - m):
				var g: int = key[i + 1]
				var tile := tile0 + cols[x]
				if open[g >> 4] == 0 or open[sea[tile]] == 0:
					a = FOG_DENSE
				else:
					var n := (float(key[i]) - 128.0) / 512.0
					var th: float = (BAYER[by + (x & 3)] + 0.5) / 16.0
					if (g & 8) == 0:
						var v: float = field[grow + (x >> 1)] + n
						if v < EDGE_LO or (v < EDGE_HI and (v - EDGE_LO) / span < th):
							a = FOG_HAZE
							out[i] = HAZE_RGB[0]
							out[i + 1] = HAZE_RGB[1]
							out[i + 2] = HAZE_RGB[2]
					var f := flags[tile]
					if f != 0:
						var dd := 1000.0
						if f & 1:
							dd = dl[x]
						if f & 2:
							dd = minf(dd, dr[x])
						if f & 4:
							dd = minf(dd, dv)
						if (dd + n * 16.0) / BANK < th:
							a = FOG_DENSE
							out[i] = _fog_src[i]
							out[i + 1] = _fog_src[i + 1]
							out[i + 2] = _fog_src[i + 2]
			out[i + 3] = a
	return Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, out)


## Max-stamps 1 - d/r around a point. The stamp reaches 1.4 r so the field
## falls well below the noise range before it ends (no visible box edge).
static func _stamp_circle(field: PackedFloat32Array, w: int, h: int, cx: float, cy: float, r: float) -> void:
	var reach := r * 1.4
	var y0 := maxi(0, floori(cy - reach))
	var y1 := mini(h - 1, ceili(cy + reach))
	for y in range(y0, y1 + 1):
		var dy := float(y) + 0.5 - cy
		var hw2 := reach * reach - dy * dy
		if hw2 <= 0.0:
			continue
		var hw := sqrt(hw2)
		var x0 := maxi(0, floori(cx - hw))
		var x1 := mini(w - 1, ceili(cx + hw))
		var row := y * w
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var v := 1.0 - sqrt(dx * dx + dy * dy) / r
			if v > field[row + x]:
				field[row + x] = v


static func _stamp_lane(field: PackedFloat32Array, w: int, h: int, a: Vector2, b: Vector2, r: float) -> void:
	var reach := r * 1.4
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
	var ab := b - a
	var ll := maxf(ab.length_squared(), 0.0001)
	for y in range(maxi(0, floori(lo.y)), mini(h - 1, ceili(hi.y)) + 1):
		var row := y * w
		for x in range(maxi(0, floori(lo.x)), mini(w - 1, ceili(hi.x)) + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t := clampf((p - a).dot(ab) / ll, 0.0, 1.0)
			var v := 1.0 - p.distance_to(a + ab * t) / r
			if v > field[row + x]:
				field[row + x] = v
