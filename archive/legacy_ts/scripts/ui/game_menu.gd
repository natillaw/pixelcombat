class_name GameMenu
extends Control
## Esc menu (D-062): opens over any screen and NEVER pauses the simulation (D-014). Resume, Options,
## Credits and a way out (back to the town or to the title). Options: music / SFX / UI volumes,
## screen shake, fullscreen, window size (x2 / x3 / x4 of the 640x360 base) and the controls list.
## Settings live in user://settings.cfg (per player, not in the save).

signal closed
signal leave_requested(to: String)

const SETTINGS := "user://settings.cfg"
const CONTROLS := [
    ["1-5 / Shift+1-5", "Drive a hero (focus + direct control)"], ["Tab", "Squad view, everyone autonomous"],
    ["G", "Select the whole squad"], ["Right click", "Move (attack / rescue in squad view)"],
    ["Q", "Basic attack at the mouse (hero you drive)"], ["W E R", "Skills (hold to aim, release to cast)"],
    ["A", "Attack-move"], ["H", "Hold"], ["V", "Follow"], ["C", "Regroup"], ["X", "Retreat (picks up the fallen nearby)"], ["S", "Stop"], ["T", "Skills: auto / manual"],
    ["F", "Interact: hold next to a fallen ally to lift them, gather, escape at the exit"], ["Shift + click", "Quick ping (hold: ping wheel)"],
    ["1 2 3", "Master commands"], ["Space", "Dash"], ["D", "Master: drink a healing potion (5 min cooldown)"], ["F", "Town: click to walk, click a building to go in, F at a door"], ["Y", "Camera: locked on the Master / free"], ["B (hold)", "Centre on the Master"],
    ["F1-F5", "Centre on a party member (double tap: follow)"], ["Arrows / screen edges / middle drag", "Move the free camera"], ["Wheel", "Zoom (whole steps)"],
    ["F11 / Alt+Enter", "Full screen"], ["M", "Whole map (the fog stays)"], ["I", "Details panel"], ["F10", "Debug overlay (debug builds)"], ["Esc", "This menu"],
]

var leave_label: String = "Back to the town"
## D-082b display options (saved in SETTINGS): full screen and, in a window, the mouse kept inside it.
## 2026-11-02 (owner: "las opciones deberían ser muchas más, y deberían funcionar"): display mode
## (window / borderless full screen / exclusive), window size, VSync, FPS cap, FPS counter, master volume,
## mute when the window is in the background, damage numbers, language, shake and effects.
static var fullscreen: bool = false
static var exclusive: bool = false
static var confine_mouse: bool = false
static var vsync: bool = true
static var max_fps: int = 0
static var show_fps: bool = false
static var mute_unfocused: bool = false
static var damage_numbers: bool = true
const FPS_CAPS := [0, 30, 60, 120, 144]
var _box: VBoxContainer
var _tab: String = "display"


static func load_settings() -> void:
    var cf := ConfigFile.new()
    if cf.load(SETTINGS) != OK:
        apply_display()
        return
    for bus in ["Master", "Music", "SFX", "UI"]:
        UIKit.set_volume(bus, float(cf.get_value("audio", bus, 1.0 if bus == "Master" else 0.8)))
    mute_unfocused = bool(cf.get_value("audio", "mute_unfocused", false))
    CombatFeel.shake_scale = float(cf.get_value("feel", "shake", 1.0))
    Ambience.quality = int(cf.get_value("feel", "effects", 2))
    damage_numbers = bool(cf.get_value("feel", "damage_numbers", true))
    TranslationServer.set_locale(String(cf.get_value("ui", "lang", "es")))
    fullscreen = bool(cf.get_value("display", "fullscreen", false))
    exclusive = bool(cf.get_value("display", "exclusive", false))
    confine_mouse = bool(cf.get_value("display", "confine_mouse", false))
    vsync = bool(cf.get_value("display", "vsync", true))
    max_fps = int(cf.get_value("display", "max_fps", 0))
    show_fps = bool(cf.get_value("display", "show_fps", false))
    apply_display()


## Running inside the editor's Game tab: the OS window belongs to the editor and cannot go full screen.
static func embedded() -> bool:
    return OS.has_feature("embedded_in_editor")


## Applies the display options (headless runs keep their window as it is).
static func apply_display() -> void:
    Engine.max_fps = max_fps
    if DisplayServer.get_name().begins_with("headless"):
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
    var tree := Engine.get_main_loop() as SceneTree
    var win: Window = tree.root if tree != null else null
    var mode := Window.MODE_WINDOWED
    if fullscreen:
        mode = Window.MODE_EXCLUSIVE_FULLSCREEN if exclusive else Window.MODE_FULLSCREEN
    if win != null:
        win.mode = mode
    else:
        DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)
    Input.mouse_mode = Input.MOUSE_MODE_CONFINED if confine_mouse and not fullscreen else Input.MOUSE_MODE_VISIBLE


