## GameHud — HUD de combate del primer corte.
##
## Lee [CombatWorld] en _process y se dibuja por código. Es presentación pura:
## no escribe estado de simulación. Muestra vida, Rage, cooldowns de M1/M2,
## estado de la pasiva Vengeful Fury, controles y la pantalla de muerte.
class_name GameHud
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")

const PANEL := Color(0.055, 0.065, 0.095, 0.86)
const PANEL_EDGE := Color(0.33, 0.37, 0.47, 0.95)
const PANEL_EDGE_SOFT := Color(0.20, 0.23, 0.30, 0.9)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.56, 0.60, 0.70, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const ORANGE := Color(1.0, 0.53, 0.18, 1.0)
const RED := Color(0.88, 0.28, 0.24, 1.0)
const HEALTH := Color(0.42, 0.78, 0.42, 1.0)
const HEALTH_LOW := Color(0.86, 0.38, 0.24, 1.0)
const RAGE := Color(0.93, 0.35, 0.20, 1.0)

var world: CombatWorld
var _damage_flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func bind(p_world: CombatWorld) -> void:
	if world == p_world:
		return
	world = p_world
	if world != null and world.warrior != null:
		world.warrior.damage_taken.connect(_on_damage_taken)


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	queue_redraw()


func _on_damage_taken(_amount: float, _source_position: Vector2, is_dot: bool) -> void:
	if not is_dot:
		_damage_flash = 1.0


func _draw() -> void:
	if world == null or world.warrior == null:
		return
	var warrior := world.warrior

	_draw_status(warrior)
	_draw_abilities(warrior)
	_draw_controls()

	if warrior.vengeful_active and warrior.alive:
		_draw_text("M2 EMPOWERED  +30%", Vector2(220, 305), 7, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 200)

	_draw_damage_flash()
	if not warrior.alive:
		_draw_death()


# --- Paneles ----------------------------------------------------------------


func _draw_status(warrior: WarriorSim) -> void:
	_panel(Rect2(10, 6, 246, 68))
	_draw_text("WARRIOR", Vector2(16, 24), 14, GOLD)
	_draw_text("TRAINING GROUNDS", Vector2(112, 23), 7, MUTED)

	var health_ratio: float = warrior.health / maxf(warrior.max_health, 1.0)
	var health_color := HEALTH if health_ratio > 0.30 else HEALTH_LOW
	_bar(Rect2(16, 30, 234, 11), health_ratio, health_color)
	_draw_text(
		"HP  %d / %d" % [ceili(warrior.health), ceili(warrior.max_health)],
		Vector2(16, 39), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 234
	)

	var rage_ratio: float = warrior.resource.get_current() / maxf(warrior.resource.max_amount, 1.0)
	_bar(Rect2(16, 45, 234, 8), rage_ratio, RAGE)
	if warrior.resource.is_full():
		draw_rect(Rect2(16, 45, 234, 8), GOLD, false, 1.0)
	_draw_text(
		"RAGE  %d / %d" % [floori(warrior.resource.get_current()), floori(warrior.resource.max_amount)],
		Vector2(16, 52), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 234
	)

	# Marca del coste del Special (30 Rage) para que la barra ya se lea.
	var special_mark := 16.0 + 234.0 * (WarriorKit.SPECIAL_COST / WarriorKit.MAX_RAGE)
	draw_line(Vector2(special_mark, 45), Vector2(special_mark, 52), Color(1, 1, 1, 0.35), 1.0)

	var passive := "PASSIVE  VENGEFUL FURY"
	var passive_color := GOLD
	if warrior.vengeful_active:
		passive += "  ACTIVE %.1fs" % warrior.vengeful_seconds_left()
		passive_color = ORANGE
	_draw_text(passive, Vector2(16, 66), 7, passive_color)


func _draw_abilities(warrior: WarriorSim) -> void:
	_draw_ability(
		Rect2(256, 310, 64, 38),
		"LMB", "SLASH", "M1",
		warrior.attack_cooldown_left("M1"), warrior.attack_cooldown_total("M1"),
		false, warrior.state == WarriorSim.AttackState.IDLE
	)
	_draw_ability(
		Rect2(326, 310, 64, 38),
		"RMB", "HEAVY", "M2",
		warrior.attack_cooldown_left("M2"), warrior.attack_cooldown_total("M2"),
		warrior.vengeful_active, warrior.state == WarriorSim.AttackState.IDLE
	)
	_draw_dodge_slot(Rect2(396, 310, 64, 38), warrior)
	_draw_ultimate_slot(Rect2(46, 310, 64, 38), warrior)
	_draw_skill_slot(Rect2(116, 310, 64, 38), "1", "S1", warrior)
	_draw_skill_slot(Rect2(186, 310, 64, 38), "2", "S2", warrior)


