class_name ArenaScene
extends RefCounted
## The setting of a land battle (battle_view): a natural coast (Coast) laid
## out round a fixed fight band, set pieces behind the band, region props
## in groves and on the flanks, and low clutter in front.
##
## Positions are screen px from the fight centre, on the drawn ground (a
## raised cell's surface is drawn 8px up). Units stand, enter (allies from
## the left, later waves from the right) and fall inside FIGHT, which is
## always raised ground. No prop stands in it, and no prop's sprite reaches
## into it unless the prop stands behind it (and so is drawn behind every
## unit).
##
## The set pieces depend on the location kind (island cove, beached wreck,
## grotto lagoon, walled pit, pillared hall underground), on the foe (an
## enemy camp for people, a lair for beasts) and on the encounter (a shrine
## of obelisk, braziers and standards for bosses and trials, standards for
## elites).

const FIGHT := Rect2(-236, -60, 566, 124)
## The worn fighting ground: a noisy ellipse round the clash line.
const WORN_C := Vector2(40, 0)
const WORN_R := Vector2(286, 56)
## Per location kind: beach bias, worn ground [outer, inner], Coast style.
const KINDS := {
	"island": {"beach": 0.2, "worn": ["path", "dirt"], "style": {"trail": "path", "pad": "dirt"}},
	"port": {"beach": 0.0, "worn": ["path", "cobble0"], "style": {}},
	"wreck": {"beach": 0.9, "worn": ["sand1", "wetsand"],
		"style": {"base": "sand0", "alt": "dune", "lush": "grass3", "meadow": "sand1", "cliff": "dune", "side": "sandside"}},
	"secret": {"beach": 0.0, "worn": ["moss", "grass3"], "style": {"alt": "moss"}},
	"arena": {"beach": -0.4, "worn": ["slab0", "slab1"], "style": {"alt": "rubble", "cliff": "rubble", "side": "stone"}},
	"dungeon": {"beach": -4.0, "worn": ["floor0", "floor1"],
		"style": {"base": "stone1", "alt": "rubble", "lush": "rubble", "meadow": "floor1", "dune": "rubble", "cliff": "rubble",
			"side": "dark"}},
}
const WARM := Color(1.0, 0.66, 0.34)
const COOL := Color(0.62, 0.8, 1.0)
const NONE := Vector2(INF, INF)

var kind := "island"
var rid := ""
var coast: Coast
## [name, Vector2 foot on the drawn ground, regional variant]
var props: Array = []
## [Vector2 position, Color, texture scale]
var lights: Array = []
## Underground: no sea, a dark void round the platform.
var underground := false
## CanvasModulate colour before the time of day.
var tint := Color.WHITE
## Authored location/room dressing, independent of combat simulation.
var profile: Dictionary = {}
var landmark_at := Vector2(80, -128)
var landmark_foot := Rect2()
var _rng := RandomNumberGenerator.new()
var _used := {}
var _tall: Array = []
var _small: Array = []


