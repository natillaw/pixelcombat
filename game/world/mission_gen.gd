## MissionGen — sortea las misiones de un piso y coloca sobre el mapa todo lo necesario
## para poder cumplirlas.
##
## Regla de oro: **una mision nunca se genera si no se puede hacer en ese piso**. Cada
## tipo coloca siempre mas de lo que pide (vetas ricas que dan 3 unidades, mas enemigos
## del tipo a exterminar que el objetivo, altares y balizas en puntos alcanzables...) y
## `check()` lo verifica sobre el layout generado (los tests lo pasan a cientos de
## pisos).
##
## Tipos de piso:
##  - normal: una mision principal (limpieza, caceria, exterminio, recoleccion, altares,
##    balizas, rescate, nidos, resistencia o reliquia) y, a veces, una opcional.
##  - x5 (pico): mision doble — una principal mas la de los dos mini-jefes —, a menudo
##    con limite de tiempo, y a veces una opcional.
##  - x10 (jefe): una prueba (sellos que rompen el escudo del jefe, oleadas antes de que
##    aparezca, o caza de elites) y el jefe reforzado.
##
## El plan resultante (`layout.mission_plan`) es solo datos: `Mission` lo ejecuta.
class_name MissionGen
extends RefCounted

const GUARD_RADIUS := 70.0


## Estado compartido de una generacion.
class Ctx extends RefCounted:
	var layout: FloorLayout
	var analysis: MapAnalysis
	var rng: RandomNumberGenerator
	var tier_data: Dictionary
	var tier: int
	var placed: Array = []
	var camp_counter: int = 0
	## Si es true los enemigos ambientales cuentan para completar el piso (mision "clear").
	var ambient_required: bool = false
	## Solo pruebas: ids de mision forzados.
	var forced: Array = []


static func populate(layout: FloorLayout, analysis: MapAnalysis, rng: RandomNumberGenerator, floor_number: int, tier_data: Dictionary, spike: String, forced: Array = []) -> void:
	var ctx := Ctx.new()
	ctx.forced = forced
	ctx.layout = layout
	ctx.analysis = analysis
	ctx.rng = rng
	ctx.tier_data = tier_data
	ctx.tier = layout.tier
	ctx.placed = [analysis.spawn_position(), analysis.exit_position()]

	var plan := _choose_plan(ctx, floor_number, spike)
	var specs: Array = plan["missions"]
	for spec: Dictionary in specs:
		if String(spec["kind"]) == "clear" and not bool(spec["optional"]):
			ctx.ambient_required = true
	for spec: Dictionary in specs:
		_place(ctx, spec)
	_add_ambient(ctx)
	if ctx.ambient_required:
		for spec: Dictionary in specs:
			if String(spec["kind"]) == "clear":
				spec["target"] = layout.enemies.filter(func(e: Dictionary) -> bool: return bool(e["required"])).size()
	layout.mission_plan = {"missions": specs, "time_limit": float(plan["time_limit"]), "variant": String(plan["variant"])}
	var main_titles: Array = specs.filter(func(s: Dictionary) -> bool: return not bool(s["optional"])).map(func(s: Dictionary) -> String: return String(s["title"]))
	layout.objective = {"type": "missions", "label": " + ".join(main_titles)}


# --- Plan -------------------------------------------------------------------------


