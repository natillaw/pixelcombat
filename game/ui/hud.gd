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
const MUTED := Color(0.84, 0.77, 0.60, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const ORANGE := Color(1.0, 0.53, 0.18, 1.0)
const RED := Color(0.88, 0.28, 0.24, 1.0)
const HEALTH := Color(0.42, 0.78, 0.42, 1.0)
const HEALTH_LOW := Color(0.86, 0.38, 0.24, 1.0)
const RAGE := Color(0.93, 0.35, 0.20, 1.0)
const XP := Color(0.45, 0.68, 1.0, 1.0)
const GREEN_DONE := Color(0.55, 0.82, 0.45, 1.0)
const ENERGY := Color(0.95, 0.80, 0.25, 1.0)
const MANA := Color(0.35, 0.55, 1.0, 1.0)

## Huecos que se dibujan en la barra de habilidades (6, o 7 si la clase aun tiene Especial).
var _slots_shown: int = 6
const SLOT_W := 54.0
const SLOT_H := 38.0
const SLOT_GAP := 3.0
const SLOT_Y := 316.0

var world: CombatWorld
var session: GameSession
var _damage_flash: float = 0.0
var _toast: String = ""
var _portrait: Texture2D = null
var _portrait_key: String = ""
var show_controls: bool = false
var _minimap: ImageTexture = null
var _minimap_layout: FloorLayout = null
## Casillas ya descubiertas del piso actual (niebla del minimapa); vacio = todo descubierto (ciudad, entrenamiento).
var _explored: PackedByteArray = PackedByteArray()
const MINIMAP_REVEAL := 8
## Texto bajo el cursor sobre algo que se puede coger (lo pone main).
var pickup_prompt: String = ""
var _toast_time: float = 0.0
var _toast_color: Color = Color(0.93, 0.90, 0.83, 1.0)
var _banner: String = ""
var _banner_time: float = 0.0
## Pista del tutorial en pantalla (TutorialHints) y lo que le queda.
var _tip: String = ""
var _tip_time: float = 0.0
var _boss_bar_seen: bool = false
## Segundos reales desde que murio el jugador (el telon de la muerte aparece poco a poco).
var _death_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
		session.location_changed.connect(_on_location_tip)
		_on_location_tip(session.layout)
	if world != null and world.player != null:
		world.player.item_gained.connect(_on_item_gained)
		world.player.bag_full.connect(_on_bag_full)
		world.player.material_gained.connect(_on_material_gained)
		world.gather_interrupted.connect(_on_gather_interrupted)
	if world != null and world.player != null:
		world.player.damage_taken.connect(_on_damage_taken)
		world.player.damage_taken.connect(func(_a: float, _p: Vector2, is_dot: bool) -> void:
			if not is_dot:
				show_tip("first_damage"))
		world.player.item_gained.connect(func(_item: Dictionary) -> void: show_tip("first_item"))


func _process(delta: float) -> void:
	_damage_flash = maxf(0.0, _damage_flash - delta * 3.5)
	_toast_time = maxf(0.0, _toast_time - delta)
	_banner_time = maxf(0.0, _banner_time - delta)
	_tip_time = maxf(0.0, _tip_time - delta)
	if world != null and world.player != null and not world.player.alive:
		_death_time += delta / maxf(Engine.time_scale, 0.05)
	else:
		_death_time = 0.0
	queue_redraw()


## Muestra la pista de tutorial de `trigger` si aun no se ha visto (se recuerda por personaje).
func show_tip(trigger: String) -> void:
	if session == null or session.tower == null:
		return
	var tip := TutorialHints.next_tip(trigger, session.tower.flags)
	if tip.is_empty():
		return
	session.tower.set_flag(TutorialHints.flag_for(tip))
	_tip = TutorialHints.render(String(tip["text"]), func(action: String) -> String: return Settings.short_label(action))
	_tip_time = float(tip.get("seconds", 8))


func _on_location_tip(layout: FloorLayout) -> void:
	if layout == null:
		return
	if layout.kind == FloorLayout.KIND_CITY:
		show_tip("city")
	elif layout.kind == FloorLayout.KIND_FLOOR and layout.floor_number == 1:
		show_tip("floor_1")


func _on_message(text: String) -> void:
	_toast = text
	_toast_color = TEXT
	_toast_time = 2.5 + float(text.length()) * 0.045


func _on_item_gained(item: Dictionary) -> void:
	_toast = "BOTIN: %s" % ItemCatalog.display_name(item)
	_toast_color = ItemCatalog.rarity_color(String(item["rarity"]))
	_toast_time = 3.0


func _on_material_gained(id: String, amount: int) -> void:
	_toast = "+%d %s" % [amount, MaterialCatalog.display_name(id)]
	_toast_color = Color(0.85, 0.9, 0.7, 1.0)
	_toast_time = 2.5


func _on_gather_interrupted(_node: ResourceNode, reason: String) -> void:
	_toast = "RECOLECCION INTERRUMPIDA" if reason != "moved" else "RECOLECCION CANCELADA: TE MOVISTE"
	_toast_color = MUTED
	_toast_time = 2.0


func _on_bag_full(_item: Dictionary) -> void:
	_toast = "MOCHILA LLENA: no puedes recoger mas"
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
	_draw_quick_items(warrior)
	_draw_active_food(warrior)
	if show_controls:
		_draw_controls()
	else:
		_draw_text("F1  AYUDA", Vector2(520, 354), 7, MUTED)
	_draw_boss_bar()
	_draw_location()
	_draw_minimap()

	if warrior.vengeful_active and warrior.alive:
		_draw_text("M2 EMPOWERED  +30%", Vector2(220, 305), 7, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 200)

	_draw_damage_flash()
	if not warrior.alive:
		_draw_death()


# --- Paneles ----------------------------------------------------------------


const CHAR_PANEL := preload("res://assets/pixel/ui/craftpix/character_panel.png")
## Placa con anillo de retrato y tres ranuras (de character_panel): se dibuja a x2.
const PLATE := Rect2(1, 34, 86, 30)


## Retrato circular + placa del paquete CraftPix (vida, recurso y XP en sus ranuras) y, a la
## derecha, nombre, clase, valores y oro.
func _draw_status(warrior: PlayerSim) -> void:
	var origin := Vector2(6, 6)
	var scale := 2.0
	var key := str([warrior.class_id, warrior.equipment, warrior.appearance].hash())
	if key != _portrait_key:
		_portrait_key = key
		_portrait = ClassLook.portrait(warrior.class_id, warrior.appearance, warrior.equipment)
	var center := origin + Vector2(15.5, 15.0) * scale
	if _portrait != null:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i: int in range(32):
			var angle := TAU * float(i) / 32.0
			points.append(center + Vector2(cos(angle), sin(angle)) * 21.0)
			uvs.append(Vector2((10.0 + (cos(angle) * 0.5 + 0.5) * 44.0) / 64.0, (2.0 + (sin(angle) * 0.5 + 0.5) * 44.0) / 64.0))
		draw_circle(center, 22.0, Color(0.10, 0.12, 0.2, 1.0))
		draw_colored_polygon(points, Color.WHITE, uvs, _portrait)
	draw_texture_rect_region(CHAR_PANEL, Rect2(origin, PLATE.size * scale), PLATE)
	# Chapa de nivel.
	draw_circle(center + Vector2(15, 14), 9.0, Color(0.16, 0.10, 0.05, 1.0))
	draw_arc(center + Vector2(15, 14), 9.0, 0.0, TAU, 20, UiStyle.GOLD, 1.0)
	_draw_text(str(warrior.level), center + Vector2(6, 17), 8, UiStyle.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, 18)

	var health_ratio: float = warrior.health / maxf(warrior.max_health, 1.0)
	var rage_ratio: float = warrior.resource.get_current() / maxf(warrior.resource.max_amount, 1.0)
	var to_next := warrior.xp_to_next()
	var xp_ratio := 1.0 if to_next <= 0 else float(warrior.xp) / float(to_next)
	var health_color := Color(0.86, 0.2, 0.18, 1.0) if health_ratio > 0.30 else Color(1.0, 0.45, 0.15, 1.0)
	_slot_bar(origin + Vector2(31, 9) * scale, 52.0 * scale, health_ratio, health_color)
	_slot_bar(origin + Vector2(31, 14) * scale, 46.0 * scale, rage_ratio, _resource_color(warrior))
	_slot_bar(origin + Vector2(31, 19) * scale, 40.0 * scale, xp_ratio, Color(0.35, 0.82, 0.38, 1.0))

	# Texto a la derecha de la placa.
	var tx := 184.0
	_panel(Rect2(tx - 4, 8, 112, 58))
	_draw_text(warrior.character_name.to_upper(), Vector2(tx, 19), 8, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 104)
	var where := "%s  -  %s" % [String(warrior.class_def["name"]).to_upper(), _location_title()]
	if FONT.get_string_size(where, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7).x > 104.0:
		where = _location_title()                    # largo: solo el lugar, sin la clase
	_draw_text(_fit(where, 7, 104.0), Vector2(tx, 28), 7, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 104)
	_draw_text("VIDA  %d / %d" % [ceili(warrior.health), ceili(warrior.max_health)], Vector2(tx, 38), 7, TEXT)
	_draw_text("%s  %d / %d" % [warrior.resource.resource_name.to_upper(), floori(warrior.resource.get_current()), floori(warrior.resource.max_amount)], Vector2(tx, 46), 7, TEXT)
	var passive := ""
	var passive_color := MUTED
	if warrior.vengeful_active:
		passive = "FURIA  %.1fs" % warrior.vengeful_seconds_left()
		passive_color = ORANGE
	if warrior.empower_mult > 1.0:
		passive = "POTENCIADO x%.1f" % warrior.empower_mult
		passive_color = Color(0.65, 0.88, 1.0, 1.0)
	_draw_text(passive if passive != "" else "XP  %d / %d" % [warrior.xp, maxi(to_next, 0)], Vector2(tx, 54), 7, passive_color if passive != "" else XP)
	_draw_text("ORO %d" % warrior.gold, Vector2(tx, 62), 7, GOLD)


## Barra fina que rellena una ranura de la placa (vida, recurso, XP).
func _slot_bar(at: Vector2, width: float, ratio: float, color: Color) -> void:
	var rect := Rect2(at, Vector2(width, 6.0))
	draw_rect(rect, Color(0.07, 0.04, 0.03, 1.0))
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var fill := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
		draw_rect(fill, color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2.0)), color.lightened(0.35))


