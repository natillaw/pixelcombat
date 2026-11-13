## SecretEvents — evaluador de eventos secretos (data/quests/secret_events.json). Se alimenta de cada evento del
## juego y decide si se cumple alguna condicion oculta: condiciones all (todas) / any (alguna) / sequence (eventos en
## orden), piso, banderas, items y "una vez por partida". Los disparadores viven aqui, separados de las misiones
## secretas que inician (eso es un efecto: start_quest, reward, flag o message).
class_name SecretEvents
extends RefCounted


## Evalua un evento y devuelve los efectos de los secretos que se activan:
## [{id, effect}]. `state` = {counters, done, progress, flags, floor, items} (lo mantiene QuestManager).
static func process(event: String, subject: String, state: Dictionary) -> Array:
	var fired: Array = []
	for secret: Dictionary in QuestLibrary.secrets():
		var id := String(secret["id"])
		if bool((state["done"] as Dictionary).get(id, false)) and bool(secret.get("once_per_run", false)):
			continue
		var floor_number := int(state.get("floor", 1))
		if floor_number < int(secret.get("floor_min", 1)) or floor_number > int(secret.get("floor_max", 100)):
			continue
		var conditions: Dictionary = secret["conditions"]
		var ok := true
		if conditions.has("sequence"):
			ok = ok and _sequence(id, conditions["sequence"], event, subject, state)
		if conditions.has("all"):
			for condition: Dictionary in conditions["all"]:
				ok = ok and _holds(condition, state)
		if conditions.has("any"):
			var any := false
			for condition: Dictionary in conditions["any"]:
				any = any or _holds(condition, state)
			ok = ok and any
		if ok:
			(state["done"] as Dictionary)[id] = true
			fired.append({"id": id, "effect": (secret.get("effect", {}) as Dictionary).duplicate(true)})
	return fired


## Eventos en orden: avanza un indice por secreto; un evento que no toca reinicia la secuencia.
static func _sequence(id: String, steps: Array, event: String, subject: String, state: Dictionary) -> bool:
	var progress: Dictionary = state["progress"]
	var index := int(progress.get(id, 0))
	var step: Dictionary = steps[index]
	if String(step["event"]) == event and (not step.has("subject") or String(step["subject"]) == subject):
		index += 1
	elif String((steps[0] as Dictionary)["event"]) == event and (not (steps[0] as Dictionary).has("subject") or String((steps[0] as Dictionary)["subject"]) == subject):
		index = 1
	if index >= steps.size():
		progress[id] = 0
		return true
	progress[id] = index
	return false


static func _holds(condition: Dictionary, state: Dictionary) -> bool:
	if condition.has("flag"):
		return bool((state["flags"] as Dictionary).get(String(condition["flag"]), false))
	if condition.has("event"):
		var key := "%s|%s" % [condition["event"], condition.get("subject", "")]
		return int((state["counters"] as Dictionary).get(key, 0)) >= int(condition.get("count", 1))
	if condition.has("item"):
		return (state.get("items", []) as Array).has(String(condition["item"]))
	if condition.has("floor_min") or condition.has("floor_max"):
		var floor_number := int(state.get("floor", 1))
		return floor_number >= int(condition.get("floor_min", 1)) and floor_number <= int(condition.get("floor_max", 100))
	return false
