extends CanvasLayer
## D-146: developer console (autoload "DevConsole"). The key under Esc (` / º, read by its physical
## position so it works on any keyboard layout) opens and closes it. Opening it enables nothing: until
## `/key <clave>` every command answers "bloqueado". The commands themselves live in DevCommands.
## Minimal UI by code: output log, input line, history (Up/Down) and autocomplete (Tab).

const TOGGLE_KEY := KEY_QUOTELEFT        # physical key under Esc
const HISTORY_CAP := 50
const LOG_LINES := 200

var commands: DevCommands
var history: Array = []
var _hist_i: int = -1
var _panel: PanelContainer
var _log: RichTextLabel
var _line: LineEdit


func _ready() -> void:
    layer = 128
    process_mode = Node.PROCESS_MODE_ALWAYS
    commands = DevCommands.new(get_tree())
    _panel = PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.05, 0.08, 0.88)
    sb.border_color = Color(0.9, 0.75, 0.3)
    sb.border_width_bottom = 1
    sb.content_margin_left = 4
    sb.content_margin_right = 4
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    _panel.add_theme_stylebox_override("panel", sb)
    _panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _panel.custom_minimum_size = Vector2(0, 150)
    add_child(_panel)
    var box := VBoxContainer.new()
    _panel.add_child(box)
    _log = RichTextLabel.new()
    _log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _log.scroll_following = true
    _log.bbcode_enabled = false
    _log.selection_enabled = true
    _log.add_theme_font_size_override("normal_font_size", 12)
    box.add_child(_log)
    _line = LineEdit.new()
    _line.placeholder_text = "/key <clave>   ·   /help"
    _line.add_theme_font_size_override("font_size", 12)
    _line.set("keep_editing_on_text_submit", true)
    _line.text_submitted.connect(submit)
    box.add_child(_line)
    _panel.visible = false
    print_line("Consola de desarrollo. Bloqueada: /key <clave>")


func is_open() -> bool:
    return _panel != null and _panel.visible


func toggle() -> void:
    set_open(not is_open())


func set_open(on: bool) -> void:
    _panel.visible = on
    DevCommands.console_open = on
    if on:
        _line.clear()
        _line.grab_focus()
    else:
        _line.release_focus()


func print_line(text: String) -> void:
    _log.append_text(text + "\n")
    if _log.get_line_count() > LOG_LINES:
        var keep := _log.get_parsed_text().split("\n")
        _log.clear()
        _log.append_text("\n".join(keep.slice(keep.size() - LOG_LINES)))


## Runs a line typed in the console. The key itself never reaches the log or the history.
func submit(text: String) -> String:
    var t := text.strip_edges()
    _line.clear()
    if t == "":
        return ""
    var is_key := t.trim_prefix("/").to_lower().begins_with("key ")
    var shown := ("/key " + "*".repeat(6)) if is_key else t
    print_line("> " + shown)
    if not is_key:
        history.append(t)
        if history.size() > HISTORY_CAP:
            history.pop_front()
    _hist_i = -1
    var out := commands.run(t)
    if out != "":
        print_line(out)
    return out


func _autocomplete() -> void:
    var text := _line.text
    var opts := DevCommands.complete(text)
    if opts.is_empty():
        return
    if opts.size() == 1:
        _line.text = "/" + String(opts[0]) + " "
    else:
        var common := String(opts[0])
        for o in opts:
            while not String(o).begins_with(common):
                common = common.substr(0, common.length() - 1)
        if common.length() > text.trim_prefix("/").length():
            _line.text = "/" + common
        print_line("  ".join(opts.map(func(o): return "/" + String(o))))
    _line.caret_column = _line.text.length()


func _browse(step: int) -> void:
    if history.is_empty():
        return
    if _hist_i < 0:
        _hist_i = history.size()
    _hist_i = clampi(_hist_i + step, 0, history.size())
    _line.text = String(history[_hist_i]) if _hist_i < history.size() else ""
    _line.caret_column = _line.text.length()


func _input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed:
        return
    var k := event as InputEventKey
    if k.physical_keycode == TOGGLE_KEY and not k.echo:
        toggle()
        get_viewport().set_input_as_handled()
        return
    if not is_open():
        return
    match k.keycode:
        KEY_ESCAPE:
            set_open(false)
        KEY_UP:
            _browse(-1)
        KEY_DOWN:
            _browse(1)
        KEY_TAB:
            _autocomplete()
        _:
            return
    get_viewport().set_input_as_handled()