## Barra inferior: basico (clic derecho: toque = combo, mantener = golpe cargado), defensa (Espacio), skills
## Q E R (y el Especial de las clases que aun lo tienen) y ultimate (F).
func _draw_abilities(warrior: PlayerSim) -> void:
	_slots_shown = 7 if warrior.class_def.get("default_loadout", {}).has("SPECIAL") else 6
	_draw_ability(
		_slot_rect(0),
		Settings.short_label("attack_m2"), _hud_label(warrior, "M1"), "M1",
		warrior.attack_cooldown_left("M1"), warrior.attack_cooldown_total("M1"),
		warrior.vengeful_active, warrior.state == PlayerSim.AttackState.IDLE
	)
	_draw_dodge_slot(_slot_rect(1), warrior)
	_draw_m1_pips(_slot_rect(0), warrior)
	_draw_m2_charge(_slot_rect(0), warrior)
	for i: int in range(3):
		_draw_skill_slot(_slot_rect(2 + i), Settings.short_label("skill_%d" % (i + 1)), "S%d" % (i + 1), warrior)
	var next := 5
	if warrior.class_def.get("default_loadout", {}).has("SPECIAL"):
		_draw_skill_slot(_slot_rect(next), Settings.short_label("special"), "SPECIAL", warrior)
		next += 1
	_draw_ultimate_slot(_slot_rect(next), warrior)


