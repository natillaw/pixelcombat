extends Control
## Root of the game. Builds the background, the currency bar and swaps screens.

var _content: Control
var _currency: Label
var _bar: Control
var dev_next_map: NavMap = null     # D-146 dev console: the next floor screen reuses this map (Wilds /floor reset)

## 2026-11-02: every screen has its own header or HUD, so the global currency bar stays hidden (it doubled
## the town bar and covered the title and the expedition HUD).


func _ready() -> void:
    StringsEs.install()                                  # beta: Spanish by default (Options can switch)
    theme = UIKit.make_theme()
    ThemeDB.fallback_font = UIKit.body_font()          # world text (bars, names, floating numbers) in m5x7 too
    ThemeDB.fallback_font_size = UIKit.BODY

    var bg := ColorRect.new()
    bg.color = UIKit.BG
    add_child(bg)
    UIKit.fill(bg)

    var bar := PanelContainer.new()
    bar.custom_minimum_size = Vector2(0, 20)       # 640x360 base (D-063)
    bar.add_theme_stylebox_override("panel", UIKit.box(ArtPalette.PANEL, ArtPalette.PANEL_RIM, 1, 0, 2))   # thin wood bar (D-075)
    add_child(bar)
    _bar = bar
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    var hb := HBoxContainer.new()
    bar.add_child(hb)
    hb.add_child(UIKit.label("Tactical Summoners", 14, UIKit.MUTED))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(spacer)
    _currency = UIKit.label("", 14, UIKit.ACCENT)
    hb.add_child(_currency)

    _content = Control.new()
    add_child(_content)
    _content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _content.offset_top = 22

    Game.changed.connect(_refresh_currency)
    _refresh_currency()
    # D-063: the title screen first; Continue -> the town (D-030), New game -> welcome + first summons
    GameMenu.load_settings()
    show_screen("title")


var _fps: Label = null


func _process(_delta: float) -> void:
    if GameMenu.show_fps:
        if _fps == null:
            _fps = UIKit.label("", 12, Color(0.7, 1.0, 0.7))
            _fps.add_theme_constant_override("outline_size", 2)
            _fps.add_theme_color_override("font_outline_color", Color(0, 0, 0))
            _fps.z_index = 100
            _fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
            add_child(_fps)
            _fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
            _fps.position = Vector2(598, 344)
        _fps.visible = true
        _fps.text = "%d FPS" % Engine.get_frames_per_second()
    elif _fps != null:
        _fps.visible = false


## Options: mute everything while the window is in the background (the game itself never pauses, D-014).
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameMenu.mute_unfocused:
        AudioServer.set_bus_mute(0, true)
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
        AudioServer.set_bus_mute(0, UIKit.get_volume("Master") <= 0.001)


## D-082b: full screen from anywhere (F11 or Alt+Enter; saved in the settings).
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == CameraDefs.KEY_FULLSCREEN or (event.keycode == KEY_ENTER and event.alt_pressed):
            GameMenu.toggle_fullscreen()
            get_viewport().set_input_as_handled()


func _refresh_currency() -> void:
    _currency.text = "Gems %d     Stones %d     Books %d" % [Game.gems, Game.stones, Game.books]


## D-115 (pista C): heavy screens (entering a floor, the town) first show a loading curtain for a frame,
## so the click answers at once instead of freezing; headless runs (tests) build at once as before.
const HEAVY_SCREENS := ["sandbox", "town"]


func show_screen(screen: String, arg: int = 0) -> void:
    if HEAVY_SCREENS.has(screen) and DisplayServer.get_name() != "headless" and is_inside_tree():
        var curtain := UIKit.loading_curtain(self)
        await get_tree().process_frame
        await get_tree().process_frame
        _show_screen_now(screen, arg)
        curtain.queue_free()
        UIKit.fade_in(self)
        return
    _show_screen_now(screen, arg)
    UIKit.fade_in(self)


func _show_screen_now(screen: String, arg: int = 0) -> void:
    for c in _content.get_children():
        c.queue_free()
    if Game.game_over and not ["title", "game_over"].has(screen):
        screen = "game_over"                     # D-081: a hardcore game whose Master died goes no further
    var back := show_screen.bind("town", 0)
    var s: Control
    match screen:
        "summon":
            s = SummonScreen.new()
            s.back_requested.connect(back)
        "roster":
            s = RosterScreen.new()
            s.back_requested.connect(back)
        "party":
            s = PartyScreen.new()
            s.back_requested.connect(back)
        "memorial":
            s = MemorialScreen.new()
            s.back_requested.connect(back)
        "sandbox":
            s = SandboxScreen.new(arg)          # 0 = training ground, 1-10 = tower floors, -tier = the Wilds (D-066)
            if dev_next_map != null:
                (s as SandboxScreen).map = dev_next_map
                dev_next_map = null
            s.back_requested.connect(back)
        "hq":
            var hq_screen := HQScreen.new()
            hq_screen.back_requested.connect(back)
            hq_screen.explore_requested.connect(back)
            s = hq_screen
        "title":
            var t := TitleScreen.new()
            t.navigate.connect(show_screen)
            s = t
        "inventory":
            s = InventoryScreen.new()
            s.back_requested.connect(back)
        "master":
            var mc := MasterCreator.new()        # D-080: new account -> welcome; old save without a Master -> town
            mc.finished.connect(func(): show_screen("town" if Game.onboarded else "welcome", 0))
            s = mc
        "master_edit":
            var me := MasterCreator.new(true)    # D-081: the mirror in the Summoner's Hall (looks only)
            me.finished.connect(back)
            s = me
        "game_over":
            var go := GameOverScreen.new()       # D-081: hardcore, the Master died
            go.finished.connect(func(): show_screen("title", 0))
            s = go
        "welcome":
            var w := WelcomeScreen.new()
            w.finished.connect(back)
            s = w
        "menu":
            var menu := MainMenu.new()
            menu.navigate.connect(func(to: String): show_screen(to, 0))
            s = menu
        _:
            var town := TownScreen.new()
            town.navigate.connect(show_screen)
            s = town
    _content.add_child(s)
    UIKit.fill(s)
    _bar.visible = false                         # every screen has its own header now (2026-11-02)
    _content.offset_top = 22 if _bar.visible else 0
