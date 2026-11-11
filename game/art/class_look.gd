## ClassLook — apariencia LPC de cada clase, leida de `data/classes/*.json`.
##
## Usa las hojas LPC importadas (assets/pixel/lpc, solo piezas con licencia de
## atribucion; ver docs/ASSET_REGISTRY.md) y las compone LpcComposer con el orden
## z de lpc_index.json.
class_name ClassLook
extends RefCounted


## Rasgos del personaje (cuerpo, piel, ojos, cabeza, pelo, barba).
static func look(class_id: String) -> Dictionary:
	var spec: Dictionary = ClassCatalog.class_def(class_id).get("look", {})
	return {
		"body": spec.get("body", "male"),
		"skin": spec.get("skin", "light"),
		"eyes": spec.get("eyes", "blue"),
		"head": spec.get("head", "head_human_male"),
		"hair": spec.get("hair", ""),
		"hair_color": spec.get("hair_color", "black"),
		"beard": spec.get("beard", ""),
	}


## Equipo visible: slot -> [pieza, variante].
static func equipment(class_id) -> Dictionary:
	var spec: Dictionary = ClassCatalog.class_def(class_id).get("look", {})
	var out: Dictionary = {"_items": true}
	var worn: Dictionary = spec.get("equipment", {})
	for slot: String in worn:
		out[slot] = worn[slot]
	return out


static func frames(class_id: String) -> SpriteFrames:
	return LpcComposer.build_frames_for(look(class_id), "class." + class_id, equipment(class_id))


static func portrait(class_id: String) -> Texture2D:
	return LpcComposer.pose_texture_for(look(class_id), "class." + class_id, "idle", equipment(class_id))
