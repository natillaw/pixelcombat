## SkillRunner — Ejecutor de habilidades data-driven (ISSUE P1.3).
class_name SkillRunner
extends RefCounted

const EffectPipelineScript = preload("res://combat/effect_pipeline.gd")
const EffectContextScript = preload("res://combat/effect_context.gd")

var pipeline = EffectPipelineScript.new()


func can_execute(skill: Object, class_resource: Object) -> bool:
	if skill.resource_cost > 0 and class_resource:
		if class_resource.get_current() < skill.resource_cost:
			return false
	return true


func execute(skill: Object, caster: Object, target: Object, class_resource: Object) -> bool:
	if not can_execute(skill, class_resource):
		return false

	# Consumir recurso si aplica
	if skill.resource_cost > 0 and class_resource:
		class_resource.consume(skill.resource_cost)

	# Generar recurso si aplica
	if skill.resource_generation > 0 and class_resource:
		class_resource.generate(skill.resource_generation)

	# Aplicar efectos de la skill
	for effect in skill.effects:
		if effect and effect.has_method("apply"):
			var ctx = EffectContextScript.new()
			ctx.source = caster
			ctx.target = target
			pipeline.process_effect(effect, ctx)

	return true
