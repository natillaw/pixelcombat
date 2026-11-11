class_name CampSite
extends Node2D
## D-090: a camp in progress (CampDefs). Placed by SandboxScreen.start_camp(); ticked by the screen on the
## simulation clock. Draws the fire (the camp-fire animation of the bandit camps), a progress ring and the
## seconds left; heroes in range sit still around it. Ends by itself: done (meal, buffs) or interrupted.

signal finished(camp, ok: bool, why: String)

var t_left: float = CampDefs.DURATION
var active: bool = true
var heroes: Array = []
var _fire: AnimatedSprite2D = null
var _hp: Dictionary = {}            # camper -> health last tick (a blow interrupts)


static func make(at: Vector2, squad: Array) -> CampSite:
    var c := CampSite.new()
    c.position = at
    c.heroes = squad
    c.z_index = 1
    return c


func _ready() -> void:
    if SimMode.on or not ResourceLoader.exists(BosqueArt.FIRE):
        return
    var tex := load(BosqueArt.FIRE) as Texture2D
    var sf := SpriteFrames.new()
    sf.set_animation_speed("default", 8.0)
    for i in 4:
        var at := AtlasTexture.new()
        at.atlas = tex
        at.region = Rect2(i * 16, 0, 16, 18)
        sf.add_frame("default", at)
    _fire = AnimatedSprite2D.new()
    _fire.sprite_frames = sf
    _fire.scale = Vector2.ONE * 1.5
    _fire.offset = Vector2(0, -8)
    _fire.play("default")
    add_child(_fire)


## Heroes standing at the fire.
func members() -> Array:
    return heroes.filter(func(h): return is_instance_valid(h) and h.alive and h.position.distance_to(position) <= CampDefs.GATHER_RADIUS)


## One step. foes = living creatures. Returns false once it is over.
func tick(delta: float, foes: Array) -> bool:
    if not active:
        return false
    for e in foes:
        var near: bool = e.position.distance_to(position) <= CampDefs.LURE_RADIUS
        e.detect_mult = CampDefs.DETECT_MULT if near else 1.0
        if e.alive and (e.alerted or e.state != SandboxEnemy.State.IDLE) and not e.dormant \
                and e.position.distance_to(position) <= CampDefs.INTERRUPT_RADIUS:
            _end(foes, false, "enemies are coming")
            return false
    for h in members():
        if h.hp < int(_hp.get(h, h.hp)):
            _end(foes, false, "attacked")          # a blow on a camper
            return false
        _hp[h] = h.hp
        if h.target == null and not h.is_controlled():
            h.path.clear()                         # sits by the fire
    t_left -= delta
    queue_redraw()
    if t_left <= 0.0:
        _end(foes, true, "")
        return false
    return true


func cancel(foes: Array, why: String) -> void:
    if active:
        _end(foes, false, why)


func _end(foes: Array, ok: bool, why: String) -> void:
    active = false
    for e in foes:
        if is_instance_valid(e):
            e.detect_mult = 1.0
    if ok:
        _feast()
    else:
        FloatingText.spawn(self, "%s (%s)" % [tr("Camp interrupted"), tr(why)], Color(1.0, 0.55, 0.4), true, 2.0)
    finished.emit(self, ok, why)
    queue_free()


## Everyone at the fire eats its own meal; a cook makes it last longer, an entertainer plays a song.
func _feast() -> void:
    var at := members()
    var cook: SandboxHero = null
    var bard: SandboxHero = null
    for h in at:
        if h.hero != null and h.hero.profession == String(SynergyDefs.param("cook", "profession", "")):
            cook = h
        if h.hero != null and h.hero.profession == String(SynergyDefs.param("bard", "profession", "")):
            bard = h
    var fed_time := CampDefs.FED_TIME * (float(SynergyDefs.param("cook", "dur_mult", 2.0)) if cook != null else 1.0)
    for h in at:
        var meal := ""
        if h.hero != null:
            for f in CampDefs.FOOD_IDS:
                if int(h.hero.bag.get(f, 0)) > 0:
                    meal = String(f)
                    break
        var share := 1.0
        if meal != "":
            h.hero.bag[meal] = int(h.hero.bag[meal]) - 1
            if int(h.hero.bag[meal]) <= 0:
                h.hero.bag.erase(meal)
            h.apply_status("well_fed", fed_time, 0.0, h)
        else:
            share = CampDefs.NO_FOOD
        h.heal(roundi(float(h.max_hp) * CampDefs.HEAL * share))
        if h.res_kind == "mana":
            h.res = minf(h.res_max, h.res + h.res_max * CampDefs.MANA * share)
        CombatVFX.play(h.get_parent(), h.position + Vector2(0, -14), "heal", 0.9)
        if bard != null and h.hero != null:
            h.hero.set_composure(h.hero.composure + int(SynergyDefs.param("bard", "composure", 20)))
            h.apply_status("inspired_song", CampDefs.SONG_TIME, 0.0, bard)
    if cook != null:
        cook.synergy("cook")
    if bard != null:
        bard.synergy("bard")
    FloatingText.spawn(self, tr("Camp done: rested"), Color(0.6, 1.0, 0.6), true, 2.0)


func _draw() -> void:
    if not active:
        return
    var k := 1.0 - clampf(t_left / CampDefs.DURATION, 0.0, 1.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, CampDefs.GATHER_RADIUS, 0.0, TAU, 48, Color(1.0, 0.7, 0.3, 0.25), 1.5)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    draw_arc(Vector2(0, -12), 16.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(1.0, 0.75, 0.3), 3.0)
    draw_string(ThemeDB.fallback_font, Vector2(-40, -38), "%s %ds" % [tr("Camping"), ceili(t_left)], HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(1.0, 0.85, 0.6))
    if _fire == null:
        draw_circle(Vector2(0, -6), 6.0, Color(1.0, 0.55, 0.2))