## Barra de objetos (teclas 1-5) sobre la de habilidades: 1 pocion de vida, 2 elixir de energia y 3-5 para los
## gadgets que se anadiran mas adelante. Muestra tecla, cantidad y enfriamiento.
func _draw_quick_items(player: PlayerSim) -> void:
	var quick_kinds := ["health", "resource"]
	var cell := 30.0
	var gap := 3.0
	var left := (640.0 - (5.0 * cell + 4.0 * gap)) * 0.5
	for index: int in range(5):
		var rect := Rect2(left + float(index) * (cell + gap), SLOT_Y - 26.0, cell, 22.0)
		UiStyle.draw_slot_bg(self, rect)
		var action := "item_%d" % (index + 1) if index >= 2 else ("quick_" + String(quick_kinds[index]))
		_draw_text(Settings.short_label(action), rect.position + Vector2(3, 8), 7, MUTED)
		if index >= 2:
			continue
		var quick: String = quick_kinds[index]
		var total := 0
		var best := ""
		for id: String in ConsumableCatalog.quick_ids(quick):
			total += player.consumable_count(id)
			if best == "" and player.consumable_count(id) > 0:
				best = id
		var ids := ConsumableCatalog.quick_ids(quick)
		var icon := SkillIcons.consumable(best if best != "" else String(ids[ids.size() - 1]))
		if icon != null:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(9, 5), Vector2(12, 12)), false, Color(1, 1, 1, 1.0 if total > 0 else 0.35))
		_draw_text("x%d" % total, rect.position + Vector2(0, 20), 7, MUTED if total > 0 else Color(0.5, 0.45, 0.38), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 2.0)
		if player.potion_cooldown_left > 0.0 and total > 0:
			var fraction := clampf(player.potion_cooldown_left / ConsumableCatalog.potion_cooldown(), 0.0, 1.0)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * fraction)), Color(0, 0, 0, 0.55))


