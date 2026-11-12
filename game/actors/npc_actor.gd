## NpcActor — un personaje no jugador de la ciudad (los artesanos de los talleres).
##
## Se compone con las capas LPC del layout (\`FloorLayout.npcs\`): cuerpo, pelo, ropa y
## herramienta. Se queda quieto mirando al sur en su animacion de reposo y muestra su
## nombre encima. Hablar con el (E o clic cerca) es el portal que Layouts puso en su
## posicion. Es presentacion pura.
class_name NpcActor
extends Node2D

const FONT := preload("res://assets/fonts/m5x7.ttf")

var spec: Dictionary
var sprite: AnimatedSprite2D
var _time: float = 0.0


func setup(p_spec: Dictionary) -> void:
	spec = p_spec
	position = spec["position"]
	var equipment: Dictionary = {"_items": true}
	for slot: String in spec["equipment"]:
		equipment[slot] = spec["equipment"][slot]
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = LpcComposer.build_frames_for(spec["look"], "class.npc", equipment)
	sprite.centered = true
	sprite.position = LpcComposer.FEET_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var animation := "idle_down" if sprite.sprite_frames.has_animation("idle_down") else "walk_down"
	sprite.play(animation)
	_time = float(abs(hash(String(spec["id"]))) % 100) * 0.1


func _process(delta: float) -> void:
	_time += delta
	if spec.has("wander"):
		_wander()
	queue_redraw()


## Los paseantes van y vienen entre dos puntos (ping-pong determinista por tiempo).
func _wander() -> void:
	var wander: Dictionary = spec["wander"]
	var from: Vector2 = wander["from"]
	var to: Vector2 = wander["to"]
	var length := maxf(from.distance_to(to), 1.0)
	var cycle := 2.0 * length / float(wander["speed"])
	var phase := fposmod(_time, cycle) / cycle
	var t := phase * 2.0 if phase < 0.5 else 2.0 - phase * 2.0
	var heading := (to - from).normalized() * (1.0 if phase < 0.5 else -1.0)
	var pause := t <= 0.02 or t >= 0.98
	position = from.lerp(to, t)
	var direction := "down"
	if absf(heading.x) > absf(heading.y):
		direction = "right" if heading.x > 0.0 else "left"
	else:
		direction = "down" if heading.y > 0.0 else "up"
	var animation := ("idle_" if pause else "walk_") + direction
	if sprite.sprite_frames.has_animation(animation) and sprite.animation != animation:
		sprite.play(animation)


func _draw() -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 15.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var label := String(spec["name"])
	var size := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var at := Vector2(-size.x * 0.5, -58.0)
	draw_rect(Rect2(at + Vector2(-3, -9), Vector2(size.x + 6, 12)), Color(0.04, 0.05, 0.08, 0.7))
	draw_string(FONT, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.95, 0.88, 0.62))
