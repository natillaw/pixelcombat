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
const XP := Color(0.45, 0.68, 1.0, 1.0)
const ENERGY := Color(0.95, 0.80, 0.25, 1.0)
const MANA := Color(0.35, 0.55, 1.0, 1.0)

const SLOT_COUNT := 10
const SLOT_W := 54.0
const SLOT_H := 38.0
const SLOT_GAP := 3.0
const SLOT_Y := 316.0

var world: CombatWorld
var session: GameSession
var _damage_flash: float = 0.0
var _toast: String = ""
var _toast_time: float = 0.0
var _toast_color: Color = Color(0.93, 0.90, 0.83, 1.0)
var _banner: String = ""
var _banner_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()


func bind(p_world: CombatWorld, p_session: GameSession = null) -> void:
	if world == p_world:
		return
	world = p_world
	session = p_session
	if session != null:
		session.message.connect(_on_message)
		session.floor_completed.connect(_on_floor_completed)
	if world != null and world.player != null:
		world.player.item_gained.connect(_on_item_gained)
		world.player.bag_full.connect(_on_bag_full)
	if world != null and world.player != null:
		world.player.damage_taken.connect(_on_damage_taken)


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	_toast_time = maxf(0.0, _toast_time - delta)
	_banner_time = maxf(0.0, _banner_time - delta)
	queue_redraw()


func _on_message(text: String) -> void:
	_toast = text
	_toast_color = TEXT
	_toast_time = 3.0


func _on_item_gained(item: Dictionary) -> void:
	_toast = "BOTIN: %s" % ItemCatalog.display_name(item)
	_toast_color = ItemCatalog.rarity_color(String(item["rarity"]))
	_toast_time = 3.0


func _on_bag_full(_item: Dictionary) -> void:
	_toast = "MOCHILA LLENA: el botin se pierde"
	_toast_color = RED
	_toast_time = 3.0


func _on_floor_completed(floor_number: int, xp: int) -> void:
	_banner = "PISO %d COMPLETADO" % floor_number if xp <= 0 else "PISO %d COMPLETADO  +%d XP" % [floor_number, xp]
	_banner_time = 4.0


func _on_damage_taken(_amount: float, _source_position: Vector2, is_dot: bool) -> void:
	if not is_dot:
		_damage_flash = 1.0


func _draw() -> void:
	if world == null or world.player == null:
		return
	var warrior := world.player

	_draw_status(warrior)
	_draw_statuses(warrior)
	_draw_abilities(warrior)
	_draw_controls()
	_draw_boss_bar()
	_draw_location()

	if warrior.vengeful_active and warrior.alive:
		_draw_text("M2 EMPOWERED  +30%", Vector2(220, 305), 7, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 200)

	_draw_damage_flash()
	if not warrior.alive:
		_draw_death()


# --- Paneles ----------------------------------------------------------------