## Comida activa (bien alimentado, fuerza, velocidad): icono y tiempo que queda, apilados sobre las pociones.
func _draw_active_food(player: PlayerSim) -> void:
	var foods := {"fed": "herb_bread", "might": "hunters_stew", "haste": "silk_tea"}
	var row := 0
	for status: String in foods:
		if not player.statuses.has(status):
			continue
		var rect := Rect2(3.0, SLOT_Y - 4.0 - float(row) * 25.0, 31.0, 23.0)
		UiStyle.draw_slot_bg(self, rect)
		var icon := SkillIcons.consumable(String(foods[status]))
		if icon != null:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(1, 5), Vector2(12, 12)), false)
		var seconds := int(player.statuses.remaining(status))
		_draw_text("%d:%02d" % [seconds / 60, seconds % 60], rect.position + Vector2(14, 10), 7, TEXT)
		_draw_text(String(StatusCatalog.status(status)["name"]).substr(0, 5), rect.position + Vector2(14, 19), 7, MUTED)
		row += 1


func _slot_rect(index: int) -> Rect2:
	var total := float(_slots_shown) * SLOT_W + float(_slots_shown - 1) * SLOT_GAP
	return Rect2((640.0 - total) * 0.5 + float(index) * (SLOT_W + SLOT_GAP), SLOT_Y, SLOT_W, SLOT_H)


