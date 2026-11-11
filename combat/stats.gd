## Stats — Colección de stats de personaje con fórmulas derivadas (ISSUE P1.2).
class_name CharacterStats
extends RefCounted

const StatBlockScript = preload("res://combat/stat_block.gd")

var stats: Dictionary = {} ## StringName -> StatBlock


func set_base_stat(stat_name: StringName, value: float, min_val: float = -INF, max_val: float = INF) -> void:
	if not stats.has(stat_name):
		var sb = StatBlockScript.new()
		sb.base_value = value
		sb.min_value = min_val
		sb.max_value = max_val
		stats[stat_name] = sb
	else:
		stats[stat_name].base_value = value


func get_stat(stat_name: StringName) -> float:
	if stats.has(stat_name):
		return stats[stat_name].get_value()
	return 0.0


func add_modifier(stat_name: StringName, modifier: Object) -> void:
	if not stats.has(stat_name):
		set_base_stat(stat_name, 0.0)
	stats[stat_name].add_modifier(modifier)


## Fórmula WoW Classic adaptada: 1 Fuerza = 2 AP
func get_attack_power() -> float:
	var strength = get_stat(&"strength")
	var bonus_ap = get_stat(&"attack_power_bonus")
	return (strength * 2.0) + bonus_ap


## Daño medio del arma: (min + max) / 2 + AP / 14 * velocidad.
func get_weapon_damage() -> float:
	var min_damage := get_stat(&"weapon_min")
	var max_damage := get_stat(&"weapon_max")
	var speed := get_stat(&"weapon_speed")
	return (min_damage + max_damage) * 0.5 + get_attack_power() / 14.0 * speed


## Tirada determinista de daño del arma (el RNG lo aporta la simulación).
func roll_weapon_damage(rng: RandomNumberGenerator) -> float:
	var min_damage := get_stat(&"weapon_min")
	var max_damage := get_stat(&"weapon_max")
	var speed := get_stat(&"weapon_speed")
	var roll := rng.randf_range(min_damage, max_damage)
	return roll + get_attack_power() / 14.0 * speed


func get_crit_chance() -> float:
	return clampf(get_stat(&"crit_chance"), 0.0, 1.0)
