class_name ExpeditionHud
extends Control
## Expedition HUD at the 640x360 base (D-063). Reads the SandboxScreen every frame; every click calls
## the same public commands the keys use (select_slot, attack_at_cursor, use_skill_selected, orders).
##   top-left: menu + floor + objective      top-centre: boss bar      top-right: minimap + camera
##   bottom-left: party (5 kit portrait slots, HP, resource, statuses, social of the focused hero)
##   bottom-centre: Q attack + W E R skills (icon, cooldown, cost, key)   bottom-right: orders (kit icons)
## Nothing is told by colour alone: every icon has a tooltip and numbers/text go with the bars.

const SLOT := 36                      # kit portrait slot (interior 30x30 at 3,3)
const SKILL := 26
const SKILL_ICON_PX := 32             # KURAI sheet cell (drawn at x0.5 inside the slot? no: cropped 24 px)

var sb: SandboxScreen
var _party: Array = []                # [{"slot": TextureButton-like Control, ...}] per hero
var _skills: Array = []               # 4 Controls: Q, W, E, R
var _commands: Array = []             # D-081: 3 Buttons, Master commands (keys 1 2 3)
var _objective: Label
var _floor: Label
var _order_label: Label
var _social: HBoxContainer
var _boss: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _minimap: Minimap
var _details: PanelContainer
var _skill_tex: Texture2D
var _frames: PartyFrames = null        # D-111: WoW-style party frames on the left edge
var _boss_smooth: PartyFrames.SmoothBar = null
var _corners: Dictionary = {}          # "bl" / "bc" / "br" / "tr" -> PanelContainer, placed from their real size


func _init(screen: SandboxScreen = null) -> void:
    sb = screen
    mouse_filter = Control.MOUSE_FILTER_IGNORE


## D-082b: height of the HUD band at the bottom (the camera frames the Master above it).
func bottom_inset() -> float:
    var h := 0.0
    for k in ["bl", "bc", "br"]:
        if _corners.has(k):
            var pc: Control = _corners[k]
            if pc.visible:
                h = maxf(h, size.y - pc.position.y)
    return h


func _ready() -> void:
    UIKit.fill(self)
    _skill_tex = load(AssetCatalog.SKILL_ICONS) if ResourceLoader.exists(AssetCatalog.SKILL_ICONS) else null
    _build_top_left()
    _build_boss()
    _build_minimap()
    _build_party()
    _build_skills()
    _build_orders()


# --- top-left: menu, floor, objective ----------------------------------------------------------

func _build_top_left() -> void:
    var pc := PanelContainer.new()
    pc.position = Vector2(4, 4)
    pc.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(pc)
    var hb := HBoxContainer.new()
    pc.add_child(hb)
    var menu := UIKit.icon_button(AssetCatalog.icon("order_retreat"), "Menu (Esc)", func(): sb.open_menu())
    hb.add_child(menu)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 0)
    hb.add_child(vb)
    _floor = UIKit.label("", 20, UIKit.ACCENT)
    vb.add_child(_floor)
    _objective = UIKit.label("", 14, UIKit.TEXT)
    vb.add_child(_objective)
    if Game.hardcore:                                    # D-081: hardcore game, always visible
        hb.add_child(UIKit.icon(MasterDefs.HARDCORE_ICON, "Hardcore: if your Master dies, the game ends"))


# --- top-centre: boss -----------------------------------------------------------------------------

func _build_boss() -> void:
    _boss = PanelContainer.new()
    _boss.visible = false
    _boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_boss)
    _boss.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _boss.position = Vector2(220, 4)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 1)
    _boss.add_child(vb)
    _boss_name = UIKit.label("", 20, ArtPalette.RARITY["mythic"])
    _boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(_boss_name)
    _boss_bar = ProgressBar.new()
    _boss_bar.show_percentage = false
    _boss_bar.custom_minimum_size = Vector2(190, 6)
    _boss_bar.add_theme_stylebox_override("fill", UIKit.box(ArtPalette.HP, Color(0, 0, 0, 0), 0, 0, 0))
    _boss_bar.visible = false                            # D-111: kept for callers; the smooth bar is drawn
    vb.add_child(_boss_bar)
    _boss_smooth = PartyFrames.SmoothBar.new(Vector2(190, 6), true)
    vb.add_child(_boss_smooth)


# --- top-right: minimap ---------------------------------------------------------------------------

