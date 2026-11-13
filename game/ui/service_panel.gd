## ServicePanel — la ventana de los edificios de servicio de Albor (taberna, mercader, banco y gremio).
##
## Cada edificio tiene pestañas con filas (nombre, detalle y un boton). Es presentacion: toda la logica
## esta en `Services`, `Bounties` y `PlayerSim`; aqui solo se llaman y se vuelve a dibujar. Pausa la
## simulacion mientras esta abierto (Esc o "Cerrar" la cierran).
class_name ServicePanel
extends Control

const TABS := {
	"tavern": ["Comprar", "Cocinar", "Descansar"],
	"merchant": ["Equipo", "Pociones", "Vender"],
	"bank": ["Guardar", "Retirar"],
	"guild": ["Tablon", "Mis encargos", "Instructor"],
}
const TITLES := {"tavern": "TABERNA", "merchant": "MERCADER", "bank": "BANCO", "guild": "GREMIO"}
const ROW_H := 22.0

var world: CombatWorld
var session: GameSession
var station: String = ""
var tab: int = 0
var is_open: bool = false

var _was_paused: bool = false
var _tier: int = 1
var _stock: Array = []
var _stock_key: int = -1
var _message: String = ""
var _rumor_index: int = 0
var _body: Control
var _list: VBoxContainer


func bind(p_world: CombatWorld, p_session: GameSession) -> void:
	world = p_world
	session = p_session
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	session.service_opened.connect(open)


func open(p_station: String) -> void:
	if not TABS.has(p_station) or is_open:
		return
	station = p_station
	tab = 0
	_tier = 1
	_message = ""
	is_open = true
	visible = true
	_was_paused = TickManager.is_paused()
	TickManager.set_paused(true)
	_build()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	TickManager.set_paused(_was_paused)
	session.autosave()


func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- Construccion --------------------------------------------------------------------


func _build() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(shade)
	MenuKit.panel(_body, Rect2(36, 14, 568, 332), String(TITLES[station]))
	var player := world.player
	MenuKit.label(_body, "Oro: %d" % player.gold, Rect2(48, 34, 120, 12), 8, MenuKit.GOLD)
	var tabs: Array = TABS[station]
	for i: int in range(tabs.size()):
		var button := MenuKit.button(_body, String(tabs[i]), Rect2(150.0 + float(i) * 104.0, 30, 100, 18), func() -> void: _select(i))
		button.disabled = i == tab
	MenuKit.button(_body, "Cerrar", Rect2(540, 30, 56, 18), close)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(46, 56)
	scroll.size = Vector2(548, 256)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(540, 0)
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	MenuKit.label(_body, _message, Rect2(48, 318, 540, 22), 8, MenuKit.MUTED)
	match station:
		"tavern":
			_fill_tavern()
		"merchant":
			_fill_merchant()
		"bank":
			_fill_bank()
		"guild":
			_fill_guild()


func _select(index: int) -> void:
	tab = index
	_message = ""
	_build()


func _say(text: String) -> void:
	_message = text
	_build()


## Una fila: nombre (a color), detalle y un boton de accion.
func _row(name_text: String, detail: String, action: String, enabled: bool, callback: Callable, color: Color = MenuKit.TEXT) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(540, ROW_H)
	_list.add_child(row)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.18)
	back.size = Vector2(540, ROW_H - 1.0)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(back)
	MenuKit.label(row, name_text, Rect2(4, 2, 170, 10), 8, color)
	MenuKit.label(row, detail, Rect2(4, 11, 400, 10), 7, MenuKit.MUTED)
	if action != "":
		var button := MenuKit.button(row, action, Rect2(440, 2, 96, ROW_H - 5.0), callback)
		button.disabled = not enabled


func _note(text: String) -> void:
	var label := MenuKit.label(_list, text, Rect2(0, 0, 540, 14), 8, MenuKit.MUTED)
	label.custom_minimum_size = Vector2(540, 14)


# --- Taberna -------------------------------------------------------------------------


