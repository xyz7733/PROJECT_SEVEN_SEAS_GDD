## Vector effects for the battle arena, drawn in world pixels with hard
## edges so they read at the game's pixel scale (the arena is shown at x2).
## Every node runs its own short timeline and frees itself.
##
## Depth: effects that belong to a combatant (swings, sparks, glyphs,
## status marks, the yield flag) are attached to that actor's rig with
## Actor.attach_fx, so they are drawn with the actor in the arena's y-sort:
## in front of the actor itself, behind anyone standing nearer. Ground
## marks (telegraphs) sit under every actor; projectiles and loot drops are
## stage nodes sorted by their own ground point.
class_name BattleFx
extends RefCounted

const STEEL := Color("#f2f6ff")
const STEEL_DIM := Color("#9fb2d6")
const FIRE := Color("#ffd27a")
const DARK := Color("#1a1218")
const ALLY := Color("#7fd8ff")
const FOE := Color("#ff8a6a")
const HEAL := Color("#8ef08a")
const RARITY := {
	"common": Color("#e8dcc0"), "uncommon": Color("#8ee07a"), "rare": Color("#6cb8ff"),
	"epic": Color("#c995ff"), "legendary": Color("#f7d154"),
}


static func rarity_color(r: String) -> Color:
	return RARITY.get(r, RARITY.common)


## Base: a timeline 0..dur (scaled by `rate`) that redraws every frame.
class Fx extends Node2D:
	var dur := 0.3
	var t := 0.0
	var rate := 1.0
	var color := Color.WHITE

	func _process(delta: float) -> void:
		t += delta * rate
		if t >= dur:
			queue_free()
			return
		queue_redraw()

	func k() -> float:
		return clampf(t / dur, 0.0, 1.0)