## F11 / Alt+Enter and the Options button.
static func toggle_fullscreen() -> void:
    fullscreen = not fullscreen
    apply_display()
    save_settings()


static func save_settings() -> void:
    var cf := ConfigFile.new()
    for bus in ["Master", "Music", "SFX", "UI"]:
        cf.set_value("audio", bus, UIKit.get_volume(bus))
    cf.set_value("audio", "mute_unfocused", mute_unfocused)
    cf.set_value("feel", "shake", CombatFeel.shake_scale)
    cf.set_value("feel", "effects", Ambience.quality)
    cf.set_value("feel", "damage_numbers", damage_numbers)
    cf.set_value("ui", "lang", TranslationServer.get_locale().substr(0, 2))
    cf.set_value("display", "fullscreen", fullscreen)
    cf.set_value("display", "exclusive", exclusive)
    cf.set_value("display", "confine_mouse", confine_mouse)
    cf.set_value("display", "vsync", vsync)
    cf.set_value("display", "max_fps", max_fps)
    cf.set_value("display", "show_fps", show_fps)
    cf.save(SETTINGS)


func _ready() -> void:
    UIKit.fill(self)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(ArtPalette.INK, 0.55)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    UIKit.fill(dim)
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    var pc := PanelContainer.new()
    # the kit panel: the Dragon Regalia frames are bright blue, out of the palette (ArtPalette)
    center.add_child(pc)
    _box = VBoxContainer.new()
    _box.custom_minimum_size = Vector2(240, 0)
    pc.add_child(_box)
    UIKit.sound("open")
    show_main()


func _clear() -> void:
    for c in _box.get_children():
        c.queue_free()


func show_main() -> void:
    _clear()
    _box.add_child(UIKit.label("Menu", 28, UIKit.ACCENT))
    _box.add_child(UIKit.label("The game keeps running.", 12, UIKit.MUTED))
    _box.add_child(UIKit.button("Resume", close, Vector2(480, 40)))
    _box.add_child(UIKit.button("Options", show_options, Vector2(480, 40)))
    _box.add_child(UIKit.button("Controls", show_controls, Vector2(480, 40)))
    _box.add_child(UIKit.button("Credits", show_credits, Vector2(480, 40)))
    _box.add_child(UIKit.button(leave_label, func():
        close()
        leave_requested.emit("town"), Vector2(480, 40)))


func close() -> void:
    UIKit.sound("close")
    closed.emit()
    queue_free()


func _slider(text: String, value: float, on_change: Callable) -> void:
    var hb := HBoxContainer.new()
    hb.add_child(_row_label(text))
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = value
    s.custom_minimum_size = Vector2(110, 12)
    s.value_changed.connect(func(v):
        on_change.call(v)
        save_settings())
    hb.add_child(s)
    _box.add_child(hb)


func show_options() -> void:
    _clear()
    _box.add_child(UIKit.label("Options", 28, UIKit.ACCENT))
    var tabs := HBoxContainer.new()
    for t in [["display", "Display"], ["audio", "Audio"], ["game", "Game"]]:
        var id: String = t[0]
        var b := UIKit.button(tr(String(t[1])), func():
            _tab = id
            show_options(), Vector2(150, 30))
        b.disabled = _tab == id
        tabs.add_child(b)
    _box.add_child(tabs)
    match _tab:
        "display":
            _choice("Mode", ["Window", "Full screen", "Exclusive full screen"], (0 if not fullscreen else (2 if exclusive else 1)), func(i: int):
                fullscreen = i > 0
                exclusive = i == 2
                apply_display()
                save_settings())
            if embedded():
                var warn := UIKit.label("You are playing inside the Godot editor: full screen only works when the game runs in its own window (tools/Play.ps1, or turn off 'Embed game' in the editor's Game tab).", 12, UIKit.BAD)
                warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                warn.custom_minimum_size = Vector2(280, 0)
                _box.add_child(warn)
            var hb := HBoxContainer.new()
            var wl := UIKit.label("Window", 14, UIKit.TEXT)
            wl.custom_minimum_size = Vector2(90, 0)
            hb.add_child(wl)
            for k in [2, 3, 4]:
                var scale_k: int = k
                hb.add_child(UIKit.button("x%d" % k, func():
                    fullscreen = false
                    apply_display()
                    DisplayServer.window_set_size(Vector2i(640, 360) * scale_k)
                    var scr := DisplayServer.window_get_current_screen()
                    DisplayServer.window_set_position(DisplayServer.screen_get_position(scr) + (DisplayServer.screen_get_size(scr) - Vector2i(640, 360) * scale_k) / 2)
                    save_settings()
                    show_options(), Vector2(56, 30)))
            _box.add_child(hb)
            _check("VSync", vsync, func(on: bool):
                vsync = on
                apply_display()
                save_settings())
            var caps: Array = []
            for c in FPS_CAPS:
                caps.append(tr("No limit") if int(c) == 0 else str(c))
            _choice("FPS limit", caps, maxi(0, FPS_CAPS.find(max_fps)), func(i: int):
                max_fps = int(FPS_CAPS[i])
                apply_display()
                save_settings())
            _check("Show FPS", show_fps, func(on: bool):
                show_fps = on
                save_settings())
            _check("Keep the mouse inside the window", confine_mouse, func(on: bool):
                confine_mouse = on
                apply_display()
                save_settings())
            _box.add_child(UIKit.label("The picture always scales by whole numbers (crisp pixels).", 12, UIKit.MUTED))
        "audio":
            _slider("General", UIKit.get_volume("Master"), func(v): UIKit.set_volume("Master", v))
            _slider("Music", UIKit.get_volume("Music"), func(v): UIKit.set_volume("Music", v))
            _slider("Effects", UIKit.get_volume("SFX"), func(v): UIKit.set_volume("SFX", v))
            _slider("Interface", UIKit.get_volume("UI"), func(v): UIKit.set_volume("UI", v))
            _check("Mute when the window is in the background", mute_unfocused, func(on: bool):
                mute_unfocused = on
                save_settings())
        "game":
            _choice("Language", ["Español", "English"], 0 if TranslationServer.get_locale().begins_with("es") else 1, func(i: int):
                TranslationServer.set_locale("es" if i == 0 else "en")
                save_settings()
                show_options())
            _slider("Shake", CombatFeel.shake_scale, func(v): CombatFeel.shake_scale = v)
            _choice("Visual effects", ["Off", "Low", "High"], Ambience.quality, func(i: int):
                Ambience.quality = i
                save_settings())
            _check("Damage numbers", damage_numbers, func(on: bool):
                damage_numbers = on
                save_settings())
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


