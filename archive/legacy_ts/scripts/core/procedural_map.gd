class_name ProceduralMap
extends NavMap
## Robust procedural dungeon generator supporting both tower floors and peaceful Headquarters layouts.
## Preserves complete backward compatibility for all public properties and navigation methods.

## Generator versions (D-026: a saved floor is never rebuilt by another generator).
## 1 = original rooms + 1-2 foes per room near the entrance (floors saved as a seed only, F-014).
## 2 = zones (entrance / explore / danger / objective) and encounters (groups, patrols, ambushes,
##     guarded treasure), saved as a full snapshot (to_snapshot / from_snapshot).
const GEN_VERSION := 2

var seed_value: int = 12345
var floor_number: int = 1
var gen_version: int = GEN_VERSION
var grid_rows: Array[String] = []
var objective_cells: Array[Vector2i] = []
## v2: [{"kind": group|patrol|ambush|guard, "zone": String, "members": [type id], "cells": [Vector2i],
##       "patrol": [Vector2i]}] and the zone of every room [{"rect": Rect2i, "zone": String}].
var encounters: Array = []
var room_zones: Array = []
var resource_nodes: Array = []      # v2: [{"kind": ore|wood|herb, "cell": Vector2i}] (EconomyDefs.NODES)


func _init(p_width: int = 100, p_height: int = 100, seed_val: int = 12345, floor_num: int = 1, gen: int = GEN_VERSION, generate: bool = true) -> void:
	width = clampi(p_width, 40, 200)
	height = clampi(p_height, 40, 200)
	seed_value = seed_val
	floor_number = floor_num
	gen_version = gen
	if generate:
		_generate_with_retry()


func _generate_with_retry() -> void:
	var rng := RandomNumberGenerator.new()
	var attempts := 0
	while attempts < 10:
		rng.seed = seed_value + absi(floor_number) * 997 + attempts * 31
		if _try_generate(rng):
			if _validate_map():
				_set_mission_cells()
				return
		attempts += 1
	_force_fallback_generate(rng)


## Relic in the far room (goal), extraction back in the start room (F-003: never the same cell).
func _set_mission_cells() -> void:
	relic_cell = goal_cell
	extract_cell = spawn_cells[0] if not spawn_cells.is_empty() else goal_cell


