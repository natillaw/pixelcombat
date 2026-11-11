## Crafting — fabrica un item gastando materiales y oro.
##
## Es una operacion de ciudad (no pasa en un tick): comprueba todo antes de gastar,
## es todo o nada, y la rareza del resultado sale del RNG de botin del mundo, asi que
## con la misma semilla y las mismas acciones el resultado es el mismo.
class_name Crafting
extends RefCounted


## Motivo por el que no se puede fabricar `recipe_id` en `tier` (o "" si se puede):
## unknown, busy (fuera de zona segura), tier (mayor que `max_tier`), materials,
## gold o full (mochila llena).
static func reason(player: PlayerSim, recipe_id: String, tier: int, max_tier: int) -> String:
	var recipe := RecipeCatalog.recipe(recipe_id)
	if recipe.is_empty():
		return "unknown"
	if not player.safe_zone:
		return "busy"
	if tier < 1 or tier > max_tier or tier > MaterialCatalog.tier_count():
		return "tier"
	if not player.has_materials(RecipeCatalog.cost_at(recipe, tier)):
		return "materials"
	if player.gold < RecipeCatalog.gold_at(recipe, tier):
		return "gold"
	if not player.bag_has_room():
		return "full"
	return ""


## Fabrica el item. Devuelve {"ok": true, "item": item} o {"ok": false, "reason": motivo}.
static func craft(player: PlayerSim, rng: RandomNumberGenerator, recipe_id: String, tier: int, max_tier: int) -> Dictionary:
	var why := reason(player, recipe_id, tier, max_tier)
	if why != "":
		return {"ok": false, "reason": why}
	var recipe := RecipeCatalog.recipe(recipe_id)
	player.spend_materials(RecipeCatalog.cost_at(recipe, tier))
	player.spend_gold(RecipeCatalog.gold_at(recipe, tier))
	var item := ItemGen.roll_item(rng, tier, "", "", "", String(recipe["item"]), float(recipe["quality_bonus"]))
	player.add_item(item)
	return {"ok": true, "item": item}
