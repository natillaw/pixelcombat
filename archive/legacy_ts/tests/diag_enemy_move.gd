extends Control
## Diagnostic: a creature placed near a holding hero walks to it and strikes.
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag_em.json"
    Game.new_game()
    Game.starter_summons()
    var sb := SandboxScreen.new(1)
    add_child(sb)
    await get_tree().process_frame
    sb.set_physics_process(false)
    var h: SandboxHero = sb.heroes[0]
    var e: SandboxEnemy = sb.enemies[0]
    for x in sb.heroes:
        x.order_hold()
        if x != h:
            x.position = sb.map.nearest_walkable(h.position + Vector2(-600, 0))
    for o in sb.enemies:
        if o != e:
            o.position = sb.map.nearest_walkable(h.position + Vector2(3000, 3000))
    e.max_hp = 99999
    e.hp = 99999
    e.position = sb.map.nearest_walkable(h.position + Vector2(140, 0))
    var p0 := e.position
    var hp0 := h.hp
    for i in 150:
        sb.tick(1.0 / 30.0)
    print("enemy %s moved %.0f px, state %s, hero hp %d -> %d, enemy alive %s" % [e.type_id, e.position.distance_to(p0), str(e.state), hp0, h.hp, str(e.alive)])
    get_tree().quit(0)
