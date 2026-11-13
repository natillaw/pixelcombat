## TowerGenerator — genera de forma determinista los pisos de la torre.
##
## `generate(piso, semilla_del_mundo, visita)`:
##  - El **terreno** (estilo, tamano, mapa, entrada y salida) sale solo de la semilla del
##    mundo y el numero de piso: es siempre el mismo, asi un piso "se guarda" con solo
##    recordar su numero.
##  - El **contenido** (misiones, enemigos, objetos, nodos) sale ademas del numero de
##    visita: cada vez que se entra a un piso se sortean misiones nuevas, pero siempre
##    cumplibles en ese terreno (ver MissionGen).
## El tier fija el bioma, los estilos de mapa, los enemigos y los jefes (data/tower.json);
## los pisos 5 y 10 de cada tier son de pico (mini-jefes y jefe).
class_name TowerGenerator
extends RefCounted


## `forced` (solo pruebas): ids de mision que sustituyen al sorteo (principal, opcional)
## o, en un piso x10, la variante de la prueba (seals, gauntlet, elites).
static func generate(floor_number: int, world_seed: int, visit: int = 1, forced: Array = [], with_elite: bool = false) -> FloorLayout:
	var tier_number := TowerCatalog.tier_of_floor(floor_number)
	var tier_data := TowerCatalog.tier(tier_number)
	var spike := TowerCatalog.spike_kind(floor_number)
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = world_seed * 1000003 + floor_number * 7919

	var layout := FloorLayout.new()
	layout.id = "tower_%d" % floor_number
	layout.kind = FloorLayout.KIND_FLOOR
	layout.floor_number = floor_number
	layout.tier = tier_number
	layout.seed_value = int(terrain_rng.seed)
	layout.title = Lore.floor_title(floor_number)
	layout.theme = FloorLayout.make_theme(tier_data["theme"])
	layout.theme["name"] = String(tier_data["name"])
	layout.biome = TowerCatalog.biome(tier_number)
	layout.enemy_scale = TowerCatalog.enemy_scale(floor_number)

	layout.style = _pick_style(terrain_rng, TowerCatalog.styles(tier_number))
	var size := MapGen.map_size(floor_number, terrain_rng)
	var analysis := MapGen.build(layout.style, size.x, size.y, terrain_rng)
	layout.grid = analysis.grid
	layout.wall_margin = TowerCatalog.biome_wall_margin(layout.biome)
	layout.size = analysis.grid.pixel_size()
	layout.wall = 0.0
	layout.play_area = Rect2(Vector2.ZERO, layout.size)
	layout.player_spawn = analysis.spawn_position()
	var exit_position := analysis.exit_position()
	# La entrada va dentro de la sala segura, algo apartada de donde aparece el jugador.
	var entrance_position := layout.player_spawn + Vector2(-72.0, 0.0)
	if not analysis.grid.is_walkable_point(entrance_position):
		entrance_position = layout.player_spawn + Vector2(72.0, 0.0)
	layout.portals = [
		{"id": "exit", "position": exit_position, "radius": 54.0,
			"label": "Subir al piso %d" % (floor_number + 1) if floor_number < TowerCatalog.floors() else "Cima de la torre",
			"action": "next_floor" if floor_number < TowerCatalog.floors() else "to_city", "requires_complete": true},
		{"id": "entrance", "position": entrance_position, "radius": 36.0, "label": "Volver a la ciudad", "action": "to_city", "requires_complete": false},
	]

	var content_rng := RandomNumberGenerator.new()
	content_rng.seed = int(terrain_rng.seed) * 31 + visit * 104729
	MissionGen.populate(layout, analysis, content_rng, floor_number, tier_data, spike, forced)
	if with_elite:
		MissionGen.add_wandering_elite(layout, analysis, content_rng)
	return layout


static func _pick_style(rng: RandomNumberGenerator, styles: Array) -> String:
	var total := 0.0
	for entry: Dictionary in styles:
		total += float(entry["weight"])
	var roll := rng.randf() * total
	for entry: Dictionary in styles:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return String(entry["style"])
	return String((styles[styles.size() - 1] as Dictionary)["style"])