func _draw_ability(rect: Rect2, key: String, label: String, slot: String, left: float, total: float, empowered: bool, idle: bool) -> void:
	var edge := ORANGE if empowered else PANEL_EDGE
	UiStyle.draw_slot_bg(self, rect)
	UiStyle.draw_slot_edge(self, rect, edge)

	_draw_text(key, rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text(slot, Vector2(rect.position.x, rect.position.y + 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)

	var icon_color := ORANGE if empowered else (GOLD if left <= 0.0 else Color(0.62, 0.64, 0.72, 1.0))
	var icon_center := rect.position + Vector2(rect.size.x * 0.5, 17)
	var shape := String(world.player.loadout.get(slot, {}).get("shape", "cone"))
	var icon := SkillIcons.texture(String(world.player.loadout.get(slot, {}).get("id", "")))
	if icon != null:
		_draw_icon(icon, rect, left <= 0.0)
	elif shape == "projectile":
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


## Icono de habilidad centrado en el hueco; apagado mientras esta en enfriamiento.
func _draw_icon(icon: Texture2D, rect: Rect2, active: bool) -> void:
	var side := 26.0
	var dst := Rect2(rect.position + Vector2((rect.size.x - side) * 0.5, 5.0), Vector2(side, side))
	draw_texture_rect(icon, dst, false, Color(1, 1, 1, 1.0) if active else Color(0.55, 0.55, 0.62, 0.9))
	draw_rect(dst, Color(0.0, 0.0, 0.02, 0.7), false, 1.0)


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
	UiStyle.draw_slot_bg(self, rect)
	var ultimate_icon := SkillIcons.texture(String(warrior.loadout.get("ULTIMATE", {}).get("id", "")))
	if ultimate_icon != null:
		_draw_icon(ultimate_icon, rect, ready)
	var fill := Color(GOLD.r, GOLD.g, GOLD.b, 0.40 if ready else 0.22)
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * (1.0 - ratio), rect.size.x, rect.size.y * ratio), fill)
	draw_rect(rect, edge, false, 1.0)
	_draw_text("F", rect.position + Vector2(4, 9), 7, MUTED)
	_draw_text("ULT", Vector2(rect.position.x, rect.position.y + 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4)
	_draw_text("READY" if ready else "%d%%" % int(ratio * 100.0), Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62), 7, GOLD if ready else TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
	_draw_text(_hud_label(warrior, "ULTIMATE"), Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


## Hueco de una skill equipada (S1-S5): etiqueta, coste y cooldown. Se vuelve
## rojo si no hay Rage suficiente.
func _draw_skill_slot(rect: Rect2, key: String, slot: String, warrior: PlayerSim) -> void:
	UiStyle.draw_slot_bg(self, rect)
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
	var skill_icon := SkillIcons.texture(String(skill.get("id", "")))
	if skill_icon != null:
		_draw_icon(skill_icon, rect, left <= 0.0 and affordable)
	else:
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
	UiStyle.draw_slot_bg(self, rect)
	UiStyle.draw_slot_edge(self, rect, edge)
	_draw_text(Settings.short_label("dodge"), rect.position + Vector2(4, 9), 7, MUTED)
	var icon_color := Color(0.6, 0.85, 1.0, 1.0) if ready else Color(0.62, 0.64, 0.72, 1.0)
	var c := rect.position + Vector2(rect.size.x * 0.5, 18)
	var mobility := warrior.mobility()
	var dodge_icon := SkillIcons.texture(String(mobility.get("icon", "dodge")))
	if dodge_icon != null:
		_draw_icon(dodge_icon, rect, ready)
	else:
		for i: int in range(3):
			var x := -8.0 + i * 8.0
			draw_line(Vector2(c.x + x - 2, c.y - 6), Vector2(c.x + x + 2, c.y), icon_color, 2.0)
			draw_line(Vector2(c.x + x + 2, c.y), Vector2(c.x + x - 2, c.y + 6), icon_color, 2.0)
	_draw_text(String(mobility.get("name", "Dodge")).to_upper().substr(0, 9), Vector2(rect.position.x, rect.position.y + rect.size.y - 2), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
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
		if not _boss_bar_seen:
			_boss_bar_seen = true
			show_tip("first_boss_bar")
		var panel := Rect2(300, 6, 190, 34)
		_panel(panel)
		_draw_text(_fit(String(enemy.data["name"]).to_upper(), 7, 110.0), Vector2(306, 18), 7, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 110)
		_draw_text(enemy.phase_name().to_upper(), Vector2(306, 18), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 178)
		var bar := Rect2(306, 24, 178, 9)
		var ratio := clampf(enemy.health / maxf(enemy.max_health, 1.0), 0.0, 1.0)
		var roaring := enemy.state == EnemySim.State.PHASE
		_bar(bar, ratio, Color(1.0, 0.8, 0.3, 1.0) if roaring else RED)
		for i: int in range(1, enemy.data["phases"].size()):
			var mark := bar.position.x + bar.size.x * float(enemy.data["phases"][i]["hp_below"])
			draw_line(Vector2(mark, bar.position.y - 1.0), Vector2(mark, bar.end.y + 1.0), Color(1, 1, 1, 0.55), 1.0)
		return


## Lista de misiones del piso (principales y opcionales) y limite de tiempo.
var _quest_tracker_y: float = 92.0


func _draw_missions() -> void:
	_quest_tracker_y = 92.0
	var lines := session.mission_lines()
	if lines.is_empty() and session.time_limit <= 0.0:
		_draw_quest_tracker()
		return
	var height := 26.0 + float(lines.size()) * 11.0 + (12.0 if session.time_limit > 0.0 else 0.0)
	_quest_tracker_y = 92.0 + height + 6.0
	_panel(Rect2(488, 92, 142, height), "OBJETIVOS")
	var y := 112.0                                   # bajo la cabecera verde (antes pisaba el titulo)
	for line: Dictionary in lines:
		var color := GREEN_DONE if bool(line["done"]) else (MUTED if bool(line["optional"]) else TEXT)
		var mark := "[x] " if bool(line["done"]) else "[ ] "
		var shown := mark + String(line["text"])
		if shown.length() > 38:
			shown = shown.substr(0, 36) + ".."
		_draw_text(shown, Vector2(494, y), 7, color, HORIZONTAL_ALIGNMENT_LEFT, 130)
		y += 11.0
	if session.time_limit > 0.0:
		var left := session.time_left
		var urgent := left < 60.0
		_draw_text("TIEMPO  %d:%02d" % [int(left) / 60, int(left) % 60], Vector2(494, y + 1.0), 7, RED if urgent else GOLD)
	_draw_quest_tracker()


## Seguimiento de las misiones activas del marco de misiones (hasta 3), bajo la lista de objetivos del piso.
func _draw_quest_tracker() -> void:
	var active: Array = session.tower.quests.active()
	if active.is_empty():
		return
	var shown := mini(active.size(), 3)
	var height := 26.0 + float(shown) * 20.0
	_panel(Rect2(488, _quest_tracker_y, 142, height), "MISIONES")
	var y := _quest_tracker_y + 20.0
	for i: int in range(shown):
		var instance: Dictionary = active[i]
		var objective: Dictionary = {}
		for candidate: Dictionary in instance["objectives"]:
			if not bool(candidate["optional"]) and int(candidate["progress"]) < int(candidate["required"]):
				objective = candidate
				break
		_draw_text(String(instance["title"]).substr(0, 24), Vector2(494, y), 7, TEXT, HORIZONTAL_ALIGNMENT_LEFT, 130)
		if not objective.is_empty():
			_draw_text("%s  %d / %d" % [String(objective["kind"]), int(objective["progress"]), int(objective["required"])], Vector2(494, y + 9.0), 7, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 130)
		y += 20.0


## Minimapa de los escenarios con mapa de casillas: terreno (una textura de 1 px por
## casilla, se rehace al cambiar de escenario), la salida, los objetivos de mision sin
## cumplir, los jefes y elites vivos y la posicion del jugador.
func _draw_minimap() -> void:
	if session == null or session.layout == null or session.layout.grid == null:
		return
	if _minimap_layout != session.layout:
		_minimap_layout = session.layout
		_explored = PackedByteArray()
		if session.layout.kind == FloorLayout.KIND_FLOOR:
			_explored.resize(session.layout.grid.cols * session.layout.grid.rows)
		_reveal_around(world.player.position, session.layout.grid)
		_minimap = _build_minimap(session.layout.grid)
	elif _reveal_around(world.player.position, session.layout.grid):
		_minimap = _build_minimap(session.layout.grid)
	var box := Rect2(522, 6, 108, 80)
	_panel(box)
	var grid := session.layout.grid
	var size := grid.pixel_size()
	var scale := minf((box.size.x - 4.0) / size.x, (box.size.y - 4.0) / size.y)
	var origin := box.position + (box.size - size * scale) * 0.5
	draw_texture_rect(_minimap, Rect2(origin, size * scale), false)
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) in ["exit", "door_tower", "to_training"] and _seen(portal["position"], grid):
			var spot: Vector2 = origin + (portal["position"] as Vector2) * scale
			var active := session.portal_active(portal)
			draw_rect(Rect2(spot - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.35, 0.95, 1.0) if active else Color(0.5, 0.5, 0.55))
	for object: Interactable in world.interactables:
		if not object.done and _seen(object.position, grid):
			draw_rect(Rect2(origin + object.position * scale - Vector2(1, 1), Vector2(2, 2)), GOLD)
	for enemy: EnemySim in world.enemies:
		if enemy.alive and (enemy.is_boss() or enemy.elite) and _seen(enemy.position, grid):
			draw_rect(Rect2(origin + enemy.position * scale - Vector2(1, 1), Vector2(2, 2)), RED)
	var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.01)
	draw_rect(Rect2(origin + world.player.position * scale - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1, blink))


## Descubre las casillas a MINIMAP_REVEAL de `point`; true si se descubrio alguna nueva.
func _reveal_around(point: Vector2, grid: TileGrid) -> bool:
	if _explored.is_empty():
		return false
	var center := grid.world_to_cell(point)
	var changed := false
	for dr: int in range(-MINIMAP_REVEAL, MINIMAP_REVEAL + 1):
		for dc: int in range(-MINIMAP_REVEAL, MINIMAP_REVEAL + 1):
			if dr * dr + dc * dc > MINIMAP_REVEAL * MINIMAP_REVEAL or not grid.in_bounds(center.x + dc, center.y + dr):
				continue
			var index := (center.y + dr) * grid.cols + center.x + dc
			if _explored[index] == 0:
				_explored[index] = 1
				changed = true
	return changed


func _seen(point: Vector2, grid: TileGrid) -> bool:
	if _explored.is_empty():
		return true
	var cell := grid.world_to_cell(point)
	return grid.in_bounds(cell.x, cell.y) and _explored[cell.y * grid.cols + cell.x] == 1


func _build_minimap(grid: TileGrid) -> ImageTexture:
	var image := Image.create(grid.cols, grid.rows, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.02, 0.02, 0.04, 0.0))
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			var color := Color(0, 0, 0, 0)
			if not _explored.is_empty() and _explored[r * grid.cols + c] == 0:
				image.set_pixel(c, r, Color(0.04, 0.05, 0.07, 0.92))
				continue
			match grid.get_cell(c, r):
				TileGrid.FLOOR:
					color = Color(0.22, 0.38, 0.24, 0.95)
				TileGrid.ROAD:
					color = Color(0.62, 0.6, 0.56, 0.95)
				TileGrid.WATER:
					color = Color(0.2, 0.4, 0.62, 0.95)
				TileGrid.SOLID:
					color = Color(0.45, 0.3, 0.2, 0.95)
				TileGrid.WALL:
					color = Color(0.05, 0.07, 0.06, 0.9)
				TileGrid.GATE:
					color = Color(0.8, 0.5, 0.2, 0.95)
			image.set_pixel(c, r, color)
	return ImageTexture.create_from_image(image)