## A melee swing at the point of impact, oriented along `dir` (attacker to
## target). Styles: slash (blade crescent), thrust (spear streak), punch
## (fist ring), bash (shield wedge), claw (three rakes), lash (whip curve),
## crush (heavy two-ring blow).
class Swing extends Fx:
	var style := "slash"
	var dir := Vector2.RIGHT
	var size := 1.0

	func _draw() -> void:
		var f := k()
		var a := 1.0 - smoothstep(0.55, 1.0, f)
		var ang := dir.angle()
		var c := Color(color.r, color.g, color.b, a)
		var dk := Color(DARK.r, DARK.g, DARK.b, 0.6 * a)
		var s := size
		match style:
			"slash":
				# Crescent sweeping across the target, drawn on as it swings.
				var span := 2.2
				var reveal := clampf(f / 0.45, 0.0, 1.0)
				var a0 := ang - PI * 0.5 - span * 0.5
				var a1 := a0 + span * reveal
				var outer := PackedVector2Array()
				var inner := PackedVector2Array()
				var n := 12
				for i in n + 1:
					var q := lerpf(a0, a1, float(i) / n)
					var w := sin(PI * float(i) / n)
					outer.append((Vector2(cos(q), sin(q) * 0.8) * 14.0 * s).round())
					inner.append((Vector2(cos(q), sin(q) * 0.8) * (14.0 - 4.5 * w) * s - dir * 2.0 * w).round())
				inner.reverse()
				var poly := outer + inner
				if poly.size() >= 3 and reveal > 0.05:
					draw_colored_polygon(poly, c)
					draw_polyline(outer, dk, 1.0)
			"thrust":
				var len := 22.0 * s
				var head := dir * (6.0 + 4.0 * f) * s
				var tail := head - dir * len * (1.0 - 0.5 * f)
				var nrm := Vector2(-dir.y, dir.x)
				var poly2 := PackedVector2Array([(tail).round(), (head - dir * 3.0 + nrm * 2.0).round(), (head).round(), (head - dir * 3.0 - nrm * 2.0).round()])
				draw_colored_polygon(poly2, c)
				_star(head, 4.0 * s * (1.0 - f) + 2.0, c)
			"punch":
				var r := (5.0 + 9.0 * f) * s
				_ring(Vector2.ZERO, r, 0.8, c, 2.0)
				for i in 4:
					var q2 := ang + PI * 0.25 + TAU * i / 4.0
					var d2 := Vector2(cos(q2), sin(q2) * 0.8)
					draw_line((d2 * r * 0.9).round(), (d2 * (r + 4.0 * s)).round(), c, 2.0)
			"bash":
				var nrm2 := Vector2(-dir.y, dir.x)
				var front := dir * (2.0 + 6.0 * f) * s
				var poly3 := PackedVector2Array([(front + nrm2 * 9.0 * s).round(), (front + dir * 4.0 * s).round(), (front - nrm2 * 9.0 * s).round(), (front - dir * 3.0 * s).round()])
				draw_colored_polygon(poly3, Color(c.r, c.g, c.b, 0.55 * a))
				draw_polyline(poly3 + PackedVector2Array([poly3[0]]), c, 1.0)
				_ring(front, (4.0 + 10.0 * f) * s, 0.7, c, 1.0)
			"claw":
				var nrm3 := Vector2(-dir.y, dir.x)
				for i in 3:
					var on := clampf((f - 0.08 * i) / 0.3, 0.0, 1.0)
					if on <= 0.0:
						continue
					var off := nrm3 * (float(i) - 1.0) * 4.0 * s
					var p0 := off - (dir * 0.6 + nrm3 * 0.8).normalized() * 9.0 * s
					var p1 := off + (dir * 0.6 + nrm3 * 0.8).normalized() * 9.0 * s
					draw_line(p0.round(), p0.lerp(p1, on).round(), c, 2.0)
			"lash":
				var nrm4 := Vector2(-dir.y, dir.x)
				var pts := PackedVector2Array()
				for i in 11:
					var u := float(i) / 10.0
					if u > f / 0.5:
						break
					pts.append((dir * (u - 0.6) * 24.0 * s + nrm4 * sin(u * TAU * 1.2 + f * 6.0) * 4.0 * s).round())
				if pts.size() >= 2:
					draw_polyline(pts, c, 2.0)
			"crush":
				_ring(Vector2(0, 10), (6.0 + 16.0 * f) * s, 0.45, c, 2.0)
				_ring(Vector2(0, 10), (3.0 + 10.0 * f) * s, 0.45, Color(c.r, c.g, c.b, 0.6 * a), 1.0)
				_star(Vector2.ZERO, (9.0 - 5.0 * f) * s, c)

	func _ring(at: Vector2, r: float, squash: float, c: Color, w: float) -> void:
		var pts := PackedVector2Array()
		for i in 21:
			var q := TAU * i / 20.0
			pts.append((at + Vector2(cos(q), sin(q) * squash) * r).round())
		draw_polyline(pts, c, w)

	func _star(at: Vector2, r: float, c: Color) -> void:
		draw_line((at + Vector2(-r, 0)).round(), (at + Vector2(r, 0)).round(), c, 2.0)
		draw_line((at + Vector2(0, -r)).round(), (at + Vector2(0, r)).round(), c, 2.0)
		var r2 := r * 0.55
		draw_line((at + Vector2(-r2, -r2)).round(), (at + Vector2(r2, r2)).round(), c, 1.0)
		draw_line((at + Vector2(-r2, r2)).round(), (at + Vector2(r2, -r2)).round(), c, 1.0)