func _row_label(text: String) -> Label:
    var l := UIKit.label(text, 14, UIKit.TEXT)
    l.custom_minimum_size = Vector2(90, 0)
    return l


func _choice(text: String, options: Array, selected: int, on_pick: Callable) -> void:
    var hb := HBoxContainer.new()
    hb.add_child(_row_label(text))
    var ob := OptionButton.new()
    for o in options:
        ob.add_item(StringsEs.tx(String(o)))
    ob.select(clampi(selected, 0, options.size() - 1))
    ob.custom_minimum_size = Vector2(150, 20)
    ob.item_selected.connect(func(i: int): on_pick.call(i))
    hb.add_child(ob)
    _box.add_child(hb)


func _check(text: String, on: bool, on_toggle: Callable) -> void:
    var cb := CheckBox.new()
    cb.text = StringsEs.tx(text)
    cb.button_pressed = on
    cb.toggled.connect(func(v: bool): on_toggle.call(v))
    var flat := UIKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 2)
    var hov := UIKit.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 0, 2)
    for st in ["normal", "pressed", "focus", "disabled"]:
        cb.add_theme_stylebox_override(st, flat)
    for st in ["hover", "hover_pressed"]:
        cb.add_theme_stylebox_override(st, hov)
    _box.add_child(cb)


func show_controls() -> void:
    _clear()
    _box.add_child(UIKit.label("Controls", 28, UIKit.ACCENT))
    var grid := GridContainer.new()
    grid.columns = 2
    _box.add_child(grid)
    for c in CONTROLS:
        grid.add_child(UIKit.label(String(c[0]), 12, UIKit.ACCENT))
        grid.add_child(UIKit.label(String(c[1]), 12, UIKit.TEXT))
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


## Credits generated from the asset registry (assets/CREDITS.md, made by the import tools).
func show_credits() -> void:
    _clear()
    _box.add_child(UIKit.label("Credits", 28, UIKit.ACCENT))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(300, 190)
    _box.add_child(scroll)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    scroll.add_child(vb)
    vb.add_child(UIKit.label("Tactical Summoners — heroes by Caz (Tiny Pixel Fantasy).", 12, UIKit.TEXT))
    for line in credit_lines():
        var l := UIKit.label(line, 12, UIKit.MUTED)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.custom_minimum_size = Vector2(290, 0)
        vb.add_child(l)
    _box.add_child(UIKit.button("Back", show_main, Vector2(480, 36)))


## "Name by Author - License" for every registered asset (markdown links stripped).
static func credit_lines() -> Array:
    var out: Array = []
    var path := "res://assets/CREDITS.md"
    if not FileAccess.file_exists(path):
        return out
    for raw in FileAccess.get_file_as_string(path).split("\n"):
        var line := String(raw).strip_edges()
        if not line.begins_with("- "):
            continue
        line = line.substr(2).replace("**", "")
        var re := RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
        line = re.sub(line, "$1", true)
        out.append(line)
    return out
