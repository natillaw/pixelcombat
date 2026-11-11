extends SceneTree
## Overhaul LPC phase 1 (gate: one UI style). A = the game's inventory today (Dragon Regalia, capture
## docs/reports/ui_art/after_07_inventory.png); B = CraftPix "basic pixel art UI for RPG" inventory and
## equipment mock-ups at x2. The owner picks one; the two are never mixed.
##   UI_B=<extracted pack PNG dir> godot --headless --path . --script res://tools/overhaul_ui_ab.gd
func _init() -> void:
    var a := Image.load_from_file(ProjectSettings.globalize_path("res://docs/reports/ui_art/after_07_inventory.png"))
    a.convert(Image.FORMAT_RGBA8)
    var b_dir := OS.get_environment("UI_B")
    var parts: Array = []
    for n in ["Inventory.png", "Equipment.png", "character_panel.png"]:
        var i := Image.load_from_file(b_dir + "/" + n)
        i.convert(Image.FORMAT_RGBA8)
        i.resize(i.get_width() * 2, i.get_height() * 2, Image.INTERPOLATE_NEAREST)
        parts.append(i)
    var bw := 0
    var bh := 0
    for i in parts:
        bw += (i as Image).get_width() + 16
        bh = maxi(bh, (i as Image).get_height())
    var aw := mini(a.get_width(), 1280)
    var ah := mini(a.get_height(), 720)
    var out := Image.create(aw + bw + 40, maxi(ah, bh) + 20, false, Image.FORMAT_RGBA8)
    out.fill(Color(0.12, 0.12, 0.14))
    out.blit_rect(a, Rect2i(0, 0, aw, ah), Vector2i(10, 10))
    var x := aw + 30
    for i in parts:
        out.blend_rect(i, Rect2i(Vector2i.ZERO, (i as Image).get_size()), Vector2i(x, 10))
        x += (i as Image).get_width() + 16
    out.save_png("res://docs/reports/overhaul/ui_ab.png")
    print("RESULT ui_ab.png %dx%d" % [out.get_width(), out.get_height()])
    quit(0)