## Impact sparks thrown along `dir`, with a white flash. `crit` throws more,
## larger, gold sparks with a star.
class Sparks extends Fx:
	var dir := Vector2.RIGHT
	var crit := false
	var _p: Array = []

	func setup(seed_value: int) -> Sparks:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var n := 12 if crit else 7
		for i in n:
			var q := dir.angle() + rng.randf_range(-1.1, 1.1)
			_p.append([Vector2(cos(q), sin(q) * 0.85), rng.randf_range(10.0, 22.0) * (1.4 if crit else 1.0), rng.randf_range(2.0, 4.0)])
		dur = 0.36 if crit else 0.26
		return self

	func _draw() -> void:
		var f := k()
		var a := 1.0 - f
		var base := FIRE if crit else STEEL
		if f < 0.3:
			var fr := (1.0 - f / 0.3)
			draw_circle(Vector2.ZERO, (7.0 if crit else 5.0) * fr + 1.0, Color(1, 1, 1, 0.9 * fr))
		for p in _p:
			var d: Vector2 = p[0]
			var dist: float = p[1] * (1.0 - pow(1.0 - f, 2.0))
			var ln: float = p[2] * (1.0 - f) + 1.0
			var at := d * dist
			draw_line(at.round(), (at - d * ln * 2.0).round(), Color(base.r, base.g, base.b, a), 2.0 if crit else 1.0)
		if crit:
			var r := 6.0 + 16.0 * f
			for i in 8:
				var q2 := TAU * i / 8.0 + 0.2
				var d2 := Vector2(cos(q2), sin(q2))
				draw_line((d2 * r * 0.6).round(), (d2 * r).round(), Color(1.0, 0.85, 0.35, a), 2.0)


## Wind-up telegraph on the ground under the target: an outline ring that
## fills as the attack charges. Freed by the view when the attack lands,
## is interrupted or the caster falls.
class Telegraph extends Node2D:
	var secs := 2.0
	## Charge time so far; the view sets it from the caster's wind-up.
	var t := 0.0
	var color := FOE
	var radius := 13.0
	var _pt := 0.0

	func _process(delta: float) -> void:
		_pt += delta
		queue_redraw()

	func _draw() -> void:
		var f := clampf(t / maxf(0.1, secs), 0.0, 1.0)
		var pulse := 0.65 + 0.35 * sin(_pt * (10.0 + 10.0 * f))
		var pts := PackedVector2Array()
		for i in 25:
			var q := TAU * i / 24.0
			pts.append((Vector2(cos(q), sin(q) * 0.5) * radius).round())
		draw_colored_polygon(_ellipse(radius * f), Color(color.r, color.g, color.b, 0.28 + 0.2 * f))
		draw_polyline(pts, Color(color.r, color.g, color.b, pulse), 1.0)
		# Corner ticks so the mark reads even over busy ground.
		for i in 4:
			var q2 := TAU * i / 4.0 + PI * 0.25
			var d := Vector2(cos(q2), sin(q2) * 0.5)
			draw_line((d * (radius + 2.0)).round(), (d * (radius + 5.0)).round(), Color(color.r, color.g, color.b, pulse), 1.0)

	func _ellipse(r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		var rr := maxf(1.0, r)
		for i in 16:
			var q := TAU * i / 16.0
			p.append((Vector2(cos(q), sin(q) * 0.5) * rr).round())
		return p


## Charging glow around a winding-up caster: rings contracting inward.
class Charge extends Node2D:
	var t := 0.0
	var color := FOE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for j in 2:
			var ph := fmod(t * 1.6 + j * 0.5, 1.0)
			var r := 16.0 - 12.0 * ph
			var pts := PackedVector2Array()
			for i in 17:
				var q := TAU * i / 16.0
				pts.append((Vector2(cos(q), sin(q) * 0.55) * r).round())
			draw_polyline(pts, Color(color.r, color.g, color.b, 0.9 * ph), 1.0)


## A skill silhouette above the caster: sword (damage), lightning (control),
## cross (support) or shield (survival), outlined in dark ink, in the
## caster's side colour. Pops, holds, then rises and fades.
class Glyph extends Fx:
	var cat := "damage"

	func _init() -> void:
		dur = 0.8

	func _draw() -> void:
		var f := k()
		var pop := 1.0
		if f < 0.15:
			pop = lerpf(0.4, 1.15, f / 0.15)
		elif f < 0.25:
			pop = lerpf(1.15, 1.0, (f - 0.15) / 0.1)
		var a := 1.0 - smoothstep(0.6, 1.0, f)
		var lift := -6.0 * smoothstep(0.5, 1.0, f)
		var poly := _shape(cat)
		var outp := PackedVector2Array()
		var inp := PackedVector2Array()
		var cen := Vector2(0, lift)
		for p in poly:
			outp.append((cen + p * pop * 1.18).round())
			inp.append((cen + p * pop).round())
		draw_colored_polygon(outp, Color(DARK.r, DARK.g, DARK.b, 0.85 * a))
		draw_colored_polygon(inp, Color(color.r, color.g, color.b, a))
		var hi := Color(1, 1, 1, 0.55 * a)
		draw_polyline(PackedVector2Array([inp[0], inp[1]]), hi, 1.0)

	static func _shape(c: String) -> PackedVector2Array:
		match c:
			"control":
				return PackedVector2Array([Vector2(2, -12), Vector2(-6, 1), Vector2(-1, 1), Vector2(-3, 12), Vector2(6, -2), Vector2(1, -2), Vector2(4, -12)])
			"support":
				return PackedVector2Array([Vector2(-3, -10), Vector2(3, -10), Vector2(3, -3), Vector2(10, -3), Vector2(10, 3), Vector2(3, 3),
					Vector2(3, 10), Vector2(-3, 10), Vector2(-3, 3), Vector2(-10, 3), Vector2(-10, -3), Vector2(-3, -3)])
			"survival":
				return PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(9, -1), Vector2(6, 6), Vector2(0, 11), Vector2(-6, 6), Vector2(-9, -1)])
			_:
				# Sword, point up, slightly tilted.
				return PackedVector2Array([Vector2(0, -13), Vector2(2, -10), Vector2(2, 3), Vector2(7, 3), Vector2(7, 5), Vector2(2, 5),
					Vector2(2, 10), Vector2(-2, 10), Vector2(-2, 5), Vector2(-7, 5), Vector2(-7, 3), Vector2(-2, 3), Vector2(-2, -10)])