func _build_minimap() -> void:
    var pc := PanelContainer.new()
    add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    pc.position = Vector2(-4, 4)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    pc.add_child(vb)
    _corners["tr"] = pc
    _minimap = Minimap.new(sb)
    vb.add_child(_minimap)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 2)
    vb.add_child(hb)
    hb.add_child(UIKit.icon_button(AssetCatalog.icon("order_follow"), "Squad view (Tab)", func():
        sb.overview = false
        sb.group_view()))
    hb.add_child(UIKit.icon_button(AssetCatalog.icon("order_explore"), "Whole map (M): the fog stays", func(): sb.overview = not sb.overview))
    hb.add_child(UIKit.icon_button(AssetCatalog.icon("order_interact"), "Details (I)", func(): toggle_details()))
    pc.position.x = -pc.size.x - 4


# --- bottom-left: party -----------------------------------------------------------------------------

func _build_party() -> void:
    var pc := PanelContainer.new()
    add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _corners["bl"] = pc
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    pc.add_child(vb)
    _social = HBoxContainer.new()
    _social.add_theme_constant_override("separation", 2)
    vb.add_child(_social)
    # D-111: the party is a column of frames down the left edge (PartyFrames); PartyCell stays for tests
    _frames = PartyFrames.new(sb)
    add_child(_frames)
    _frames.position = Vector2(4, 58)                 # below the mission header (it overlapped it)
    _order_label = UIKit.label("", 12, UIKit.MUTED)
    vb.add_child(_order_label)


# --- bottom-centre: skills ------------------------------------------------------------------------

func _build_skills() -> void:
    var pc := PanelContainer.new()
    add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
    pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _corners["bc"] = pc
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 3)
    pc.add_child(hb)
    for i in 4:
        var cell := SkillCell.new(sb, i - 1, _skill_tex)          # -1 = Q basic attack, 0..2 = W E R
        hb.add_child(cell)
        _skills.append(cell)
    if sb != null and sb.master_hero != null:             # D-081: the Master's commands, apart from the skills
        hb.add_child(VSeparator.new())
        for i in MasterDefs.COMMAND_KEYS.size():
            var slot := i
            var b := UIKit.button("", func(): sb.use_command(slot), Vector2(SKILL + 12, SKILL))
            b.focus_mode = Control.FOCUS_NONE
            hb.add_child(b)
            _commands.append(b)


# --- bottom-right: orders -----------------------------------------------------------------------------

func _build_orders() -> void:
    var pc := PanelContainer.new()
    add_child(pc)
    pc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
    pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _corners["br"] = pc
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    pc.add_child(grid)
    var orders := [
        ["order_attack_move", "Attack here (A, then click) · Shift+click: quick ping · hold: ping wheel", func(): sb.squad_key(KEY_A)],
        ["order_hold", "Defend this area (H)", func(): sb.squad_key(KEY_H)],
        ["order_follow", "Follow (V)", func(): sb.squad_key(KEY_V)],
        ["order_move", "Regroup (C)", func(): sb.squad_key(KEY_C)],
        ["order_invalid", "Stop: everyone back to their own judgement (S)", func(): sb.squad_key(KEY_S)],
        ["order_retreat", "Retreat to the exit (X)", func(): sb.squad_key(KEY_X)],
        ["order_explore", "Extract: escape with what you carry (all standing heroes at the exit)", func(): sb.extract()],
        ["order_attack", "Attack at the mouse (Q) with the hero you drive", func(): sb.attack_at_cursor()],
    ]
    for o in orders:
        grid.add_child(UIKit.icon_button(AssetCatalog.icon(String(o[0])), String(o[1]), o[2]))


func toggle_details() -> void:
    if _details == null:
        _details = PanelContainer.new()
        add_child(_details)
        _details.position = Vector2(4, 48)
        var vb := VBoxContainer.new()
        _details.add_child(vb)
        sb._info.get_parent().remove_child(sb._info) if sb._info.get_parent() != null else null
        vb.add_child(sb._info)
        if sb._squad_label.get_parent() != null:
            sb._squad_label.get_parent().remove_child(sb._squad_label)
        vb.add_child(sb._squad_label)
        return
    _details.visible = not _details.visible