static func _choose_plan(ctx: Ctx, floor_number: int, spike: String) -> Dictionary:
	var rng := ctx.rng
	var specs: Array = []
	var time_limit := 0.0
	var variant := ""
	if spike == "boss":
		var boss_cfg := MissionCatalog.config("spike_boss")
		var variants: Array = boss_cfg["variants"]
		variant = String(variants[rng.randi_range(0, variants.size() - 1)])
		if not ctx.forced.is_empty():
			variant = String(ctx.forced[0])
		match variant:
			"seals":
				specs.append(_synthetic(ctx, "seals", "interact", "Romper los sellos", "Rompe los {count} sellos para quebrar el escudo del jefe", rng.randi_range(int(boss_cfg["seals"][0]), int(boss_cfg["seals"][1])), 1.4, {"group": "seal", "channel": 3.0, "on_complete": {"unshield": "boss"}}))
			"gauntlet":
				specs.append(_synthetic(ctx, "gauntlet", "survive", "Oleadas", "Resiste {seconds} s las oleadas junto a la baliza: despues llegara el jefe", 1, 1.6, {"group": "survive", "seconds": rng.randi_range(int(boss_cfg["gauntlet_seconds"][0]), int(boss_cfg["gauntlet_seconds"][1])), "on_complete": {"spawn_deferred": "boss"}}))
			_:
				specs.append(_synthetic(ctx, "elites", "kill_group", "Los guardianes", "Derrota a los {count} guardianes elite para quebrar el escudo del jefe", 2, 1.5, {"group": "elite_guard", "on_complete": {"unshield": "boss"}}))
		specs.append(_synthetic(ctx, "boss", "kill_group", "El jefe del tier", "Derrota a {names}", 1, 3.0, {"group": "boss"}))
		if rng.randf() < float(boss_cfg["optional_chance"]):
			specs.append(_optional(ctx, floor_number, specs))
	elif spike == "mid_boss":
		var mid_cfg := MissionCatalog.config("spike_mid")
		var primary := _pick_template(rng, MissionCatalog.eligible(ctx.tier, mid_cfg["primary_pool"]))
		if not ctx.forced.is_empty():
			primary = MissionCatalog.mission(String(ctx.forced[0]))
		specs.append(_from_template(ctx, primary, false))
		specs.append(_synthetic(ctx, "bosses", "kill_group", "Los dos mini-jefes", "Derrota a {names}", 2, 2.2, {"group": "mini"}))
		if rng.randf() < float(mid_cfg["time_limit_chance"]):
			time_limit = float(rng.randi_range(int(mid_cfg["time_limit_seconds"][0]), int(mid_cfg["time_limit_seconds"][1])))
		if rng.randf() < float(mid_cfg["optional_chance"]):
			specs.append(_optional(ctx, floor_number, specs))
	else:
		var main_template := _pick_template(rng, MissionCatalog.eligible(ctx.tier))
		if not ctx.forced.is_empty():
			main_template = MissionCatalog.mission(String(ctx.forced[0]))
		specs.append(_from_template(ctx, main_template, false))
		var optional_cfg := MissionCatalog.config("optional")
		var chance := float(optional_cfg["chance_first_floors"]) if floor_number <= 3 else float(optional_cfg["chance"])
		if ctx.forced.size() > 1:
			specs.append(_from_template(ctx, MissionCatalog.mission(String(ctx.forced[1])), true))
		elif ctx.forced.is_empty() and rng.randf() < chance:
			specs.append(_optional(ctx, floor_number, specs))
	return {"missions": specs, "time_limit": time_limit, "variant": variant}


static func _pick_template(rng: RandomNumberGenerator, templates: Array) -> Dictionary:
	var total := 0.0
	for entry: Dictionary in templates:
		total += float(entry["weight"])
	var roll := rng.randf() * total
	for entry: Dictionary in templates:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry
	return templates[templates.size() - 1]


## Una mision opcional distinta de las que ya hay (por id y por tipo de contenido).
static func _optional(ctx: Ctx, _floor_number: int, existing: Array) -> Dictionary:
	var cfg := MissionCatalog.config("optional")
	var taken: Array = existing.map(func(s: Dictionary) -> String: return String(s["id"]))
	var pool: Array = (cfg["pool"] as Array).filter(func(id: Variant) -> bool: return not taken.has(String(id)))
	var choice := _pick_template(ctx.rng, MissionCatalog.eligible(ctx.tier, pool))
	return _from_template(ctx, choice, true)


static func _count(ctx: Ctx, template: Dictionary, optional: bool) -> int:
	var range_data: Array = template.get("count", [1, 1])
	var count := ctx.rng.randi_range(int(range_data[0]), int(range_data[1]))
	if optional:
		count = maxi(1, int(round(float(count) * float(MissionCatalog.config("optional")["scale"]))))
	return count


