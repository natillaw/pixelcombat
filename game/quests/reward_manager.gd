## RewardManager — entrega al jugador el paquete de recompensa de una mision (oro, XP, items, consumibles,
## materiales, tomos de habilidad, banderas). Es el UNICO punto que modifica el inventario; RewardGenerator solo genera.
## La entrega es todo o nada (si la mochila no tiene sitio para los items no se entrega nada) y la reclamacion
## segura contra duplicados la garantiza QuestManager (una instancia solo se reclama una vez).
class_name RewardManager
extends RefCounted


## Devuelve {ok, reason}. `flags` es el diccionario de banderas del mundo (se anaden las del paquete).
static func deliver(player: PlayerSim, package: Dictionary, flags: Dictionary) -> Dictionary:
	var items: Array = package.get("items", [])
	if player.bag.size() + items.size() > ItemCatalog.bag_size():
		return {"ok": false, "reason": "bag"}
	player.add_gold(int(package.get("gold", 0)))
	if int(package.get("xp", 0)) > 0:
		player.grant_xp(int(package["xp"]), player.position)
	for item: Variant in items:
		player.add_item((item as Dictionary).duplicate(true))
	for id: Variant in package.get("consumables", {}):
		player.add_consumable(String(id), int(package["consumables"][id]))
	for id: Variant in package.get("materials", {}):
		player.add_material(String(id), int(package["materials"][id]))
	if int(package.get("tomes", 0)) > 0:
		player.add_consumable("skill_tome", int(package["tomes"]))
	for flag: Variant in package.get("flags", []):
		flags[String(flag)] = true
	return {"ok": true, "reason": ""}