## Corner panels are placed from their real (content) size every frame: no anchor guesswork.
func _place() -> void:
    var view := size
    for k in _corners:
        var pc: Control = _corners[k]
        pc.size = pc.get_combined_minimum_size()
        match k:
            "bl":
                pc.position = Vector2(4, view.y - pc.size.y - 4)
            "bc":
                pc.position = Vector2(floorf((view.x - pc.size.x) * 0.5), view.y - pc.size.y - 4)
            "br":
                pc.position = Vector2(view.x - pc.size.x - 4, view.y - pc.size.y - 4)
            "tr":
                pc.position = Vector2(view.x - pc.size.x - 4, 4)
    if _boss != null:
        _boss.size = _boss.get_combined_minimum_size()
        _boss.position = Vector2(floorf((view.x - _boss.size.x) * 0.5), 4)


func _process(_delta: float) -> void:
    if sb == null or not is_instance_valid(sb):
        return
    _place()
    if sb.floor_number < 0:
        _floor.text = String(TowerExpedition.get_floor_config(sb.floor_number)["name"])
    else:
        _floor.text = StringsEs.tx(sb.mission_title() if sb.floor_number <= 0 else "Floor %d · %s" % [sb.floor_number, sb.mission_title()])
    _objective.text = sb._objective_text()
    var focus: SandboxHero = sb.controlled()
    if focus == null and not sb.selected.is_empty():
        focus = sb.selected[0]                   # squad view: the first selected hero's actions
    for c in _party:
        (c as PartyCell).refresh()
    if _frames != null:
        _frames.refresh()
    for c in _skills:
        (c as SkillCell).refresh(focus)
    _refresh_commands()
    _refresh_social(focus)
    _order_label.text = ("%s · %s" % [focus.hero.hero_name.split(" ")[0], focus.order_label()]) if focus != null else "Squad: %d selected" % sb.selected.size()
    var boss := sb.boss
    _boss.visible = boss != null and is_instance_valid(boss) and boss.alive and boss.visible
    if _boss.visible:
        _boss_name.text = boss.enemy_name
        _boss_bar.max_value = boss.max_hp
        _boss_bar.value = boss.hp
        _boss_smooth.set_value(float(boss.hp), float(boss.max_hp))
    _minimap.queue_redraw()


## D-081: key, then cooldown seconds or the level that unlocks it; the tooltip says what it does.
func _refresh_commands() -> void:
    if _commands.is_empty():
        return
    var m: HeroData = sb.master_hero.hero
    var known := MasterRules.commands(m)
    for i in _commands.size():
        var b: Button = _commands[i]
        var id := ""
        for cid in MasterDefs.COMMANDS:
            if int(MasterDefs.COMMANDS[cid]["slot"]) == i:
                id = String(cid)
        if id == "":
            b.visible = false
            continue
        var c: Dictionary = MasterDefs.COMMANDS[id]
        var cd := float(sb.command_cd.get(id, 0.0))
        var key := OS.get_keycode_string(MasterDefs.COMMAND_KEYS[i])
        if not known.has(id):
            b.text = "%s %s%d" % [key, tr("Lv"), int(c["unlock_level"])]
            b.disabled = true
        else:
            b.text = key if cd <= 0.0 else "%s %d" % [key, ceili(cd)]
            b.disabled = cd > 0.0 or not sb.master_hero.alive
        b.tooltip_text = "%s (%s)\n%s" % [tr(String(c["name"])), key, tr(String(c["desc"]))]


func _refresh_social(h: SandboxHero) -> void:
    for c in _social.get_children():
        c.queue_free()
    if h == null or h.hero == null:
        return
    var d := h.hero
    for s in [["social_trust", "Trust", d.trust], ["social_obedience", "Obedience", d.obedience], ["social_composure", "Composure", d.composure]]:
        _social.add_child(UIKit.icon(AssetCatalog.icon(String(s[0])), "%s %d / 100" % [String(s[1]), int(s[2])]))
        _social.add_child(UIKit.label(str(int(s[2])), 12, UIKit.TEXT))
    if not h.obeys():
        _social.add_child(UIKit.label("won't obey", 12, UIKit.BAD))