## Healing: a soft green column and small crosses rising off the body.
class HealRise extends Fx:
	func _init() -> void:
		dur = 0.75
		color = HEAL

	func _draw() -> void:
		var f := k()
		var a := 1.0 - f
		for i in 7:
			var y := -float(i) * 4.0
			var w := 8.0 - float(i) * 0.6
			draw_line(Vector2(-w, y).round(), Vector2(w, y).round(), Color(color.r, color.g, color.b, 0.22 * a * (1.0 - i / 7.0)), 3.0)
		for i in 4:
			var ph := clampf(f * 1.4 - i * 0.12, 0.0, 1.0)
			if ph <= 0.0 or ph >= 1.0:
				continue
			var x: float = [-7.0, 5.0, -2.0, 8.0][i]
			var p := Vector2(x, -6.0 - 22.0 * ph)
			var c := Color(color.r, color.g, color.b, 1.0 - ph)
			draw_rect(Rect2((p + Vector2(-1, -3)).round(), Vector2(2, 6)), c)
			draw_rect(Rect2((p + Vector2(-3, -1)).round(), Vector2(6, 2)), c)


## Lasting status marks on a combatant, read from its combat status each
## frame: stun stars over the head, a red reticle when marked, falling
## blue drops when slowed, a pale ward around the body while shielded,
## embers at the feet while burning, and small chevrons for attack and
## defence buffs. A mark pops in when it is first applied.
class Status extends Node2D:
	var h := 28.0
	var st: Dictionary = {}
	var t := 0.0
	var _on := {}

	func _process(delta: float) -> void:
		t += delta
		for k in ["stun", "mark", "slow", "shield", "dot", "buffAtkT", "buffDefT"]:
			var v := float(st.get(k, 0.0))
			if v > 0.0 and not _on.has(k):
				_on[k] = t
			elif v <= 0.0 and _on.has(k):
				_on.erase(k)
		queue_redraw()

	func _pop(k: String) -> float:
		var e := t - float(_on.get(k, t))
		if e < 0.12:
			return lerpf(0.3, 1.3, e / 0.12)
		if e < 0.22:
			return lerpf(1.3, 1.0, (e - 0.12) / 0.1)
		return 1.0

	func _draw() -> void:
		if _on.has("shield"):
			var s0 := _pop("shield")
			var c0 := Vector2(0, -h * 0.5)
			var rx := h * 0.42 * s0
			var ry := h * 0.6 * s0
			var pts := PackedVector2Array()
			for i in 25:
				var q := TAU * i / 24.0
				pts.append((c0 + Vector2(cos(q) * rx, sin(q) * ry)).round())
			draw_polyline(pts, Color(0.62, 0.86, 1.0, 0.45 + 0.15 * sin(t * 5.0)), 1.0)
			var q0 := fmod(t * 2.5, TAU)
			var arc := PackedVector2Array()
			for i in 7:
				var q1 := q0 + i * 0.12
				arc.append((c0 + Vector2(cos(q1) * rx, sin(q1) * ry)).round())
			draw_polyline(arc, Color(0.92, 0.98, 1.0, 0.9), 1.0)
		if _on.has("dot"):
			for i in 3:
				var ph := fmod(t * 1.8 + i * 0.37, 1.0)
				var p := Vector2(-6.0 + i * 6.0 + sin(t * 7.0 + i) * 1.0, -2.0 - 12.0 * ph)
				var c1 := Color(1.0, 0.55 + 0.35 * (1.0 - ph), 0.2, 1.0 - ph)
				draw_rect(Rect2(p.round(), Vector2(2, 2)), c1)
		if _on.has("slow"):
			for i in 3:
				var ph2 := fmod(t * 1.5 + i * 0.33, 1.0)
				var p2 := Vector2(-7.0 + i * 7.0, -h * 0.7 + h * 0.6 * ph2)
				draw_rect(Rect2(p2.round(), Vector2(1, 3)), Color(0.5, 0.75, 1.0, 1.0 - ph2))
		if _on.has("mark"):
			var s2 := _pop("mark")
			var r := (6.0 + sin(t * 8.0)) * s2
			var cm := Vector2(0, -h * 0.55)
			var c2 := Color(1.0, 0.38, 0.32, 0.95)
			var pts2 := PackedVector2Array()
			for i in 17:
				var q2 := TAU * i / 16.0
				pts2.append((cm + Vector2(cos(q2), sin(q2)) * r).round())
			draw_polyline(pts2, c2, 1.0)
			for i in 4:
				var q3 := TAU * i / 4.0
				var d := Vector2(cos(q3), sin(q3))
				draw_line((cm + d * (r - 2.0)).round(), (cm + d * (r + 3.0)).round(), c2, 1.0)
		if _on.has("stun"):
			var s3 := _pop("stun")
			for i in 3:
				var q4 := t * 5.0 + TAU * i / 3.0
				var p4 := Vector2(cos(q4) * 8.0 * s3, -h - 4.0 + sin(q4) * 3.0)
				var c4 := Color(1.0, 0.92, 0.4, 0.6 + 0.4 * (sin(q4) * 0.5 + 0.5))
				draw_line((p4 + Vector2(-2, 0)).round(), (p4 + Vector2(2, 0)).round(), c4, 1.0)
				draw_line((p4 + Vector2(0, -2)).round(), (p4 + Vector2(0, 2)).round(), c4, 1.0)
		var bx := 9.0
		for k in ["buffAtkT", "buffDefT"]:
			if not _on.has(k):
				continue
			var c5 := Color(1.0, 0.55, 0.4) if k == "buffAtkT" else Color(0.55, 0.8, 1.0)
			var y := -h + 4.0 - 2.0 * absf(sin(t * 3.0))
			var at := Vector2(bx, y)
			draw_polyline(PackedVector2Array([(at + Vector2(-3, 2)).round(), at.round(), (at + Vector2(3, 2)).round()]), c5, 1.0)
			draw_polyline(PackedVector2Array([(at + Vector2(-3, 5)).round(), (at + Vector2(0, 3)).round(), (at + Vector2(3, 5)).round()]), c5, 1.0)
			bx += 7.0