func _location_title() -> String:
	if session == null or session.layout == null:
		return "TRAINING GROUNDS"
	return session.layout.title.to_upper()


## Objetivo del piso, aviso de interaccion, mensajes y banner de piso completado.
func _draw_location() -> void:
	if session == null or session.layout == null:
		return
	if not pickup_prompt.is_empty():
		_panel(Rect2(170, 268, 300, 16))
		_draw_text(pickup_prompt.to_upper(), Vector2(170, 279), 7, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 300)
	var objective := session.objective_text()
	if not objective.is_empty():
		_draw_text(objective.to_upper(), Vector2(262, 52), 7, GOLD if session.is_floor_done() else MUTED, HORIZONTAL_ALIGNMENT_CENTER, 230)
	_draw_missions()
	if world.player.alive:
		var portal: Variant = session.nearest_portal()
		if portal != null:
			var prompt := session.portal_prompt(portal)
			_panel(Rect2(190, 290, 260, 16))
			_draw_text(prompt.to_upper(), Vector2(190, 301), 7, TEXT if session.portal_active(portal) else MUTED, HORIZONTAL_ALIGNMENT_CENTER, 260)
	if _tip_time > 0.0 and not _tip.is_empty():
		var tip_size := FONT.get_multiline_string_size(_tip, HORIZONTAL_ALIGNMENT_LEFT, 324.0, 7, 3)
		var tip_rect := Rect2(150, 276.0 - tip_size.y - 12.0, 340, tip_size.y + 12.0)
		_panel(tip_rect, "")
		draw_multiline_string(FONT, tip_rect.position + Vector2(8, 13), _tip, HORIZONTAL_ALIGNMENT_LEFT, tip_rect.size.x - 16.0, 7, 3, TEXT)
	if _toast_time > 0.0:
		_draw_text(_toast.to_upper(), Vector2(0, 120), 7, _toast_color, HORIZONTAL_ALIGNMENT_CENTER, 640)
	if _banner_time > 0.0:
		_draw_text(_banner, Vector2(0, 90), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 640)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		show_controls = not show_controls


