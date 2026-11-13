## LegacyKit — el kit completo anterior al rediseño (solo para tests de mecanicas): aprende todas las
## skills de mundo de la clase y deja el loadout de antes (S1-S3 de dano), para que las pruebas de
## formas, proyectiles y estados sigan ejercitando cada skill.
class_name LegacyKit
extends RefCounted

const KITS := {
	"warrior": {"M1": "warrior_m1", "M2": "warrior_m2", "S1": "cleaving_strike", "S2": "piercing_thrust", "SPECIAL": "iron_counter", "ULTIMATE": "war_gods_descent"},
	"rogue": {"M1": "twin_fang", "M2": "cross_cut", "S1": "ambush", "S2": "blade_flurry", "S3": "fan_of_knives", "SPECIAL": "perfect_evasion", "ULTIMATE": "death_sentence"},
	"mage": {"M1": "arcane_bolt", "M2": "charged_arcane_blast", "S1": "fireball", "S2": "arcane_explosion", "S3": "ice_lance", "SPECIAL": "arcane_overload", "ULTIMATE": "cataclysm"},
	"archer": {"M1": "quick_shot", "M2": "charged_shot", "S1": "multishot", "S2": "explosive_arrow", "S3": "piercing_arrow", "SPECIAL": "deadeye", "ULTIMATE": "rain_of_arrows"},
}


static func apply(player: PlayerSim) -> void:
	PlayerSim.allow_legacy_special = true
	for id: StringName in SkillCatalog.ids_for_class(player.class_id):
		if bool(SkillCatalog.skill(id).get("world", false)) and not player.learned_skills.has(String(id)):
			player.learned_skills.append(String(id))
	var kit: Dictionary = {}
	for slot: String in KITS[player.class_id]:
		kit[slot] = StringName(KITS[player.class_id][slot])
	# El resto de skills desbloqueadas ocupan los huecos S libres (como antes, por orden del catalogo).
	var used := {}
	for slot: String in kit:
		used[String(kit[slot])] = true
	var free_slots: Array = ["S1", "S2", "S3", "S4", "S5"].filter(func(slot: String) -> bool: return not kit.has(slot))
	for id: StringName in SkillCatalog.ids_for_class(player.class_id):
		var skill: Dictionary = SkillCatalog.skill(id)
		var allowed_extra := {"warrior": ["ground_stomp"], "rogue": ["blade_flurry", "poisoned_blades"]}
		if allowed_extra.has(player.class_id) and not bool(skill.get("retired", false)) and not (allowed_extra[player.class_id] as Array).has(String(id)):
			continue
		if used.has(String(id)) or String(skill.get("slot", "")) != "S" or int(skill["unlock_level"]) > player.level or not bool(skill.get("implemented", false)) or free_slots.is_empty():
			continue
		kit[free_slots.pop_front()] = id
	player.set_loadout(kit)
