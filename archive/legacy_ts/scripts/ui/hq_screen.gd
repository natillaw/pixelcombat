class_name HQScreen
extends Control
## Living Headquarters screen: manage facility assignments, view resource outputs, and process HQ turns.

signal back_requested
signal explore_requested

var _res_label: Label
var _status_label: Label
var _facility_container: VBoxContainer
var _roster_container: VBoxContainer
var _selected_hero_id: String = ""


func _ready() -> void:
	var margin := UIKit.margin(20)
	add_child(margin)
	UIKit.fill(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_child(UIKit.button("< Back", func(): back_requested.emit(), Vector2(110, 40)))
	header.add_child(UIKit.label("Living Headquarters", 32, UIKit.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_res_label = UIKit.label("", 18, UIKit.ACCENT)
	header.add_child(_res_label)
	header.add_child(UIKit.button("To the town", func(): explore_requested.emit(), Vector2(130, 40)))
	# owner 2026-11-02: no "pass a day" button (skipping time while crafting or building is cheating)
	root.add_child(header)

	_status_label = UIKit.label("Assign heroes to facilities based on their past-life occupations to generate resources and build relationships.", 15, UIKit.MUTED)
	root.add_child(_status_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)  # px
	root.add_child(body)

	# Left: Facilities
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(250, 0)  # px
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_panel)
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(lscroll)
	_facility_container = VBoxContainer.new()
	_facility_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_container.add_theme_constant_override("separation", 8)  # px
	lscroll.add_child(_facility_container)

	# Right: Unassigned / All Roster
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(rscroll)
	_roster_container = VBoxContainer.new()
	_roster_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_container.add_theme_constant_override("separation", 5)  # px
	rscroll.add_child(_roster_container)

	Game.changed.connect(_rebuild)
	_rebuild()


func _refresh_res() -> void:
	_res_label.text = "Food: %d   |   Materials: %d   |   Medicine: %d" % [
		Game.hq_outputs.get("food", 0),
		Game.hq_outputs.get("materials", 0),
		Game.hq_outputs.get("medicine", 0)
	]


func _rebuild() -> void:
	_refresh_res()
	for c in _facility_container.get_children():
		c.queue_free()
	for c in _roster_container.get_children():
		c.queue_free()

	# every built workplace (TownTables) + the construction crew (D-048); same data as the town panels
	var facilities: Array = [{"id": "construction", "name": "Construction crew", "desc": "Builders raise and upgrade buildings (needs the Builder profession)."}]
	for bid in TownTables.ids():
		if TownTables.worker_slots(bid, Game.building_level(bid)) > 0:
			facilities.append({"id": bid, "name": "%s (%d/%d)" % [TownTables.info(bid)["name"], Game.workers_at(bid).size(), TownTables.worker_slots(bid, Game.building_level(bid))],
				"desc": "Needs: %s. %s" % [ProfessionDefs.info(Game.workplace_prof(bid)).get("name", "-"), TownTables.info(bid)["desc"]]})

	for fac in facilities:
		var fid: String = fac["id"]
		var fbox := VBoxContainer.new()
		fbox.add_child(UIKit.label(fac["name"], 20, UIKit.TEXT))
		fbox.add_child(UIKit.label(fac["desc"], 13, UIKit.MUTED))

		var workers := VBoxContainer.new()
		var has_workers := false
		for id in Game.heroes:
			var h: HeroData = Game.heroes[id]
			if h.hq_assignment == fid:
				has_workers = true
				var row := HBoxContainer.new()
				var prof := Game.workplace_prof(fid)
				var name_lbl := UIKit.label("• %s (%s Lv %d, %s)" % [h.display_name(), ProfessionDefs.info(prof).get("name", prof), h.prof_level(prof), h.activity_state], 15, UIKit.ACCENT)
				row.add_child(name_lbl)
				var sp := Control.new()
				sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(sp)
				var unassign_btn := UIKit.button("Remove", func(): Game.unassign_hq(h.id), Vector2(90, 30))
				row.add_child(unassign_btn)
				workers.add_child(row)
		if not has_workers:
			workers.add_child(UIKit.label("(No heroes assigned)", 14, UIKit.MUTED))
		fbox.add_child(workers)

		# Facility target button for selected hero
		var assign_here := UIKit.button("Assign Selected Here", func(): 
			if _selected_hero_id != "" and Game.heroes.has(_selected_hero_id):
				var why := Game.assign_work(Game.heroes[_selected_hero_id], fid)
				_status_label.text = ("Assigned." if why == "" else "Cannot assign: " + why)
				_rebuild()
		, Vector2(180, 35))
		fbox.add_child(assign_here)

		var sep := HSeparator.new()
		fbox.add_child(sep)
		_facility_container.add_child(fbox)

	# Roster list for assignment
	_roster_container.add_child(UIKit.label("Roster (Click to select, then assign to a facility above)", 16, UIKit.ACCENT))
	for id in Game.heroes:
		var h: HeroData = Game.heroes[id]
		var hbox := HBoxContainer.new()
		var sel_prefix := "[SELECTED] " if h.id == _selected_hero_id else ""
		var hlbl := UIKit.label("%s%s (%s) — HQ: %s" % [sel_prefix, h.display_name(), h.profession if h.profession != "" else "Citizen", h.hq_assignment if h.hq_assignment != "" else "Idle"], 15, UIKit.TEXT)
		hbox.add_child(hlbl)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(sp)
		var select_btn := UIKit.button("Select", func(): 
			_selected_hero_id = h.id
			_rebuild()
		, Vector2(80, 32))
		hbox.add_child(select_btn)
		_roster_container.add_child(hbox)


func _on_process_turn() -> void:
	var summary: Dictionary = Game.process_headquarters_turn()
	var parts: Array = []
	for k in summary:
		if String(k).ends_with("_produced"):
			parts.append("+%d %s" % [int(summary[k]), String(k).trim_suffix("_produced")])
	_status_label.text = "A day passed (%s). Produced: %s. Events: %d (see the Summoner's Hall log)." % [Game.town_time_text(), ", ".join(parts) if not parts.is_empty() else "nothing", int(summary.get("events", 0))]
	_rebuild()
