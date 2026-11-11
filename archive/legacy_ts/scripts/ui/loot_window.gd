class_name LootWindow
extends CanvasLayer
## D-121 (pista D): the loot window that opens after holding F next to a glowing body. The game keeps
## running (D-014: no pause): it closes on its own when the Master walks away or the body is empty.
## Each item shows its icon with the rarity border and its name in the rarity colour; "Take" puts it in
## the Master's backpack (or the nearest ally's with room), "Take all" takes everything that fits.

var bag: LootBag = null
var screen: Node = null               # SandboxScreen
var _list: VBoxContainer
var _msg: Label


func _init(p_bag: LootBag, p_screen: Node) -> void:
    bag = p_bag
    screen = p_screen
    layer = 20


func _ready() -> void:
    var pc := PanelContainer.new()
    pc.custom_minimum_size = Vector2(250, 0)
    pc.anchor_left = 0.5
    pc.anchor_right = 0.5
    pc.anchor_top = 0.18
    pc.offset_left = -125
    pc.offset_right = 125
    pc.theme = UIKit.make_theme()                    # a CanvasLayer does not inherit the screen's theme
    pc.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.08, 0.06, 0.94), UIKit.ACCENT, 1, 2, 6))
    add_child(pc)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 3)
    pc.add_child(v)
    var title := tr("Backpack of %s") % bag.owner_name if bag.source == "pack" else tr("Loot")
    v.add_child(UIKit.label(title, 16, UIKit.ACCENT))
    _list = VBoxContainer.new()
    v.add_child(_list)
    _msg = UIKit.label("", 10, UIKit.MUTED)
    v.add_child(_msg)
    var row := HBoxContainer.new()
    v.add_child(row)
    row.add_child(UIKit.button(tr("Take all"), func(): _take(-1), Vector2(110, 26)))
    row.add_child(UIKit.button(tr("Close"), func(): queue_free(), Vector2(90, 26)))
    refresh()


func refresh() -> void:
    if not is_instance_valid(bag) or bag.is_empty():
        queue_free()
        return
    for c in _list.get_children():
        c.queue_free()
    for i in bag.items.size():
        var it: Dictionary = bag.items[i]
        var row := HBoxContainer.new()
        var icon := ItemIcons.slot_control(String(ItemDefs.slots_for(String(it["base"]))[0]) if not ItemDefs.slots_for(String(it["base"])).is_empty() else "", it)
        icon.tooltip_text = ItemIcons.tooltip(it)
        icon.mouse_filter = Control.MOUSE_FILTER_STOP
        row.add_child(icon)
        var lbl := ItemIcons.name_label(it, 11)
        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        lbl.tooltip_text = ItemIcons.tooltip(it)
        lbl.mouse_filter = Control.MOUSE_FILTER_STOP
        row.add_child(lbl)
        var idx := i
        row.add_child(UIKit.button(tr("Take"), func(): _take(idx), Vector2(56, 24)))
        _list.add_child(row)
    for k in bag.res:
        _list.add_child(UIKit.label("%d %s" % [int(bag.res[k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k))], 11, Color(0.95, 0.85, 0.45)))


func _take(idx: int) -> void:
    _msg.text = String(screen.call("take_loot", bag, idx, screen.get("master_hero")))
    UIKit.sound("click")
    refresh()