func _draw_status(warrior: PlayerSim) -> void:
	_panel(Rect2(10, 6, 246, 78))
	_draw_text(String(warrior.class_def["name"]).to_upper(), Vector2(16, 24), 14, GOLD)
	_draw_text("LV %d" % warrior.level, Vector2(16, 24), 14, TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 234)
	_draw_text(_location_title(), Vector2(84, 23), 7, MUTED)

	var health_ratio: float = warrior.health / maxf(warrior.max_health, 1.0)
	var health_color := HEALTH if health_ratio > 0.30 else HEALTH_LOW
	_bar(Rect2(16, 30, 234, 11), health_ratio, health_color)
	_draw_text(
		"HP  %d / %d" % [ceili(warrior.health), ceili(warrior.max_health)],
		Vector2(16, 39), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 234
	)

	var rage_ratio: float = warrior.resource.get_current() / maxf(warrior.resource.max_amount, 1.0)
	_bar(Rect2(16, 45, 234, 8), rage_ratio, _resource_color(warrior))
	if warrior.resource.is_full() and warrior.resource_kind == "rage":
		draw_rect(Rect2(16, 45, 234, 8), GOLD, false, 1.0)
	_draw_text(
		"%s  %d / %d" % [warrior.resource.resource_name.to_upper(), floori(warrior.resource.get_current()), floori(warrior.resource.max_amount)],
		Vector2(16, 52), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 234
	)

	# Marca del coste del Special (30 Rage) para que la barra ya se lea.
	var special_mark := 16.0 + 234.0 * (WarriorKit.SPECIAL_COST / WarriorKit.MAX_RAGE)
	draw_line(Vector2(special_mark, 45), Vector2(special_mark, 52), Color(1, 1, 1, 0.35), 1.0)

	var passive := String(warrior.class_def["role"]).to_upper()
	var passive_color := MUTED
	if String(warrior.class_def["passive"]) == "vengeful_fury":
		passive = "PASSIVE  VENGEFUL FURY"
		passive_color = GOLD
		if warrior.vengeful_active:
			passive += "  ACTIVE %.1fs" % warrior.vengeful_seconds_left()
			passive_color = ORANGE
	if warrior.empower_mult > 1.0:
		passive = "EMPOWERED  x%.1f  %.1fs" % [warrior.empower_mult, warrior.empower_seconds_left()]
		passive_color = Color(0.65, 0.88, 1.0, 1.0)
	_draw_text(passive, Vector2(16, 66), 7, passive_color)

	# XP del nivel actual.
	var to_next := warrior.xp_to_next()
	var xp_ratio := 1.0 if to_next <= 0 else float(warrior.xp) / float(to_next)
	_bar(Rect2(16, 70, 234, 5), xp_ratio, XP)
	_draw_text("GOLD  %d" % warrior.gold, Vector2(16, 82), 7, GOLD)
	_draw_text("MAX LEVEL" if to_next <= 0 else "XP  %d / %d" % [warrior.xp, to_next], Vector2(16, 82), 7, XP, HORIZONTAL_ALIGNMENT_RIGHT, 234)


## Barra inferior: M1, M2, esquiva, S1-S5, Special y Ultimate (10 huecos).
func _draw_abilities(warrior: PlayerSim) -> void:
	_draw_ability(
		_slot_rect(0),
		"LMB", _hud_label(warrior, "M1"), "M1",
		warrior.attack_cooldown_left("M1"), warrior.attack_cooldown_total("M1"),
		false, warrior.state == PlayerSim.AttackState.IDLE
	)
	_draw_ability(
		_slot_rect(1),
		"RMB", _hud_label(warrior, "M2"), "M2",
		warrior.attack_cooldown_left("M2"), warrior.attack_cooldown_total("M2"),
		warrior.vengeful_active, warrior.state == PlayerSim.AttackState.IDLE
	)
	_draw_dodge_slot(_slot_rect(2), warrior)
	_draw_m1_pips(_slot_rect(0), warrior)
	_draw_m2_charge(_slot_rect(1), warrior)
	for i: int in range(5):
		_draw_skill_slot(_slot_rect(3 + i), str(i + 1), "S%d" % (i + 1), warrior)
	_draw_skill_slot(_slot_rect(8), "Q", "SPECIAL", warrior)
	_draw_ultimate_slot(_slot_rect(9), warrior)


func _slot_rect(index: int) -> Rect2:
	var total := float(SLOT_COUNT) * SLOT_W + float(SLOT_COUNT - 1) * SLOT_GAP
	return Rect2((640.0 - total) * 0.5 + float(index) * (SLOT_W + SLOT_GAP), SLOT_Y, SLOT_W, SLOT_H)


func _draw_ability(rect: Rect2, key: String, label: String, slot: String, left: float, total: float, empowered: bool, idle: bool) -> void:
	var edge := ORANGE if empowered else PANEL_EDGE
	draw_rect(rect, PANEL)
	draw_rect(rect, edge, false, 1.0)

	_draw_text(key, rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text(slot, Vector2(rect.position.x, rect.position.y + 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)

	var icon_color := ORANGE if empowered else (GOLD if left <= 0.0 else Color(0.62, 0.64, 0.72, 1.0))
	var icon_center := rect.position + Vector2(rect.size.x * 0.5, 17)
	var shape := String(world.player.loadout.get(slot, {}).get("shape", "cone"))
	if shape == "projectile":
		_draw_arrow_icon(icon_center, icon_color, slot == "M2")
	elif slot == "M1":
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


## Cargas de M1 como tres barras sobre el hueco; la que se esta recargando se va
## llenando.
func _draw_m1_pips(rect: Rect2, warrior: PlayerSim) -> void:
	var maximum := int(warrior.charges_max("M1"))
	if maximum <= 0:
		return
	var left := warrior.charges_left("M1")
	var gap := 3.0
	var width := (rect.size.x - gap * float(maximum - 1)) / float(maximum)
	for i: int in range(maximum):
		var fill := clampf(left - float(i), 0.0, 1.0)
		var bar := Rect2(rect.position.x + float(i) * (width + gap), rect.position.y - 7.0, width, 3.0)
		draw_rect(bar, Color(0.02, 0.02, 0.04, 0.8))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), GOLD if fill >= 1.0 else Color(0.62, 0.64, 0.72, 1.0))