## kind: the location type; key: a stable id of the room (the same room
## always gets the same arena); people: the foes are people rather than
## beasts; tier: "battle", "elite", "boss" or "trial".
func build(kind_: String, rid_: String, key: String, people: bool, tier: String, profile_: Dictionary = {}) -> void:
	kind = kind_ if KINDS.has(kind_) else "island"
	rid = rid_
	profile = profile_
	landmark_at = SceneProfiles.point(profile.get("landmarkOffset", [80, -128]))
	var landmark := Art.world_landmark(rid, int(profile.get("landmarkVariant", 0)))
	var art_foot: Vector2 = landmark.get("footprint", Vector2(144, 64))
	var profile_foot := SceneProfiles.point(profile.get("landmarkFootprint", [108, 36]))
	var foot_size := Vector2(maxf(144.0, maxf(art_foot.x, profile_foot.x)), maxf(64.0, maxf(art_foot.y, profile_foot.y)))
	landmark_at.y = minf(landmark_at.y, FIGHT.position.y - foot_size.y * 0.5 - 20.0)
	landmark_foot = Rect2(landmark_at - foot_size * 0.5, foot_size)
	underground = kind == "dungeon"
	_rng.seed = U.hash32("arena:" + key)
	var cfg: Dictionary = KINDS[kind]
	coast = Coast.new()
	coast.setup(Rect2i(-28, -28, 57, 57), U.hash32("arenacoast:" + key))
	coast.use_region(rid)
	coast.beach_bias = float(cfg.beach)
	for k in cfg.style:
		coast.style[k] = cfg.style[k]
	_shape_land()
	if not profile.is_empty():
		for y in range(coast.rect.position.y, coast.rect.end.y):
			for x in range(coast.rect.position.x, coast.rect.end.x):
				if landmark_foot.grow(8.0).has_point(Art.iso(x, y) - Vector2(0, 8)):
					coast.force_land(Vector2i(x, y))
	_force_fight(cfg.worn)
	coast.generate()
	# Reserve the landmark footing before scattering any ordinary props.
	# Everything remains behind the combat strip, including wave entries.
	if not profile.is_empty():
		for i in coast.lvl.size():
			var c := coast.cell_of(i)
			if landmark_foot.grow(8.0).has_point(Art.iso(c.x, c.y) - Vector2(0, 8)):
				_used[c] = true
	_pools()
	var ceremony := tier == "boss" or tier == "trial"
	match kind:
		"dungeon":
			tint = Color(0.68, 0.65, 0.77)
			_hall(ceremony)
		"wreck":
			_beached_wreck()
		"secret":
			tint = Color(0.78, 0.74, 0.95)
			_grotto()
		"arena":
			_pit()
		_:
			_cove()
	if kind != "dungeon":
		if ceremony:
			_shrine(Vector2(92, -104), tier == "trial")
		elif people:
			_camp(Vector2(92, -98))
		else:
			_lair(Vector2(92, -94))
		if tier == "elite":
			_place("standard", Vector2(-14, -76), true)
			_place("standard", Vector2(196, -80), true)
	else:
		_hall_foes(people)
	_profile_set_pieces()
	_scatter_back()
	_scatter_front()
	_shore()
	_sea_rocks()
	if not underground:
		tint *= Color.html(String(SceneProfiles.region(rid).get("light_day", "#fff7e9")))


func _profile_set_pieces() -> void:
	for piece in profile.get("setPieces", []):
		if not (piece is Array) or piece.size() < 4:
			continue
		var nm := String(piece[0])
		var at := Vector2(float(piece[1]), float(piece[2]))
		# put() verifies dry ground, occupancy and the complete fight band.
		if put(nm, at, bool(piece[3])) and nm == "brazier":
			light(at + Vector2(0, -18), Color.html(String(SceneProfiles.region(rid).get("warm_light", "#ffcc7a"))), 0.75)


# ------------------------------------------------------------- the land
static func g(p: Vector2) -> Vector2:
	return Art.uniso(p)


func _shape_land() -> void:
	var c := coast
	if not profile.is_empty():
		c.add_disk(g(landmark_at), 4.8)
	if underground:
		# A rock platform: the fighting floor and a hall behind it.
		c.add_capsule(g(Vector2(-330, 2)), g(Vector2(400, 2)), 6.0)
		c.add_capsule(g(Vector2(-300, -100)), g(Vector2(380, -100)), 3.6)
		c.add_disk(g(Vector2(40, -150)), 4.2)
		c.add_capsule(g(Vector2(-180, 70)), g(Vector2(240, 78)), 2.8)
		return
	# A broad ridge along the fight band, hinterland behind it where the
	# set pieces stand, and an uneven front shore.
	c.add_capsule(g(Vector2(-340, 0)), g(Vector2(410, 0)), 6.2)
	c.add_disk(g(Vector2(70, -122)), 6.4)
	c.add_disk(g(Vector2(260, -104)), 5.4)
	c.add_disk(g(Vector2(-110, -104)), 4.8)
	c.add_capsule(g(Vector2(-210, 64)), g(Vector2(240, 80)), 3.2)
	match kind:
		"wreck":
			# A wide bay behind the landing party where the wreck came ashore.
			c.cut_disk(g(Vector2(-210, -168)), 4.6)
			c.cut_disk(g(Vector2(-330, -96)), 3.0)
		"secret":
			# A lagoon pool inland, behind the fight.
			c.cut_disk(g(Vector2(-112, -150)), 2.5)
			c.add_reef(g(Vector2(-60, 160)), 3.0)
		"arena":
			pass
		_:
			# A cove behind the party, open to the sea on the left.
			c.cut_disk(g(Vector2(-262, -122)), 3.4)
			c.add_reef(g(Vector2(-300, -170)), 2.5)


