class_name RosterScreen
extends Control
## All owned heroes + a detail panel with stats, traits, passives, training and promotion.

signal back_requested

var _grid: GridContainer
var _detail: VBoxContainer
var _sort: OptionButton
var _selected_id: String = ""
var _count_label: Label
var _status_msg: String = ""        # result of the last action on the sheet
var _sheet_tab: int = 0


func _ready() -> void:
	var margin := UIKit.margin(20)
	add_child(margin)
	UIKit.fill(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
	header.add_child(UIKit.label("Roster", 32, UIKit.ACCENT))
	_count_label = UIKit.label("", 16, UIKit.MUTED)
	header.add_child(_count_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UIKit.label("Sort:", 16, UIKit.MUTED))
	_sort = OptionButton.new()
	for s in ["Newest", "Stars", "Level", "Name"]:
		_sort.add_item(s)
	_sort.item_selected.connect(func(_i): _rebuild())
	header.add_child(_sort)
	root.add_child(header)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 5)  # px
	_grid.add_theme_constant_override("v_separation", 5)  # px
	left.add_child(_grid)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(372, 0)  # px: the tabbed hero sheet (paper doll + numbers)
	body.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_detail)

	Game.changed.connect(_rebuild)
	_rebuild()


func _sorted_heroes() -> Array:
	var list: Array = Game.heroes.values()
	match _sort.selected:
		1: list.sort_custom(func(a, b): return a.stars > b.stars or (a.stars == b.stars and a.level > b.level))
		2: list.sort_custom(func(a, b): return a.level > b.level or (a.level == b.level and a.stars > b.stars))
		3: list.sort_custom(func(a, b): return a.hero_name < b.hero_name)
		_: list.reverse()
	return list


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var list := _sorted_heroes()
	_count_label.text = "   %d heroes" % list.size()
	if _selected_id == "" or not Game.heroes.has(_selected_id):
		_selected_id = list[0].id if not list.is_empty() else ""
	for h in list:
		var card := HeroCard.new(h)
		card.selected = (h.id == _selected_id)
		card.card_pressed.connect(_on_card)
		_grid.add_child(card)
	_show_detail()


func _on_card(h: HeroData) -> void:
	_selected_id = h.id
	for c in _grid.get_children():
		(c as HeroCard).selected = ((c as HeroCard).hero.id == _selected_id)
	_show_detail()


func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected_id == "" or not Game.heroes.has(_selected_id):
		_detail.add_child(UIKit.label("No heroes yet.
Summon some first!", 20, UIKit.MUTED))
		return
	# D-063: the hero sheet in tabs (summary, skills, equipment, progression, profession, relations)
	var sheet := HeroSheet.new(Game.heroes[_selected_id], _sheet_tab)
	sheet._msg = _status_msg
	sheet.changed.connect(func():
		_status_msg = sheet._msg
		_sheet_tab = sheet._tab_index
		if not Game.heroes.has(_selected_id):
			_selected_id = ""                     # sacrificed: back to the list
		_show_detail())
	_detail.add_child(sheet)


func _wrapped(text: String, p_size: int, color: Color) -> Label:
	var l := UIKit.label(text, p_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(190, 0)  # px
	return l


func _ascend(h: HeroData) -> void:
	var r := Game.attempt_promotion(h)
	_status_msg = ("%s ascended to %d stars!" % [h.display_name(), h.stars]) if bool(r["ok"]) else ("The ascension failed (%d%% chance). Next try: %d%%." % [roundi(float(r["chance"]) * 100.0), roundi(Game.promotion_chance(h) * 100.0)])
	_rebuild()


func _train_skill(h: HeroData, sid: String) -> void:
	Game.train_skill(h, sid)