static func _runtime_kind(kind: String) -> String:
	match kind:
		"hunt", "destroy":
			return "kill_group"
		"activate", "rescue":
			return "interact"
		_:
			return kind


static func _from_template(ctx: Ctx, template: Dictionary, optional: bool) -> Dictionary:
	var kind := String(template["kind"])
	var spec := {
		"id": String(template["id"]), "kind": _runtime_kind(kind), "source_kind": kind, "optional": optional,
		"title": String(template["name"]), "desc": String(template["desc"]),
		"target": 1, "xp_mult": float(template["xp_mult"]) * (float(MissionCatalog.config("optional")["xp_mult"]) if optional else 1.0),
		"group": "", "on_complete": {},
	}
	if optional:
		spec["title"] = "(Opcional) " + String(template["name"])
	match kind:
		"clear":
			spec["target"] = 0
		"hunt":
			spec["target"] = _count(ctx, template, optional)
			spec["group"] = "hunt"
		"destroy":
			spec["target"] = _count(ctx, template, optional)
			spec["group"] = "nest"
		"slay":
			spec["target"] = _count(ctx, template, optional)
			var pool: Array = ctx.tier_data["pool"]
			var chosen := _pick_enemy(ctx)
			if pool.size() > 1:
				# Evita los mas raros: el objetivo se cumple con los comunes.
				chosen = String((pool[ctx.rng.randi_range(0, pool.size() - 1)] as Dictionary)["id"])
			spec["enemy_id"] = chosen
		"collect":
			spec["target"] = _count(ctx, template, optional)
			var kinds := MaterialCatalog.gatherable_kinds()
			spec["material_kind"] = String(kinds[ctx.rng.randi_range(0, kinds.size() - 1)])
		"activate":
			spec["target"] = _count(ctx, template, optional)
			spec["group"] = "altar"
			spec["channel"] = float(template["channel"])
		"rescue":
			spec["target"] = _count(ctx, template, optional)
			spec["group"] = "cage"
			spec["channel"] = float(template["channel"])
		"explore":
			spec["target"] = _count(ctx, template, optional)
			spec["group"] = "waypoint"
		"survive":
			var seconds_range: Array = template["seconds"]
			spec["seconds"] = ctx.rng.randi_range(int(seconds_range[0]), int(seconds_range[1]))
			if optional:
				spec["seconds"] = int(round(float(spec["seconds"]) * 0.7))
			spec["group"] = "survive"
		"relic":
			spec["target"] = 2
			spec["group"] = "relic"
			spec["groups"] = ["relic", "relic_altar"]
	return _describe(spec, ctx)


static func _synthetic(ctx: Ctx, id: String, kind: String, title: String, desc: String, target: int, xp_mult: float, extra: Dictionary) -> Dictionary:
	var spec := {
		"id": id, "kind": kind, "source_kind": kind, "optional": false, "title": title, "desc": desc,
		"target": target, "xp_mult": xp_mult, "group": "", "on_complete": {},
	}
	for key: String in extra:
		spec[key] = extra[key]
	return _describe(spec, ctx)


## Rellena los marcadores {count}, {enemy}, {material}, {names} y {seconds} del texto.
static func _describe(spec: Dictionary, ctx: Ctx) -> Dictionary:
	var text := String(spec["desc"])
	text = text.replace("{count}", str(int(spec["target"])))
	text = text.replace("{seconds}", str(int(spec.get("seconds", 0))))
	if spec.has("enemy_id"):
		text = text.replace("{enemy}", String(EnemyCatalog.enemy(StringName(String(spec["enemy_id"])))["name"]) + "s")
	if spec.has("material_kind"):
		text = text.replace("{material}", MaterialCatalog.display_name(MaterialCatalog.material_id(String(spec["material_kind"]), ctx.tier)))
	text = text.replace("{names}", _names_for(spec, ctx))
	spec["desc"] = text
	return spec


static func _names_for(spec: Dictionary, ctx: Ctx) -> String:
	match String(spec["id"]):
		"bosses":
			return "%s y %s" % [_enemy_name(String(ctx.tier_data["mid_boss"])), _enemy_name(String(ctx.tier_data["mid_boss_2"]))]
		"boss":
			return _enemy_name(String(ctx.tier_data["boss"]))
		"hunt":
			return "elites del bosque"
	return "los objetivos"


