class_name ShipDress
extends RefCounted
## Deterministic dressing for the interior levels of a hull (view only).
##
## Facilities furnish the rooms; the dressing composes the rest of each
## interior level so it reads as a working ship, not an empty floor:
##   - frame columns split the level into compartments. On the orlop and in
##     the hold, plank partitions run in from the far wall at each frame and
##     end in a door post with the door hooked open and a lantern; each
##     compartment is furnished as one kind of room (store, sail room,
##     berths, carpenter; dry goods, casks, stores, grain and hens);
##   - stanchions stand beside the corridor at the frames;
##   - guns under the gun-deck ports with powder, shot, chests and hammocks;
##   - mess tables under hanging lanterns in the middle of the gun deck, sail
##     and cable islands on the orlop, cargo islands in the hold;
##   - runners (or duckboards in the hold) along the routes between the
##     ladders, hatches, bulkhead doors and every facility's work spots, and
##     worn, patched or grated boards elsewhere;
##   - low battens on the fronts of the hold's cargo.
## Runs along the walls are broken so the floor shows between pieces.
##
## The rules side (Rules.walkable, layout analysis, placement) ignores the
## dressing. The ship view treats dressed cells as blocked for crew pathing,
## so placement keeps navigation intact: a cell is dressed only when it is
## not on a route, not beside a ladder or hatch, not a cell that must stay
## clear (facility fronts and work-spot access, door sides) and when its free
## neighbours stay connected without it. Every cell the crew could reach
## before the dressing therefore stays reachable.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const RING := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

## Item pools per level theme and placement role. Roles:
##   back   - against the far wall (y = 0), back to the wall (rot 0)
##   alcove - inside a compartment, in front of the far wall (orlop, hold)
##   stern  - against the stern end (x = 0), back to it (rot 1)
##   bay    - the hold row in front of the near row: cargo bays
##   front  - the cut-away near row (y = h - 1): low pieces only
##   mid    - islands in the open middle of the level
const POOLS := {
	"lower": {
		"back": ["shot_rack", "chests", "hammock", "water_butt", "workbench", "powder", "hammock"],
		"stern": ["hammock", "chests", "water_butt", "shot_rack"],
		"front": ["powder", "chests", "rope_coil", "lantern", "chests"],
		"mid": ["mess_table"],
	},
	"orlop": {
		"back": ["lockers", "shelves", "hammock", "workbench", "water_butt", "barrels", "crates", "lockers"],
		"stern": ["lockers", "cable", "sails", "shelves"],
		"front": ["chests", "rope_coil", "cable", "sails", "lumber", "lantern"],
		"mid": ["sails", "cable", "chests", "barrels", "lumber", "crates"],
	},
	"hold": {
		"back": ["crates_tall", "barrels", "crates", "shelves", "cask", "net_cargo", "sacks", "crates_tall"],
		"stern": ["crates_tall", "barrels", "net_cargo", "cask"],
		"bay": ["crates", "barrels", "sacks", "cask", "net_cargo", "lumber", "ballast", "coop", "barrels"],
		"front": ["sacks", "ballast", "lumber", "rope_coil", "lantern", "barrels"],
		"mid": ["crates_tall", "net_cargo", "cask", "crates", "barrels", "sacks"],
	},
}
## Compartment kinds (orlop and hold): the far wall and alcove cells of each
## compartment between two frames draw from one of these.
const ROOMS := {
	"orlop": [
		["lockers", "shelves", "barrels", "crates", "lockers"],
		["sails", "sails", "cable", "rope_coil", "lumber"],
		["hammock", "chests", "hammock", "water_butt", "chests"],
		["workbench", "lumber", "crates", "rope_coil", "shelves"],
	],
	"hold": [
		["crates_tall", "crates", "sacks", "crates"],
		["cask", "barrels", "cask", "barrels"],
		["net_cargo", "crates", "ballast", "lumber"],
		["sacks", "coop", "sacks", "barrels"],
	],
}
## At most one of these per level.
const ONCE := ["workbench", "water_butt", "coop", "pump", "cable", "shelves"]
## Pieces with no per-level count limit.
const UNCAPPED := ["gun", "partition", "partition_end", "pillar", "mess_table"]
## Share of each role's cells that may be dressed, per level theme.
const FILL := {
	"lower": {"back": 1.0, "stern": 0.5, "front": 0.45},
	"orlop": {"back": 1.0, "stern": 0.5, "alcove": 0.45, "front": 0.4},
	"hold": {"back": 1.0, "stern": 0.6, "alcove": 0.55, "bay": 0.6, "front": 0.4},
}
## Longest unbroken run of pieces per role (along x; along y at the stern).
const RUN := {"front": 2, "bay": 3, "alcove": 2, "stern": 3}
## Pieces that get battens on their open fronts in the hold.
const CARGO := ["crates", "crates_tall", "barrels", "sacks", "cask", "net_cargo", "lumber", "ballast"]
## Pieces that light their surroundings (spacing for free-standing lanterns).
const LIT := ["lantern", "partition_end", "mess_table"]
const ROLE_RANK := {"back": 0, "stern": 1, "alcove": 2, "bay": 3, "front": 4}
const PATCHES := {"lower": ["sand", "scuff", "boards", "grate"], "orlop": ["scuff", "stain", "boards"], "hold": ["straw", "stain", "boards"]}


