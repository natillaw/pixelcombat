class_name JuicePlayer
extends RefCounted
## D-110: plays a JuiceProfile on an impact. Hooked on the visual calls that already exist (the damage
## number in Combatant.take_hit and the death look), never in the combat logic: it reads the hit, it
## never changes damage, cooldowns, real positions or when a blow lands. Positions are whole pixels,
## particles are CPUParticles2D 2x2 squares, no bloom.
##
## Filter (owner): camera shake and the render freeze ONLY for bosses, crits, the finishing blow and
## heavy skills; normal blows get flash + particles + a light kick.

## Audio hook: set by the audio track (09) to play profile.sound. Nothing is played until then.
static var on_sound: Callable = Callable()
## Last value of each attacker's `blows` counter: a hero's basic attack bumps it right before the hit
## lands (SandboxHero._land_basic), a skill does not. Read only.
static var _blows_seen: Dictionary = {}
static var _px_tex: ImageTexture = null
## Test hook: the last decision taken (id, heavy, shake, freeze), headless included.
static var last: Dictionary = {}


# --- choosing the profile -------------------------------------------------------------------

## Which profile a hit uses and whether it gets the heavy treatment. Pure: no nodes are touched.
static func resolve(target: Node, info: DamageInfo, lethal: bool, blocked: bool = false) -> Dictionary:
    var src: Node = info.source if info != null and info.source != null and is_instance_valid(info.source) else null
    var id := ""
    var boss := _is_boss(target) or _is_boss(src)
    if info != null and info.tags.has("dot"):
        id = "dot"
    elif blocked:
        id = "block"
    elif src != null and src.get("hero") != null:
        id = _hero_profile_id(src)
    elif info != null and info.tags.any(func(t): return String(t).begins_with("eskill.") and JuiceDefs.raw(String(t)) != {}):
        id = String(info.tags.filter(func(t): return String(t).begins_with("eskill."))[0])   # D-145 creature attack
    elif src != null and _is_boss(src):
        id = "boss"
    elif src != null and String(src.get("type_id") if src.get("type_id") != null else "").begins_with("bandit"):
        id = "bandit"
    else:
        id = "enemy"
    var prof := JuiceProfile.get_profile(id)
    if prof == null:
        prof = JuiceProfile.get_profile("enemy")
    var crit := info != null and info.crit
    var heavy := id != "dot" and (boss or crit or lethal or prof.heavy)
    return {"id": id, "profile": prof.boosted() if heavy else prof.light(), "heavy": heavy}


static func _is_boss(n: Node) -> bool:
    return n != null and is_instance_valid(n) and n.get("is_boss") == true


static func _class_key(src: Node) -> String:
    var hd = src.get("hero")
    var cls := String(hd.hero_class) if hd != null and hd.get("hero_class") != null else "class.commoner"
    return cls.trim_prefix("class.")


## Skill profile when the hero is resolving a skill, basic-attack profile (by class) otherwise.
static func _hero_profile_id(src: Node) -> String:
    var key := src.get_instance_id()
    var blows := int(src.get("blows")) if src.get("blows") != null else 0
    var basic := blows != int(_blows_seen.get(key, -1))
    _blows_seen[key] = blows
    var firing := String(src.get("_firing")) if src.get("_firing") != null else ""
    if not basic and firing != "" and JuiceDefs.has_skill(firing):
        return "skill." + firing
    var cls := "basic." + _class_key(src)
    return cls if JuiceDefs.BASIC.has(cls) else "basic.commoner"


# --- hooks ------------------------------------------------------------------------------------

## Called from Combatant.take_hit after the number is shown.
static func on_hit(target: Node2D, info: DamageInfo, dmg: int, blocked: bool) -> void:
    if target == null or (dmg <= 0 and not blocked):
        return
    var lethal: bool = int(target.get("hp")) <= 0
    var r := resolve(target, info, lethal, blocked)
    var prof: JuiceProfile = r["profile"]
    last = {"id": r["id"], "heavy": r["heavy"], "shake": prof.shake, "freeze": prof.freeze}
    if SimMode.on or not target.is_inside_tree():
        return
    var src: Node2D = info.source if info.source != null and is_instance_valid(info.source) else null
    var dir := Vector2.RIGHT
    if src != null and src != target:
        dir = (target.position - src.position).normalized()
    play(prof, target, src, dir)


## Called when a unit dies for good (the "pop").
static func on_death(unit: Node2D) -> void:
    if SimMode.on or unit == null or not unit.is_inside_tree():
        return
    var prof := JuiceProfile.get_profile("death")
    burst(unit.get_parent(), unit.position + Vector2(0, -12), Vector2.UP, prof)
    _sound(prof.sound)


static func play(prof: JuiceProfile, target: Node2D, src: Node2D, dir: Vector2) -> void:
    var sprite := _sprite_of(target)
    flash(sprite, prof.flash, prof.flash_frames)
    kick(sprite, dir, prof.kick)
    if prof.squash > 0.0:
        squash(sprite, prof.squash)
    if src != null and prof.recoil > 0:
        kick(_sprite_of(src), -dir, prof.recoil)
    burst(target.get_parent(), target.position + Vector2(0, -12), dir, prof)
    if prof.shake > 0.0:
        CombatFeel.shake_px(target, prof.shake, 0.12, dir)
    if prof.freeze > 0.0:
        CombatFeel.freeze_for(sprite, prof.freeze)
        if src != null:
            CombatFeel.freeze_for(_sprite_of(src), prof.freeze)
    _sound(prof.sound)


