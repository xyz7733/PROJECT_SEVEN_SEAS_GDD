"""Static coverage/geometry audit for the authored scene catalogue.

Does not run Godot, a game instance or a gameplay test suite. Its purpose is to
catch missing art direction and data references before import/export.
"""
from __future__ import annotations

import collections
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def segment_distance(p: list, a: list, b: list) -> float:
    vx, vy = b[0] - a[0], b[1] - a[1]
    wx, wy = p[0] - a[0], p[1] - a[1]
    t = min(1.0, max(0.0, (wx * vx + wy * vy) / max(0.001, vx * vx + vy * vy)))
    return math.hypot(wx - t * vx, wy - t * vy)


def audit() -> dict:
    world = json.loads((ROOT / "game/data/world.json").read_text(encoding="utf-8"))
    profiles = json.loads((ROOT / "game/data/scene_profiles.json").read_text(encoding="utf-8"))
    env_props = json.loads((ROOT / "game/assets/gen/env/env.json").read_text(encoding="utf-8"))["props"]
    regions, locations, battles = (profiles[k] for k in ("regions", "locations", "battleRooms"))
    errors = []
    if set(regions) != {r["id"] for r in world["REGIONS"]}:
        errors.append("Region coverage differs from world.json")
    if set(locations) != set(world["LOCATIONS"]):
        errors.append("Location coverage differs from world.json")
    expected_battles = set()
    expected_variants = {loc_id: index for region in world["REGIONS"] for index, loc_id in enumerate(region["locationIds"])}
    composition_ids = set()
    room_count = 0
    minimum_route_clearance = math.inf
    site_foundations = 0
    for loc_id, loc in world["LOCATIONS"].items():
        rec = locations.get(loc_id, {})
        if not rec:
            continue
        rooms = world["ROOM_TEMPLATES"].get(loc["type"], [])
        room_count += len(rooms)
        expected_nodes = {r["id"] for r in rooms} | {"_landing"}
        nodes = rec.get("nodes", {})
        if set(nodes) != expected_nodes:
            errors.append(f"{loc_id}: room coordinate coverage mismatch")
        if rec.get("regionId") != loc["regionId"] or rec.get("landmarkAsset") != loc["regionId"]:
            errors.append(f"{loc_id}: region/landmark assignment mismatch")
        if rec.get("landmarkVariant") != expected_variants[loc_id]:
            errors.append(f"{loc_id}: landmark variant does not match the region location order")
        if rec.get("landmarkFootprint") != [144, 64]:
            errors.append(f"{loc_id}: expected actual 144x64 foundation")
        cid = rec.get("compositionId")
        if not cid or cid in composition_ids:
            errors.append(f"{loc_id}: missing/duplicate composition")
        composition_ids.add(cid)
        for shape_kind in ("lobes", "cuts"):
            for shape in rec.get("coast", {}).get(shape_kind, []):
                if len(shape) != 3 or not all(isinstance(n, (int, float)) and math.isfinite(n) for n in shape) or shape[2] <= 0:
                    errors.append(f"{loc_id}: invalid {shape_kind} coast shape")
        for piece in rec.get("setPieces", []):
            if len(piece) != 4:
                errors.append(f"{loc_id}: malformed scenic piece")
                continue
            prop_key = loc["regionId"] + ":" + piece[0] if piece[3] else piece[0]
            if prop_key not in env_props and piece[0] not in env_props:
                errors.append(f"{loc_id}: missing prop resource {prop_key}")
        for name, p in nodes.items():
            if len(p) != 2 or not all(isinstance(n, (int, float)) and math.isfinite(n) for n in p):
                errors.append(f"{loc_id}:{name}: invalid world-pixel point")
        for a, pa in nodes.items():
            for b, pb in nodes.items():
                if a < b and math.dist(pa, pb) < 88:
                    errors.append(f"{loc_id}: nodes {a}/{b} are less than 88px apart")
        if rooms:
            site_foundations += 1
            center = rec["landmarkPosition"]
            half_w, half_h = 72.0, 32.0
            for name, p in nodes.items():
                if abs(p[0] - center[0]) <= half_w + 34.0 and abs(p[1] - center[1]) <= half_h + 34.0:
                    errors.append(f"{loc_id}:{name}: landmark overlaps the 34px room pad")
            edges = [(nodes[r["id"]], nodes[n]) for r in rooms for n in r["next"]]
            edges.append((nodes["_landing"], nodes[rooms[0]["id"]]))
            for a, b in edges:
                distance = segment_distance(center, a, b)
                minimum_route_clearance = min(minimum_route_clearance, distance)
                if distance < math.hypot(half_w, half_h) + 30.0:
                    errors.append(f"{loc_id}: landmark foundation overlaps a party route")
        if loc["type"] == "port":
            port = rec.get("port", {})
            if set(port.get("order", [])) != {"market", "tavern", "workshop", "quest_board", "house", "navigation"}:
                errors.append(f"{loc_id}: service order is incomplete")
            if len(port.get("setbacks", [])) != 6 or any(not -14 <= y <= -7 for y in port.get("setbacks", [])):
                errors.append(f"{loc_id}: service setbacks are invalid")
        for r in rooms:
            if r["kind"] not in {"battle", "elite", "boss", "trial"}:
                continue
            key = f"{loc_id}:{r['id']}"
            expected_battles.add(key)
            bp = battles.get(key, {})
            if bp.get("locationId") != loc_id or bp.get("roomId") != r["id"] or bp.get("tier") != r["kind"]:
                errors.append(f"{key}: battle identity mismatch")
            if bp.get("landmarkVariant") != expected_variants[loc_id]:
                errors.append(f"{key}: battle landmark variant does not match its location")
            if bp.get("landmarkFootprint") != [144, 64]:
                errors.append(f"{key}: expected actual 144x64 foundation")
            if bp.get("landmarkOffset", [0, 0])[1] > -128:
                errors.append(f"{key}: landmark enters the fight band")
            if any(p[2] > -100 for p in bp.get("setPieces", [])):
                errors.append(f"{key}: skyline piece enters the fight band")
            for piece in bp.get("setPieces", []):
                prop_key = loc["regionId"] + ":" + piece[0] if piece[3] else piece[0]
                if prop_key not in env_props and piece[0] not in env_props:
                    errors.append(f"{key}: missing prop resource {prop_key}")
    if set(battles) != expected_battles:
        errors.append("Battle coverage differs from existing combat rooms")
    result = {"regions": len(regions), "locations": len(locations), "rooms": room_count,
              "battleContexts": len(battles), "locationTypes": dict(collections.Counter(l["type"] for l in world["LOCATIONS"].values())),
              "safeSiteFoundations": site_foundations, "minimumLandmarkRouteDistancePx": round(minimum_route_clearance, 3),
              "requiredLandmarkRouteDistancePx": round(math.hypot(72, 32) + 30, 3),
              "errors": errors}
    if errors:
        raise ValueError("\n".join(errors))
    return result


if __name__ == "__main__":
    print(json.dumps(audit(), indent=2))
