## FxSprite — un efecto visual animado que se reproduce y se libera solo. Los efectos de luz
## se mezclan en aditivo; los bucles duran `seconds` (o para siempre si es 0).
class_name FxSprite
extends AnimatedSprite2D

static var _additive: CanvasItemMaterial


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


func setup(id: String, p_scale: float = 1.0, p_rotation: float = 0.0, tint: Color = Color.WHITE, seconds: float = 0.0) -> void:
	var spec := FxLibrary.effect(id)
	sprite_frames = FxLibrary.frames(id)
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pivot: Array = spec["pivot"]
	offset = Vector2(float(spec["w"]) * 0.5 - float(pivot[0]), float(spec["h"]) * 0.5 - float(pivot[1]))
	scale = Vector2.ONE * p_scale
	rotation = p_rotation
	modulate = tint
	if String(spec.get("blend", "mix")) == "add":
		material = additive()
	z_index = 4
	play(&"play")
	if bool(spec["loop"]):
		if seconds > 0.0:
			get_tree().create_timer(seconds).timeout.connect(queue_free)
	else:
		animation_finished.connect(queue_free)
