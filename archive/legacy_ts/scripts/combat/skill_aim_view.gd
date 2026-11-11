class_name SkillAimView
extends Node2D
## Quick cast with indicator (D-053): while W/E/R is held on the hero the player drives, shows the
## skill's real reach around the hero and, for area skills, the real area at the cursor (clamped to the
## reach). The skill fires when the key is released (SandboxScreen._skill_key).

var hero: SandboxHero = null
var slot: int = -1
var cursor: Vector2 = Vector2.ZERO


func _init() -> void:
    z_index = 30
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _draw() -> void:
    if hero == null or slot < 0 or not hero.alive:
        return
    var sk := hero.slot_skill(slot)
    if sk.is_empty():
        return
    var reach := float(sk["range"])
    var ready := hero.skill_ready(slot)
    var col := Color(0.55, 0.85, 1.0) if ready else Color(0.8, 0.5, 0.5)
    draw_set_transform(hero.position, 0.0, Vector2(1.0, 0.55))
    if reach > 0.0:
        draw_arc(Vector2.ZERO, reach, 0.0, TAU, 56, Color(col, 0.8), 2.0)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    match String(sk["target"]):
        "target_aoe":
            var at := hero.position + (cursor - hero.position).limit_length(reach)
            draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
            var r := float(sk.get("radius", 80.0))
            draw_circle(Vector2.ZERO, r, Color(col, 0.18))
            draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, 2.0)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        "self_aoe":
            draw_set_transform(hero.position, 0.0, Vector2(1.0, 0.55))
            draw_circle(Vector2.ZERO, reach, Color(col, 0.15))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        "enemy":
            draw_line(hero.position + Vector2(0, -16), hero.position + (cursor - hero.position).limit_length(reach), Color(col, 0.7), 2.0)