## Barra de carga de M2 mientras se mantiene el boton.
func _draw_m2_charge(rect: Rect2, warrior: PlayerSim) -> void:
	var fraction := warrior.charge_fraction()
	if fraction <= 0.0:
		return
	var bar := Rect2(rect.position.x, rect.position.y - 7.0, rect.size.x, 4.0)
	draw_rect(bar, Color(0.02, 0.02, 0.04, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), GOLD if fraction >= 1.0 else ORANGE)
	draw_rect(bar, PANEL_EDGE, false, 1.0)


## Hueco de la ultimate: se llena con la Ultimate Charge y brilla cuando esta lista.
func _draw_ultimate_slot(rect: Rect2, warrior: PlayerSim) -> void:
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
	_draw_text(_hud_label(warrior, "ULTIMATE"), Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## Hueco de una skill equipada (S1-S5): etiqueta, coste y cooldown. Se vuelve
## rojo si no hay Rage suficiente.
func _draw_skill_slot(rect: Rect2, key: String, slot: String, warrior: PlayerSim) -> void:
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
	var affordable := warrior.resource_amount() >= cost
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
func _draw_dodge_slot(rect: Rect2, warrior: PlayerSim) -> void:
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
	elif warrior.state == PlayerSim.AttackState.IDLE:
		draw_rect(rect.grow(-2.0), Color(edge.r, edge.g, edge.b, 0.22), false, 1.0)


func _hud_label(warrior: PlayerSim, slot: String) -> String:
	return String((warrior.loadout.get(slot, {}) as Dictionary).get("hud_label", slot))


func _resource_color(warrior: PlayerSim) -> Color:
	match warrior.resource_kind:
		"energy":
			return ENERGY
		"mana":
			return MANA
		_:
			return RAGE


## Flecha o proyectil como icono de los basicos a distancia.
func _draw_arrow_icon(center: Vector2, color: Color, heavy: bool) -> void:
	var width := 3.0 if heavy else 2.0
	draw_line(center + Vector2(-10, 6), center + Vector2(8, -6), color, width)
	draw_colored_polygon(PackedVector2Array([center + Vector2(11, -8), center + Vector2(3, -7), center + Vector2(7, -1)]), color)
	draw_line(center + Vector2(-10, 6), center + Vector2(-13, 2), color, 1.5)
	draw_line(center + Vector2(-10, 6), center + Vector2(-6, 9), color, 1.5)
	if heavy:
		draw_circle(center + Vector2(-2, 0), 1.5, color)


func _draw_sword_icon(center: Vector2, angle: float, color: Color, heavy: bool) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	var width := 3.0 if heavy else 2.0
	draw_line(Vector2(0, 9), Vector2(0, -10), color, width)
	draw_line(Vector2(-5, -6), Vector2(5, -6), color, 2.0)
	draw_line(Vector2(-2, 8), Vector2(2, 8), color, 2.0)
	if heavy:
		draw_circle(Vector2(0, -10), 1.5, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Estados alterados del jugador (STUN, SLOW, POISON) con su tiempo restante, bajo
## el panel de estado.
func _draw_statuses(warrior: PlayerSim) -> void:
	var x := 12.0
	for id: String in warrior.statuses.active_ids():
		var definition := StatusCatalog.status(id)
		var color_data: Array = definition["color"]
		var color := Color(float(color_data[0]), float(color_data[1]), float(color_data[2]), 1.0)
		var label := "%s %.1f" % [String(definition["name"]).to_upper(), warrior.statuses.remaining(id)]
		var width := 8.0 + 4.6 * float(label.length())
		draw_rect(Rect2(x, 90, width, 12), Color(color.r, color.g, color.b, 0.25))
		draw_rect(Rect2(x, 90, width, 12), color, false, 1.0)
		_draw_text(label, Vector2(x + 4.0, 99), 7, color)
		x += width + 4.0


## Barra de vida del jefe activo, arriba al centro, con una marca en cada cambio de
## fase y el nombre de la fase actual.
func _draw_boss_bar() -> void:
	for enemy: EnemySim in world.enemies:
		if not enemy.alive or not enemy.is_boss() or enemy.state == EnemySim.State.IDLE:
			continue
		var panel := Rect2(262, 6, 230, 34)
		_panel(panel)
		_draw_text(String(enemy.data["name"]).to_upper(), Vector2(268, 18), 7, GOLD)
		_draw_text(enemy.phase_name().to_upper(), Vector2(268, 18), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 218)
		var bar := Rect2(268, 24, 218, 9)
		var ratio := clampf(enemy.health / maxf(enemy.max_health, 1.0), 0.0, 1.0)
		var roaring := enemy.state == EnemySim.State.PHASE
		_bar(bar, ratio, Color(1.0, 0.8, 0.3, 1.0) if roaring else RED)
		for i: int in range(1, enemy.data["phases"].size()):
			var mark := bar.position.x + bar.size.x * float(enemy.data["phases"][i]["hp_below"])
			draw_line(Vector2(mark, bar.position.y - 1.0), Vector2(mark, bar.end.y + 1.0), Color(1, 1, 1, 0.55), 1.0)
		return


func _location_title() -> String:
	if session == null or session.layout == null:
		return "TRAINING GROUNDS"
	return session.layout.title.to_upper()


## Objetivo del piso, aviso de interaccion, mensajes y banner de piso completado.
func _draw_location() -> void:
	if session == null or session.layout == null:
		return
	var objective := session.objective_text()
	if not objective.is_empty():
		_draw_text(objective.to_upper(), Vector2(262, 52), 7, GOLD if session.is_floor_done() else MUTED, HORIZONTAL_ALIGNMENT_CENTER, 230)
	if world.player.alive:
		var portal: Variant = session.nearest_portal()
		if portal != null:
			var prompt := session.portal_prompt(portal)
			_panel(Rect2(190, 290, 260, 16))
			_draw_text(prompt.to_upper(), Vector2(190, 301), 7, TEXT if session.portal_active(portal) else MUTED, HORIZONTAL_ALIGNMENT_CENTER, 260)
	if _toast_time > 0.0:
		_draw_text(_toast.to_upper(), Vector2(0, 120), 7, _toast_color, HORIZONTAL_ALIGNMENT_CENTER, 640)
	if _banner_time > 0.0:
		_draw_text(_banner, Vector2(0, 90), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 640)


func _draw_controls() -> void:
	_panel(Rect2(498, 6, 132, 148))
	var lines := [
		"WASD   MOVE",
		"MOUSE  AIM",
		"LMB    PRIMARY",
		"RMB    SECONDARY (HOLD)",
		"SPACE  DODGE",
		"1-5    SKILLS",
		"Q      SPECIAL",
		"F      ULTIMATE",
		"TAB    LOADOUT",
		"I      INVENTORY",
		"E      INTERACT",
		", .    TOWER FLOOR",
		"R      RESTART",
		"F3     DEBUG",
		"F7     NEXT CLASS",
	]
	for i: int in range(lines.size()):
		_draw_text(String(lines[i]), Vector2(504, 17 + i * 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 120)


# --- Overlays ---------------------------------------------------------------


func _draw_damage_flash() -> void:
	var amount := 0.0
	if _damage_flash > 0.0:
		amount = 0.35 * _damage_flash
	if world != null and world.player != null and world.player.alive:
		var ratio: float = world.player.health / maxf(world.player.max_health, 1.0)
		if ratio < 0.30:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			amount = maxf(amount, 0.10 + 0.08 * pulse)
	if amount > 0.0:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.65, 0.06, 0.06, amount), false, 7.0)


func _draw_death() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.01, 0.02, 0.62))
	_draw_text("YOU DIED", Vector2(0, 176), 28, RED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	if session != null and session.layout != null and session.layout.kind == FloorLayout.KIND_FLOOR:
		_draw_text("RETURNING TO THE CITY...", Vector2(0, 194), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)
		return
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
