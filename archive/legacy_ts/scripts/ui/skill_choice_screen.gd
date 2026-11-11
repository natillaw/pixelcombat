class_name SkillChoiceScreen
extends PanelContainer
## D-090: the level-up skill choice. One card per option (icon, name, cost in the class resource, cooldown,
## range, description) and a Learn button; the options not taken are gone for this choice. A skill tome
## (pista D, HeroData.bonus_skill_choice) shows one extra card. Emits `chosen` and closes.

signal chosen(skill_id: String)
signal closed

var hero: HeroData
var choice_index: int = 0


static func make(h: HeroData, index: int = 0) -> SkillChoiceScreen:
    var s := SkillChoiceScreen.new()
    s.hero = h
    s.choice_index = index
    return s


func _ready() -> void:
    add_theme_stylebox_override("panel", UIKit.box(ArtPalette.PANEL, ArtPalette.PANEL_RIM, 2, 2, 8))
    if hero == null or choice_index < 0 or choice_index >= hero.skill_choices.size():
        queue_free()
        return
    var c: Dictionary = hero.skill_choices[choice_index]
    var v := VBoxContainer.new()
    add_child(v)
    v.add_child(UIKit.label(tr("%s reached level %d: choose ONE skill") % [hero.display_name(), int(c["level"])], 20, UIKit.ACCENT))
    var hint := UIKit.label(tr("The others are lost for this choice. Up to 3 skills on W E R (Q = basic attack)."), 12, UIKit.MUTED)
    v.add_child(hint)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    v.add_child(row)
    var res_id := SkillDefs.resource_of(hero.hero_class)
    var res_name := String(SkillDefs.RESOURCES[res_id]["name"]).to_lower()
    for sid in c["options"]:
        row.add_child(_card(String(sid), res_id, res_name))
    if bool(c.get("bonus", false)):
        v.add_child(UIKit.label(tr("Skill tome: one extra option."), 12, UIKit.ACCENT))
    v.add_child(UIKit.button(tr("Later"), func():
        closed.emit()
        queue_free(), Vector2(90, 28)))


func _card(id: String, res_id: String, res_name: String) -> Control:
    var sk := SkillDefs.info(id)
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", UIKit.box(ArtPalette.PANEL_LIGHT, ArtPalette.PANEL_RIM, 1, 2, 6))
    card.custom_minimum_size = Vector2(170, 0)
    var v := VBoxContainer.new()
    card.add_child(v)
    var top := HBoxContainer.new()
    v.add_child(top)
    var icon := TextureRect.new()
    icon.texture = ItemIcons.skill_texture(id)
    icon.custom_minimum_size = Vector2(32, 32)
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    top.add_child(icon)
    top.add_child(UIKit.label(tr(String(sk.get("name", id))), 16, UIKit.TEXT))
    var cost := "—" if res_id == "none" else "%d %s" % [int(sk.get("cost", 0)), tr(res_name)]
    var extra := ""
    if bool(sk.get("finisher", false)):
        extra = " · " + tr("finisher")
    elif sk.has("combo"):
        extra = " · +%d %s" % [int(sk["combo"]), tr("combo")]
    v.add_child(UIKit.label("%s · %.0fs%s" % [cost, float(sk.get("cd", 0.0)), extra], 12, UIKit.ACCENT))
    if float(sk.get("range", 0.0)) > 0.0:
        v.add_child(UIKit.label(tr("range %d") % int(sk["range"]), 12, UIKit.MUTED))
    var d := UIKit.label(tr(String(sk.get("desc", ""))), 12, UIKit.MUTED)
    d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    d.custom_minimum_size = Vector2(160, 0)
    v.add_child(d)
    v.add_child(UIKit.button(tr("Learn"), func(): _pick(id), Vector2(120, 28)))
    return card


func _pick(id: String) -> void:
    if hero.choose_skill(choice_index, id):
        Game._commit()
        chosen.emit(id)
        queue_free()