static func _enemy_name(id: String) -> String:
	return String(EnemyCatalog.enemy(StringName(id))["name"])


# --- Colocacion -------------------------------------------------------------------


static func _place(ctx: Ctx, spec: Dictionary) -> void:
	match String(spec["id"]):
		"seals":
			_place_interactables(ctx, spec, "seal", 0.3, 0.92, 3, 1.0)
			_place_boss(ctx, spec, true, false)
		"gauntlet":
			_place_survive(ctx, spec)
			_place_boss(ctx, spec, false, true)
		"elites":
			_place_hunt(ctx, spec, "elite_guard", false)
			_place_boss(ctx, spec, true, false)
		"boss", "bosses":
			if String(spec["id"]) == "bosses":
				_place_mini_bosses(ctx, spec)
			# El jefe del piso x10 lo coloca la prueba que lo protege.
		_:
			match String(spec["source_kind"]):
				"clear":
					pass
				"hunt":
					_place_hunt(ctx, spec, "hunt", true)
				"destroy":
					_place_nests(ctx, spec)
				"slay":
					_place_slay(ctx, spec)
				"collect":
					_place_collect(ctx, spec)
				"activate":
					_place_interactables(ctx, spec, "altar", 0.22, 1.0, 3, 1.0)
				"rescue":
					_place_interactables(ctx, spec, "cage", 0.25, 1.0, 4, 1.0)
				"explore":
					_place_waypoints(ctx, spec)
				"survive":
					_place_survive(ctx, spec)
				"relic":
					_place_relic(ctx, spec)


static func _spot(ctx: Ctx, t_min: float, t_max: float, clearance: int, spacing: float) -> Vector2:
	var point: Variant = null
	var wanted := clearance
	while point == null and wanted >= 1:
		point = ctx.analysis.pick_spot(ctx.rng, t_min, t_max, wanted, ctx.placed, spacing)
		wanted -= 1
	if point == null:
		point = ctx.analysis.spawn_position()
	ctx.placed.append(point)
	return point as Vector2


static func _walkable_near(ctx: Ctx, center: Vector2, radius: float) -> Vector2:
	for attempt: int in range(12):
		var offset := Vector2.from_angle(ctx.rng.randf() * TAU) * ctx.rng.randf_range(0.0, radius)
		var point := center + offset
		var cell := ctx.analysis.cell_at(point)
		if ctx.analysis.dist[cell.y * ctx.analysis.grid.cols + cell.x] >= 0 and ctx.analysis.clearance_at(cell) >= 1:
			return point
	return center


static func _pick_enemy(ctx: Ctx) -> String:
	var pool: Array = ctx.tier_data["pool"]
	var total := 0.0
	for entry: Dictionary in pool:
		total += float(entry["weight"])
	var roll := ctx.rng.randf() * total
	for entry: Dictionary in pool:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return String(entry["id"])
	return String((pool[pool.size() - 1] as Dictionary)["id"])


static func _add_enemy(ctx: Ctx, id: String, position: Vector2, required: bool, group: String, extra: Dictionary = {}) -> Dictionary:
	var spec := {"id": StringName(id), "position": position, "required": required, "group": group}
	for key: String in extra:
		spec[key] = extra[key]
	ctx.layout.enemies.append(spec)
	return spec


## Un grupo de enemigos alrededor de `center`. `ids` vacio = elegidos del pool del tier.
static func _camp(ctx: Ctx, center: Vector2, size: int, required: bool, group: String, ids: Array = []) -> void:
	for i: int in range(size):
		var id := String(ids[i % ids.size()]) if not ids.is_empty() else _pick_enemy(ctx)
		_add_enemy(ctx, id, _walkable_near(ctx, center, GUARD_RADIUS), required, group)


static func _guard(ctx: Ctx, center: Vector2, size: int) -> void:
	_camp(ctx, center, size, false, "guard")