static func theme_of(dk: Dictionary) -> String:
	var id := String(dk.get("id", ""))
	return id if POOLS.has(id) else "orlop"


static func _hash(s: String) -> int:
	return absi(s.hash())


## Rows (from the far wall) that partitions reach into.
static func _depth(theme: String, h: int) -> int:
	if theme == "lower":
		return 0
	if theme == "hold":
		return 2
	return 2 if h <= 6 else 3


static func _role(c: Vector2i, w: int, h: int, theme: String) -> String:
	if c.y == 0:
		return "back"
	if c.y == h - 1:
		return "front"
	if theme == "hold" and c.y == h - 2:
		return "bay"
	if c.y < _depth(theme, h):
		return "alcove"
	if c.x == 0:
		return "stern"
	return ""


## Frame columns: every 5-6 cells, where the far wall cell and both its
## neighbours are open floor (not facilities, bulkheads or kept cells).
static func _frames(free: Dictionary, blocked: Dictionary, w: int, salt: String) -> Array:
	var out := []
	var step := 5 if w <= 16 else 6
	var x := 3 + _hash(salt + ":f") % 2
	while x <= w - 3:
		var pick := -1
		for dx in [0, 1, -1]:
			var fx: int = x + dx
			if free.has(Vector2i(fx, 0)) and free.has(Vector2i(fx - 1, 0)) and free.has(Vector2i(fx + 1, 0)) \
					and not blocked.has(Vector2i(fx, 0)) and (out.is_empty() or fx - int(out[-1]) >= 4):
				pick = fx
				break
		if pick >= 0:
			out.append(pick)
			x = pick + step
		else:
			x += 1
	return out


static func _zone(x: int, frames: Array) -> int:
	var z := 0
	for fx in frames:
		if int(fx) < x:
			z += 1
	return z


## Pieces in an unbroken line through c (c included), along x or along y.
static func _run(c: Vector2i, dressed: Dictionary, along_y: bool) -> int:
	var o := Vector2i(0, 1) if along_y else Vector2i(1, 0)
	var n := 1
	var p := c + o
	while dressed.has(p):
		n += 1
		p += o
	p = c - o
	while dressed.has(p):
		n += 1
		p -= o
	return n