static func _sound(id: String) -> void:
    if id != "" and on_sound.is_valid():
        on_sound.call(id)


static func _sprite_of(n: Node) -> CanvasItem:
    if n == null or not is_instance_valid(n):
        return null
    var s = n.get("_sprite")
    return s as CanvasItem if s is CanvasItem else null


# --- the pieces -------------------------------------------------------------------------------

## Tints the sprite with the flash colour for 2-4 frames (self_modulate above 1 reads as a flash).
static func flash(sprite: CanvasItem, color: Color, frames: int) -> void:
    if sprite == null or not sprite.is_inside_tree():
        return
    var k := 1.0 + 1.6 * color.a
    sprite.self_modulate = Color(color.r * k + 0.4, color.g * k + 0.4, color.b * k + 0.4, 1.0)
    if sprite.has_meta("juice_flash"):
        var old: Tween = sprite.get_meta("juice_flash")
        if old != null and old.is_valid():
            old.kill()
    var t := sprite.create_tween()
    sprite.set_meta("juice_flash", t)
    t.tween_interval(float(clampi(frames, 2, 4)) * JuiceDefs.FRAME)
    t.tween_property(sprite, "self_modulate", Color.WHITE, JuiceDefs.FRAME * 2.0)


## Knocks the drawing `px` whole pixels along `dir` and brings it back (the unit itself never moves).
static func kick(sprite: CanvasItem, dir: Vector2, px: int) -> void:
    if sprite == null or px <= 0 or not sprite.is_inside_tree() or not ("offset" in sprite):
        return
    if not sprite.has_meta("juice_offset"):
        sprite.set_meta("juice_offset", sprite.get("offset"))
    var base: Vector2 = sprite.get_meta("juice_offset")
    if sprite.has_meta("juice_kick"):
        var old: Tween = sprite.get_meta("juice_kick")
        if old != null and old.is_valid():
            old.kill()
    sprite.set("offset", base + (dir.normalized() * float(px)).round())
    var t := sprite.create_tween()
    sprite.set_meta("juice_kick", t)
    t.tween_interval(JuiceDefs.FRAME * 2.0)
    t.tween_property(sprite, "offset", base, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    t.tween_callback(func(): sprite.set("offset", base))


## Squash then stretch then back to the sprite's own scale.
static func squash(sprite: CanvasItem, amount: float) -> void:
    if sprite == null or not (sprite is Node2D) or not sprite.is_inside_tree():
        return
    var n := sprite as Node2D
    if not n.has_meta("juice_scale"):
        n.set_meta("juice_scale", n.scale)
    var base: Vector2 = n.get_meta("juice_scale")
    if n.has_meta("juice_squash"):
        var old: Tween = n.get_meta("juice_squash")
        if old != null and old.is_valid():
            old.kill()
    var a := clampf(amount, 0.0, 0.3)
    var t := n.create_tween()
    n.set_meta("juice_squash", t)
    t.tween_property(n, "scale", base * Vector2(1.0 + a, 1.0 - a), 0.04)
    t.tween_property(n, "scale", base * Vector2(1.0 - a * 0.5, 1.0 + a * 0.5), 0.06)
    t.tween_property(n, "scale", base, 0.08)


## Death look on the corpse sprite: pop (squash/stretch) and a white flash.
static func pop(sprite: CanvasItem) -> void:
    if SimMode.on or sprite == null:
        return
    if not sprite.is_inside_tree():
        sprite.ready.connect(func(): pop(sprite), CONNECT_ONE_SHOT)
        return
    var prof := JuiceProfile.get_profile("death")
    flash(sprite, prof.flash, prof.flash_frames)
    squash(sprite, prof.squash)


static func _pixel() -> ImageTexture:
    if _px_tex == null:
        var img := Image.create(JuiceDefs.PARTICLE_PX, JuiceDefs.PARTICLE_PX, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _px_tex = ImageTexture.create_from_image(img)
    return _px_tex


## One-shot 2 px particles thrown along the blow (or rising, holy). A second colour when `extra` is set.
static func burst(parent: Node, at: Vector2, dir: Vector2, prof: JuiceProfile) -> int:
    if SimMode.on or parent == null or prof == null or prof.amount <= 0:
        return 0
    var n := 0
    for pair in [[prof.particles, prof.amount], [prof.extra, prof.amount / 2]]:
        var col: Color = pair[0]
        var count: int = pair[1]
        if col.a <= 0.0 or count <= 0:
            continue
        var p := CPUParticles2D.new()
        p.texture = _pixel()
        p.one_shot = true
        p.explosiveness = 1.0
        p.amount = count
        p.lifetime = 0.35
        p.position = at.round()
        p.direction = Vector2.UP if prof.rise else dir
        p.spread = prof.spread
        p.initial_velocity_min = prof.speed * 0.5
        p.initial_velocity_max = prof.speed
        p.gravity = Vector2(0, -60) if prof.rise else Vector2(0, 160)
        p.damping_min = 40.0
        p.damping_max = 80.0
        p.color = col
        var ramp := Gradient.new()
        ramp.set_color(0, Color(1, 1, 1, 1))
        ramp.set_color(1, Color(1, 1, 1, 0))
        p.color_ramp = ramp
        p.z_index = CombatVFX.Z_AIR
        p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
        parent.add_child(p)
        p.emitting = true
        p.finished.connect(p.queue_free)
        n += 1
    return n
