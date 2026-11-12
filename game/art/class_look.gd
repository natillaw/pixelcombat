## ClassLook — apariencia LPC de cada clase, leida de `data/classes/*.json`.
##
## Usa las hojas LPC importadas (assets/pixel/lpc, solo piezas con licencia de
## atribucion; ver docs/ASSET_REGISTRY.md) y las compone LpcComposer con el orden
## z de lpc_index.json.
class_name ClassLook
extends RefCounted


## Rasgos del personaje (cuerpo, piel, ojos, cabeza, pelo, barba).
static func look(class_id: String, appearance: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = ClassCatalog.class_def(class_id).get("look", {}).duplicate()
	for key: String in ["body", "skin", "eyes", "head", "hair", "hair_color", "beard"]:
		if appearance.has(key):
			spec[key] = appearance[key]
	return {
		"body": spec.get("body", "male"),
		"skin": spec.get("skin", "light"),
		"eyes": spec.get("eyes", "blue"),
		"head": spec.get("head", "head_human_male"),
		"hair": spec.get("hair", ""),
		"hair_color": spec.get("hair_color", "black"),
		"beard": spec.get("beard", ""),
	}


## Equipo visible: slot -> [pieza, variante]. Parte del atuendo de la clase y, por
## encima, las piezas de los items equipados (`worn`: ranura -> item) que tengan capa
## LPC; asi un item equipado sustituye a la pieza de la clase en su hueco.
static func equipment(class_id: String, worn: Dictionary = {}) -> Dictionary:
	var spec: Dictionary = ClassCatalog.class_def(class_id).get("look", {})
	var out: Dictionary = {"_items": true}
	var defaults: Dictionary = spec.get("equipment", {})
	for slot: String in defaults:
		out[slot] = defaults[slot]
	for item_slot: String in worn:
		var layer := ItemCatalog.look_layer(worn[item_slot])
		if not layer.is_empty():
			out[String(layer[0])] = layer[1]
	return out


static func frames(class_id: String, worn: Dictionary = {}, appearance: Dictionary = {}) -> SpriteFrames:
	return LpcComposer.build_frames_for(look(class_id, appearance), "class." + class_id, equipment(class_id, worn))


static func portrait(class_id: String, appearance: Dictionary = {}, worn: Dictionary = {}) -> Texture2D:
	return LpcComposer.pose_texture_for(look(class_id, appearance), "class." + class_id, "idle", equipment(class_id, worn))