func _try_generate(rng: RandomNumberGenerator) -> bool:
	var map_grid := []
	for y in height:
		var row := []
		for x in width:
			row.append("#")
		map_grid.append(row)

	# Headquarters (floor_number <= 0) gets a spacious open layout, tower gets multi-room dungeons
	var is_hq := (floor_number == 0)              # D-066: negative floor numbers are tiers of the Wilds (rooms, zones)
	objective_cells.clear()
	var target_rooms := 1 if is_hq else clampi(10 + floor_number * 2, 12, 30)
	if gen_version >= 2 and not is_hq:
		target_rooms = clampi(width * height / 300, 14, 40)       # rooms grow with the map, not the floor number
	var rooms: Array[Rect2i] = []

	if is_hq:
		# Headquarters open hall layout
		var hq_room := Rect2i(3, 3, width - 6, height - 6)
		rooms.append(hq_room)
		for y in range(hq_room.position.y, hq_room.end.y):
			for x in range(hq_room.position.x, hq_room.end.x):
				map_grid[y][x] = "."
	else:
		var max_placement_attempts := target_rooms * 20
		var placed := 0
		for i in range(max_placement_attempts):
			if placed >= target_rooms:
				break
			var rw := rng.randi_range(7, 16)
			var rh := rng.randi_range(7, 16)
			var rx := rng.randi_range(2, width - rw - 2)
			var ry := rng.randi_range(2, height - rh - 2)
			var candidate := Rect2i(rx, ry, rw, rh)

			var overlap := false
			for r in rooms:
				if candidate.grow(2).intersects(r):
					overlap = true
					break
			if not overlap:
				rooms.append(candidate)
				placed += 1
				for y in range(candidate.position.y, candidate.end.y):
					for x in range(candidate.position.x, candidate.end.x):
						map_grid[y][x] = "."

		if rooms.size() < 4:
			return false

		rooms.sort_custom(func(a, b): return a.position.x + a.position.y < b.position.x + b.position.y)

		for i in range(1, rooms.size()):
			var p1 := rooms[i - 1].get_center()
			var p2 := rooms[i].get_center()
			_carve_corridor(map_grid, p1, p2)

		for i in range(maxi(1, rooms.size() / 3)):
			var r1 = rooms[rng.randi_range(0, rooms.size() - 1)]
			var r2 = rooms[rng.randi_range(0, rooms.size() - 1)]
			if r1 != r2:
				_carve_corridor(map_grid, r1.get_center(), r2.get_center())

	if not is_hq:
		_roughen_rooms(map_grid, rooms, rng)
	var start_room := rooms[0]
	var end_room := rooms[rooms.size() - 1]

	spawn_cells.clear()
	for i in maxi(5, Game.PARTY_SIZE):
		var sx := start_room.position.x + 1 + (i % 4)
		var sy := start_room.position.y + 1 + int(i / 4)
		if in_bounds(Vector2i(sx, sy)):
			spawn_cells.append(Vector2i(sx, sy))
			map_grid[sy][sx] = "."

	goal_cell = end_room.get_center()
	map_grid[goal_cell.y][goal_cell.x] = "."
	if not is_hq:
		objective_cells.append(goal_cell)

	enemy_spawn_cells.clear()
	treasure_cells.clear()

	if not is_hq and gen_version >= 2:
		_place_encounters(rooms, map_grid, rng)
	elif not is_hq:
		var cfg := TowerExpedition.get_floor_config(floor_number)
		var target_enemies: int = int(cfg.get("enemies", cfg.get("threat", 8)))
		for i in range(1, rooms.size() - 1):
			var rm := rooms[i]
			var enemies_in_room := rng.randi_range(1, 2)
			for e in enemies_in_room:
				if enemy_spawn_cells.size() < target_enemies:
					var ex := rng.randi_range(rm.position.x + 1, rm.end.x - 2)
					var ey := rng.randi_range(rm.position.y + 1, rm.end.y - 2)
					if map_grid[ey][ex] == ".":
						enemy_spawn_cells.append(Vector2i(ex, ey))
			
			if rng.randf() < 0.4 and treasure_cells.size() < 4:
				var tx := rm.get_center().x + rng.randi_range(-1, 1)
				var ty := rm.get_center().y + rng.randi_range(-1, 1)
				if map_grid[ty][tx] == ".":
					treasure_cells.append(Vector2i(tx, ty))

	grid_rows.clear()
	for y in height:
		var row_str := ""
		for x in width:
			var ch := String(map_grid[y][x])
			row_str += "." if ch == "c" else ch
		grid_rows.append(row_str)

	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				grid.set_point_solid(Vector2i(x, y), true)
	if not is_hq:
		_seal_pockets()
		if gen_version >= 2:
			ensure_density()
	return true


## D-082b (owner: "on floor 2 there were almost no enemies after a long walk"): every floor gets at least
## EnemyDefs.ENCOUNTER_MIN encounters (or ENCOUNTER_MIN_SHARE of its rooms past the entrance) and no room
## further than ENCOUNTER_MAX_GAP px from one. Small filler patrols of the floor's creatures go into the
## emptiest rooms. Deterministic (own RNG from the seed), and also run when a saved floor is loaded, so
## floors made before the fix are filled the same way every time.
func ensure_density() -> int:
	if floor_number == 0 or room_zones.is_empty():
		return 0
	var cfg := TowerExpedition.get_floor_config(floor_number)
	var foes: Array = cfg.get("foes", ["goblin"])
	if String(cfg.get("mission", "")) == "boss" and foes.size() > 1:
		foes = foes.slice(1)                                     # never a second boss
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x0DE45E
	var rooms: Array = room_zones.filter(func(z): return String(z["zone"]) != "entrance")
	var want := maxi(EnemyDefs.ENCOUNTER_MIN, ceili(float(rooms.size()) * EnemyDefs.ENCOUNTER_MIN_SHARE))
	var added := 0
	for guard in rooms.size() * 2:
		var worst: Dictionary = {}
		var worst_d := -1.0
		for z in rooms:
			var c: Vector2 = center_of((z["rect"] as Rect2i).get_center())
			var d := _nearest_encounter(c)
			if d > worst_d:
				worst_d = d
				worst = z
		var need_gap := worst_d > EnemyDefs.ENCOUNTER_MAX_GAP
		if not need_gap and encounters.size() >= want:
			break
		var room: Dictionary = worst
		if not need_gap:                                         # count: the emptiest room without a group
			var empty: Array = rooms.filter(func(z): return _nearest_encounter(center_of((z["rect"] as Rect2i).get_center())) > float(NavMap.CELL) * 4.0)
			if empty.is_empty():
				break
			room = empty[rng.randi() % empty.size()]
		var size := rng.randi_range(int(EnemyDefs.FILLER_SIZE[0]), int(EnemyDefs.FILLER_SIZE[1]))
		var cells := _open_cells(room["rect"], rng, size)
		if cells.is_empty():
			rooms.erase(room)
			continue
		var members := _compose(foes, cells.size(), rng, cfg.get("pack", []) as Array)
		var zone := String(room["zone"])
		encounters.append({"kind": "patrol" if cells.size() == 1 else "group", "zone": zone if zone != "objective" else "danger",
			"members": members, "cells": cells, "patrol": [], "filler": true})
		for c in cells:
			enemy_spawn_cells.append(c)
		added += 1
	return added


