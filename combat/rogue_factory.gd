## RogueFactory — Fábrica de habilidades y recursos de la clase Rogue (Phase 2).
class_name RogueFactory
extends RefCounted

const SkillScript: GDScript = preload("res://combat/skill.gd")
const DamageEffectScript: GDScript = preload("res://combat/damage_effect.gd")
const RogueResourceScript: GDScript = preload("res://combat/rogue_resource.gd")

static func create_rogue_resource() -> RogueResourceScript:
	return RogueResourceScript.new()

static func create_skill(id: StringName, display_name: String, slot: SkillScript.Slot, cooldown: float, energy_cost: int, energy_gen: int, combo_gen: int, combo_cost: bool, damage: float, is_ex: bool = false, is_ultimate: bool = false) -> SkillScript:
	var skill = SkillScript.new()
	skill.id = id
	skill.display_name = display_name
	skill.slot = slot
	skill.cooldown = cooldown
	skill.resource_cost = energy_cost
	skill.resource_generation = energy_gen
	skill.is_ex = is_ex
	skill.is_ultimate = is_ultimate

	if damage > 0.0:
		var dmg_effect = DamageEffectScript.new()
		dmg_effect.base_damage = damage
		skill.effects.append(dmg_effect)

	return skill

static func get_rogue_skills() -> Dictionary:
	return {
		"M1": create_skill(&"rogue_m1", "Quick Strike", SkillScript.Slot.M1, 0.4, 0, 20, 1, false, 18.0),
		"M2": create_skill(&"rogue_m2", "Eviscerate", SkillScript.Slot.M2, 2.0, 30, 0, 0, true, 45.0, true),
		"SPACE": create_skill(&"rogue_space", "Shadowstep", SkillScript.Slot.SPACE, 6.0, 15, 0, 0, false, 0.0),
		"Q": create_skill(&"rogue_q", "Stealth", SkillScript.Slot.Q, 12.0, 0, 30, 0, false, 0.0),
		"E": create_skill(&"rogue_e", "Ambush", SkillScript.Slot.E, 5.0, 10, 0, 1, false, 30.0),
		"R": create_skill(&"rogue_r", "Blade Flurry", SkillScript.Slot.R, 10.0, 40, 0, 0, true, 55.0),
		"F": create_skill(&"rogue_f", "Assassination Ultimate", SkillScript.Slot.F, 60.0, 100, 0, 0, false, 150.0, false, true)
	}