func _draw_controls() -> void:
	_panel(Rect2(10, 84, 132, 148), "CONTROLES")
	var lines := [
		"%s %s %s %s  MOVER" % [Settings.short_label("move_up"), Settings.short_label("move_left"), Settings.short_label("move_down"), Settings.short_label("move_right")],
		"RATON  APUNTAR",
		"%s  PRIMARIO" % Settings.short_label("attack_m1"),
		"%s  SECUNDARIO (MANTENER)" % Settings.short_label("attack_m2"),
		"%s  MOVILIDAD" % Settings.short_label("dodge"),
		"%s %s %s  HABILIDADES" % [Settings.short_label("skill_1"), Settings.short_label("skill_2"), Settings.short_label("skill_3")],
		"%s  ESPECIAL" % Settings.short_label("special"),
		"%s  ULTIMATE" % Settings.short_label("ultimate"),
		"%s  LIBRO DE SKILLS" % Settings.short_label("toggle_loadout"),
		"%s  MOCHILA" % Settings.short_label("toggle_inventory"),
		"%s  PERSONAJE" % Settings.short_label("toggle_character"),
		"%s  INTERACTUAR" % Settings.short_label("interact"),
		", .    PISO DE LA TORRE",
		"%s  REINICIAR" % Settings.short_label("restart_training"),
		"ESC    MENU",
		"F3     DEPURACION",
	]
	for i: int in range(lines.size()):
		_draw_text(String(lines[i]), Vector2(16, 100 + i * 9), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 120)


