extends SceneTree
## Scale audit (game feel report): measures the OPAQUE pixels of the hero, every creature and every
## area effect, and compares area effects with the real radius of their skill. Read-only, prints a table.
##   godot --headless --path . --script res://tools/measure_scale.gd


func _opaque(tex: Texture2D) -> Rect2i:
    if tex == null:
        return Rect2i()
    var img := tex.get_image()
    if img == null:
        return Rect2i()
    if img.is_compressed():
        img.decompress()
    return img.get_used_rect()


func _initialize() -> void:
    var h := HeroGenerator.generate(101, 3)
    var hf := SpriteComposer.build_frames(h)
    var hr := _opaque(hf.get_frame_texture("idle_down", 0))
    print("HERO  frame=%d opaque=%dx%d" % [SpriteComposer.FRAME, hr.size.x, hr.size.y])
    var ids: Array = []
    for f in TowerExpedition.FLOORS.values():
        for id in f["foes"]:
            if not ids.has(id):
                ids.append(id)
    ids.append_array(EnemySprites.IDS)
    for id in ids:
        var sf := EnemySprites.build_frames(String(id))
        if sf == null:
            print("ENEMY %-16s MISSING ART" % id)
            continue
        var r := _opaque(sf.get_frame_texture("idle", 0))
        var s := EnemySprites.scale_for(String(id))
        print("ENEMY %-16s frame=%dx%d opaque=%dx%d (x%.1f)  vs hero h: %.2f  size_class=%s" % [id,
            sf.get_frame_texture("idle", 0).get_width(), sf.get_frame_texture("idle", 0).get_height(),
            r.size.x, r.size.y, s, float(r.size.y) * s / maxf(1.0, float(hr.size.y)), CombatRules.size_class_of(String(id))])
    for sid in SkillDefs.SKILLS:
        var sk: Dictionary = SkillDefs.SKILLS[sid]
        var fx: Dictionary = CombatVFX.SKILL_FX.get(sid, {})
        var t := String(sk["target"])
        if t != "self_aoe" and t != "target_aoe":
            continue
        var radius := float(sk.get("radius", sk["range"]))
        var parts: Array = []
        for k in fx.get("area", []):
            var f := CombatVFX.frames_for(String(k))
            if f == null:
                parts.append("%s=MISSING" % k)
                continue
            var r := _opaque(f.get_frame_texture("fx", mini(2, f.get_frame_count("fx") - 1)))
            var area_scale := CombatVFX.area_scale(String(k), radius)
            parts.append("%s=%.0f" % [k, float(r.size.x) * float(CombatVFX.FX[k][2]) * area_scale * 0.5])
        print("SKILL %-16s %-10s radius=%.0f  visual half-width: %s" % [sid, t, radius, ", ".join(parts)])
    quit()
