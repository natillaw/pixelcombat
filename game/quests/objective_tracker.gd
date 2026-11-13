## ObjectiveTracker — avanza los objetivos de una mision con los eventos del juego. Cada tipo de objetivo
## (kill, collect, interact, discover, reach, survive, protect, deliver, complete, condition) es un manejador
## reutilizable: no hay un script por mision. Un evento es {nombre, sujeto, cantidad}; nombres:
##   enemy_defeated (sujeto = id de enemigo), item_collected (id de material), object_interacted (tipo de objeto),
##   location_discovered (tipo de lugar), floor_entered / floor_completed (numero de piso), survival_completed
##   (baliza, cantidad = segundos), npc_rescued, item_delivered, condition_met (id de condicion).
class_name ObjectiveTracker
extends RefCounted

## Eventos a los que escucha cada tipo de objetivo.
const LISTENS := {
	"kill": ["enemy_defeated"], "collect": ["item_collected"], "interact": ["object_interacted"],
	"discover": ["location_discovered"], "reach": ["floor_entered", "floor_completed"], "survive": ["survival_completed"],
	"protect": ["npc_rescued"], "deliver": ["item_delivered"], "complete": ["floor_completed"], "condition": ["condition_met", "floor_completed"],
}


## Aplica el evento a un objetivo de instancia; true si cambio su progreso. `ctx`: {potion_used, damage_taken, floor}.
static func apply(objective: Dictionary, event: String, subject: String, amount: int, ctx: Dictionary) -> bool:
	if int(objective["progress"]) >= int(objective["required"]):
		return false
	if not (LISTENS[String(objective["kind"])] as Array).has(event):
		return false
	var target := String(objective["target"])
	var before := int(objective["progress"])
	match String(objective["kind"]):
		"kill":
			if QuestLibrary.target_matches_enemy(target, subject):
				objective["progress"] = before + amount
		"collect":
			var parsed := MaterialCatalog.parse(subject)
			if not parsed.is_empty() and (target == subject or target == String(parsed["kind"]) or (target == "gatherable" and MaterialCatalog.gatherable_kinds().has(String(parsed["kind"])))):
				objective["progress"] = before + amount
		"interact", "discover", "protect", "deliver":
			if target == subject:
				objective["progress"] = before + amount
		"reach":
			objective["progress"] = maxi(before, int(subject))
		"survive":
			if target == subject:
				objective["progress"] = before + amount
		"complete":
			objective["progress"] = before + 1
		"condition":
			if event == "condition_met" and target == subject:
				objective["progress"] = int(objective["required"])
			elif event == "floor_completed" and target == "no_potions_floor" and not bool(ctx.get("potion_used", false)):
				objective["progress"] = int(objective["required"])
			elif event == "floor_completed" and target == "no_damage_floor" and not bool(ctx.get("damage_taken", false)):
				objective["progress"] = int(objective["required"])
	objective["progress"] = mini(int(objective["progress"]), int(objective["required"]))
	return int(objective["progress"]) != before