static func _place_hunt(ctx: Ctx, spec: Dictionary, group: String, with_guards: bool) -> void:
	spec["group"] = group
	var count := int(spec["target"])
	for i: int in range(count):
		var t_min := 0.35 + 0.5 * float(i) / float(count)
		var spot := _spot(ctx, t_min, minf(1.0, t_min + 0.4), 2, 420.0)
		# Un elite es un enemigo del pool reforzado.
		_add_enemy(ctx, _pick_enemy(ctx), spot, false, group, {"elite": true})
		if with_guards:
			_guard(ctx, spot, 2)


static func _place_nests(ctx: Ctx, spec: Dictionary) -> void:
	var count := int(spec["target"])
	for i: int in range(count):
		var t_min := 0.3 + 0.55 * float(i) / float(count)
		var spot := _spot(ctx, t_min, minf(1.0, t_min + 0.4), 3, 380.0)
		_add_enemy(ctx, String(ctx.tier_data["nest"]), spot, false, "nest")
		_guard(ctx, spot, 2)


static func _place_slay(ctx: Ctx, spec: Dictionary) -> void:
	var enemy_id := String(spec["enemy_id"])
	var needed := int(spec["target"]) + 3
	var packs := int(ceil(float(needed) / 3.0))
	for i: int in range(packs):
		var spot := _spot(ctx, 0.15 + 0.8 * float(i) / float(maxi(packs, 1)), 1.0, 2, 220.0)
		_camp(ctx, spot, 3, false, "slay_pack", [enemy_id])


static func _place_collect(ctx: Ctx, spec: Dictionary) -> void:
	var nodes := int(ceil(float(int(spec["target"])) / float(ResourceNode.RICH_YIELD))) + 1
	for i: int in range(nodes):
		var spot := _spot(ctx, 0.08, 1.0, 1, 170.0)
		ctx.layout.resources.append({"kind": String(spec["material_kind"]), "position": spot, "rich": true})
	# Cada tres vetas, una patrulla cerca para que no sea un paseo.
	for i: int in range(maxi(1, nodes / 3)):
		var node: Dictionary = ctx.layout.resources[ctx.layout.resources.size() - 1 - i]
		_guard(ctx, node["position"], 2)


## `count` objetos de `kind` repartidos por bandas del camino; cada uno con una guardia.
static func _place_interactables(ctx: Ctx, spec: Dictionary, kind: String, t_lo: float, t_hi: float, guard_size: int, _unused: float) -> void:
	var count := int(spec["target"])
	for i: int in range(count):
		var t_min := t_lo + (t_hi - t_lo) * float(i) / float(count)
		var t_max := t_lo + (t_hi - t_lo) * float(i + 1) / float(count)
		var spot := _spot(ctx, t_min, t_max, 2, 300.0)
		ctx.layout.interactables.append({"kind": kind, "position": spot, "group": String(spec["group"]), "channel": float(spec.get("channel", 2.5)), "label": _label(kind)})
		_guard(ctx, spot, guard_size)


static func _label(kind: String) -> String:
	match kind:
		"altar":
			return "Altar antiguo"
		"cage":
			return "Prisionero"
		"seal":
			return "Sello del jefe"
		"beacon":
			return "Baliza de resistencia"
		"relic":
			return "Reliquia"
		"relic_altar":
			return "Altar de entrega"
		"waypoint":
			return "Baliza"
	return kind


static func _place_waypoints(ctx: Ctx, spec: Dictionary) -> void:
	var count := int(spec["target"])
	for i: int in range(count):
		var t_min := 0.18 + 0.82 * float(i) / float(count)
		var spot := _spot(ctx, t_min, minf(1.0, t_min + 0.82 / float(count)), 2, 380.0)
		ctx.layout.interactables.append({"kind": "waypoint", "position": spot, "group": "waypoint", "channel": 0.0, "label": "Baliza"})