func _draw_ability(rect: Rect2, key: String, label: String, slot: String, left: float, total: float, empowered: bool, idle: bool) -> void:
	var edge := ORANGE if empowered else PANEL_EDGE
	draw_rect(rect, PANEL)
	draw_rect(rect, edge, false, 1.0)

	_draw_text(key, rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text(slot, Vector2(rect.position.x, rect.position.y + 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)

	var icon_color := ORANGE if empowered else (GOLD if left <= 0.0 else Color(0.62, 0.64, 0.72, 1.0))
	var icon_center := rect.position + Vector2(rect.size.x * 0.5, 17)
	if slot == "M1":
		_draw_sword_icon(icon_center, -0.65, icon_color, false)
	else:
		_draw_sword_icon(icon_center, -1.5708, icon_color, true)

	_draw_text(label, Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)

	if left > 0.05:
		var ratio := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), Color(0.02, 0.02, 0.04, 0.62))
		_draw_text("%.1f" % left, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.78), 7, Color(0.95, 0.92, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	elif idle:
		draw_rect(rect.grow(-2.0), Color(edge.r, edge.g, edge.b, 0.22), false, 1.0)

	if empowered:
		_draw_text("!", rect.position + Vector2(rect.size.x - 12, 9), 7, ORANGE)


## Hueco de la ultimate: se llena con la Ultimate Charge y brilla cuando esta lista.
func _draw_ultimate_slot(rect: Rect2, warrior: WarriorSim) -> void:
	var maximum := WarriorKit.ULTIMATE_CHARGE_MAX
	var ratio := clampf(warrior.ultimate_charge / maximum, 0.0, 1.0)
	var ready := warrior.ultimate_ready_now()
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
	var edge := Color(GOLD.r, GOLD.g, GOLD.b, 0.65 + 0.35 * pulse) if ready else PANEL_EDGE
	draw_rect(rect, PANEL)
	var fill := Color(GOLD.r, GOLD.g, GOLD.b, 0.55 if ready else 0.35)
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * (1.0 - ratio), rect.size.x, rect.size.y * ratio), fill)
	draw_rect(rect, edge, false, 1.0)
	_draw_text("F", rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text("ULT", Vector2(rect.position.x, rect.position.y + 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)
	_draw_text("READY" if ready else "%d%%" % int(ratio * 100.0), Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62), 7, GOLD if ready else TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	_draw_text("DESCENT", Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## Hueco de una skill equipada (S1-S5): etiqueta, coste y cooldown. Se vuelve
## rojo si no hay Rage suficiente.
func _draw_skill_slot(rect: Rect2, key: String, slot: String, warrior: WarriorSim) -> void:
	draw_rect(rect, PANEL)
	if not warrior.loadout.has(slot):
		draw_rect(rect, PANEL_EDGE_SOFT, false, 1.0)
		_draw_text(key, rect.position + Vector2(4, 9), 7, MUTED)
		_draw_text("EMPTY", Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		return
	var skill: Dictionary = warrior.loadout[slot]
	var cost := float(skill.get("cost", 0.0))
	var left := warrior.attack_cooldown_left(slot)
	var total := warrior.attack_cooldown_total(slot)
	var affordable := warrior.rage() >= cost
	var edge := PANEL_EDGE if affordable else RED
	draw_rect(rect, edge, false, 1.0)
	_draw_text(key, rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text("%d" % int(cost), Vector2(rect.position.x, rect.position.y + 9), 7, RAGE if affordable else RED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)
	var icon_color := GOLD if (left <= 0.0 and affordable) else Color(0.62, 0.64, 0.72, 1.0)
	var c := rect.position + Vector2(rect.size.x * 0.5, 19)
	draw_circle(c, 8.0, Color(icon_color.r, icon_color.g, icon_color.b, 0.22))
	draw_arc(c, 8.0, 0.0, TAU, 20, icon_color, 1.5)
	_draw_text(String(skill.get("hud_label", "")), Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if left > 0.05:
		var ratio := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), Color(0.02, 0.02, 0.04, 0.62))
		_draw_text("%.1f" % left, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.78), 7, Color(0.95, 0.92, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## Hueco de la esquiva: tres chevrones y cooldown en el mismo estilo que M1/M2.
func _draw_dodge_slot(rect: Rect2, warrior: WarriorSim) -> void:
	var left := warrior.dodge_cooldown_left()
	var total := warrior.dodge_cooldown_total()
	var ready := left <= 0.0
	var edge := Color(0.55, 0.82, 1.0, 1.0) if warrior.dodging else PANEL_EDGE
	draw_rect(rect, PANEL)
	draw_rect(rect, edge, false, 1.0)
	_draw_text("SPACE", rect.position + Vector2(4, 9), 7, MUTED)
	var icon_color := Color(0.6, 0.85, 1.0, 1.0) if ready else Color(0.62, 0.64, 0.72, 1.0)
	var c := rect.position + Vector2(rect.size.x * 0.5, 18)
	for i: int in range(3):
		var x := -8.0 + i * 8.0
		draw_line(Vector2(c.x + x - 2, c.y - 6), Vector2(c.x + x + 2, c.y), icon_color, 2.0)
		draw_line(Vector2(c.x + x + 2, c.y), Vector2(c.x + x - 2, c.y + 6), icon_color, 2.0)
	_draw_text("DODGE", Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	if left > 0.05:
		var ratio := clampf(left / maxf(total, 0.001), 0.0, 1.0)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), Color(0.02, 0.02, 0.04, 0.62))
		_draw_text("%.1f" % left, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.78), 7, Color(0.95, 0.92, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	elif warrior.state == WarriorSim.AttackState.IDLE:
		draw_rect(rect.grow(-2.0), Color(edge.r, edge.g, edge.b, 0.22), false, 1.0)


func _draw_sword_icon(center: Vector2, angle: float, color: Color, heavy: bool) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	var width := 3.0 if heavy else 2.0
	draw_line(Vector2(0, 9), Vector2(0, -10), color, width)
	draw_line(Vector2(-5, -6), Vector2(5, -6), color, 2.0)
	draw_line(Vector2(-2, 8), Vector2(2, 8), color, 2.0)
	if heavy:
		draw_circle(Vector2(0, -10), 1.5, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_controls() -> void:
	_panel(Rect2(498, 265, 132, 89))
	var lines := [
		"WASD   MOVE",
		"MOUSE  AIM",
		"LMB    SWORD SLASH",
		"RMB    HEAVY STRIKE",
		"SPACE  DODGE",
		"1 2    SKILLS",
		"F      ULTIMATE",
		"R      RESET",
		"F3     DEBUG",
	]
	for i: int in range(lines.size()):
		_draw_text(String(lines[i]), Vector2(504, 276 + i * 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 120)


# --- Overlays ---------------------------------------------------------------


func _draw_damage_flash() -> void:
	var amount := 0.0
	if _damage_flash > 0.0:
		amount = 0.35 * _damage_flash
	if world != null and world.warrior != null and world.warrior.alive:
		var ratio: float = world.warrior.health / maxf(world.warrior.max_health, 1.0)
		if ratio < 0.30:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			amount = maxf(amount, 0.10 + 0.08 * pulse)
	if amount > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.65, 0.06, 0.06, amount), false, 7.0)


func _draw_death() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.01, 0.02, 0.62))
	_draw_text("YOU DIED", Vector2(0, 176), 28, RED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	_draw_text("THE TRAINING DUMMY WON THIS ROUND", Vector2(0, 194), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	_draw_text("PRESS  R  TO RISE AGAIN", Vector2(0, 210), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 640)


# --- Primitivas -------------------------------------------------------------


func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, PANEL_EDGE_SOFT, false, 1.0)
	draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), Color(PANEL_EDGE.r, PANEL_EDGE.g, PANEL_EDGE.b, 0.55), 1.0)


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color(0.08, 0.09, 0.12, 0.95))
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var fill := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
		draw_rect(fill, color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.0)), color.lightened(0.35))
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.9), false, 1.0)


func _draw_text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
