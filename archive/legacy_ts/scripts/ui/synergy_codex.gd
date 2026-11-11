class_name SynergyCodex
extends PanelContainer
## D-090: the synergy codex. Every synergy by type; the undiscovered ones show "???" (SynergyDefs).
## Discoveries are saved in Game.synergy_codex.

signal closed


func _ready() -> void:
    add_theme_stylebox_override("panel", UIKit.box(ArtPalette.PANEL, ArtPalette.PANEL_RIM, 2, 2, 8))
    var codex := SynergyDefs.codex()
    var v := VBoxContainer.new()
    add_child(v)
    v.add_child(UIKit.label(tr("Synergy codex (%d/%d)") % [codex.size(), SynergyDefs.SYNERGIES.size()], 20, UIKit.ACCENT))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(360, 240)
    v.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    for t in SynergyDefs.TYPES:
        list.add_child(UIKit.label(tr(String(SynergyDefs.TYPE_NAMES[t])), 16, UIKit.ACCENT))
        for id in SynergyDefs.of_type(t):
            var known := codex.has(id)
            list.add_child(UIKit.label(tr(SynergyDefs.shown_name(id, codex)) if known else "???", 14, UIKit.TEXT if known else UIKit.MUTED))
            var d := UIKit.label(tr(SynergyDefs.shown_desc(id, codex)), 12, UIKit.MUTED)
            d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            d.custom_minimum_size = Vector2(330, 0)
            list.add_child(d)
    v.add_child(UIKit.button(tr("Close"), func():
        closed.emit()
        queue_free(), Vector2(90, 28)))
