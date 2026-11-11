class_name GameOverScreen
extends Control
## D-081: end of a hardcore game. The Master died: a short summary (floors, heroes, time) and back to
## the title. The save stays, marked over (Game.game_over): Continue no longer opens it.

signal finished


func _ready() -> void:
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)  # px
    panel.add_child(v)
    var head := HBoxContainer.new()
    head.add_child(UIKit.icon(MasterDefs.HARDCORE_ICON, "Hardcore"))
    head.add_child(UIKit.label("The Master has fallen", 22, UIKit.BAD))
    v.add_child(head)
    var info: Dictionary = Game.game_over_info
    var secs := int(info.get("seconds", 0))
    v.add_child(UIKit.label(String(info.get("name", "")), 16, UIKit.ACCENT))
    v.add_child(UIKit.label("%s: %s" % [tr("Cause"), tr(String(info.get("cause", "")))], 14, UIKit.TEXT))
    v.add_child(UIKit.label("%s: %d" % [tr("Highest floor cleared"), int(info.get("floors", 0))], 14, UIKit.TEXT))
    v.add_child(UIKit.label("%s: %d   %s: %d" % [tr("Heroes left"), int(info.get("heroes", 0)), tr("Fallen"), int(info.get("memorial", 0))], 14, UIKit.TEXT))
    v.add_child(UIKit.label("%s: %d:%02d:%02d" % [tr("Time played"), secs / 3600, (secs / 60) % 60, secs % 60], 14, UIKit.TEXT))
    v.add_child(UIKit.label("This hardcore game is over.", 14, UIKit.MUTED))
    v.add_child(UIKit.button("Back to the title", func(): finished.emit(), Vector2(240, 30)))
