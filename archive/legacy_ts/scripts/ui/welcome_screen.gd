class_name WelcomeScreen
extends Control
## New account (vertical slice): a short welcome (who you are, what the tower is, that heroes and the
## town grow), then the first ten free summons (Game.starter_summons) shown one card per hero, then the
## town. Only the essentials: the rest is for the player to discover.

signal finished

const PAGES := [
    "You are the Master.\nThe circle answered your call: from now on, those you summon will follow your lead.",
    "Above the village stands the Tower. Every floor is wilder than the last, and those who fall there do not come back.",
    "Your summoned grow with every expedition. Your village, still two empty dormitories, will grow with what they bring home.",
    "That is all anyone can tell you. The rest, you will have to find out for yourself.",
]

var _page: int = 0
var _box: VBoxContainer
var _text: Label
var _next: Button


func _ready() -> void:
    var center := CenterContainer.new()
    add_child(center)
    UIKit.fill(center)
    var panel := PanelContainer.new()
    center.add_child(panel)
    _box = VBoxContainer.new()
    _box.add_theme_constant_override("separation", 8)  # px
    panel.add_child(_box)
    _text = UIKit.label("", 22, UIKit.TEXT)
    _text.custom_minimum_size = Vector2(320, 80)  # px
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _box.add_child(_text)
    _next = UIKit.button("Continue", next_page, Vector2(640, 48))
    _box.add_child(_next)
    _show()


func _show() -> void:
    _text.text = PAGES[_page]
    _next.text = "Begin the summoning" if _page == PAGES.size() - 1 else "Continue"


func next_page() -> void:
    if _page < PAGES.size() - 1:
        _page += 1
        _show()
        return
    summon()


## The ten free summons, then a card per hero (stars, class, professions; the builder is marked).
func summon() -> void:
    var got: Array = Game.starter_summons()
    for c in _box.get_children():
        c.queue_free()
    _box.add_child(UIKit.label("Ten souls answered the circle", 22, UIKit.ACCENT))
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 9)  # px
    _box.add_child(grid)
    for h in got:
        var hd := h as HeroData
        var profs: Array = []
        for p in hd.professions:
            profs.append(String(ProfessionDefs.info(String(p)).get("name", p)))
        var line := "%s  %s  %s%s" % ["*".repeat(hd.stars), hd.display_name(), String(HeroTables.CLASSES[hd.hero_class]["name"]),
            ("   (" + ", ".join(profs) + ")") if not profs.is_empty() else ""]
        grid.add_child(UIKit.label(line, 15, UIKit.ACCENT if hd.knows_prof("builder") else UIKit.TEXT))
    _box.add_child(UIKit.label("Beds: %d / %d. The highlighted builder already works on your village." % [Game.heroes.size(), Game.max_hero_capacity()], 14, UIKit.MUTED))
    _box.add_child(UIKit.button("Enter the village", func(): finished.emit(), Vector2(640, 48)))
    add_child(SummonReveal.new(got))              # D-063: the ten arrive through the kit reveal, then this list