## One party member: kit portrait slot (normal / focused / dead) with the hero's head, HP and resource
## bars, and small status marks (each with a tooltip). Click = drive this hero (D-053).
class PartyCell extends Control:
    var sb: SandboxScreen
    var index: int
    var _frame: TextureRect
    var _face: TextureRect
    var _hp: ProgressBar
    var _res: ProgressBar
    var _marks: HBoxContainer
    var _down: Label
    var _state: String = ""

    func _init(screen: SandboxScreen, i: int) -> void:
        sb = screen
        index = i
        custom_minimum_size = Vector2(ExpeditionHud.SLOT, ExpeditionHud.SLOT + 12)

    func _ready() -> void:
        var h: SandboxHero = sb.heroes[index]
        _face = TextureRect.new()
        _face.position = Vector2(3, 3)
        _face.size = Vector2(30, 30)
        _face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _face.stretch_mode = TextureRect.STRETCH_SCALE      # 15 px head drawn at x2 (whole pixels)
        var full := SpriteComposer.pose_texture(h.hero) if h.hero != null else null
        if full != null:
            var at := AtlasTexture.new()
            at.atlas = full
            at.region = SpriteComposer.face_region(h.hero)   # the head (LPC 64 px / TPF 48 px frame)
            _face.texture = at
        add_child(_face)
        _frame = TextureRect.new()
        _frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_frame)
        _hp = _bar(ArtPalette.HP, 38)
        _res = _bar(SkillDefs.RESOURCES[h.res_kind]["color"], 43)
        _marks = HBoxContainer.new()
        _marks.position = Vector2(2, 2)
        _marks.add_theme_constant_override("separation", 1)
        add_child(_marks)
        _down = UIKit.label("", 11, UIKit.BAD)          # D-082: agony left (m:ss) on a downed hero's portrait
        _down.position = Vector2(2, ExpeditionHud.SLOT * 0.4)
        _down.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_down)
        tooltip_text = "%d · %s" % [index + 1, h.hero.display_name()]
        mouse_filter = Control.MOUSE_FILTER_STOP
        refresh()

    func _bar(col: Color, y: int) -> ProgressBar:
        var p := ProgressBar.new()
        p.show_percentage = false
        p.position = Vector2(1, y)
        p.size = Vector2(ExpeditionHud.SLOT - 2, 4)
        p.custom_minimum_size = Vector2(ExpeditionHud.SLOT - 2, 4)
        p.add_theme_stylebox_override("fill", UIKit.box(col, Color(0, 0, 0, 0), 0, 0, 0))
        p.add_theme_stylebox_override("background", UIKit.box(ArtPalette.INK, ArtPalette.OUTLINE, 1, 0, 0))
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(p)
        return p

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            sb.select_slot(index)                # D-082: in a Master squad, picks who the next ping is for
            UIKit.sound("click")
            accept_event()

    func refresh() -> void:
        var h: SandboxHero = sb.heroes[index]
        var state := "dead" if (h.dead or h.downed) else ("focused" if h.is_controlled() or (sb.follow_slot == index) else "normal")
        if state != _state:
            _state = state
            var n := clampi(index + 1, 1, 5)
            _frame.texture = load(AssetCatalog.KIT + "ui/portrait_slot_%d_%s.png" % [n, state])
            _face.modulate = Color(0.45, 0.45, 0.5) if state == "dead" else Color.WHITE
        _hp.max_value = maxf(1.0, h.max_hp)
        _hp.value = h.hp
        _res.max_value = maxf(1.0, h.res_max)
        _res.value = h.res
        var tip := "%d · %s\nHP %d/%d  %s %d/%d\n%s" % [index + 1, h.hero.display_name(), h.hp, h.max_hp,
            String(SkillDefs.RESOURCES[h.res_kind]["name"]), roundi(h.res), roundi(h.res_max), h.order_label()]
        if h.downed:
            tip += "\nDOWN %ds: right-click to rescue" % ceili(h.agony)
        elif h.dead:
            tip += "\nFALLEN"
        if h.carrying:
            tip += "\nCarries the relic"
        tooltip_text = tip
        if _marks.get_child_count() != h.statuses.size():
            for c in _marks.get_children():
                c.queue_free()
            for id in h.statuses:
                var r := ColorRect.new()
                r.custom_minimum_size = Vector2(4, 4)
                r.color = CombatRules.STATUS[id]["color"]
                r.tooltip_text = String(CombatRules.STATUS[id]["name"])
                _marks.add_child(r)


