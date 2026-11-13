## Services — lo que ofrecen los edificios de servicio de Albor (a diferencia de los talleres, que fabrican):
##
##   Taberna  — cocina (materiales -> comida y pociones), compra de comida/pociones y descanso
##              (cura todo y da la comida "bien alimentado" unos minutos) con rumores.
##   Mercader — compra de equipo (existencias fijas por piso completado) y de consumibles.
##   Banco    — alijo de 30 items fuera de la mochila.
##   Gremio   — tablon de encargos (ver Bounties) e instructor que ensena skills de mundo por oro.
##
## Todas las funciones son puras sobre PlayerSim y devuelven {ok, reason}; la interfaz solo las llama.
class_name Services
extends RefCounted

const REST_COST := 30
const MERCHANT_STOCK := 6
## Un item de la tienda cuesta tantas veces su valor de venta.
const MERCHANT_MARKUP := 3.0


static func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason}


# --- Taberna ---------------------------------------------------------------------------


## Compra una pocion o comida de la taberna por su precio.
static func buy_consumable(player: PlayerSim, id: String) -> Dictionary:
	var spec := ConsumableCatalog.item(id)
	if spec.is_empty() or int(spec["price"]) <= 0:
		return _result(false, "unknown")
	if player.gold < int(spec["price"]):
		return _result(false, "gold")
	if player.consumable_count(id) >= ConsumableCatalog.max_stack():
		return _result(false, "full")
	player.spend_gold(int(spec["price"]))
	player.add_consumable(id, 1)
	return _result(true)


## Cocina `id` con materiales del `tier` elegido (como el crafting: puedes usar los de cualquier tier abierto).
static func cook(player: PlayerSim, id: String, tier: int) -> Dictionary:
	var spec := ConsumableCatalog.item(id)
	if spec.is_empty() or not spec.has("cook"):
		return _result(false, "unknown")
	var cost := ConsumableCatalog.cook_cost(id, tier)
	var gold := int(spec["cook"]["gold"])
	if not player.has_materials(cost):
		return _result(false, "materials")
	if player.gold < gold:
		return _result(false, "gold")
	if player.consumable_count(id) >= ConsumableCatalog.max_stack():
		return _result(false, "full")
	player.spend_materials(cost)
	player.spend_gold(gold)
	player.add_consumable(id, 1)
	return _result(true)


## Descansar en la taberna: cura vida y recurso y da "bien alimentado" 10 minutos. Devuelve tambien un rumor.
static func rest(player: PlayerSim, rumor_index: int = 0, flags: Array = []) -> Dictionary:
	if player.gold < REST_COST:
		return _result(false, "gold")
	player.spend_gold(REST_COST)
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.resource.current_amount = player.resource.max_amount
	player.resource_changed.emit(player.resource.get_current(), player.resource.max_amount)
	player.statuses.apply("fed", 600.0, 0.012)
	var out := _result(true)
	out["rumor"] = Lore.rumor(rumor_index, flags)
	return out


# --- Mercader --------------------------------------------------------------------------


## Existencias del mercader: items del tier mas alto abierto, rareza comun o poco comun; cambian con
## cada piso completado y son iguales para todos los que miren con la misma partida.
static func merchant_stock(world_seed: int, completed_floors: int, highest_tier: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 53 + completed_floors * 1013 + 5
	var stock: Array = []
	for i: int in range(MERCHANT_STOCK):
		var rarity := "uncommon" if rng.randf() < 0.25 else "common"
		var piece := ItemGen.roll_item(rng, highest_tier, rarity)
		stock.append({"item": piece, "price": merchant_price(piece), "sold": false})
	return stock


static func merchant_price(piece: Dictionary) -> int:
	return maxi(1, int(round(float(ItemCatalog.sell_value(piece)) * MERCHANT_MARKUP)))


static func buy_stock(player: PlayerSim, stock: Array, index: int) -> Dictionary:
	if index < 0 or index >= stock.size() or bool((stock[index] as Dictionary)["sold"]):
		return _result(false, "unknown")
	var entry: Dictionary = stock[index]
	if player.gold < int(entry["price"]):
		return _result(false, "gold")
	if not player.bag_has_room():
		return _result(false, "bag")
	player.spend_gold(int(entry["price"]))
	player.add_item((entry["item"] as Dictionary).duplicate(true))
	entry["sold"] = true
	return _result(true)


# --- Banco -----------------------------------------------------------------------------


static func bank_deposit(player: PlayerSim, bag_index: int) -> Dictionary:
	if bag_index < 0 or bag_index >= player.bag.size():
		return _result(false, "unknown")
	if player.bank.size() >= PlayerSim.BANK_SIZE:
		return _result(false, "full")
	player.bank.append(player.bag[bag_index])
	player.bag.remove_at(bag_index)
	player.inventory_changed.emit()
	return _result(true)


static func bank_withdraw(player: PlayerSim, bank_index: int) -> Dictionary:
	if bank_index < 0 or bank_index >= player.bank.size():
		return _result(false, "unknown")
	if not player.bag_has_room():
		return _result(false, "bag")
	player.add_item(player.bank[bank_index])
	player.bank.remove_at(bank_index)
	return _result(true)


# --- Gremio: instructor ---------------------------------------------------------------


## Skills de mundo de la clase que aun no ha aprendido: [{id, name, price, level}].
static func trainer_offers(player: PlayerSim) -> Array:
	var out: Array = []
	for id: StringName in SkillCatalog.ids_for_class(player.class_id):
		var skill := SkillCatalog.skill(id)
		if bool(skill.get("world", false)) and bool(skill.get("implemented", false)) and not bool(skill.get("retired", false)) and String(skill.get("source", "trainer")) != "book" and not player.learned_skills.has(String(id)):
			out.append({"id": String(id), "name": String(skill["name"]), "price": trainer_price(skill), "level": int(skill["unlock_level"])})
	return out


static func trainer_price(skill: Dictionary) -> int:
	return 120 + 40 * int(skill["unlock_level"])


static func learn_skill(player: PlayerSim, id: String) -> Dictionary:
	var skill := SkillCatalog.skill(StringName(id))
	if skill.is_empty() or not bool(skill.get("world", false)):
		return _result(false, "unknown")
	if player.learned_skills.has(id):
		return _result(false, "known")
	if player.gold < trainer_price(skill):
		return _result(false, "gold")
	if not player.learn_skill(StringName(id)):
		return _result(false, "unknown")
	player.spend_gold(trainer_price(skill))
	return _result(true)