## Raised, unbroken ground under the whole fight band (and a margin), worn
## to the kind's ground round the clash line with a ragged edge.
func _force_fight(worn: Array) -> void:
	var r := coast.rect
	var area := FIGHT.grow(14.0)
	var tn := FastNoiseLite.new()
	tn.seed = coast.seed + 31
	tn.frequency = 0.22
	var lift := float(Coast.LIFT[Coast.HIGH])
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var top := Art.iso(x, y) - Vector2(0, lift)
			if not area.has_point(top):
				continue
			var q := (top - WORN_C) / WORN_R
			var e := q.length_squared() + 0.22 * tn.get_noise_2d(float(x), float(y))
			var h := Coast.ihash(x, y, coast.seed + 5) % 100
			var nm := ""
			if e < 1.0:
				nm = String(worn[0])
				if kind == "arena" and e > 0.8:
					nm = "cobble1"
				elif e < 0.5 and h < 38:
					nm = String(worn[1])
				elif e > 0.62 and h < 7 and kind != "arena" and kind != "dungeon":
					nm = ""
			elif kind == "dungeon" and h < 30:
				nm = "rubble"
			coast.force_land(Vector2i(x, y), nm)


# -------------------------------------------------------------- placing
## The cell whose drawn surface holds screen point p: raised ground, or a
## low beach when low_ok. Vector2i(99999, 99999) when neither.
func _cell_under(p: Vector2, low_ok: bool) -> Vector2i:
	var c := coast.cell_at(p)
	if coast.level(c) == Coast.HIGH:
		return c
	if low_ok:
		var gl := Art.uniso(p + Vector2(0, float(Coast.LIFT[Coast.LOW])))
		var c2 := Vector2i(roundi(gl.x), roundi(gl.y))
		if coast.level(c2) == Coast.LOW:
			return c2
	return Vector2i(99999, 99999)


## True when a prop's sprite at p keeps out of the fight band (props
## standing behind the band may overlap it: they are drawn behind units).
func clear_of_fight(name: String, p: Vector2, regional: bool) -> bool:
	if FIGHT.grow(6.0).has_point(p):
		return false
	if p.y < FIGHT.position.y:
		return true
	var pr: Dictionary = Art.prop(name, rid if regional else "")
	if pr.is_empty():
		return false
	var rect := Rect2(p - pr.anchor, pr.tex.get_size())
	return not rect.intersects(FIGHT)


## Stands a prop at screen point p on dry ground (raised unless low_ok);
## the cells within r of it must be dry and free of other props. False
## when the spot does not qualify.
func put(name: String, p: Vector2, regional := true, r := 0, low_ok := false) -> bool:
	var c := _cell_under(p, low_ok)
	if c.x == 99999:
		return false
	var need := Coast.LOW if low_ok else Coast.HIGH
	var cells: Array[Vector2i] = []
	for oy in range(-r, r + 1):
		for ox in range(-r, r + 1):
			if ox * ox + oy * oy > r * r + 1:
				continue
			var o := c + Vector2i(ox, oy)
			if coast.level(o) < need or _used.has(o):
				return false
			cells.append(o)
	if Art.prop(name, rid if regional else "").is_empty():
		return false
	if not clear_of_fight(name, p, regional):
		return false
	for o in cells:
		_used[o] = true
	props.append([name, p, regional])
	return true