func _nearest_encounter(p: Vector2) -> float:
	var best := INF
	for e in encounters:
		for c in e["cells"]:
			best = minf(best, p.distance_to(center_of(c)))
	return best


## Walkable cells of a room reachable from the entrance, not taken by a creature, a spot or the goal.
func _open_cells(room: Rect2i, rng: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	var start := center_of(spawn_cells[0]) if not spawn_cells.is_empty() else Vector2.ZERO
	for tries in count * 20:
		if out.size() >= count:
			break
		var c := Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), rng.randi_range(room.position.y + 1, room.end.y - 2))
		if is_blocked_cell(c) or out.has(c) or enemy_spawn_cells.has(c) or c == goal_cell or treasure_cells.has(c) \
				or resource_nodes.any(func(n): return n["cell"] == c):
			continue
		if out.is_empty() and find_path(start, center_of(c)).is_empty():
			continue                                             # never in a place nobody can walk to
		out.append(c)
	return out


## B1: no walkable cell the pathfinder cannot reach from the entrance (a unit pushed into such a
## pocket could never walk out). Content that landed in a sealed cell is dropped (nobody could reach
## it anyway). Also run on every snapshot load, so floors saved before the fix are safe too; the
## reachable layout never changes (D-026).
func _seal_pockets() -> void:
	if spawn_cells.is_empty() or seal_unreachable(spawn_cells[0], grid_rows) == 0:
		return
	var open := func(c: Vector2i) -> bool: return not is_blocked_cell(c)
	enemy_spawn_cells.assign(enemy_spawn_cells.filter(open))
	treasure_cells.assign(treasure_cells.filter(open))
	resource_nodes = resource_nodes.filter(func(n): return open.call(n["cell"]))
	for e in encounters:
		var keep: Array = []
		var members: Array = []
		for i in (e["cells"] as Array).size():
			if open.call(e["cells"][i]):
				keep.append(e["cells"][i])
				members.append(e["members"][i])
		e["cells"] = keep
		e["members"] = members
	encounters = encounters.filter(func(e): return not (e["cells"] as Array).is_empty())