## One action slot: Q = basic attack (slot -1), W E R = skills 0..2. Icon, key, cooldown shade with
## seconds, cost; greyed when the hero lacks the resource. Hover shows the reach (SkillAimView).
class SkillCell extends Control:
    var sb: SandboxScreen
    var slot: int
    var sheet: Texture2D
    var _hero: SandboxHero = null
    var _icon: TextureRect
    var _key: Label
    var _cd: ColorRect
    var _cd_text: Label
    var _cost: Label
    var _skill_id: String = "?"

    func _init(screen: SandboxScreen, p_slot: int, p_sheet: Texture2D) -> void:
        sb = screen
        slot = p_slot
        sheet = p_sheet
        custom_minimum_size = Vector2(ExpeditionHud.SKILL, ExpeditionHud.SKILL)
        mouse_filter = Control.MOUSE_FILTER_STOP

    func _ready() -> void:
        var bg := TextureRect.new()
        bg.texture = load(AssetCatalog.UI["dragon_slot"][0])
        var at := AtlasTexture.new()
        if bg.texture != null:
            at.atlas = bg.texture
            at.region = Rect2(0, 0, 32, 32)
            bg.texture = at
        bg.size = Vector2(ExpeditionHud.SKILL, ExpeditionHud.SKILL)
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_SCALE
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bg)
        _icon = TextureRect.new()
        _icon.position = Vector2(5, 5)
        _icon.size = Vector2(16, 16)
        _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        _icon.stretch_mode = TextureRect.STRETCH_SCALE
        _icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_icon)
        _cd = ColorRect.new()
        _cd.color = Color(ArtPalette.INK, 0.7)
        _cd.position = Vector2(3, 3)
        _cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(_cd)
        _cd_text = UIKit.label("", 12, UIKit.TEXT)
        _cd_text.position = Vector2(6, 4)
        add_child(_cd_text)
        _key = UIKit.label("Q" if slot < 0 else SandboxScreen.SKILL_KEYS[slot], 12, UIKit.ACCENT)
        _key.position = Vector2(1, -5)
        _key.add_theme_constant_override("outline_size", 2)
        add_child(_key)
        _cost = UIKit.label("", 12, ArtPalette.MANA)
        _cost.position = Vector2(14, 12)
        _cost.add_theme_constant_override("outline_size", 2)
        add_child(_cost)
        mouse_entered.connect(func():
            if slot >= 0:
                sb.preview_skill(slot))
        mouse_exited.connect(func(): sb.preview_skill(-1))

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            if slot < 0:
                sb.attack_at_cursor()
            else:
                sb.use_skill_selected(slot)
            accept_event()

    func _icon_for(id: String) -> Texture2D:
        if id == "":
            return null
        if id == "__attack":
            return load(AssetCatalog.icon("order_attack"))
        if sheet == null:
            return null
        var idx := SkillIcons.index_of(id)
        var at := AtlasTexture.new()
        at.atlas = sheet
        at.region = Rect2((idx % 8) * 32, (idx / 8) * 32, 32, 32)
        return at

    func refresh(h: SandboxHero) -> void:
        _hero = h
        var id := ""
        var frac := 0.0
        var secs := 0.0
        var cost := ""
        var usable := true
        var tip := ""
        if h != null and h.alive:
            if slot < 0:
                id = "__attack"
                var iv := h.attack_interval()
                secs = maxf(0.0, h._cooldown)
                frac = clampf(secs / maxf(0.01, iv), 0.0, 1.0)
                tip = "Q · Basic attack at the mouse\n%s, reach %d px, every %.1fs" % ["ranged" if h.is_ranged() else "melee", int(h.attack_range()), iv]
                usable = h.is_controlled()
                if not usable:
                    tip += "\n(drive this hero with 1-5 to aim it)"
            elif slot < h.slots.size():
                id = String(h.slots[slot])
                var sk := h.slot_skill(slot)
                secs = h.skill_cd(slot)
                frac = clampf(secs / maxf(0.01, float(sk["cd"])), 0.0, 1.0)
                cost = str(int(sk["cost"]))
                usable = h.res >= float(sk["cost"])
                tip = "%s · %s\n%s\nCost %d %s · cooldown %.0fs · reach %d%s" % [SandboxScreen.SKILL_KEYS[slot], String(sk["name"]), String(sk.get("desc", "")),
                    int(sk["cost"]), String(SkillDefs.RESOURCES[h.res_kind]["name"]).to_lower(), float(sk["cd"]), int(sk["range"]),
                    "" if usable else "\nNot enough " + String(SkillDefs.RESOURCES[h.res_kind]["name"]).to_lower()]
        if id != _skill_id:
            _skill_id = id
            _icon.texture = _icon_for(id)
        _icon.modulate = Color.WHITE if usable else Color(0.5, 0.5, 0.6)
        _cd.size = Vector2(ExpeditionHud.SKILL - 6, (ExpeditionHud.SKILL - 6) * frac)
        _cd.visible = frac > 0.0
        _cd_text.text = ("%d" % ceili(secs)) if secs >= 1.0 else ""
        _cost.text = cost
        tooltip_text = tip if tip != "" else ("Q · basic attack" if slot < 0 else "%s · empty skill slot" % SandboxScreen.SKILL_KEYS[slot])