## A defeated person yields: a small white flag pops up over the body.
class Flag extends Fx:
	func _init() -> void:
		dur = 1.6

	func _draw() -> void:
		var f := k()
		var a := 1.0 - smoothstep(0.75, 1.0, f)
		var rise := -4.0 * minf(1.0, f / 0.15)
		var base := Vector2(0, rise)
		var pole := Color(0.36, 0.25, 0.16, a)
		draw_line(base.round(), (base + Vector2(0, -11)).round(), pole, 1.0)
		var wave := 1.0 if fmod(t * 4.0, 1.0) < 0.5 else 0.0
		var cloth := PackedVector2Array([base + Vector2(1, -11), base + Vector2(8, -11 + wave), base + Vector2(8, -6 + wave), base + Vector2(1, -6)])
		for i in cloth.size():
			cloth[i] = cloth[i].round()
		draw_colored_polygon(cloth, Color(0.97, 0.96, 0.92, a))
		draw_polyline(cloth + PackedVector2Array([cloth[0]]), Color(DARK.r, DARK.g, DARK.b, 0.6 * a), 1.0)


## A projectile flying between two ground points. Drawn lifted by its
## height so the node itself sorts by the ground point under it. Kinds:
## bullet (tracer), arrow (arcing shaft), orb (glowing bolt with a trail),
## vial (arcing flask), spit (arcing blob). Calls `on_hit` on arrival.
class Shot extends Node2D:
	var kind := "bullet"
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var h0 := 14.0
	var h1 := 12.0
	var arc := 0.0
	var dur := 0.2
	var t := 0.0
	var rate := 1.0
	var color := FIRE
	var on_hit: Callable
	var _trail: Array = []
	var _prev := Vector2.ZERO

	func _process(delta: float) -> void:
		t += delta * rate
		var f := clampf(t / dur, 0.0, 1.0)
		position = from.lerp(to, f).round()
		var h := lerpf(h0, h1, f) + arc * 4.0 * f * (1.0 - f)
		var p := Vector2(0, -h)
		_trail.push_front(position + p)
		if _trail.size() > 5:
			_trail.pop_back()
		queue_redraw()
		if f >= 1.0:
			if on_hit.is_valid():
				on_hit.call()
			queue_free()

	func _draw() -> void:
		if _trail.is_empty():
			return
		var head: Vector2 = _trail[0] - position
		var back: Vector2 = (_trail[_trail.size() - 1] - position) if _trail.size() > 1 else head - (to - from).normalized() * 4.0
		var d := (head - back)
		if d.length() < 0.01:
			d = (to - from)
		d = d.normalized()
		match kind:
			"bullet":
				draw_line((head - d * 8.0).round(), head.round(), Color(1.0, 0.9, 0.55, 0.55), 1.0)
				draw_rect(Rect2((head - Vector2(1, 1)).round(), Vector2(2, 2)), Color(1.0, 0.95, 0.7))
			"arrow":
				var tail := head - d * 8.0
				var nrm := Vector2(-d.y, d.x)
				draw_line(tail.round(), head.round(), Color(0.55, 0.38, 0.22), 1.0)
				draw_line(head.round(), (head - d * 3.0 + nrm * 2.0).round(), Color(0.85, 0.85, 0.9), 1.0)
				draw_line(head.round(), (head - d * 3.0 - nrm * 2.0).round(), Color(0.85, 0.85, 0.9), 1.0)
				draw_line(tail.round(), (tail - d * 2.0 + nrm * 2.0).round(), Color(0.95, 0.95, 0.95), 1.0)
				draw_line(tail.round(), (tail - d * 2.0 - nrm * 2.0).round(), Color(0.95, 0.95, 0.95), 1.0)
			"orb", "spit":
				for i in range(_trail.size() - 1, 0, -1):
					var tp: Vector2 = _trail[i] - position
					draw_circle(tp.round(), 2.5 - i * 0.4, Color(color.r, color.g, color.b, 0.5 - i * 0.09))
				draw_circle(head.round(), 5.0 if kind == "orb" else 3.0, Color(color.r, color.g, color.b, 0.35))
				draw_circle(head.round(), 3.0 if kind == "orb" else 2.5, color)
				if kind == "orb":
					draw_circle(head.round(), 1.0, Color(1, 1, 1, 0.9))
			"vial":
				draw_circle(head.round(), 2.5, color)
				draw_rect(Rect2((head + Vector2(-1, -5)).round(), Vector2(2, 3)), Color(0.85, 0.9, 0.95))
				draw_rect(Rect2((head + Vector2(-1, -6)).round(), Vector2(2, 1)), Color(0.55, 0.38, 0.22))