## Layout for one interior deck.
##   dk      - the deck dictionary (id, w, h, fixed, ...)
##   free    - {Vector2i: true} cells the crew can stand on (no facility,
##             fixture or bulkhead wall), as reached from the gangway
##   portals - {Vector2i: true} ladder and hatch cells on this deck
##   goals   - [Vector2i] cells the routes must join: portal approach cells,
##             bulkhead door sides and facility work-spot access cells
##   keep    - {Vector2i: true} cells that must stay clear
##   salt    - per-hull, per-deck string for the deterministic choices
## Returns {items: [{x, y, name, rot}], fences: [{x, y, edge}],
##          floor: [{x, y, set, key}], routes: {Vector2i: true}}.
static func layout(dk: Dictionary, free: Dictionary, portals: Dictionary, goals: Array, keep: Dictionary, salt: String) -> Dictionary:
	var w := int(dk.w)
	var h := int(dk.h)
	var theme := theme_of(dk)
	var routes := _routes(free, portals, goals, h)
	var blocked := {}
	for c in keep:
		blocked[c] = true
	for c in routes:
		blocked[c] = true
	for p in portals:
		blocked[p] = true
		for o in DIRS:
			blocked[p + o] = true
	var trunk_x := -1
	for fx in dk.get("fixed", []):
		if String(fx[2]) == "trunk":
			trunk_x = int(fx[0])
			break
	var st := {"dressed": {}, "used": {}, "count": {}, "lit": [], "items": [],
		"cap_each": maxi(2, int(ceil(float(free.size()) / 24.0)))}
	var dressed: Dictionary = st.dressed
	var items: Array = st.items
	# 1. Structure: partitions from the far wall at each frame (orlop, hold)
	#    and a stanchion beside the corridor.
	var frames := _frames(free, blocked, w, salt)
	var depth := _depth(theme, h)
	var spine := (h - 1) * 0.5
	for fx in frames:
		var placed := []
		for y in depth:
			var c := Vector2i(fx, y)
			if not free.has(c) or blocked.has(c) or dressed.has(c) or not _keeps_connected(c, free, dressed, portals):
				break
			dressed[c] = "partition"
			placed.append(c)
		for i in placed.size():
			var pc: Vector2i = placed[i]
			var nm := "partition_end" if i == placed.size() - 1 else "partition"
			dressed[pc] = nm
			items.append({"x": pc.x, "y": pc.y, "name": nm, "rot": 0})
		if not placed.is_empty():
			st.lit.append(placed[-1])
		if theme != "lower" and _hash("%s:s:%d" % [salt, fx]) % 2 == 0:
			continue
		var rows := []
		for y in range(maxi(1, depth), h - 1):
			rows.append(y)
		rows.sort_custom(func(a, b): return absf(a - spine) < absf(b - spine))
		for y in rows:
			var c := Vector2i(fx, y)
			if not free.has(c) or blocked.has(c) or dressed.has(c):
				continue
			var near := false
			for o in RING:
				if dressed.has(c + o):
					near = true
			if near or not _keeps_connected(c, free, dressed, portals):
				continue
			_put(st, c, "pillar", 0)
			break
	# 2. Walls: far wall, compartments, stern, bays, near row.
	var cands := []
	var role_cells := {}
	for c in free:
		if blocked.has(c) or dressed.has(c):
			continue
		var role := _role(c, w, h, theme)
		if role == "" or not FILL[theme].has(role):
			continue
		role_cells[role] = int(role_cells.get(role, 0)) + 1
		cands.append({"c": c, "role": role, "k": ROLE_RANK[role] * 100000 + _hash("%s:%d:%d" % [salt, c.x, c.y]) % 100000})
	cands.sort_custom(func(a, b): return a.k < b.k)
	var role_put := {}
	for e in cands:
		var c: Vector2i = e.c
		var role: String = e.role
		if int(role_put.get(role, 0)) >= int(round(float(FILL[theme][role]) * float(role_cells[role]))):
			continue
		if RUN.has(role) and _run(c, dressed, role == "stern") > int(RUN[role]):
			continue
		var pool := _pool(theme, role, _zone(c.x, frames), salt)
		var item := _pick(theme, role, c, pool, st, trunk_x, salt)
		if item == "" or not _keeps_connected(c, free, dressed, portals):
			continue
		var rot := 0
		if role == "stern":
			rot = 1
		elif role == "bay":
			rot = _hash("%s:r:%d:%d" % [salt, c.x, c.y]) % 2
		_put(st, c, item, rot)
		role_put[role] = int(role_put.get(role, 0)) + 1
	# 3. Islands in the open middle: one mess table per gun-deck compartment,
	#    a few sail, cable or cargo islands elsewhere. Each stands clear of
	#    every other piece.
	var mids := []
	for c in free:
		if blocked.has(c) or dressed.has(c) or _role(c, w, h, theme) != "":
			continue
		if theme == "lower" and (c.y < 2 or c.y > h - 3):
			continue
		mids.append({"c": c, "k": _hash("%s:m:%d:%d" % [salt, c.x, c.y])})
	mids.sort_custom(func(a, b): return a.k < b.k)
	var mid_cap := frames.size() + 1 if theme == "lower" else maxi(1, int(round(float(mids.size()) * 0.08)))
	var per_zone := {}
	var placed_mid := 0
	for e in mids:
		if placed_mid >= mid_cap:
			break
		var c: Vector2i = e.c
		var zone := _zone(c.x, frames)
		if int(per_zone.get(zone, 0)) >= (1 if theme == "lower" else 2):
			continue
		var near := false
		for o in RING:
			if dressed.has(c + o):
				near = true
		if near:
			continue
		var item := _pick(theme, "mid", c, POOLS[theme]["mid"], st, trunk_x, salt)
		if item == "" or not _keeps_connected(c, free, dressed, portals):
			continue
		_put(st, c, item, _hash("%s:mr:%d:%d" % [salt, c.x, c.y]) % 2 if theme != "lower" else 0)
		per_zone[zone] = int(per_zone.get(zone, 0)) + 1
		placed_mid += 1
	# Battens on the open fronts of cargo in the hold.
	var fences := []
	if theme == "hold":
		for it in items:
			if not CARGO.has(String(it.name)) or it.y == h - 1:
				continue
			var c := Vector2i(int(it.x), int(it.y))
			if free.has(c + Vector2i(1, 0)) and not dressed.has(c + Vector2i(1, 0)):
				fences.append({"x": c.x, "y": c.y, "edge": "px"})
			if free.has(c + Vector2i(0, 1)) and not dressed.has(c + Vector2i(0, 1)):
				fences.append({"x": c.x, "y": c.y, "edge": "py"})
	# Floor: runners or duckboards along the routes, patches elsewhere (a
	# little more often inside the compartments).
	var floors := []
	var fset := "duck" if theme == "hold" else "runner"
	for c in routes:
		var mask := 0
		var bits := [1, 2, 4, 8]
		for i in 4:
			var n: Vector2i = c + DIRS[i]
			if routes.has(n) or portals.has(n):
				mask |= bits[i]
		floors.append({"x": c.x, "y": c.y, "set": fset, "key": str(mask)})
	var kinds: Array = PATCHES[theme]
	for c in free:
		if routes.has(c) or dressed.has(c) or portals.has(c):
			continue
		var hv := _hash("%s:p:%d:%d" % [salt, c.x, c.y])
		if hv % 100 < (24 if c.y < depth else 16):
			floors.append({"x": c.x, "y": c.y, "set": "patch", "key": kinds[(hv >> 7) % kinds.size()]})
	return {"items": items, "fences": fences, "floor": floors, "routes": routes}