## put() at p or, failing that, at a few nearby spots. Returns where the
## prop went, or NONE.
func _place(name: String, p: Vector2, regional := true, r := 0, low_ok := false, tries := 7) -> Vector2:
	for k in tries:
		var q := p
		if k > 0:
			q += Vector2(_rng.randf_range(-12.0, 12.0), _rng.randf_range(-6.0, 6.0)) * (1.0 + float(k) * 0.5)
		q = q.round()
		if put(name, q, regional, r, low_ok):
			return q
	return NONE


## A prop standing in the water near p (sea stacks, rocks in a cove).
func _place_sea(name: String, p: Vector2) -> bool:
	var gp := Art.uniso(p)
	var c := Vector2i(roundi(gp.x), roundi(gp.y))
	if coast.level(c) != Coast.WATER or _used.has(c):
		return false
	var at := Art.iso(c.x, c.y) + Vector2(0, 1)
	if not clear_of_fight(name, at, true):
		return false
	_used[c] = true
	props.append([name, at, true])
	return true


func light(p: Vector2, color: Color, scale_f: float) -> void:
	lights.append([p, color, scale_f])


## A lit prop with its glow `up` px above its foot.
func _lit(name: String, p: Vector2, regional: bool, color: Color, scale_f: float, up: float) -> void:
	var at := _place(name, p, regional)
	if at != NONE:
		light(at + Vector2(0, -up), color, scale_f)


func _pools() -> void:
	var pool: Array = Art.env.regionProps.get(rid, ["rock", "bush"])
	if kind == "dungeon":
		pool = ["stalagmite", "rock_big", "pillar_broken", "rock", "bones"]
	elif kind == "arena":
		pool = pool.filter(func(n): return n != "palm")
	for n in pool:
		if SiteView.TALL_PROPS.has(n) or n == "rock_big" or n == "stalagmite":
			_tall.append(n)
		else:
			_small.append(n)
	if _tall.is_empty():
		_tall = ["rock_big"]
	if _small.is_empty():
		_small = ["rock", "bush"]


# ---------------------------------------------------------- set pieces
## Island and port: a cove behind the landing party with stacks in the
## water and trees on its shore.
func _cove() -> void:
	for p in [Vector2(-286, -132), Vector2(-238, -150), Vector2(-318, -108)]:
		_place_sea("sea_stack" if p.x > -300 else "sea_rock", p)
	var tree: String = "palm" if _tall.has("palm") else String(_tall[0])
	for p in [Vector2(-196, -96), Vector2(-226, -82), Vector2(-160, -118)]:
		_place(tree, p, true, 0, true)
	_place("driftwood", Vector2(-250, -70), true, 0, true)
	_place("signpost", Vector2(-252, 76), false)


## Wreck: the hull beached in the bay behind the party, ribs and a fallen
## mast, cargo strewn towards the fight.
func _beached_wreck() -> void:
	_place("wreck_hull", Vector2(-150, -98), false, 1, true)
	_place("mast_fallen", Vector2(-40, -78), false, 1, true)
	_place("ribs", Vector2(-262, -74), false, 0, true)
	_place("barrels", Vector2(-84, -70), false)
	_place("crate", Vector2(-206, -66), false, 0, true)
	_place("sacks", Vector2(-10, -102), false)
	_place("cannon", Vector2(-108, -128), false, 0, true)
	_place("chest_open", Vector2(-256, 84), false, 0, true)
	_place("driftwood", Vector2(180, 86), true, 0, true)
	_place("barrel", Vector2(-170, 90), false, 0, true)


## Secret: a lagoon pool ringed by crystals and mushrooms, dripstones on
## the flanks, cool light.
func _grotto() -> void:
	for p in [Vector2(-160, -130), Vector2(-64, -126), Vector2(-150, -82), Vector2(-46, -88)]:
		var at := _place("crystal" if int(p.x) % 3 != 0 else "mushroom", p, true)
		if at != NONE:
			light(at + Vector2(0, -14), COOL, 0.6)
	_place("stalagmite", Vector2(-276, -40), true, 1)
	_place("stalagmite", Vector2(-212, -84), true)
	_place("mushroom", Vector2(-100, -72), true)
	_place("crystal", Vector2(-262, 80), true)
	_place("mushroom", Vector2(150, 92), true)


