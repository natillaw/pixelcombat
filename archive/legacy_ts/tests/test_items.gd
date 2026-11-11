extends SceneTree
## Equipment (D-039): generation (rarity, affix ranges, uniques, mythic, sets), stats, two-handed and
## ring rules, stash capacity, salvage, tower loot, crafting quality, determinism.
##   godot --headless --path . --script res://tests/test_items.gd

var fails := 0


func check(cond: bool, msg: String) -> void:
    if cond:
        print("  PASS  ", msg)
    else:
        print("  FAIL  ", msg)
        fails += 1


func _init() -> void:
    print("== Item tests ==")
    var rng := RandomNumberGenerator.new()
    rng.seed = 1234

    # rarity -> affix count; every affix inside its range; no duplicate affix groups
    var ok_counts := true
    var ok_ranges := true
    var ok_groups := true
    for r in ItemDefs.RARITY_ORDER:
        for i in 40:
            var it := ItemGen.generate(rng, i, 1 + i % 10, r)
            var good: Array = (it["affixes"] as Array).filter(func(x): return not x.get("cursed", false))   # D-077 curses ride along
            if good.size() != int(ItemDefs.RARITIES[r]["affixes"]):
                ok_counts = false
            var groups := {}
            for a in good:
                var d: Dictionary = ItemDefs.AFFIXES[String(a["id"])]
                if groups.has(d["group"]):
                    ok_groups = false
                groups[d["group"]] = true
                var hi := float(d["max"]) * (1.0 + ItemDefs.PER_ILVL * 9.0) * ItemLibrary.CURSE_BOOST * float(ItemDefs.RARITIES[r].get("quality", 1.0)) + 1.0   # D-122 quality
                if float(a["value"]) < float(d["min"]) * 0.99 - 0.5 or float(a["value"]) > hi:
                    ok_ranges = false
                if not (d["kinds"] as Array).has(String(ItemDefs.BASES[String(it["base"])]["kind"])):
                    ok_ranges = false
    check(ok_counts, "each rarity rolls its number of affixes")
    check(ok_ranges, "affix values stay in range and fit the item kind")
    check(ok_groups, "an item never rolls two affixes of the same group")

    # same seed, same item
    var r1 := RandomNumberGenerator.new()
    r1.seed = 77
    var r2 := RandomNumberGenerator.new()
    r2.seed = 77
    check(ItemGen.generate(r1, 1, 5, "epic") == ItemGen.generate(r2, 1, 5, "epic"), "generation is deterministic for a seed")
    var a1 := ItemGen.generate(rng, 1, 5, "rare", "sword")
    var a2 := ItemGen.generate(rng, 2, 5, "rare", "sword")
    check(a1["affixes"] != a2["affixes"] or a1["stats"] != a2["stats"], "two rare swords of the same level can differ")
    var low := ItemGen.generate(rng, 3, 1, "common", "sword")
    var high := ItemGen.generate(rng, 4, 10, "common", "sword")
    check(int(high["stats"]["atk"]) > int(low["stats"]["atk"]), "deeper item levels give stronger bases")

    # uniques and mythic
    var leg := ItemGen.generate(rng, 5, 5, "unique")
    check(String(leg["unique"]) != "" and not (leg["power"] as Dictionary).is_empty() and String(leg["name"]) == String(ItemDefs.UNIQUES[String(leg["unique"])]["name"]), "a unique (red, D-077) is a named piece with its own power")
    var myth := ItemGen.generate(rng, 6, 5, "mythic")
    var u: Dictionary = ItemDefs.UNIQUES[String(myth["unique"])]["power"]
    var stronger := false
    for k in u:
        if typeof(u[k]) == TYPE_FLOAT and k != "chance" and k != "dur" and float(myth["power"][k]) > float(u[k]):
            stronger = true
    check(String(myth["name"]).begins_with("Mythic") and (stronger or u.keys().all(func(k): return typeof(u[k]) != TYPE_FLOAT or k == "chance" or k == "dur" or is_zero_approx(float(u[k])))), "a mythic is a stronger variant of a unique")

    # stats, proficiency, sets
    var base := CombatRules.derive({"fue": 10, "agi": 10, "vit": 10, "int": 10, "tem": 10}, "class.warrior")
    var sword := ItemGen.generate(rng, 7, 1, "common", "sword")
    var with_sword := ItemDefs.apply_equipment(base, {"main_hand": sword}, "class.warrior")
    var mage_sword := ItemDefs.apply_equipment(CombatRules.derive({"fue": 10, "agi": 10, "vit": 10, "int": 10, "tem": 10}, "class.mage"), {"main_hand": sword}, "class.mage")
    var mage_base := CombatRules.derive({"fue": 10, "agi": 10, "vit": 10, "int": 10, "tem": 10}, "class.mage")
    check(int(with_sword["atk"]) - int(base["atk"]) > int(mage_sword["atk"]) - int(mage_base["atk"]), "a trained user gets more out of a weapon than an untrained one")
    var warden := {}
    for b in ["helm", "mail", "shield"]:
        var it := ItemGen.generate(rng, 10 + warden.size(), 3, "rare", b)
        it["set"] = "warden"
        warden[ItemDefs.slots_for(b)[0]] = it
    var two := warden.duplicate()
    two.erase("off_hand")
    var s2 := ItemDefs.apply_equipment(base, two, "class.warrior")
    var s3 := ItemDefs.apply_equipment(base, warden, "class.warrior")
    check(not (s2["mods"] as Dictionary).has("shield_mult") and float(s3["mods"].get("shield_mult", 1.0)) > 1.0, "the 3-piece set bonus changes how shields work")
    var plain := {}
    for k in two:
        plain[k] = (two[k] as Dictionary).duplicate()
        plain[k]["set"] = ""
    check(int(s2["hp"]) > int(ItemDefs.apply_equipment(base, plain, "class.warrior")["hp"]), "2 set pieces give their bonus (+max HP)")
    var ember := ItemGen.generate(rng, 20, 3, "legendary", "sword")
    ember["unique"] = "emberbrand"
    ember["power"] = ItemDefs.UNIQUES["emberbrand"]["power"]
    var procs: Array = ItemDefs.apply_equipment(base, {"main_hand": ember}, "class.warrior")["mods"].get("procs", [])
    check(procs.size() == 1 and String(procs[0]["on_hit_status"]) == "burn", "a unique's power reaches combat (on-hit burn)")

    # stash, equip rules, salvage, loot
    var g: Node = load("res://scripts/autoload/game.gd").new()
    g.autosave = false
    g.save_path = "user://test_items.json"
    g.rng.seed = 9
    g.new_game()
    g.gems = 100000
    var h: HeroData = g.pull(1)[0]
    var axe := ItemGen.generate(rng, g._next_uid(), 2, "common", "greataxe")
    var shield := ItemGen.generate(rng, g._next_uid(), 2, "common", "shield")
    var sw := ItemGen.generate(rng, g._next_uid(), 2, "common", "sword")
    var ring_a := ItemGen.generate(rng, g._next_uid(), 2, "common", "ring")
    var ring_b := ItemGen.generate(rng, g._next_uid(), 2, "common", "ring")
    for it in [axe, shield, sw, ring_a, ring_b]:
        g.stash.append(it)
    check(g.equip(h, int(sw["uid"])) == "" and g.equip(h, int(shield["uid"])) == "", "sword and shield are equipped")
    check(g.equip(h, int(axe["uid"])) == "" and h.equipment.has("main_hand") and not h.equipment.has("off_hand") and g.stash_index(int(shield["uid"])) >= 0 and g.stash_index(int(sw["uid"])) >= 0, "a two-handed axe frees the off hand; both old items go back to the stash")
    check(g.equip(h, int(shield["uid"])) == "" and not h.equipment.has("main_hand") and g.stash_index(int(axe["uid"])) >= 0, "a shield takes the off hand back from the two-handed weapon")
    # D-060: one ring slot is open for now (ring2 opens later): a second ring swaps with the first
    check(g.equip(h, int(ring_a["uid"])) == "" and g.equip(h, int(ring_b["uid"])) == "" and h.equipment.has("ring1") and not h.equipment.has("ring2")
        and g.stash_index(int(ring_a["uid"])) >= 0, "one open ring slot: a second ring swaps the first back to the stash (D-060)")
    check(ItemDefs.slot_open("hands") and not ItemDefs.slot_open("ring2") and ItemDefs.slot_open("special") and ItemDefs.slot_open("bag") and ItemDefs.ACTIVE_SLOTS.size() == 11,
        "11 equipment slots are open (D-077: hands and trinket; D-124: bag); ring2 stays locked")
    var in_stash: int = g.stash.size()
    var total: int = in_stash + h.equipment.size()
    check(g.unequip(h, "ring1") == "" and g.stash.size() + h.equipment.size() == total, "unequipping moves the item without copying it")
    g.equip(h, int(ring_b["uid"]))
    var ingot0: int = int(g.hq_outputs["ingot"])
    g.salvage(int(axe["uid"]))
    check(g.stash_index(int(axe["uid"])) < 0 and int(g.hq_outputs["ingot"]) > ingot0, "salvage turns an item into ingots")
    while g.stash.size() < g.stash_cap():
        g.stash.append(ItemGen.generate(rng, g._next_uid(), 1, "common"))
    check(g.unequip(h, "ring1") != "" and h.equipment.has("ring1"), "a full stash refuses more items (nothing is lost)")
    var r10: Dictionary = g.complete_floor(10, "boss")
    check(int(r10["left_behind"]) > 0 and (r10["items"] as Array).is_empty(), "tower loot that does not fit is reported as left behind")
    g.stash.clear()
    var r10b: Dictionary = g.complete_floor(10, "boss")
    check(int(r10["left_behind"]) >= 3, "the first clear of the floor-10 boss drops several items (%d)" % int(r10["left_behind"]))
    check((r10b["items"] as Array).size() == 1 and int(r10b["starsteel"]) == 0, "D-066: a replay of a cleared floor pays one item and no rarities")
    var best := ""
    for it in g.stash:
        if ItemDefs.RARITY_ORDER.find(String(it["rarity"])) >= 2:
            best = String(it["rarity"])
    check(best != "", "the boss guarantees at least one rare or better")
    var uids := {}
    var dup := false
    for it in g.stash:
        if uids.has(int(it["uid"])):
            dup = true
        uids[int(it["uid"])] = true
    check(not dup, "every item has a unique id")
    check(g.pack_consumable(h, "potion") == "" and int(h.bag["potion"]) == 1, "a potion goes from storage into the hero's bag")
    check(g.pack_consumable(h, "grain") != "", "only carryable consumables fit in the bag")

    # crafting quality: smith level and forge level work together
    var cr := RandomNumberGenerator.new()
    cr.seed = 5
    var app := {}
    var master := {}
    var big_forge_apprentice := {}
    for i in 200:
        app[ItemGen.craft_rarity(cr, 0, 1)] = true
        master[ItemGen.craft_rarity(cr, 10, 5)] = true
        big_forge_apprentice[ItemGen.craft_rarity(cr, 1, 5)] = true
    check(not app.has("rare") and not app.has("epic"), "an apprentice in a basic forge makes only common/uncommon gear")
    check(master.has("epic"), "a master smith in a great forge can make epic gear")
    check(not big_forge_apprentice.has("rare") and not big_forge_apprentice.has("epic"), "a great forge does not make an apprentice a master")

    # owner 2026-11-02: jeweller variety and trinkets with chance-based passives per class
    var base_st := {"hp": 100, "atk": 5, "mag": 0, "def": 0, "mres": 0, "crit": 0.0, "status_resist": 0.0, "interval": 1.0, "move": 70.0}
    var rune := {"base": "blood_rune", "stats": {"hp": 6}}
    var w_st: Dictionary = ItemDefs.apply_equipment(base_st, {"special": rune}, "class.warrior")
    var m_st: Dictionary = ItemDefs.apply_equipment(base_st, {"special": rune}, "class.mage")
    check(((w_st["mods"] as Dictionary).get("trinket_procs", []) as Array).size() == 1, "a warrior's blood rune carries its passive")
    check(not (m_st["mods"] as Dictionary).has("trinket_procs"), "a trinket passive only works for its classes")
    var jewels: Array = ItemDefs.BASES.keys().filter(func(b): return String(ItemDefs.BASES[b]["kind"]) == "jewel")
    check(jewels.size() >= 14 and jewels.all(func(b): return ItemIcons.RPG.has(String(b)) and ItemLibrary.recipes().has(ItemLibrary.recipe_id("jeweler", String(b), 1))),
        "every jewel and trinket has its own icon and a jeweller recipe")
    var trinkets: Array = ItemDefs.BASES.keys().filter(func(b): return (ItemDefs.BASES[b] as Dictionary).has("proc"))
    check(trinkets.size() >= 8 and trinkets.all(func(b): return ItemDefs.proc_text(String(b)) != "" and ItemDefs.TRINKET_PROCS.has(String(ItemDefs.BASES[b]["proc"]["type"]))),
        "every trinket passive has a description")
    var classes_covered := {}
    for b in trinkets:
        for c in ItemDefs.BASES[b]["classes"]:
            classes_covered[c] = true
    check(["class.warrior", "class.rogue", "class.archer", "class.mage", "class.cleric"].all(func(c): return classes_covered.has(c)), "every combat class has its own trinket")

    g.free()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    quit(1 if fails > 0 else 0)