## v2 content (D-056). Rooms are chained from the entrance (rooms[0]) to the goal (last), so the
## position in the chain is the progression: a quiet entrance, an explore band with small groups and
## patrols, a danger band with bigger mixed groups, ambushes and guarded treasure, and a guarded goal.
## Groups mix roles (a front-liner first, at most one healer) from the floor's creature list.
func _place_encounters(rooms: Array[Rect2i], map_grid: Array, rng: RandomNumberGenerator) -> void:
	encounters.clear()
	room_zones.clear()
	var cfg := TowerExpedition.get_floor_config(floor_number)
	# master prompt D: a floor's "threat" budget is spent in EnemyDefs.THREAT points (basic 1, healer 2,
	# elite 3...) so roles mix; old configs ("enemies") count one point per creature.
	var budget: int = int(cfg.get("threat", cfg.get("enemies", 8)))
	var party := TowerExpedition.party_max(floor_number) if floor_number > 0 else 5
	var foes: Array = cfg.get("foes", ["goblin"])
	var boss_id := ""
	if String(cfg.get("mission", "")) == "boss" and foes.size() > 1:
		boss_id = String(foes[0])                                # the boss waits at the goal, alone of its kind
		foes = foes.slice(1)
	var n := rooms.size()
	var reserve := mini(4, budget)                               # the goal's guards are always there
	var used := 0
	# 2026-10-31 (owner: "camino mucho sin pelear"): spread the threat over the whole chain of rooms, so
	# the budget does not run out halfway and leave long empty stretches.
	var per_room := float(budget - reserve) / float(maxi(1, rooms.size() - 2))
	for i in n:
		var f := float(i) / float(maxi(1, n - 1))
		var zone := "entrance" if f < 0.15 else ("explore" if f < 0.45 else "danger")
		if i == n - 1:
			zone = "objective"
		room_zones.append({"rect": rooms[i], "zone": zone})
		if i == 0 or zone == "entrance":
			continue
		var kind := ""
		var size := 0
		var roll := rng.randf()
		match zone:
			"explore":
				if roll < 0.62:
					kind = "group"
					size = rng.randi_range(2, 3)
				elif roll < 0.88:
					kind = "patrol"
					size = rng.randi_range(1, 2)
			"danger":
				if roll < 0.4:
					kind = "group"
					size = rng.randi_range(3, 4)
				elif roll < 0.65:
					kind = "ambush"
					size = rng.randi_range(2, 3)
				elif roll < 0.85:
					kind = "guard"
					size = 2
				else:
					kind = "patrol"
					size = 2
				if roll > 0.95:
					kind = ""
			"objective":
				kind = "guard"
				size = reserve
		if kind == "":
			if rng.randf() < 0.35 and treasure_cells.size() < 6:
				_add_treasure(rooms[i], map_grid, rng)         # quiet room, small find
			continue
		if zone != "objective":
			size = mini(size, budget - reserve - used)
			if size <= 0:
				continue
		if size == party and floor_number > 0:
			size += 1                                            # a group is never the squad's size
		var cells := _free_cells(rooms[i], map_grid, rng, size)
		if cells.is_empty():
			continue
		var members := _compose(foes, cells.size(), rng, cfg.get("pack", []) as Array)
		if zone == "objective" and boss_id != "":
			members[0] = boss_id
		if cfg.has("threat") and zone != "objective":
			var allow := mini(budget - reserve - used, ceili(per_room * float(i) + per_room * 1.5) - used)
			while members.size() > 1 and _threat(members) > maxi(1, allow):
				members.pop_back()
				cells.pop_back()
		var enc := {"kind": kind, "zone": zone, "members": members, "cells": cells, "patrol": []}
		if kind == "patrol" and i + 1 < n:
			enc["patrol"] = [rooms[i].get_center(), rooms[mini(n - 2, i + 1)].get_center()]
		if kind == "guard" and zone != "objective":
			_add_treasure(rooms[i], map_grid, rng)
		encounters.append(enc)
		used += _threat(members) if cfg.has("threat") else cells.size()
		for c in cells:
			enemy_spawn_cells.append(c)
	_place_nodes(rooms, map_grid, rng, cfg)


## Gathering spots spread over the rooms after the entrance (count and mix per floor config).
func _place_nodes(rooms: Array[Rect2i], map_grid: Array, rng: RandomNumberGenerator, cfg: Dictionary) -> void:
	resource_nodes.clear()
	var mix: Dictionary = cfg.get("node_mix", {"herb": 1, "wood": 1, "ore": 1})
	var bag: Array = []
	for k in mix:
		for i in int(mix[k]):
			bag.append(String(k))
	var want := int(cfg.get("nodes", 0))
	var tries := 0
	while resource_nodes.size() < want and tries < want * 10 and rooms.size() > 2:
		tries += 1
		var room: Rect2i = rooms[rng.randi_range(1, rooms.size() - 1)]
		var cells := _free_cells(room, map_grid, rng, 1)
		if cells.is_empty() or resource_nodes.any(func(n): return n["cell"] == cells[0]) or treasure_cells.has(cells[0]):
			continue
		resource_nodes.append({"kind": String(bag[rng.randi() % bag.size()]), "cell": cells[0]})
	# D-066 Wilds: hidden caches of building materials in the deep rooms (danger / objective zones)
	var deep: Array = room_zones.filter(func(z): return String(z["zone"]) in ["danger", "objective"])
	var caches := int(cfg.get("caches", 0))
	tries = 0
	while caches > 0 and not deep.is_empty() and tries < 40:
		tries += 1
		var dz: Dictionary = deep[rng.randi() % deep.size()]
		var cc := _free_cells(dz["rect"], map_grid, rng, 1)
		if cc.is_empty() or resource_nodes.any(func(n): return n["cell"] == cc[0]):
			continue
		resource_nodes.append({"kind": "cache", "cell": cc[0]})
		caches -= 1


