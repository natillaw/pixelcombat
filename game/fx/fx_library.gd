## FxLibrary — los efectos visuales (sprites animados) desde `data/fx.json`.
##
## Esquema:
##   effects: {id: {file, w, h, cols, count, ms, pivot, loop, blend}}: hoja en rejilla (cols
##            fotogramas por fila, w x h cada uno), `ms` por fotograma, `pivot` el punto que
##            se coloca sobre la posicion del efecto, `blend` "add" (luz aditiva) o "mix"
##   skills: {skill_id: {cast: [{id, scale, ahead|at, up}], hit: id, crit: id}}: que efecto
##           acompana a cada habilidad al lanzarla y al acertar
##   events: {nombre: [{id, scale, up}]}: efectos de sucesos (subir de nivel, esquiva, estados...)
## Efectos: PVFX Foundry (CC0) y Pixel Spell & Combat FX; ver assets/pixel/fx/vfx/CREDITS.txt.
class_name FxLibrary
extends RefCounted

const PATH := "res://data/fx.json"

static var _data: Dictionary = {}
static var _frames: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed


static func has_effect(id: String) -> bool:
	_ensure()
	return (_data.get("effects", {}) as Dictionary).has(id)


static func effect(id: String) -> Dictionary:
	_ensure()
	return ((_data.get("effects", {}) as Dictionary).get(id, {}) as Dictionary).duplicate()


static func effect_ids() -> Array:
	_ensure()
	return (_data.get("effects", {}) as Dictionary).keys()


static func skill_fx(skill_id: String) -> Dictionary:
	_ensure()
	return ((_data.get("skills", {}) as Dictionary).get(skill_id, {}) as Dictionary).duplicate(true)


static func event_fx(name: String) -> Array:
	_ensure()
	return ((_data.get("events", {}) as Dictionary).get(name, []) as Array).duplicate(true)


## SpriteFrames de un efecto (cacheado): una animacion "play" con sus fotogramas.
static func frames(id: String) -> SpriteFrames:
	if _frames.has(id):
		return _frames[id]
	var spec := effect(id)
	var texture: Texture2D = load(String(spec["file"]))
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(&"play")
	sprite_frames.set_animation_speed(&"play", 1000.0 / maxf(float(spec["ms"]), 1.0))
	sprite_frames.set_animation_loop(&"play", bool(spec["loop"]))
	if sprite_frames.has_animation(&"default"):
		sprite_frames.remove_animation(&"default")
	var cols := int(spec["cols"])
	for i: int in range(int(spec["count"])):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(i % cols) * float(spec["w"]), float(i / cols) * float(spec["h"]), float(spec["w"]), float(spec["h"]))
		sprite_frames.add_frame(&"play", atlas)
	_frames[id] = sprite_frames
	return sprite_frames


## Problemas del archivo: efectos con hoja que existe y que cada referencia apunte a un efecto.
static func errors() -> Array[String]:
	_ensure()
	var problems: Array[String] = []
	for id: String in effect_ids():
		var spec := effect(id)
		if not ResourceLoader.exists(String(spec.get("file", ""))):
			problems.append("%s: falta la hoja %s" % [id, spec.get("file", "")])
		if int(spec.get("count", 0)) < 1 or int(spec.get("cols", 0)) < 1 or float(spec.get("ms", 0)) <= 0.0:
			problems.append("%s: count, cols y ms deben ser > 0" % id)
	for skill_id: String in (_data.get("skills", {}) as Dictionary):
		var entry: Dictionary = _data["skills"][skill_id]
		var refs: Array = []
		for cast: Variant in entry.get("cast", []):
			refs.append(String((cast as Dictionary)["id"]))
		for key: String in ["hit", "crit"]:
			if entry.has(key):
				refs.append(String(entry[key]))
		for ref: String in refs:
			if not has_effect(ref):
				problems.append("skill %s: efecto desconocido %s" % [skill_id, ref])
	for name: String in (_data.get("events", {}) as Dictionary):
		for entry: Variant in _data["events"][name]:
			if not has_effect(String((entry as Dictionary)["id"])):
				problems.append("evento %s: efecto desconocido %s" % [name, (entry as Dictionary)["id"]])
	return problems
