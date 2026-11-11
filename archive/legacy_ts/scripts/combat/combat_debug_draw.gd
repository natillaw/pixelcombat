class_name CombatDebugDraw
extends Node2D
## Debug overlay for a mission (F3, debug builds only; SandboxScreen.toggle_debug_overlay). Draws what
## the rules really use: body radius (separation / hurtbox), hero attack range, enemy strike range and
## strike radius, perception, the current path and destination, the current target, AI state and speed.
## Never shown in exported release builds (OS.is_debug_build()).

var screen: SandboxScreen


func _init(p_screen: SandboxScreen = null) -> void:
    screen = p_screen
    z_index = 90
    physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ellipse(at: Vector2, r: float, col: Color, width: float = 1.0) -> void:
    draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, col, width)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
    if screen == null:
        return
    var font := ThemeDB.fallback_font
    for h in screen.heroes:
        if h.dead:
            continue
        _ellipse(h.position, CombatRules.HERO_BODY, Color(0.3, 1.0, 0.4), 1.5)
        _ellipse(h.position, h.attack_range(), Color(0.3, 0.8, 1.0, 0.5))
        var from: Vector2 = h.position
        for p in h.path:
            draw_line(from, p, Color(1, 1, 1, 0.6), 1.0)
            from = p
        if not h.path.is_empty():
            draw_circle(h.path[h.path.size() - 1], 3.0, Color(1, 1, 1, 0.8))
        if h.target != null and is_instance_valid(h.target):
            draw_line(h.position + Vector2(0, -16), h.target.position + Vector2(0, -12), Color(1.0, 0.8, 0.2, 0.7), 1.0)
        draw_string(font, h.position + Vector2(-30, 14), "%s %.0f" % [h.order, h.velocity.length()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 1.0, 0.8))
    for e in screen.living_enemies():
        _ellipse(e.position, e.body_radius, Color(1.0, 0.4, 0.3), 1.5)
        _ellipse(e.position, e.strike_range, Color(1.0, 0.6, 0.2, 0.5))
        _ellipse(e.position, e.perception, Color(1.0, 1.0, 1.0, 0.12))
        if e.is_telegraphing():
            _ellipse(e.aim_point(), e.strike_radius, Color(1.0, 0.1, 0.1), 2.0)
        if e.focus != null and is_instance_valid(e.focus):
            draw_line(e.position + Vector2(0, -12), e.focus.position + Vector2(0, -16), Color(1.0, 0.3, 0.3, 0.5), 1.0)
        var st := ["idle", "chase", "windup", "recover"]
        draw_string(font, e.position + Vector2(-30, 14), "%s %s m%.1f %.0f" % [e.size_class, st[e.state], e.mass, e.velocity.length()],
            HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.8, 0.7))
