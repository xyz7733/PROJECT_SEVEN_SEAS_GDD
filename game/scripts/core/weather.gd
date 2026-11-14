class_name Weather
extends RefCounted
## Weather over the seas. It is presentation only: it never touches rules,
## odds, costs or the save. The sky is rolled from the save's seed, the
## region and the six-hour watch, so reloading shows the same weather and
## two captains on the same seed share it. Weather tends to hold for a few
## watches. A new game's first morning is always fair, and an open "weather"
## sea event is always a storm.

const KINDS := ["clear", "cloudy", "rain", "fog", "storm", "ash"]
## Hours per watch (one roll each).
const WATCH := 6
## Chance (percent) that a watch keeps the previous watch's weather.
const HOLD := 45
## Watches before this one are always clear (a new game starts at 08:00, in
## watch 1, so the first morning is fair everywhere).
const FAIR_UNTIL := 2
## Region -> weights per kind. Regions not listed use dawnwater's.
const CLIMATE := {
	"dawnwater": {"clear": 50, "cloudy": 22, "rain": 16, "fog": 8, "storm": 4},
	"emberreach": {"clear": 45, "fog": 25, "ash": 20, "cloudy": 10},
	"verdant_maw": {"clear": 25, "rain": 30, "fog": 20, "cloudy": 20, "storm": 5},
	"glass_current": {"clear": 55, "fog": 20, "cloudy": 15, "rain": 10},
	"crown_shoals": {"clear": 55, "cloudy": 20, "rain": 15, "storm": 10},
	"stormbelt": {"storm": 35, "rain": 30, "cloudy": 20, "fog": 10, "clear": 5},
	"moonwake": {"fog": 35, "clear": 35, "cloudy": 15, "rain": 15},
	"ashen_trench": {"ash": 35, "fog": 25, "cloudy": 25, "rain": 10, "storm": 5},
	"leviathan_ring": {"clear": 30, "cloudy": 25, "rain": 25, "storm": 15, "fog": 5},
	"grand_horizon": {"clear": 60, "cloudy": 20, "rain": 10, "fog": 10},
}


## Overrides every roll when set (screenshot harness and tests only).
static var forced := ""


## The weather where the captain is now.
static func now(state: Dictionary) -> String:
	if forced != "":
		return forced
	var v = state.get("voyage")
	if v != null and v.get("event") != null and String(v.event.get("kind", "")) == "weather":
		return "storm"
	return roll(int(state.envelope.seed), region_here(state), int(floor(float(state.envelope.gameClock) / float(WATCH))))


## The region the captain is in: the fight's, the open site's, the leg being
## sailed (its destination) or the current location's.
static func region_here(state: Dictionary) -> String:
	var enc = state.get("encounter")
	if enc != null:
		var rid = enc.get("def", {}).get("regionId")
		if rid != null and String(rid) != "":
			return String(rid)
		var ctx: Dictionary = enc.get("context", {})
		var lid = ctx.get("locationId") if ctx.get("locationId") else ctx.get("toId")
		if lid != null:
			var r = C.region_of(String(lid))
			if r != null:
				return String(r.id)
	var v = state.get("voyage")
	if v != null and v.get("route") != null:
		var r2 = C.region_of(String(v.route.to))
		if r2 != null:
			return String(r2.id)
	var r3 = C.region_of(String(state.world.currentLocationId))
	return String(r3.id) if r3 != null else "dawnwater"


## Deterministic weather for a seed, region and watch number.
static func roll(seed_value: int, region_id: String, watch: int) -> String:
	var w := watch
	# A spell of weather: walk back while each watch keeps the one before.
	for _i in 4:
		if U.mix(U.hash32("sky-hold|%d|%s|%d" % [seed_value, region_id, w])) % 100 >= HOLD:
			break
		w -= 1
	if w < FAIR_UNTIL:
		return "clear"
	return _pick(CLIMATE.get(region_id, CLIMATE.dawnwater), U.mix(U.hash32("sky|%d|%s|%d" % [seed_value, region_id, w])))


static func _pick(table: Dictionary, h: int) -> String:
	var total := 0
	for k in table:
		total += int(table[k])
	var x := h % maxi(1, total)
	for k in KINDS:
		if not table.has(k):
			continue
		x -= int(table[k])
		if x < 0:
			return k
	return "clear"


## True for skies that drop rain (the views draw it and the rain bed plays).
static func wet(kind: String) -> bool:
	return kind == "rain" or kind == "storm"