func _fill_tavern() -> void:
	var player := world.player
	match tab:
		0:
			for id: String in ConsumableCatalog.sold_ids():
				var spec := ConsumableCatalog.item(id)
				_row("%s  (tienes %d)" % [spec["name"], player.consumable_count(id)], String(spec["description"]), "%d oro" % int(spec["price"]), player.gold >= int(spec["price"]), func() -> void: _after(Services.buy_consumable(player, id), "Comprado: %s." % spec["name"]))
		1:
			var top := maxi(session.max_craft_tier(), 1)
			_row("Tier de los materiales: %d" % _tier, "Cocina con los materiales de ese tier (el tier mas alto abierto es %d)." % top, "Cambiar tier", top > 1, func() -> void: _tier = _tier % top + 1; _build())
			for id: String in ConsumableCatalog.cookable_ids():
				var spec := ConsumableCatalog.item(id)
				var cost := ConsumableCatalog.cook_cost(id, _tier)
				var parts: Array = []
				var has_all := true
				for material_id: String in cost:
					var parsed := MaterialCatalog.parse(material_id)
					parts.append("%s x%d (%d)" % [String(MaterialCatalog.kind(String(parsed["kind"]))["name"]), cost[material_id], player.material_count(material_id)])
					has_all = has_all and player.material_count(material_id) >= int(cost[material_id])
				var gold := int(spec["cook"]["gold"])
				_row("%s  (tienes %d)" % [spec["name"], player.consumable_count(id)], "%s + %d oro" % [", ".join(parts), gold], "Cocinar", has_all and player.gold >= gold, func() -> void: _after(Services.cook(player, id, _tier), "Cocinado: %s." % spec["name"]))
		2:
			_note("Ottis te ofrece una cama y una comida caliente: curas toda la vida y el recurso, y quedas bien alimentado 10 minutos.")
			_row("Descansar", "Cuesta %d de oro. Es lo unico que hace la taberna que no hacen los demas: curar sin pociones." % Services.REST_COST, "%d oro" % Services.REST_COST, player.gold >= Services.REST_COST, _rest)


func _rest() -> void:
	var result := Services.rest(world.player, _rumor_index, session.tower.flags.keys())
	if bool(result["ok"]):
		_rumor_index += 1
		_say(String(result["rumor"]))
	else:
		_say("No te alcanza el oro.")


# --- Mercader ------------------------------------------------------------------------


func _fill_merchant() -> void:
	var player := world.player
	match tab:
		0:
			var key := session.tower.completed_count()
			if key != _stock_key:
				_stock = Services.merchant_stock(session.tower.world_seed, key, maxi(session.max_craft_tier(), 1))
				_stock_key = key
			_note("Las existencias cambian cada vez que completas un piso nuevo.")
			for index: int in range(_stock.size()):
				var entry: Dictionary = _stock[index]
				var piece: Dictionary = entry["item"]
				var color := ItemCatalog.rarity_color(String(piece["rarity"]))
				var detail := "%s - %s" % [ItemCatalog.slot_name(String(ItemCatalog.item(String(piece["id"]))["slot"])), _stats_text(piece)]
				_row(ItemCatalog.display_name(piece) if not bool(entry["sold"]) else "(vendido)", detail, "%d oro" % int(entry["price"]), not bool(entry["sold"]) and player.gold >= int(entry["price"]), func() -> void: _after(Services.buy_stock(player, _stock, index), "Comprado."), color)
		1:
			for id: String in ConsumableCatalog.sold_ids():
				var spec := ConsumableCatalog.item(id)
				if String(spec["kind"]) != "potion":
					continue
				_row("%s  (tienes %d)" % [spec["name"], player.consumable_count(id)], String(spec["description"]), "%d oro" % int(spec["price"]), player.gold >= int(spec["price"]), func() -> void: _after(Services.buy_consumable(player, id), "Comprado: %s." % spec["name"]))
			_note("La comida y las pociones mayores se consiguen en la taberna.")
		2:
			if player.bag.is_empty():
				_note("La mochila esta vacia.")
			for index: int in range(player.bag.size()):
				var piece: Dictionary = player.bag[index]
				_row(ItemCatalog.display_name(piece), _stats_text(piece), "Vender %d" % ItemCatalog.sell_value(piece), true, func() -> void: _sell(index), ItemCatalog.rarity_color(String(piece["rarity"])))


func _sell(index: int) -> void:
	var value := world.player.sell_from_bag(index)
	_say("Vendido por %d de oro." % value if value >= 0 else "Solo se vende en zona segura.")


# --- Banco ---------------------------------------------------------------------------