## Arena: a paved pit walled by low barriers along its back and front,
## standards at the gaps, statues flanking an arch behind the party.
func _pit() -> void:
	var back_y := -74.0
	for x in [-210, -150, -90, -30, 190, 250, 310]:
		_place("barrier", Vector2(x, back_y + float(x) * 0.02), true, 0, false, 2)
	for x in [-190, -120, -50, 20, 90, 160, 230]:
		_place("barrier", Vector2(x, 96.0), true, 0, false, 2)
	_place("standard", Vector2(-248, -76), true)
	_place("standard", Vector2(342, -70), true)
	_place("ruin_arch", Vector2(-120, -124), true, 1)
	_place("statue", Vector2(-188, -112), true)
	_place("statue", Vector2(-52, -134), true)
	_lit("brazier", Vector2(-268, 30), false, WARM, 0.8, 18)
	_lit("brazier", Vector2(-262, -40), false, WARM, 0.8, 18)


## Dungeon: a pillared hall behind the floor with an arch and braziers in
## its middle, dripstones on the flanks, bones in front, torchlight.
func _hall(ceremony: bool) -> void:
	var xs := [-232, -164, -96, 176, 244, 312]
	for i in xs.size():
		var nm := "pillar_broken" if i == 1 or i == 4 else "pillar"
		_place(nm, Vector2(float(xs[i]), -80.0 - float(i % 2) * 6.0), true, 0)
	if ceremony:
		_place("obelisk", Vector2(40, -116), true, 1)
	else:
		_place("ruin_arch", Vector2(40, -112), true, 1)
	_lit("brazier", Vector2(-6, -74), false, WARM, 0.9, 18)
	_lit("brazier", Vector2(88, -76), false, WARM, 0.9, 18)
	_place("standard", Vector2(-40, -92), true)
	_place("standard", Vector2(124, -96), true)
	_place("stalagmite", Vector2(-292, -24), true, 1)
	_place("stalagmite", Vector2(-270, 46), true)
	_place("stalagmite", Vector2(376, -20), true, 1)
	_place("bones", Vector2(-120, 88), true)
	_place("rock", Vector2(70, 94), true)
	# a soft pool of light over the floor so the fight reads in the dark
	light(Vector2(40, -4), Color(0.75, 0.68, 0.6), 3.2)


func _hall_foes(people: bool) -> void:
	if people:
		_place("rack", Vector2(214, -110), false)
		_place("barrels", Vector2(270, -104), false)
		_place("crate", Vector2(-212, -112), false)
	else:
		_place("bone_pile", Vector2(214, -110), false)
		_place("lair_nest", Vector2(-200, -116), false, 1)


## People: tents, a campfire, a weapon rack, stores and a palisade behind
## the enemy line.
func _camp(at: Vector2) -> void:
	_place("tent", at + Vector2(-48, -8), false, 1)
	_place("tent_b", at + Vector2(46, -24), false, 1)
	var f := _place("campfire", at + Vector2(0, 12), false)
	if f != NONE:
		light(f + Vector2(0, -6), WARM, 0.8)
	_place("rack", at + Vector2(-104, 10), false)
	_place("barrels", at + Vector2(98, 4), false)
	_place("crate", at + Vector2(80, 18), false)
	_place("sacks", at + Vector2(-8, -36), false)
	_place("flag", at + Vector2(16, -50), false)
	_place("stakes_x", at + Vector2(-124, -34), false)
	_place("stakes_y", at + Vector2(146, -38), false)


