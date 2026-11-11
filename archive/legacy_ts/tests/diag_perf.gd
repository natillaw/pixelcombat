extends Control
## Diagnostic: cost per frame of the minimap cell loop and of one rules tick on floor 5.
func _ready() -> void:
    Game.autosave = false
    Game.save_path = "user://diag_perf.json"
    Game.new_game()
    Game.starter_summons()
    var sb := SandboxScreen.new(5)
    add_child(sb)
    sb.size = Vector2(1280, 720)
    await get_tree().process_frame
    sb.set_physics_process(false)
    var t0 := Time.get_ticks_usec()
    var tex := ExpeditionHud.Minimap.terrain_texture(sb.map)
    print("minimap terrain image: %.2f ms ONCE per mission (was a per-cell loop every frame); per frame: 2 textures + dots" % [float(Time.get_ticks_usec() - t0) / 1000.0])
    t0 = Time.get_ticks_usec()
    for k in 20:
        sb.update_fog()
    print("update_fog incl. fog image (only changed cells): %.2f ms every %.2f s" % [float(Time.get_ticks_usec() - t0) / 20000.0, CombatRules.FOG_EVERY])
    var hud = sb._hud
    t0 = Time.get_ticks_usec()
    for k in 300:
        sb.tick(1.0 / 60.0)
    print("rules tick (5 heroes, %d enemies): %.2f ms" % [sb.enemies.size(), float(Time.get_ticks_usec() - t0) / 300000.0])
    get_tree().quit(0)
