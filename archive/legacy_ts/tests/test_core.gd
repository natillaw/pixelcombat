extends SceneTree
## Headless checks for the core systems. Run from the project folder:
##   godot --headless --path . --script res://tests/test_core.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _init() -> void:
    print("== Core tests ==")
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345

    # 1. gacha rates + pity
    var counts := [0, 0, 0, 0, 0]
    var p4 := 0
    var p5 := 0
    var gap4 := 0
    var gap5 := 0
    var max_gap4 := 0
    var max_gap5 := 0
    var n := 100000
    var banner := SummonConfig.default_banner()
    var PITY_4: int = banner["pity4"]
    var PITY_5: int = banner["pity5"]
    for i in n:
        var r := Gacha.roll_stars(rng, p4, p5, banner)
        var s: int = r["stars"]
        counts[s - 1] += 1
        p4 = r["pity4"]
        p5 = r["pity5"]
        gap4 = 0 if s >= 4 else gap4 + 1
        gap5 = 0 if s == 5 else gap5 + 1
        max_gap4 = maxi(max_gap4, gap4)
        max_gap5 = maxi(max_gap5, gap5)
    print("  rates: ", counts.map(func(c): return snappedf(100.0 * c / n, 0.1)))
    check(max_gap4 <= PITY_4 - 1, "4-star pity never exceeded (max gap %d)" % max_gap4)
    check(max_gap5 <= PITY_5 - 1, "5-star pity never exceeded (max gap %d)" % max_gap5)
    check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4], "rarity ordering sane")

    # 2. determinism
    var a := HeroGenerator.generate(987654321, 4)
    var b := HeroGenerator.generate(987654321, 4)
    check(a.to_dict() == b.to_dict(), "same seed + stars -> identical hero")

    # 3. class rules
    var invalid_class := 0
    var commoner_seen := false
    for i in 2000:
        var h1 := HeroGenerator.generate(i * 7919 + 13, 1 + (i % 2))
        if not HeroTables.CLASSES.has(h1.hero_class):
            invalid_class += 1
        if h1.hero_class == "class.commoner":
            commoner_seen = true
    check(invalid_class == 0, "all generated heroes have valid fundamental classes")
    check(commoner_seen, "commoners appear frequently in summons")

    # 4. uniqueness of looks
    var sigs := {}
    var dups := 0
    for i in 5000:
        var h := HeroGenerator.generate(i * 1000003 + 99, 1 + (i % 5))
        var sg := h.signature()
        if sigs.has(sg):
            dups += 1
        sigs[sg] = true
    check(dups == 0, "5000 heroes, no duplicate looks (%d dups)" % dups)

    # 5. rarity affects layers
    var layer_sum := [0, 0, 0, 0, 0]
    for st in range(1, 6):
        for i in 500:
            var hh := HeroGenerator.generate(i * 31 + st * 100003, st)
            for k in ["hat", "held", "facial_hair"]:
                if String(hh.appearance[k]) != "":
                    layer_sum[st - 1] += 1
    print("  extra layers per 500 heroes by star: ", layer_sum)
    check(layer_sum[4] > layer_sum[2] and layer_sum[2] > layer_sum[0], "higher stars get more sprite layers")

    # 6. xp / levels / promotion
    var h5 := HeroGenerator.generate(4242, 1)
    check(h5.level_cap() == 10, "1-star cap is 10")
    var gained := h5.add_xp(100000)
    check(h5.level == 10 and gained == 9, "levels up to the cap and stops (level %d)" % h5.level)
    check(h5.can_promote(), "can promote at cap")
    h5.promote()
    check(h5.stars == 2 and h5.level_cap() == 20, "promotion raises star and cap")
    h5.add_xp(100000)
    h5.promote()
    check(h5.stars == 3 and h5.traits.size() == 2 and h5.passives.size() == 2, "traits/passives grow with stars (%d/%d)" % [h5.traits.size(), h5.passives.size()])

    # 6b. F-007 regression: a classless hero (e.g. a migrated legacy class) can reach 3 stars
    var legacy := HeroGenerator.generate(777, 2)
    legacy.hero_class = "class.none"
    legacy.add_xp(100000)
    legacy.promote()
    check(legacy.stars == 3, "classless hero promotes to 3 stars without crashing")

    # 7. save round-trip (64-bit seed survives JSON)
    var h6 := HeroGenerator.generate(0x7123456789ABCDEF, 5)
    var txt := JSON.stringify(h6.to_dict())
    var h7 := HeroData.from_dict(JSON.parse_string(txt))
    check(h7.hero_seed == 0x7123456789ABCDEF and JSON.stringify(h7.to_dict()) == JSON.stringify(h6.to_dict()), "hero survives JSON save/load")

    # 8. game singleton logic (not added to the tree, no autosave)
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.rng.seed = 777
    g.gems = 2000
    var multi_cost := SummonConfig.cost_for(SummonConfig.default_banner(), 10)
    var got: Array = g.pull(10)
    check(got.size() == 10 and g.gems == 2000 - multi_cost and g.heroes.size() == 10, "x10 pull costs %d gems and adds 10 heroes" % multi_cost)
    var ids := {}
    for hh in got:
        ids[hh.id] = true
    check(ids.size() == 10, "pulled heroes are all distinct")
    g.assign_party(0, got[0].id)
    g.assign_party(3, got[0].id)
    check(g.party[0] == "" and g.party[3] == got[0].id, "a hero can only sit in one slot")
    var snapshot := {"version": 1, "gems": g.gems, "stones": g.stones, "books": g.books, "pity4": g.pity4, "pity5": g.pity5, "party": g.party, "heroes": got.map(func(x): return x.to_dict())}
    var g2: Node = load("res://scripts/autoload/game.gd").new()
    g2.autosave = false
    g2.apply_save(JSON.parse_string(JSON.stringify(snapshot)))
    check(g2.heroes.size() == 10 and g2.party[3] == got[0].id and g2.gems == 2000 - multi_cost, "full save state restores")
    var broke: Node = load("res://scripts/autoload/game.gd").new()
    broke.autosave = false
    broke.gems = 5
    check(broke.pull(1).is_empty(), "pull with too few gems does nothing")
    g.free(); g2.free(); broke.free()

    # 9. sprites compose (needs imported assets)
    var h8 := HeroGenerator.generate(555, 5)
    var img := SpriteComposer.compose_frame(h8.appearance, 0, 0)
    check(img.get_size() == Vector2i(48, 48) and not img.is_invisible(), "frame composes and is not empty")
    var sheet := SpriteComposer.compose_sheet(h8.appearance)
    check(sheet.get_size() == Vector2i(576, 384), "full sheet composes")
    var frames := SpriteComposer.build_frames(h8)
    check(SpriteComposer.ANIMS.keys().all(func(n): return frames.has_animation(n)), "SpriteFrames have every animation the game plays (LPC look: %s)" % str(SpriteComposer.uses_lpc(h8)))

    # contact sheet for eyeballing: 5 rows (stars) x 8 heroes
    var out := Image.create(8 * 48, 5 * 48, false, Image.FORMAT_RGBA8)
    out.fill(Color(0.2, 0.18, 0.3))
    for st in range(1, 6):
        for i in 8:
            var hx := HeroGenerator.generate(1000 + i * 17 + st * 101, st)
            var fr := SpriteComposer.compose_frame(hx.appearance, 0, 0)
            out.blend_rect(fr, Rect2i(0, 0, 48, 48), Vector2i(i * 48, (st - 1) * 48))
    out.save_png("/tmp/contact_sheet.png")

    # --- slower XP (2026-10-31): a normal floor < 1 level; MVP + secret ≈ 1 level ---------------
    for lv in [1, 5, 10]:
        var xa := HeroGenerator.generate(900 + lv, 1)
        var xb := HeroGenerator.generate(950 + lv, 1)
        xa.level = lv
        xb.level = lv
        var ents := [{"hero": xa, "alive": true, "contrib": {"damage": 500.0}}, {"hero": xb, "alive": true, "contrib": {"damage": 50.0}}]
        var fl := maxi(1, lv - 1)
        var normal := ExpeditionResults.compute(ents, "success", fl, 2000)
        var frac_n := float(normal["xp"][xb.id]) / float(xb.xp_to_next())
        check(frac_n < 1.0 and frac_n >= 0.2, "lv %d: a normal floor gives %.2f of a level (< 1)" % [lv, frac_n])
        var special := ExpeditionResults.compute(ents, "success", fl, 2000, true)
        var frac_s := float(special["xp"][xa.id]) / float(xa.xp_to_next())
        check(special["mvp"] == xa and frac_s >= 0.85 and frac_s <= ProgressionDefs.BONUS_CAP_FRAC + 0.01, "lv %d: MVP + secret gives %.2f of a level (≈ 1)" % [lv, frac_s])
        var wild := ExpeditionResults.compute(ents, "escaped", -1, 2000)
        check(int(wild["xp"][xb.id]) < int(normal["xp"][xb.id]), "lv %d: the Wilds pay less XP than a floor" % lv)

    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
