## SkillIcons — los iconos de las habilidades (assets/pixel/icons/skills/<id>.png, 64x64).
##
## Un icono por habilidad (el id de la skill es el nombre del archivo) mas `dodge`. Salen de
## los packs Swordsman / Paladin (CraftPix), Dark Fantasy Combat Skills (M-Xing Studio),
## Spell Icons Volume 1 y Aeromancer; ver assets/pixel/icons/skills/CREDITS.txt.
class_name SkillIcons
extends RefCounted

const DIR := "res://assets/pixel/icons/skills/"

static var _cache: Dictionary = {}

## Skills nuevas que aun no tienen icono propio reutilizan el de una parecida (placeholder, ver docs/PLACEHOLDERS_PENDIENTES.md).
const ALIASES := {
	"poison_arrow": "poisoned_blades", "snare_trap": "caltrops", "volley": "multishot", "marked_prey": "deadeye",
	"stunning_arrow": "piercing_arrow", "blazing_arrow": "explosive_arrow",
	"arcane_missiles": "arcane_bolt", "flame_wave": "fireball", "gravity_well": "arcane_orb",
}


## Icono de un consumible (assets/pixel/icons/consumables/<id>.png, 12x12; se dibuja a escala entera).
static func consumable(id: String) -> Texture2D:
	var key := "consumable/" + id
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/pixel/icons/consumables/%s.png" % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = tex
	return tex


static func texture(skill_id: String) -> Texture2D:
	if skill_id.is_empty():
		return null
	if _cache.has(skill_id):
		return _cache[skill_id]
	var path := DIR + skill_id + ".png"
	if not ResourceLoader.exists(path) and ALIASES.has(skill_id):
		path = DIR + String(ALIASES[skill_id]) + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[skill_id] = tex
	return tex