## Beasts: big rocks, a nest, gnawed bones and a dead tree.
func _lair(at: Vector2) -> void:
	_place("rock_big", at + Vector2(-62, -10), true, 1)
	_place("rock_big", at + Vector2(66, -28), true, 1)
	_place("lair_nest", at + Vector2(6, -18), false, 1)
	_place("bone_pile", at + Vector2(-16, 14), false)
	_place("bones", at + Vector2(52, 12), true)
	_place("dead_tree", at + Vector2(-112, -26), true)
	_place("rock", at + Vector2(110, 8), true)


## Bosses and trials: an obelisk (an arch for a trial) between two lit
## braziers, standards beyond them.
func _shrine(at: Vector2, trial: bool) -> void:
	_place("ruin_arch" if trial else "obelisk", at, true, 1)
	_lit("brazier", at + Vector2(-52, 28), false, WARM, 0.9, 18)
	_lit("brazier", at + Vector2(52, 26), false, WARM, 0.9, 18)
	_place("standard", at + Vector2(-100, 20), true)
	_place("standard", at + Vector2(100, 14), true)
	_place("bones" if not trial else "pillar_broken", at + Vector2(-150, -8), true)
	_place("statue", at + Vector2(150, -16), true)


# --------------------------------------------------------- the backdrop
## Groves of the region's tall props behind the set pieces and on both
## flanks, thinned by a slow noise, small props at their edges.
func _scatter_back() -> void:
	var gn := FastNoiseLite.new()
	gn.seed = coast.seed + 77
	gn.frequency = 0.012
	var y := -232.0
	var row := 0
	while y < 80.0:
		var x := -360.0 + (12.0 if row % 2 else 0.0)
		while x < 460.0:
			var p := Vector2(x + _rng.randf_range(-8.0, 8.0), y + _rng.randf_range(-4.0, 4.0)).round()
			x += 34.0
			if p.y > FIGHT.position.y - 4.0 and p.x > FIGHT.position.x - 40.0 and p.x < FIGHT.end.x + 40.0:
				continue
			var n := gn.get_noise_2dv(p)
			var roll := _rng.randf()
			if n > 0.12 and roll < 0.75:
				_place(String(_tall[_rng.randi() % _tall.size()]), p, true, 0, false, 1)
			elif n > -0.2 and roll < 0.22:
				_place(String(_small[_rng.randi() % _small.size()]), p, true, 0, false, 1)
		y += 17.0
		row += 1


## Sparse low clutter in front of the fight (nothing reaches into it).
func _scatter_front() -> void:
	var low := ["rock", "bush", "tuft", "herb"]
	if kind == "dungeon":
		low = ["rock", "bones"]
	elif kind == "wreck":
		low = ["rock", "tuft", "driftwood"]
	var y := 74.0
	while y < 210.0:
		var x := -340.0 + _rng.randf_range(0.0, 30.0)
		while x < 440.0:
			if _rng.randf() < 0.2:
				_place(String(low[_rng.randi() % low.size()]), Vector2(x, y).round(), true, 0, true, 1)
			x += _rng.randf_range(36.0, 70.0)
		y += 16.0


## Dune grass and driftwood on the beaches.
func _shore() -> void:
	if underground:
		return
	for i in coast.lvl.size():
		if coast.lvl[i] != Coast.LOW:
			continue
		var c := coast.cell_of(i)
		var h := Coast.ihash(c.x, c.y, coast.seed + 13) % 1000
		var nm := ""
		if h < 70:
			nm = "tuft"
		elif h > 975:
			nm = "driftwood"
		if nm == "" or _used.has(c):
			continue
		var at := Art.iso(c.x, c.y) + Vector2(float(h % 7) - 3.0, float((h / 7) % 5) - 2.0 - coast.lift(c))
		if clear_of_fight(nm, at, true):
			_used[c] = true
			props.append([nm, at, true])


func _sea_rocks() -> void:
	if underground:
		return
	for r in coast.rocks:
		var rp: Vector2 = r[0]
		var at := Art.iso(rp.x, rp.y) + Vector2(0, 1)
		if clear_of_fight(String(r[1]), at, true):
			props.append([String(r[1]), at, true])