static func _put(st: Dictionary, c: Vector2i, item: String, rot: int) -> void:
	st.dressed[c] = item
	if ONCE.has(item):
		st.used[item] = true
	st.count[item] = int(st.count.get(item, 0)) + 1
	if LIT.has(item):
		st.lit.append(c)
	st.items.append({"x": c.x, "y": c.y, "name": item, "rot": rot})


static func _pool(theme: String, role: String, zone: int, salt: String) -> Array:
	if (role == "back" or role == "alcove") and ROOMS.has(theme):
		var rooms: Array = ROOMS[theme]
		return rooms[_hash("%s:z:%d" % [salt, zone]) % rooms.size()]
	return POOLS[theme].get(role, [])


static func _pick(theme: String, role: String, c: Vector2i, pool: Array, st: Dictionary, trunk_x: int, salt: String) -> String:
	var dressed: Dictionary = st.dressed
	if theme == "lower" and role == "back" and c.x % 2 == 1:
		return "gun"
	if theme == "hold" and role == "back" and not st.used.has("pump") and trunk_x >= 0 and absi(c.x - trunk_x) <= 3:
		return "pump"
	if pool.is_empty():
		return ""
	var start := _hash("%s:i:%d:%d" % [salt, c.x, c.y]) % pool.size()
	for i in pool.size():
		var item: String = pool[(start + i) % pool.size()]
		if ONCE.has(item) and st.used.has(item):
			continue
		if not UNCAPPED.has(item) and int(st.count.get(item, 0)) >= int(st.cap_each):
			continue
		if dressed.get(c - Vector2i(1, 0), "") == item or dressed.get(c - Vector2i(0, 1), "") == item \
				or dressed.get(c + Vector2i(1, 0), "") == item or dressed.get(c + Vector2i(0, 1), "") == item:
			continue
		if item == "lantern":
			var near := false
			for l in st.lit:
				if absi(l.x - c.x) + absi(l.y - c.y) < 5:
					near = true
			if near:
				continue
		return item
	return ""