## Minimap: the fog of war image (1 pixel per cell, never more than the heroes saw), heroes as dots
## (the driven one brighter), enemies the squad can see, the exit. Click = look there (camera only).
class Minimap extends Control:
    var sb: SandboxScreen
    const MAX := Vector2(96, 72)

    func _init(screen: SandboxScreen) -> void:
        sb = screen
        mouse_filter = Control.MOUSE_FILTER_STOP
        tooltip_text = "Map: what the squad has explored (click to look there)"

    func _ready() -> void:
        custom_minimum_size = _size()

    func _scale() -> float:
        if sb.map == null:
            return 1.0
        return minf(1.0, minf(MAX.x / float(sb.map.width), MAX.y / float(sb.map.height)))

    func _size() -> Vector2:
        if sb.map == null:
            return MAX
        return (Vector2(sb.map.width, sb.map.height) * _scale()).floor()

    func _cell_pos(world: Vector2) -> Vector2:
        return world / float(NavMap.CELL) * _scale()

    var _terrain: ImageTexture = null

    static func terrain_texture(m: NavMap) -> ImageTexture:
        var img := Image.create(maxi(1, m.width), maxi(1, m.height), false, Image.FORMAT_RGBA8)
        img.fill(ArtPalette.GREEN[1])
        for y in m.height:
            for x in m.width:
                if m.is_blocked_cell(Vector2i(x, y)):
                    img.set_pixel(x, y, ArtPalette.GREEN[0])
        return ImageTexture.create_from_image(img)

    func _draw() -> void:
        if sb.map == null:
            return
        var r := Rect2(Vector2.ZERO, _size())
        # B3: the terrain is one image made once (1 pixel per cell); the opaque fog image on top hides
        # what was never explored, so nothing is looped per cell per frame (was ~6.6 ms on floor 5).
        if _terrain == null:
            _terrain = terrain_texture(sb.map)
        draw_texture_rect(_terrain, r, false)
        if sb._fog_view != null and sb._fog_view._tex != null:
            draw_texture_rect(sb._fog_view._tex, r, false)
        var ex := _cell_pos(sb.map.center_of(sb.map.extract_cell))
        draw_rect(Rect2(ex - Vector2(2, 2), Vector2(4, 4)), ArtPalette.BLUE[3])
        for e in sb.enemies:
            if e.alive and e.visible:
                draw_rect(Rect2(_cell_pos(e.position) - Vector2(1, 1), Vector2(2, 2)), ArtPalette.RED[2])
        for e in sb.revealed_enemies():          # B6: the last creatures of a "clear the floor" mission
            if not e.visible:
                draw_rect(Rect2(_cell_pos(e.position) - Vector2(2, 2), Vector2(4, 4)), ArtPalette.RED[2], false, 1.0)
        for h in sb.heroes:
            if not h.dead:
                var c := ArtPalette.TEXT if h.is_controlled() else ArtPalette.GREEN[3]
                draw_rect(Rect2(_cell_pos(h.position) - Vector2(1, 1), Vector2(3, 3)), c)
        var cam := sb.camera
        if cam != null:
            var half := sb._viewport.size / 2.0 / maxf(0.05, cam.zoom.x) if sb._viewport != null else Vector2(320, 180)
            draw_rect(Rect2(_cell_pos(cam.position - Vector2(half)), Vector2(half) * 2.0 / float(NavMap.CELL) * _scale()), Color(1, 1, 1, 0.5), false, 1.0)
        draw_rect(r, ArtPalette.OUTLINE, false, 1.0)

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            sb.look_at_world(e.position / _scale() * float(NavMap.CELL))
            accept_event()