## Room zone of a cell ("" outside every room): the Wilds scale creatures and spots by it.
func zone_of(cell: Vector2i) -> String:
	for z in room_zones:
		if (z["rect"] as Rect2i).has_point(cell):
			return String(z["zone"])
	return ""


## A mixed group: a front-liner first, then any creature of the floor, at most one support.
func _threat(members: Array) -> int:
	var t := 0
	for id in members:
		t += EnemyDefs.threat_of(String(id))
	return t


func _compose(foes: Array, count: int, rng: RandomNumberGenerator, pack: Array = []) -> Array:
	if not pack.is_empty():
		var by_role: Array = []
		for k in count:
			var want := String(pack[k % pack.size()])
			var fit := foes.filter(func(id): return EnemyDefs.role_of(String(id)) == want)
			by_role.append(String(fit[rng.randi_range(0, fit.size() - 1)]) if not fit.is_empty() else String(foes[rng.randi_range(0, foes.size() - 1)]))
		return by_role
	var front := foes.filter(func(id): return EnemyDefs.role_of(String(id)) in ["melee", "brute", "guard", "swarm", "assassin"])
	var out: Array = []
	var supports := 0
	for k in count:
		var pick := String(foes[rng.randi_range(0, foes.size() - 1)])
		if k == 0 and not front.is_empty():
			pick = String(front[rng.randi_range(0, front.size() - 1)])
		if EnemyDefs.role_of(pick) == "support":
			supports += 1
			if supports > 1 and not front.is_empty():
				pick = String(front[rng.randi_range(0, front.size() - 1)])
		out.append(pick)
	return out


