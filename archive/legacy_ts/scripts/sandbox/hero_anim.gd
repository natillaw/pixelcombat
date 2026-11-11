class_name HeroAnim
extends RefCounted
## T-023 (D-020): animations the sheet lacks, built in code from existing frames.
## Purely visual: never touches stats, orders or targets.

const LOCK_ATTACK := 0.40
const LOCK_CAST := 0.45
## Attack phases (game feel report): anticipation (pull back) -> execution (snap forward, the blow) ->
## recovery. With a lead (SandboxHero.ATTACK_LEAD) the anticipation plays BEFORE the damage, so the
## snap forward lands on the frame the hit is resolved; without one (first blow on arrival) it is short.
const ANTICIPATION := 0.10
const ANTICIPATION_SHORT := 0.03
const EXECUTION := 0.05
const RECOVERY := 0.16
## Hero death (D-011): the body stays visible longer than an enemy's and fades slowly.
const DEATH_HOLD := 2.4
const DEATH_FADE := 1.4


static func dir_vec(facing: String) -> Vector2:
    match facing:
        "left":
            return Vector2.LEFT
        "right":
            return Vector2.RIGHT
        "up":
            return Vector2.UP
    return Vector2.DOWN


## Side frames exist only for left/right; up/down reuse the last horizontal side.
static func side_of(facing: String, last_side: String) -> String:
    if facing == "left" or facing == "right":
        return facing
    return last_side


## Overhaul LPC: the four real directions when the sheet has them (LPC), else the last side (TPF).
static func dir_anim(sprite: AnimatedSprite2D, base: String, facing: String, last_side: String) -> String:
    if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(base + facing):
        return base + facing
    return base + side_of(facing, last_side)


static func attack_anim(facing: String, last_side: String) -> String:
    return "attack_" + side_of(facing, last_side)


static func _fresh_tween(sprite: AnimatedSprite2D) -> Tween:
    if sprite.has_meta("anim_tween"):
        var old = sprite.get_meta("anim_tween")
        if old is Tween and old.is_valid():
            old.kill()
    sprite.position = Vector2.ZERO
    sprite.modulate = Color.WHITE
    var t := sprite.create_tween()
    sprite.set_meta("anim_tween", t)
    return t


## Melee: side lunge frames + forward tween. Ranged: ready pose + draw-back/release tween.
## Returns seconds during which idle/walk must not override the pose (0 if nothing played).
## offhand (D-082b, two daggers): the second blow. Facing up or down the sprite is mirrored for it, so the
## other hand strikes; sideways the same swing plays again (the off-hand dagger is the one in front).
static func play_attack(sprite: AnimatedSprite2D, facing: String, last_side: String, ranged: bool, lead: bool = false, offhand: bool = false) -> float:
    if sprite == null or not sprite.is_inside_tree():
        return 0.0
    if offhand and (facing == "up" or facing == "down"):
        sprite.flip_h = true
        sprite.get_tree().create_timer(LOCK_ATTACK).timeout.connect(func():
            if is_instance_valid(sprite):
                sprite.flip_h = false)
    var v := dir_vec(facing)
    var side := side_of(facing, last_side)
    var t := _fresh_tween(sprite)
    var wind := ANTICIPATION if lead else ANTICIPATION_SHORT
    sprite.speed_scale = 1.0
    if ranged:
        sprite.play(dir_anim(sprite, "ready_", facing, last_side))
        t.tween_property(sprite, "position", -v * 3.0, wind).set_ease(Tween.EASE_OUT)
        t.tween_property(sprite, "position", v * 2.0, EXECUTION)
        t.tween_property(sprite, "position", Vector2.ZERO, RECOVERY)
    else:
        sprite.stop()
        sprite.play(dir_anim(sprite, "attack_", facing, last_side))
        t.tween_property(sprite, "position", -v * 2.0, wind).set_ease(Tween.EASE_OUT)
        t.tween_property(sprite, "position", v * 6.0, EXECUTION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        t.tween_property(sprite, "position", Vector2.ZERO, RECOVERY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    return LOCK_ATTACK + (wind - ANTICIPATION_SHORT)


## Skill cast: ready pose, small rise and a warm pulse. The effect itself stays in _draw (T-027).
static func play_cast(sprite: AnimatedSprite2D, last_side: String) -> float:
    if sprite == null or not sprite.is_inside_tree():
        return 0.0
    var t := _fresh_tween(sprite)
    sprite.play("ready_" + last_side)
    t.tween_property(sprite, "position", Vector2(0, -5), 0.15)
    t.parallel().tween_property(sprite, "modulate", Color(1.5, 1.35, 1.0), 0.15)
    t.tween_property(sprite, "position", Vector2.ZERO, 0.25)
    t.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.25)
    return LOCK_CAST


## Hit reaction: white flash + recoil away from the source. Does not lock the pose.
static func play_hit(sprite: AnimatedSprite2D, away: Vector2) -> void:
    if sprite == null or not sprite.is_inside_tree():
        return
    var t := _fresh_tween(sprite)
    sprite.modulate = Color(2.5, 2.5, 2.5)
    sprite.position = away * 4.0
    t.tween_property(sprite, "modulate", Color.WHITE, 0.12)
    t.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.12)


## Death: the real hero node is hidden by the combat code (unchanged); a short-lived corpse
## sprite lies down (rows 5/6, cols 0-1), holds, fades and frees itself.
static func spawn_death(hero: Node2D, sprite: AnimatedSprite2D, facing: String, last_side: String, hero_name: String = "") -> void:
    if hero == null or sprite == null or not hero.is_inside_tree():
        return
    var parent := hero.get_parent()
    if parent == null:
        return
    var ghost := Node2D.new()
    ghost.position = hero.position
    ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    var s := AnimatedSprite2D.new()
    s.sprite_frames = sprite.sprite_frames
    s.offset = sprite.offset
    ghost.add_child(s)
    s.play(dir_anim(sprite, "down_", facing, last_side))
    parent.add_child.call_deferred(ghost)
    if hero_name != "":
        FloatingText.spawn(hero, "%s has fallen" % hero_name, Color(0.95, 0.85, 0.6), true, DEATH_HOLD + 0.6)
    var t := hero.get_tree().create_tween()
    t.tween_property(s, "modulate", Color(0.7, 0.7, 0.78), 0.5)      # the colour drains out of the body
    t.tween_interval(DEATH_HOLD - 0.5)
    t.tween_property(s, "modulate:a", 0.0, DEATH_FADE)
    t.tween_callback(ghost.queue_free)