## Muzzle flash at a gun's mouth.
class Muzzle extends Fx:
	var dir := Vector2.RIGHT

	func _init() -> void:
		dur = 0.1

	func _draw() -> void:
		var a := 1.0 - k()
		var tip := dir * 6.0
		var nrm := Vector2(-dir.y, dir.x)
		var poly := PackedVector2Array([(tip - nrm * 3.0).round(), (tip + dir * 7.0).round(), (tip + nrm * 3.0).round()])
		draw_colored_polygon(poly, Color(1.0, 0.85, 0.4, a))
		draw_circle(tip.round(), 3.0 * a + 1.0, Color(1, 1, 0.85, a))


## A loot drop: the item's icon on the ground with a rarity ring, and for
## rare and better a thin light beam. It pops out of the fallen opponent in
## a short arc, bounces, and waits until the view collects it.
class Drop extends Node2D:
	var rarity := "common"
	var icon: Texture2D
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var t := 0.0
	var rate := 1.0
	var _spr: Sprite2D

	func _ready() -> void:
		_spr = Sprite2D.new()
		_spr.texture = icon
		_spr.centered = true
		add_child(_spr)
		position = from

	func _process(delta: float) -> void:
		t += delta * rate
		var pop := 0.38
		var hgt := 0.0
		if t < pop:
			var f := t / pop
			position = from.lerp(to, f).round()
			hgt = 18.0 * 4.0 * f * (1.0 - f)
		elif t < pop + 0.16:
			var f2 := (t - pop) / 0.16
			position = to
			hgt = 4.0 * 4.0 * f2 * (1.0 - f2)
		else:
			position = to
			hgt = 1.0 + roundf(sin((t - pop) * 4.0))
		_spr.position = Vector2(0, -8.0 - hgt).round()
		queue_redraw()

	func _draw() -> void:
		var c := BattleFx.rarity_color(rarity)
		var settle := clampf((t - 0.3) / 0.2, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 17:
			var q := TAU * i / 16.0
			pts.append((Vector2(cos(q) * 8.0, sin(q) * 3.5)).round())
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.22 * settle))
		draw_polyline(pts, Color(c.r, c.g, c.b, 0.85 * settle), 1.0)
		if rarity in ["rare", "epic", "legendary"] and settle > 0.0:
			var hb := 26.0 if rarity == "legendary" else 20.0
			for i in 6:
				var y := -float(i) * hb / 6.0
				draw_line(Vector2(0, y - 18.0).round(), Vector2(0, y - 18.0 - hb / 6.0).round(), Color(c.r, c.g, c.b, 0.5 * settle * (1.0 - i / 6.0)), 2.0)
			var tw := fmod(t * 1.3, 1.0)
			if tw < 0.3:
				var s := 3.0 * (1.0 - absf(tw - 0.15) / 0.15)
				var p := Vector2(5, -14)
				draw_line((p + Vector2(-s, 0)).round(), (p + Vector2(s, 0)).round(), Color(1, 1, 1, 0.9), 1.0)
				draw_line((p + Vector2(0, -s)).round(), (p + Vector2(0, s)).round(), Color(1, 1, 1, 0.9), 1.0)
