## StatusSet — estados alterados activos sobre una unidad (jugador o enemigo).
##
## Se aplica con apply(): refresca la duracion (no se acumula), respeta los topes
## del catalogo, la resistencia de la unidad y la inmunidad posterior de los
## controles (un stun no se puede encadenar con otro). step() avanza el tiempo y
## devuelve el dano continuo (veneno) que toca aplicar en ese tick.
class_name StatusSet
extends RefCounted

signal applied(id: String)
signal expired(id: String)

## id -> {remaining, strength, tick_left}
var _active: Dictionary = {}
## id -> segundos de inmunidad que quedan
var _immune: Dictionary = {}
## id -> resistencia 0..1 (1 = inmune); la fija la unidad (jefes)
var resist: Dictionary = {}


## Aplica `id` durante `duration` segundos con `strength`. Devuelve false si la
## unidad es inmune (resistencia total o inmunidad tras un control previo).
func apply(id: String, duration: float, strength: float = 0.0) -> bool:
	var definition := StatusCatalog.status(id)
	if definition.is_empty() or duration <= 0.0:
		return false
	if String(definition["kind"]) == "push":
		# Empuje: es instantaneo, lo resuelve la unidad (push_from); aqui solo se comprueba la resistencia.
		return float(resist.get(id, 0.0)) < 1.0
	var resistance := clampf(float(resist.get(id, 0.0)), 0.0, 1.0)
	if resistance >= 1.0 or float(_immune.get(id, 0.0)) > 0.0:
		return false
	var final_duration := minf(duration * (1.0 - resistance), float(definition["max_duration"]))
	var final_strength := strength
	if definition.has("max_strength"):
		final_strength = minf(strength, float(definition["max_strength"]))
	if _active.has(id):
		var current: Dictionary = _active[id]
		current["remaining"] = maxf(float(current["remaining"]), final_duration)
		current["strength"] = maxf(float(current["strength"]), final_strength)
	else:
		_active[id] = {"remaining": final_duration, "strength": final_strength, "tick_left": float(definition.get("tick", 0.0))}
	applied.emit(id)
	return true


## Avanza `delta` segundos. Devuelve el dano continuo acumulado en este tick.
func step(delta: float) -> float:
	var damage := 0.0
	for id: String in _immune.keys():
		var left := float(_immune[id]) - delta
		if left <= 0.0:
			_immune.erase(id)
		else:
			_immune[id] = left
	for id: String in _active.keys():
		var entry: Dictionary = _active[id]
		var definition := StatusCatalog.status(id)
		if String(definition["kind"]) == "damage":
			entry["tick_left"] = float(entry["tick_left"]) - delta
			if float(entry["tick_left"]) <= 0.0:
				damage += float(entry["strength"]) * float(definition["tick"])
				entry["tick_left"] = float(entry["tick_left"]) + float(definition["tick"])
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			_active.erase(id)
			var immune_after := float(definition["immune_after"])
			if immune_after > 0.0:
				_immune[id] = immune_after
			expired.emit(id)
	return damage


## El escudo absorbe `amount` antes que la vida; devuelve lo que sobra (0 si lo absorbe todo).
func absorb(amount: float) -> float:
	if not _active.has("shield"):
		return amount
	var entry: Dictionary = _active["shield"]
	var soaked := minf(amount, float(entry["strength"]))
	entry["strength"] = float(entry["strength"]) - soaked
	if float(entry["strength"]) <= 0.01:
		_active.erase("shield")
		expired.emit("shield")
	return amount - soaked


func has(id: String) -> bool:
	return _active.has(id)


func remaining(id: String) -> float:
	return float((_active.get(id, {}) as Dictionary).get("remaining", 0.0))


func strength(id: String) -> float:
	return float((_active.get(id, {}) as Dictionary).get("strength", 0.0))


func is_immune(id: String) -> bool:
	return float(_immune.get(id, 0.0)) > 0.0 or float(resist.get(id, 0.0)) >= 1.0


func is_stunned() -> bool:
	return _active.has("stun")


## Multiplicador de velocidad de movimiento: 0 aturdido; 1 - strength con slow.
func speed_mult() -> float:
	if is_stunned():
		return 0.0
	var mult := 1.0 + strength("haste")
	if _active.has("slow"):
		mult *= 1.0 - strength("slow")
	return mult


## Ids activos (para dibujar los iconos).
func active_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _active:
		ids.append(id)
	return ids


const FOOD_IDS := ["fed", "might", "haste"]


## Quita todos los estados; con `keep_food` conserva la comida (fed, might, haste), que dura
## aunque se cambie de piso o se muera.
func clear(keep_food: bool = false) -> void:
	for id: String in _active.keys():
		if keep_food and FOOD_IDS.has(id):
			continue
		_active.erase(id)
		expired.emit(id)
	if not keep_food:
		_immune = {}


func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for id: String in _active:
		out[id] = {"remaining": remaining(id), "strength": strength(id)}
	return out