## True when every free neighbour of c can still reach every other one
## without c (and without dressed cells or ladder cells).
static func _keeps_connected(c: Vector2i, free: Dictionary, dressed: Dictionary, portals: Dictionary) -> bool:
	var nbs := []
	for o in DIRS:
		var n: Vector2i = c + o
		if free.has(n) and not dressed.has(n) and not portals.has(n):
			nbs.append(n)
	if nbs.size() <= 1:
		return true
	var seen := {nbs[0]: true}
	var queue := [nbs[0]]
	var qi := 0
	var left := nbs.size() - 1
	while qi < queue.size() and left > 0:
		var p: Vector2i = queue[qi]
		qi += 1
		for o in DIRS:
			var n: Vector2i = p + o
			if n == c or seen.has(n) or not free.has(n) or dressed.has(n) or portals.has(n):
				continue
			seen[n] = true
			if nbs.has(n):
				left -= 1
			queue.append(n)
	return left == 0


## Routes joining all goals: each goal is joined to the network grown so far
## by the cheapest path. Steps prefer the middle rows (away from the walls)
## and reuse of existing routes, so the result reads as one or two straight
## gangways with short branches.
static func _routes(free: Dictionary, portals: Dictionary, goals: Array, h: int) -> Dictionary:
	var net := {}
	var spine := (h - 1) * 0.5
	var todo := []
	for g in goals:
		if free.has(g) and not portals.has(g) and not todo.has(g):
			todo.append(g)
	if todo.is_empty():
		return net
	net[todo[0]] = true
	for gi in range(1, todo.size()):
		var g: Vector2i = todo[gi]
		if net.has(g):
			continue
		var dist := {g: 0.0}
		var prev := {}
		var open := [g]
		var hit := Vector2i(-1, -1)
		while not open.is_empty():
			var bi := 0
			for i in range(1, open.size()):
				if dist[open[i]] < dist[open[bi]]:
					bi = i
			var p: Vector2i = open[bi]
			open.remove_at(bi)
			if net.has(p):
				hit = p
				break
			for o in DIRS:
				var n: Vector2i = p + o
				if not free.has(n) or portals.has(n):
					continue
				var step := 0.45 if net.has(n) else 1.0 + 0.3 * absf(float(n.y) - spine)
				var nd: float = dist[p] + step
				if not dist.has(n) or nd < dist[n] - 0.0001:
					dist[n] = nd
					prev[n] = p
					if not open.has(n):
						open.append(n)
		if hit.x < 0:
			continue
		var q := hit
		while q != g:
			q = prev[q]
			net[q] = true
		net[g] = true
	return net