# --- Overlays ---------------------------------------------------------------


func _draw_damage_flash() -> void:
	if not Settings.damage_flash:
		return
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
	var fade := clampf(_death_time / 0.9, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 640, 360), Color(0.04, 0.01, 0.02, 0.62 * fade))
	if fade < 0.35:
		return
	var text_alpha := clampf((fade - 0.35) / 0.65, 0.0, 1.0)
	_draw_text("HAS MUERTO", Vector2(0, 176), 28, Color(RED.r, RED.g, RED.b, text_alpha), HORIZONTAL_ALIGNMENT_CENTER, 640)
	if session != null and session.layout != null and session.layout.kind == FloorLayout.KIND_FLOOR:
		_draw_text("VOLVIENDO A LA CIUDAD...", Vector2(0, 194), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)
		return
	_draw_text("EL MUNECO DE ENTRENAMIENTO GANO ESTA RONDA", Vector2(0, 194), 7, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640)
	_draw_text("PULSA  R  PARA LEVANTARTE", Vector2(0, 210), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 640)


# --- Primitivas -------------------------------------------------------------


func _panel(rect: Rect2, title: String = "") -> void:
	UiStyle.draw_panel(self, rect, title)


func _bar(rect: Rect2, ratio: float, color: Color) -> void:
	UiStyle.draw_bar(self, rect, ratio, color)


## Recorta el texto con ".." para que quepa en `width` (antes se cortaba a mitad de palabra).
func _fit(text: String, font_size: int, width: float) -> String:
	if FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x <= width:
		return text
	var cut := text
	while cut.length() > 1 and FONT.get_string_size(cut + "..", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > width:
		cut = cut.substr(0, cut.length() - 1)
	return cut.strip_edges() + ".."


func _draw_text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
