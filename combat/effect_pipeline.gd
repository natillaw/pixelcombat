## EffectPipeline — Pipeline único para procesar todo efecto de combate (ISSUE P1.1).
class_name EffectPipeline
extends RefCounted

signal on_pre_effect(context)
signal on_effect(context)
signal on_post_effect(context)


func process_effect(effect: Resource, context: Object) -> void:
	emit_signal("on_pre_effect", context)
	if context.cancelled:
		return

	effect.apply(context)

	emit_signal("on_effect", context)
	emit_signal("on_post_effect", context)