func _fill_bank() -> void:
	var player := world.player
	_note("Alijo: %d / %d items." % [player.bank.size(), PlayerSim.BANK_SIZE])
	if tab == 0:
		if player.bag.is_empty():
			_note("La mochila esta vacia.")
		for index: int in range(player.bag.size()):
			var piece: Dictionary = player.bag[index]
			_row(ItemCatalog.display_name(piece), _stats_text(piece), "Guardar", player.bank.size() < PlayerSim.BANK_SIZE, func() -> void: _after(Services.bank_deposit(player, index), "Guardado."), ItemCatalog.rarity_color(String(piece["rarity"])))
	else:
		if player.bank.is_empty():
			_note("El alijo esta vacio.")
		for index: int in range(player.bank.size()):
			var piece: Dictionary = player.bank[index]
			_row(ItemCatalog.display_name(piece), _stats_text(piece), "Retirar", player.bag_has_room(), func() -> void: _after(Services.bank_withdraw(player, index), "Retirado."), ItemCatalog.rarity_color(String(piece["rarity"])))


# --- Gremio --------------------------------------------------------------------------


func _fill_guild() -> void:
	var player := world.player
	match tab:
		0:
			_note("Encargos aceptados: %d / %d. Cobrar uno renueva el tablon." % [player.bounties.size(), Bounties.max_active()])
			var offers := Bounties.offers(session.tower.world_seed, player.bounty_serial, maxi(session.max_craft_tier(), 1))
			for offer: Dictionary in offers:
				var taken := false
				for bounty: Dictionary in player.bounties:
					taken = taken or String(bounty["template"]) == String(offer["template"])
				_row(String(offer["name"]), "%s  Recompensa: %d oro, %d XP%s" % [offer["text"], offer["gold"], offer["xp"], " + " + String(ConsumableCatalog.item(String(offer["consumable"])).get("name", "")) if String(offer["consumable"]) != "" else ""], "Aceptado" if taken else "Aceptar", not taken and player.bounties.size() < Bounties.max_active(), func() -> void:
					Bounties.accept(player, offer)
					session.autosave()
					_say("Encargo aceptado: %s." % offer["name"]))
		1:
			if player.bounties.is_empty():
				_note("No tienes encargos. Acepta alguno en el tablon.")
			for index: int in range(player.bounties.size()):
				var bounty: Dictionary = player.bounties[index]
				var done := int(bounty["progress"]) >= int(bounty["count"])
				_row("%s  [%d/%d]" % [bounty["name"], bounty["progress"], bounty["count"]], "%s  Recompensa: %d oro, %d XP" % [bounty["text"], bounty["gold"], bounty["xp"]], "Cobrar" if done else "En curso", done, func() -> void:
					Bounties.turn_in(player, index)
					session.autosave()
					_say("Encargo cobrado. El tablon se ha renovado."), MenuKit.GOLD if done else MenuKit.TEXT)
		2:
			var offers := Services.trainer_offers(player)
			_note("Dara ensena habilidades de mundo a tu clase. Se equipan en el libro de skills (Tab).")
			if offers.is_empty():
				_note("Ya conoces todo lo que puede ensenarte.")
			for offer: Dictionary in offers:
				var skill := SkillCatalog.skill(StringName(String(offer["id"])))
				_row("%s  (nivel %d)" % [offer["name"], offer["level"]], String(skill.get("description", "")), "%d oro" % int(offer["price"]), player.gold >= int(offer["price"]), func() -> void: _after(Services.learn_skill(player, String(offer["id"])), "Aprendida: %s." % offer["name"]))


# --- Utilidades ----------------------------------------------------------------------


func _after(result: Dictionary, success: String) -> void:
	if bool(result["ok"]):
		session.autosave()
		_say(success)
		return
	var reasons := {"gold": "No te alcanza el oro.", "full": "Ya no te caben mas.", "bag": "La mochila esta llena.", "materials": "Te faltan materiales.", "known": "Ya la conoces.", "unknown": "No se puede."}
	_say(String(reasons.get(String(result["reason"]), "No se puede.")))


func _stats_text(piece: Dictionary) -> String:
	var parts: Array = []
	for stat: String in piece["stats"]:
		parts.append("%s %s" % [stat.replace("_bonus", "").replace("_", " "), str(snappedf(float(piece["stats"][stat]), 0.1))])
	return "T%d  %s" % [int(piece["tier"]), ", ".join(parts)]
