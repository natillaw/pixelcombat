## SkillIcons — los iconos de las habilidades (assets/pixel/icons/skills/<id>.png, 64x64).
##
## Un icono por habilidad (el id de la skill es el nombre del archivo) mas `dodge`. Salen de
## los packs Swordsman / Paladin (CraftPix), Dark Fantasy Combat Skills (M-Xing Studio),
## Spell Icons Volume 1 y Aeromancer; ver assets/pixel/icons/skills/CREDITS.txt.
class_name SkillIcons
extends RefCounted

const DIR := "res://assets/pixel/icons/skills/"

static var _cache: Dictionary = {}


static func texture(skill_id: String) -> Texture2D:
	if skill_id.is_empty():
		return null
	if _cache.has(skill_id):
		return _cache[skill_id]
	var path := DIR + skill_id + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[skill_id] = tex
	return tex
