class_name StarRow
extends HBoxContainer
## Hero rank as kit stars (D-063): full stars up to the hero's rank, empty ones up to the cap (5 for now,
## D-062). Small (9 x 8) or big (16 px) icons; the rank is also in the tooltip (never colour alone).

var count: int = 1
var star_size: float = 14.0
var star_color: Color = Color.WHITE        # kept for callers; the kit stars carry their own colour


func _init(c: int = 1, s: float = 14.0, col: Color = Color.WHITE) -> void:
    count = c
    star_size = s
    star_color = col
    add_theme_constant_override("separation", 1)
    tooltip_text = "%d star%s" % [c, "" if c == 1 else "s"]
    mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
    var big := star_size >= 16.0
    for i in HeroTables.MAX_STARS:
        var r := TextureRect.new()
        var id := ("star_full" if i < count else "star_empty") if big else ("star_small_full" if i < count else "star_small_empty")
        var path := AssetCatalog.icon(id)
        r.texture = load(path) if ResourceLoader.exists(path) else null
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(r)