func _free_cells(room: Rect2i, map_grid: Array, rng: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 20:
		tries += 1
		var c := Vector2i(rng.randi_range(room.position.x + 1, room.end.x - 2), rng.randi_range(room.position.y + 1, room.end.y - 2))
		if map_grid[c.y][c.x] == "." and not out.has(c) and not enemy_spawn_cells.has(c) and c != goal_cell:
			out.append(c)
	return out


func _add_treasure(room: Rect2i, map_grid: Array, rng: RandomNumberGenerator) -> void:
	var c := room.get_center() + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
	if map_grid[c.y][c.x] == "." and not treasure_cells.has(c):
		treasure_cells.append(c)


## Full snapshot (D-004 / D-026): the floor is loaded exactly as generated, never regenerated.
func to_snapshot() -> Dictionary:
	var enc: Array = []
	for e in encounters:
		enc.append({"kind": e["kind"], "zone": e["zone"], "members": e["members"],
			"cells": (e["cells"] as Array).map(func(c): return [c.x, c.y]), "patrol": (e["patrol"] as Array).map(func(c): return [c.x, c.y])})
	var zones: Array = []
	for z in room_zones:
		var r: Rect2i = z["rect"]
		zones.append({"rect": [r.position.x, r.position.y, r.size.x, r.size.y], "zone": z["zone"]})
	return {"gen": gen_version, "seed": seed_value, "width": width, "height": height, "grid_rows": grid_rows.duplicate(),
		"spawn": spawn_cells.map(func(c): return [c.x, c.y]), "goal": [goal_cell.x, goal_cell.y],
		"relic": [relic_cell.x, relic_cell.y], "extract": [extract_cell.x, extract_cell.y],
		"enemy_cells": enemy_spawn_cells.map(func(c): return [c.x, c.y]),
		"treasure": treasure_cells.map(func(c): return [c.x, c.y]), "encounters": enc, "zones": zones,
		"nodes": resource_nodes.map(func(n): return {"kind": n["kind"], "cell": [n["cell"].x, n["cell"].y]})}


static func _v(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func from_snapshot(d: Dictionary, floor_num: int) -> ProceduralMap:
	var m := ProceduralMap.new(int(d["width"]), int(d["height"]), int(d["seed"]), floor_num, int(d.get("gen", GEN_VERSION)), false)
	for r in d["grid_rows"]:
		m.grid_rows.append(String(r))
	for c in d.get("spawn", []):
		m.spawn_cells.append(_v(c))
	m.goal_cell = _v(d["goal"])
	m.relic_cell = _v(d.get("relic", d["goal"]))
	m.extract_cell = _v(d.get("extract", d["spawn"][0]))
	for c in d.get("enemy_cells", []):
		m.enemy_spawn_cells.append(_v(c))
	for c in d.get("treasure", []):
		m.treasure_cells.append(_v(c))
	m.objective_cells.append(m.goal_cell)
	for e in d.get("encounters", []):
		m.encounters.append({"kind": String(e["kind"]), "zone": String(e["zone"]), "members": (e["members"] as Array).map(func(x): return String(x)),
			"cells": (e["cells"] as Array).map(func(c): return _v(c)), "patrol": (e.get("patrol", []) as Array).map(func(c): return _v(c))})
	for n in d.get("nodes", []):
		m.resource_nodes.append({"kind": String(n["kind"]), "cell": _v(n["cell"])})
	for z in d.get("zones", []):
		var r: Array = z["rect"]
		m.room_zones.append({"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), "zone": String(z["zone"])})
	m.grid = AStarGrid2D.new()
	m.grid.region = Rect2i(0, 0, m.width, m.height)
	m.grid.cell_size = Vector2(CELL, CELL)
	m.grid.offset = Vector2(CELL, CELL) * 0.5
	m.grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	m.grid.update()
	for y in m.height:
		for x in m.width:
			if m.grid_rows[y][x] == "#":
				m.grid.set_point_solid(Vector2i(x, y), true)
	m._seal_pockets()
	if m.gen_version >= 2:
		m.ensure_density()                                       # D-082b: floors saved before the fix too
	return m


func _force_fallback_generate(_rng: RandomNumberGenerator) -> void:
	var map_grid := []
	for y in height:
		var row := []
		for x in width:
			row.append("#" if (x == 0 or y == 0 or x == width - 1 or y == height - 1) else ".")
		map_grid.append(row)

	spawn_cells = [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 3)]
	goal_cell = Vector2i(width - 4, height - 4)
	if floor_number != 0:
		enemy_spawn_cells = [Vector2i(width / 2, height / 2), Vector2i(width / 2 + 2, height / 2)]
		treasure_cells = [Vector2i(width / 3, height / 3)]
	else:
		enemy_spawn_cells.clear()
		treasure_cells.clear()

	grid_rows.clear()
	for y in height:
		var row_str := ""
		for x in width:
			row_str += String(map_grid[y][x])
		grid_rows.append(row_str)

	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2(CELL, CELL)
	grid.offset = Vector2(CELL, CELL) * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				grid.set_point_solid(Vector2i(x, y), true)
	_set_mission_cells()


func _validate_map() -> bool:
	if spawn_cells.is_empty():
		return false
	var test_grid := AStarGrid2D.new()
	test_grid.region = Rect2i(0, 0, width, height)
	test_grid.cell_size = Vector2(CELL, CELL)
	test_grid.update()
	for y in height:
		for x in width:
			if grid_rows[y][x] == "#":
				test_grid.set_point_solid(Vector2i(x, y), true)
	var path := test_grid.get_point_path(spawn_cells[0], goal_cell)
	return path.size() > 0


## Forest look (D-031): clearings get ragged edges and a few tree clumps inside, so rooms stop
## looking like rectangles. Never touches corridor cells ("c") or the room centre; reachability is
## re-checked by _validate_map afterwards.
func _roughen_rooms(map_grid: Array, rooms: Array[Rect2i], rng: RandomNumberGenerator) -> void:
	for room in rooms:
		var centre := room.get_center()
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if map_grid[y][x] != ".":
					continue
				var edge := x == room.position.x or y == room.position.y or x == room.end.x - 1 or y == room.end.y - 1
				var corner := (x - room.position.x < 2 or room.end.x - 1 - x < 2) and (y - room.position.y < 2 or room.end.y - 1 - y < 2)
				if Vector2i(x, y).distance_to(centre) < 2.5:
					continue
				if (corner and rng.randf() < 0.75) or (edge and rng.randf() < 0.35):
					map_grid[y][x] = "#"
				elif not edge and room.size.x > 9 and room.size.y > 9 and rng.randf() < 0.025:
					map_grid[y][x] = "#"                  # lone tree clump inside a big clearing


func _carve_corridor(map_grid: Array, p1: Vector2i, p2: Vector2i) -> void:
	var cx := p1.x
	var cy := p1.y
	var horizontal_first := (seed_value % 2 == 0)
	if horizontal_first:
		while cx != p2.x:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "c"
			cx += 1 if p2.x > cx else -1
		while cy != p2.y:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "c"
			cy += 1 if p2.y > cy else -1
	else:
		while cy != p2.y:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "c"
			cy += 1 if p2.y > cy else -1
		while cx != p2.x:
			if in_bounds(Vector2i(cx, cy)):
				map_grid[cy][cx] = "c"
			cx += 1 if p2.x > cx else -1