static func _place_survive(ctx: Ctx, spec: Dictionary) -> void:
	var spot := _spot(ctx, 0.4, 0.8, 4, 360.0)
	spec["radius"] = 250.0
	spec["wave_size"] = 3 + ctx.tier / 2 + (1 if int(spec["seconds"]) > 75 else 0)
	spec["wave_interval"] = 11.0
	spec["wave_seed"] = ctx.rng.randi()
	spec["wave_pool"] = (ctx.tier_data["pool"] as Array).map(func(e: Dictionary) -> String: return String(e["id"]))
	spec["beacon"] = [spot.x, spot.y]
	ctx.layout.interactables.append({"kind": "beacon", "position": spot, "group": "survive", "channel": 1.5, "label": _label("beacon")})


static func _place_relic(ctx: Ctx, spec: Dictionary) -> void:
	var relic_spot := _spot(ctx, 0.6, 0.96, 3, 400.0)
	ctx.layout.interactables.append({"kind": "relic", "position": relic_spot, "group": "relic", "channel": 2.0, "label": _label("relic")})
	_add_enemy(ctx, _pick_enemy(ctx), relic_spot, false, "relic_guard", {"elite": true})
	_guard(ctx, relic_spot, 3)
	var altar_spot := _spot(ctx, 0.08, 0.3, 2, 300.0)
	ctx.layout.interactables.append({"kind": "relic_altar", "position": altar_spot, "group": "relic_altar", "channel": 2.0, "requires": "relic", "label": _label("relic_altar")})


## Los dos mini-jefes del piso x5, en puntos lejanos y distintos, con crias.
static func _place_mini_bosses(ctx: Ctx, _spec: Dictionary) -> void:
	var ids := [String(ctx.tier_data["mid_boss"]), String(ctx.tier_data["mid_boss_2"])]
	for i: int in range(2):
		var spot := _spot(ctx, 0.5 + 0.2 * float(i), 1.0, 4, 650.0)
		_add_enemy(ctx, ids[i], spot, true, "mini")
		var adds: Array = ctx.tier_data["adds"]
		for k: int in range(2):
			_add_enemy(ctx, String(adds[ctx.rng.randi_range(0, adds.size() - 1)]), _walkable_near(ctx, spot, 110.0), false, "guard")


## El jefe del piso x10: reforzado y, segun la prueba, protegido (escudo) o diferido.
static func _place_boss(ctx: Ctx, _spec: Dictionary, shielded: bool, deferred: bool) -> void:
	var boost: Array = MissionCatalog.config("spike_boss")["boss_boost"]
	var spot := _spot(ctx, 0.82, 1.0, 5, 500.0)
	var spec := {"id": StringName(String(ctx.tier_data["boss"])), "position": spot, "required": true, "group": "boss", "boost": [float(boost[0]), float(boost[1])], "invulnerable": shielded}
	if deferred:
		ctx.layout.deferred_enemies.append(spec)
	else:
		ctx.layout.enemies.append(spec)
		var adds: Array = ctx.tier_data["adds"]
		for k: int in range(3):
			_add_enemy(ctx, String(adds[ctx.rng.randi_range(0, adds.size() - 1)]), _walkable_near(ctx, spot, 130.0), false, "guard")


# --- Ambiente ---------------------------------------------------------------------


## Campamentos de enemigos y nodos de recoleccion repartidos por todo el mapa.
static func _add_ambient(ctx: Ctx) -> void:
	var camps_cfg := MissionCatalog.config("camps")
	var reach := ctx.analysis.reach.size()
	var camps := maxi(3, reach / int(camps_cfg["cells_per_camp"]))
	var size_range: Array = camps_cfg["size"]
	for i: int in range(camps):
		var spot := _spot(ctx, 0.14, 1.0, 2, float(camps_cfg["spacing"]))
		var size := ctx.rng.randi_range(int(size_range[0]), int(size_range[1])) + (ctx.tier - 1) / 3
		_camp(ctx, spot, mini(size, 6), ctx.ambient_required, "camp_%d" % ctx.camp_counter)
		ctx.camp_counter += 1
	var nodes_cfg := MissionCatalog.config("nodes")
	var node_count := clampi(reach / int(nodes_cfg["cells_per_node"]), int(nodes_cfg["min"]), int(nodes_cfg["max"]))
	var kinds := MaterialCatalog.gatherable_kinds()
	for i: int in range(node_count):
		var spot := _spot(ctx, 0.05, 1.0, 1, 130.0)
		ctx.layout.resources.append({"kind": String(kinds[ctx.rng.randi_range(0, kinds.size() - 1)]), "position": spot})


