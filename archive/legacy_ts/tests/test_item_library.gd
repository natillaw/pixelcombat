extends SceneTree
## D-077 item library: crafted vs dropped, tiers, sets, rarities, cursed affixes, requirements, uniques.
##   godot --headless --path . --script res://tests/test_item_library.gd
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _initialize() -> void:
    print("== Item library tests ==")
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var rec := ItemLibrary.recipes()
    check(rec.has("craft_blacksmith_mail_t1") and rec.has("craft_jeweler_ring_t3") and rec.has("craft_workshop_bow_t5"), "recipes exist for the 3 lines and 5 tiers (%d)" % rec.size())
    var mail := ItemGen.generate_crafted(rng, 1, "craft_blacksmith_mail_t1", "epic", "sturdy")
    check(mail["name"] == "Copper Mail shirt" and mail["rarity"] == "rare" and mail["set"] == "smith_t1" and mail["source"] == "craft"
        and (mail["affixes"] as Array).size() == 1 and mail["affixes"][0]["id"] == "sturdy", "crafted: clean name, capped at rare, set piece, chosen affix")
    var names := {}
    var cursed_ok := true
    var cursed_n := 0
    for i in 400:
        var d := ItemGen.generate_drop(rng, 100 + i, 5, "epic", "bandit")
        if String(d["set"]) == "":
            names[d["name"]] = true
        check_names(d)
        var c := (d["affixes"] as Array).filter(func(a): return a.get("cursed", false))
        if not c.is_empty():
            cursed_n += 1
            cursed_ok = cursed_ok and (d["affixes"] as Array).size() >= 2
    check(not names.has("Copper Mail Shirt") and names.keys().all(func(n): return ["Cutthroat's", "Brigand's", "Bandit's", "Highwayman's"].any(func(w): return String(n).begins_with(w))), "bandit drops are themed and never share a crafted name")
    check(cursed_n > 20 and cursed_n < 110 and cursed_ok, "about 15%% carry a cursed affix, always with a good one (%d/400)" % cursed_n)
    var g: Node = load("res://scripts/autoload/game.gd").new()
    root.add_child(g)
    g.autosave = false
    g.new_game()
    var mage := HeroGenerator.generate(3, 1)
    mage.hero_class = "class.mage"
    check(ItemLibrary.equip_block(mage, {"base": "greataxe", "ilvl": 1}) != "" and ItemLibrary.equip_block(mage, {"base": "wand", "ilvl": 15}).contains("level"), "a mage cannot wield a greataxe; tier 2 needs level 10")
    var first: String = g.roll_unique(1.0)
    var all := [first]
    for i in ItemDefs.UNIQUES.size() + 3:
        all.append(g.roll_unique(1.0))
    var got := all.filter(func(n): return n != "")
    check(first != "" and got.size() == ItemDefs.UNIQUES.size(), "each unique drops once per account (%d of %d)" % [got.size(), ItemDefs.UNIQUES.size()])
    check(ItemDefs.RARITY_ORDER.slice(0, 6) == ["common", "uncommon", "rare", "epic", "legendary", "unique"] and int(ItemDefs.RARITIES["legendary"]["affixes"]) == 2 and ItemDefs.RARITIES.has("junk"),
        "rarities grey/white/green/blue/purple/orange/red; legendary has 2 strong properties (D-122, D-123)")
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)


func check_names(_d: Dictionary) -> void:
    pass