# --- Verificacion -----------------------------------------------------------------


## Problemas que impedirian cumplir las misiones del layout (lista vacia = todo bien).
## Comprueba que hay objetos suficientes, que son alcanzables y que los grupos coinciden.
static func check(layout: FloorLayout) -> Array[String]:
	var problems: Array[String] = []
	if layout.grid == null or layout.mission_plan.is_empty():
		return ["el layout no tiene mapa o plan de misiones"]
	var cell := layout.grid.world_to_cell(layout.player_spawn)
	var seen := layout.grid.reachable_from(cell)
	var reachable := func(point: Vector2) -> bool:
		var c := layout.grid.world_to_cell(point)
		return seen[c.y * layout.grid.cols + c.x] == 1
	for enemy: Dictionary in layout.enemies:
		if not reachable.call(enemy["position"]):
			problems.append("enemigo %s inalcanzable" % str(enemy["id"]))
	for enemy: Dictionary in layout.deferred_enemies:
		if not reachable.call(enemy["position"]):
			problems.append("enemigo diferido %s inalcanzable" % str(enemy["id"]))
	for object: Dictionary in layout.interactables:
		if not reachable.call(object["position"]):
			problems.append("objeto %s inalcanzable" % String(object["kind"]))
	for node: Dictionary in layout.resources:
		if not reachable.call(node["position"]):
			problems.append("nodo %s inalcanzable" % String(node["kind"]))
	var mains := 0
	for spec: Dictionary in layout.mission_plan["missions"]:
		if not bool(spec["optional"]):
			mains += 1
		var target := int(spec["target"])
		var id := String(spec["id"])
		match String(spec["kind"]):
			"clear":
				var required := layout.enemies.filter(func(e: Dictionary) -> bool: return bool(e["required"])).size()
				if required < 1:
					problems.append("%s: no hay enemigos obligatorios" % id)
			"kill_group":
				var group := String(spec["group"])
				var total := layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == group).size() + layout.deferred_enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == group).size()
				if total < target:
					problems.append("%s: hay %d enemigos del grupo %s y pide %d" % [id, total, group, target])
			"slay":
				var same := layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["id"]) == String(spec["enemy_id"])).size()
				if same < target + 1:
					problems.append("%s: hay %d %s y pide %d" % [id, same, spec["enemy_id"], target])
			"collect":
				var supply := 0
				for node: Dictionary in layout.resources:
					if String(node["kind"]) == String(spec["material_kind"]) and bool(node.get("rich", false)):
						supply += ResourceNode.RICH_YIELD
				if supply < target:
					problems.append("%s: las vetas ricas dan %d y se piden %d" % [id, supply, target])
			"interact", "explore", "relic":
				var groups: Array = spec.get("groups", [String(spec["group"])])
				for group: String in groups:
					var have := layout.interactables.filter(func(o: Dictionary) -> bool: return String(o["group"]) == group).size()
					var need := target if groups.size() == 1 else 1
					if have < need:
						problems.append("%s: hay %d objetos %s y pide %d" % [id, have, group, need])
			"survive":
				var beacons := layout.interactables.filter(func(o: Dictionary) -> bool: return String(o["kind"]) == "beacon").size()
				if beacons < 1:
					problems.append("%s: no hay baliza" % id)
		if (spec.get("on_complete", {}) as Dictionary).has("unshield"):
			var shielded := layout.enemies.filter(func(e: Dictionary) -> bool: return bool(e.get("invulnerable", false))).size()
			if shielded < 1:
				problems.append("%s: promete quitar un escudo que no existe" % id)
		if (spec.get("on_complete", {}) as Dictionary).has("spawn_deferred") and layout.deferred_enemies.is_empty():
			problems.append("%s: promete un enemigo diferido que no existe" % id)
	if mains < 1:
		problems.append("el piso no tiene ninguna mision principal")
	return problems
