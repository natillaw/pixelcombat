extends Control
## Pista D (D-120..D-129): loot on the bodies, F to loot, backpacks, junk, rarities, greed, class armour,
## bags, meals and books.
##   godot --headless --path . res://tests/smoke_loot.tscn --quit-after 3000
const DT := 1.0 / 30.0
var fails := 0


func check(cond: bool, msg: String) -> void:
    print("  ", "PASS  " if cond else "FAIL  ", msg)
    if not cond:
        fails += 1


func _account(seed_value: int) -> void:
    Game.new_game()
    Game.rng.seed = seed_value
    Game.create_master({"first": "Loot", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()
    for f in range(1, 11):
        Game.tower_cleared[str(f)] = 1


func _screen(f: int) -> SandboxScreen:
    var sb := SandboxScreen.new(f)
    add_child(sb)
    sb.size = Vector2(640, 360)
    sb.set_physics_process(false)
    return sb


func _ready() -> void:
    print("== Loot tests (pista D) ==")
    Game.autosave = false
    Game.save_path = "user://smoke_loot_%d.json" % OS.get_process_id()
    _drops()
    _items()
    _greed()
    _books()
    await _bodies()
    await _meal()
    print("== %s ==" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
    get_tree().quit(1 if fails > 0 else 0)


static func _uid_counter() -> Callable:
    var box := [1000]
    return func():
        box[0] += 1
        return box[0]


## D-120 drops with a fixed seed: same seed, same loot; bosses always carry gear; normal bodies sometimes, junk among it.
func _drops() -> void:
    var a := RandomNumberGenerator.new()
    a.seed = 77
    var b := RandomNumberGenerator.new()
    b.seed = 77
    var la := LootService.body_loot(3, "elite", "bandit", false, 0.0, a, _uid_counter())
    var lb := LootService.body_loot(3, "elite", "bandit", false, 0.0, b, _uid_counter())
    check(JSON.stringify(la) == JSON.stringify(lb), "same seed -> the same body loot")
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var boss := LootService.body_loot(5, "boss", "bandit", true, 0.0, rng, _uid_counter())
    check((boss["items"] as Array).size() == int(LootDefs.CREATURE_ITEMS["boss"]) and (boss["items"] as Array).all(func(it): return not ItemDefs.is_junk(it)),
        "a boss always carries %d pieces of gear, never junk" % int(LootDefs.CREATURE_ITEMS["boss"]))
    var b10 := LootService.body_loot(10, "boss", "bandit", false, 0.0, rng, _uid_counter())
    var axes: Array = (b10["items"] as Array).filter(func(it): return String(it["base"]) == "greataxe" and String(it["rarity"]) == "epic")
    check(axes.size() == 1 and (b10["items"] as Array).size() == int(LootDefs.CREATURE_ITEMS["boss"]) + 1,
        "the floor 10 boss always drops an epic axe on top of its normal loot (D-142)")
    check(is_equal_approx(float(LootDefs.CREATURE_ITEM_CHANCE["normal"]), 0.03) and is_equal_approx(float(LootDefs.CREATURE_ITEM_CHANCE["elite"]), 0.20),
        "gear chance per creature: 3% normal, 20% elite (D-142)")
    var n_items := 0
    var n_junk := 0
    rng.seed = 5
    for i in 2000:
        var l := LootService.body_loot(2, "normal", "bandit", false, 0.0, rng, _uid_counter())
        n_items += (l["items"] as Array).size()
        n_junk += (l["items"] as Array).filter(func(it): return ItemDefs.is_junk(it)).size()
    check(n_items >= 30 and n_items <= 90 and n_junk < n_items, "2000 bandits (gear on 3%%, D-142): %d items on the bodies, %d of them junk" % [n_items, n_junk])
    var greedy := 0
    rng.seed = 5
    for i in 2000:
        greedy += (LootService.body_loot(2, "normal", "bandit", false, 0.5, rng, _uid_counter())["items"] as Array).size()
    check(greedy > n_items, "a greedy squad finds more (%d > %d items)" % [greedy, n_items])
    check(LootService.creature_rank(false, "leader", "") == "elite" and LootService.creature_rank(false, "", "shaman") == "elite"
        and LootService.creature_rank(true, "", "") == "boss" and LootService.creature_rank(false, "brute", "") == "normal", "ranks: boss, elite (leader/shaman/caller), normal")


## D-122/D-123/D-126/D-127/D-124: rarities, junk, class armour, new bows/shields/bags and their looks.
func _items() -> void:
    _account(11)
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    var ok := true
    for r in ["common", "uncommon", "rare", "epic", "legendary"]:
        for i in 30:
            var it := ItemGen.generate(rng, i, 5, r, "sword")
            var good := (it["affixes"] as Array).filter(func(x): return not x.get("cursed", false)).size()
            if good != int(ItemDefs.RARITIES[r]["affixes"]) or int(it["stats"]["atk"]) != roundi(6.0 * (1.0 + ItemDefs.PER_ILVL * 4.0) * float(ItemDefs.RARITIES[r]["mult"])):
                ok = false
    check(ok and int(ItemDefs.RARITIES["uncommon"]["affixes"]) == 1 and int(ItemDefs.RARITIES["rare"]["affixes"]) == 2,
        "fixed base stats + 1 (green) or 2 (blue and up) random properties")
    var cols := ["junk", "common", "uncommon", "rare", "epic", "legendary", "unique"].map(func(r): return ItemDefs.rarity_color(r).to_html())
    var uniq := {}
    for c in cols:
        uniq[c] = true
    check(uniq.size() == 7, "seven rarity colours: grey, white, green, blue, purple, orange, red")
    var junk := ItemGen.generate_junk(rng, Game._next_uid(), 3, "bandit")
    var m: HeroData = Game.master()
    Game.stash.append(junk)
    check(ItemDefs.is_junk(junk) and Game.equip(m, int(junk["uid"])) != "", "junk cannot be worn (%s)" % String(junk["name"]))
    var before := int(Game.hq_outputs.get("ore", 0)) + int(Game.hq_outputs.get("hide", 0)) + int(Game.hq_outputs.get("materials", 0))
    var got := Game.salvage(int(junk["uid"]))
    var after := int(Game.hq_outputs.get("ore", 0)) + int(Game.hq_outputs.get("hide", 0)) + int(Game.hq_outputs.get("materials", 0))
    check(not got.is_empty() and after > before and Game.stash_index(int(junk["uid"])) < 0, "junk is salvaged into materials (%s)" % str(got))
    # class armour (D-126)
    var by_class := {}
    for id in Game.heroes:
        by_class[(Game.heroes[id] as HeroData).hero_class] = Game.heroes[id]
    var probe := func(h: HeroData, base: String) -> String:
        return ItemLibrary.equip_block(h, ItemGen.generate(rng, 1, 1, "common", base))
    check(probe.call(m, "mail") == "" and probe.call(m, "leather_vest") == "" and probe.call(m, "robe") != "", "a warrior wears plate and leather, not cloth")
    var mage := HeroGenerator.generate(4242, 2)
    mage.hero_class = "class.mage"
    check(probe.call(mage, "robe") == "" and probe.call(mage, "mail") != "" and probe.call(mage, "leather_vest") != "", "a mage wears only cloth")
    var rogue := HeroGenerator.generate(4243, 2)
    rogue.hero_class = "class.rogue"
    check(probe.call(rogue, "leather_vest") == "" and probe.call(rogue, "boots") == "" and probe.call(rogue, "mail") != "" and probe.call(rogue, "robe") != "",
        "a rogue (and an archer) wear leather only")
    check(String(ItemLibrary.recipes()[ItemLibrary.recipe_id("tannery", "leather_vest", 1)]["prof"]) == "leatherworker"
        and String(ItemLibrary.recipes()[ItemLibrary.recipe_id("tailor", "robe", 1)]["prof"]) == "tailor"
        and String(ItemLibrary.recipes()[ItemLibrary.recipe_id("blacksmith", "mail", 1)]["prof"]) == "blacksmith",
        "blacksmith -> plate, tanner -> leather, tailor -> cloth")
    check((TownTables.info("workshop")["jobs"] as Array).has(ItemLibrary.recipe_id("tannery", "satchel", 1))
        and (TownTables.info("workshop")["jobs"] as Array).has("make_camp_kit") and (TownTables.info("kitchen")["jobs"] as Array).has("cook_stew"),
        "until the town builds them, tanner and tailor work in the workshop; the kitchen cooks the buff meals")
    # every new base has its LPC piece imported (what you wear is what you see)
    var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pixel/lpc/lpc_index.json"))
    var missing: Array = []
    for b in ["recurve", "longbow", "crossbow", "shield", "kite_shield", "bronze_shield", "leather_cap", "leather_vest", "leather_pants", "cloth_pants", "satchel", "backpack"]:
        var lay := ItemVisuals.layer_for({"base": b, "ilvl": 1})
        if lay.is_empty() or not (idx["pieces"] as Dictionary).has(String(lay[0])):
            missing.append(b)
    check(missing.is_empty(), "every new bow, shield, armour and bag shows on the sprite (missing: %s)" % str(missing))
    check(ItemIcons.texture("satchel") != null and ItemIcons.texture("book_xp") != null and ItemIcons.texture("meal_stew") != null, "icons for bags, books and meals")
    # bags: more pack slots
    var sat := ItemGen.generate_crafted(rng, Game._next_uid(), ItemLibrary.recipe_id("tannery", "satchel", 1), "rare")
    Game.stash.append(sat)
    var slots0 := LootService.pack_slots(m)
    check(Game.equip(m, int(sat["uid"])) == "" and LootService.pack_slots(m) == slots0 + 2 and ItemVisuals.equipment_layers(m.equipment).has("bag"),
        "a satchel from the tanner: +2 backpack slots, worn on the back (%d -> %d)" % [slots0, LootService.pack_slots(m)])


## D-125 the greedy trait with a fixed seed.
func _greed() -> void:
    _account(21)
    var h: HeroData = null
    for id in Game.heroes:
        if not (Game.heroes[id] as HeroData).is_master:
            h = Game.heroes[id]
            break
    h.traits.append("trait.greedy")
    var items: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    for i in 12:
        items.append(ItemGen.generate(rng, Game._next_uid(), 2, "uncommon", "dagger"))
    var stash0 := Game.stash.size()
    Game.rng.seed = 999
    var rep := Game.deliver_packs([{"hero": h, "items": items}])
    var kept := int(rep["kept"])
    check(kept > 0 and kept < 12 and Game.stash.size() == stash0 + 12 - kept and h.hoard.size() == kept,
        "a greedy hero keeps some back (%d of 12), the rest reaches the stash" % kept)
    _account(21)
    var h2: HeroData = null
    for id in Game.heroes:
        if not (Game.heroes[id] as HeroData).is_master:
            h2 = Game.heroes[id]
            break
    h2.traits.append("trait.greedy")
    Game.rng.seed = 999
    var rep2 := Game.deliver_packs([{"hero": h2, "items": items.duplicate(true)}])
    check(int(rep2["kept"]) == kept and (rep2["caught"] as Array).size() == (rep["caught"] as Array).size(), "same seed -> the same items kept and the same caught")
    var m: HeroData = Game.master()
    m.traits.append("trait.greedy")
    Game.rng.seed = 999
    check(int(Game.deliver_packs([{"hero": m, "items": [ItemGen.generate(rng, Game._next_uid(), 2, "rare", "sword")]}])["kept"]) == 0, "the Master never keeps loot back")
    for it in h2.hoard:
        it["caught"] = true
    var trust0 := h2.trust
    var n := h2.hoard.size()
    Game.stash.clear()                                     # room for what comes back (a full stash keeps the rest hoarded)
    var sus := Game.hoard_suspects().has(h2)
    var conf := Game.confiscate_hoard(h2)
    check(sus and conf == n and h2.hoard.is_empty() and h2.trust < trust0,
        "caught: the Master confiscates %d of %d item(s); Trust %d -> %d (suspect %s, stash %d/%d)" % [conf, n, trust0, h2.trust, sus, Game.stash.size(), Game.stash_cap()])
    var d := h2.to_dict()
    h2.hoard.append({"uid": 1, "base": "ring", "name": "Ring", "rarity": "rare", "caught": false})
    h2.bonus_skill_choice = 2
    var back := HeroData.from_dict(h2.to_dict())
    check(back.hoard.size() == 1 and back.bonus_skill_choice == 2 and HeroData.from_dict(d).hoard.is_empty(),
        "hoard and bonus skill choices survive a save; old saves default (%d, %d, %d)" % [back.hoard.size(), back.bonus_skill_choice, HeroData.from_dict(d).hoard.size()])


## D-129 books.
func _books() -> void:
    _account(31)
    var m: HeroData = Game.master()
    for b in LootDefs.BOOKS:
        Game.hq_outputs[b] = 2
    var lv := m.level
    check(Game.use_book("book_xp", m) == "" and m.level == lv + 1 and int(Game.hq_outputs["book_xp"]) == 1, "book of experience: one level up")
    check(Game.use_book("book_skill", m) == "" and m.bonus_skill_choice == 1, "skill tome: bonus_skill_choice on the hero (pista A reads it)")
    var worker: HeroData = null
    for id in Game.heroes:
        if not (Game.heroes[id] as HeroData).professions.is_empty():
            worker = Game.heroes[id]
            break
    var prof := String(worker.professions.keys()[0])
    var pl := worker.prof_level(prof)
    check(Game.use_book("book_trade", worker, prof) == "" and worker.prof_level(prof) == pl + 1, "trade manual: +1 level in a profession")
    check(Game.use_book("book_plan", m) != "" and int(Game.hq_outputs["book_plan"]) == 2, "master plan: kept until the town can use it (pista B)")
    check(Game.pack_consumable(m, "camp_kit") != "cannot be carried" and Game.pack_consumable(m, "arrows") != "cannot be carried", "camp kits and arrows can be carried")


## D-120/D-121/D-124 in a real floor: bodies glow, F opens the window, packs, fall, end.
func _bodies() -> void:
    _account(41)
    var sb := _screen(5)
    await get_tree().process_frame
    var tries := 0
    while sb.loot_bags.filter(func(b): return not b.items.is_empty()).is_empty() and tries < sb.enemies.size():
        var e: SandboxEnemy = sb.enemies[tries]
        if e.alive:
            e.die()
        tries += 1
    var bags: Array = sb.loot_bags.filter(func(b): return not b.items.is_empty())
    check(not bags.is_empty(), "killed creatures leave glowing bodies with gear (%d bodies, %d with items)" % [sb.loot_bags.size(), bags.size()])
    if bags.is_empty():
        sb.queue_free()
        return
    var bag: LootBag = bags[0]
    var m: SandboxHero = sb.master_hero
    m.position = bag.position + Vector2(10, 0)
    for e in sb.enemies:
        if e.alive:
            e.position = m.position + Vector2(3000, 3000)        # nobody to fight here
    sb.interact_held = true
    for i in roundi(LootDefs.LOOT_HOLD / DT) + 3:
        sb._tick_interact(DT)
    check(sb._loot_win != null and is_instance_valid(sb._loot_win) and sb._loot_win.bag == bag, "holding F ~1 s next to the body opens the loot window")
    sb.interact_held = false
    var n := bag.items.size()
    var res0 := sb.ledger.duplicate()
    sb.take_loot(bag, -1, m)
    check(sb.pack_of(m).size() == mini(n, LootService.pack_slots(m.hero)), "take all: the items go into the Master's backpack (%d)" % sb.pack_of(m).size())
    # an ally falls: the pack falls with them
    var ally: SandboxHero = sb.heroes[1]
    var ring := ItemGen.generate(RandomNumberGenerator.new(), Game._next_uid(), 2, "rare", "ring")
    sb.pack_of(ally).append(ring)
    ally.went_down.emit(ally)
    var dropped: Array = sb.loot_bags.filter(func(b): return is_instance_valid(b) and b.source == "pack")
    check(sb.pack_of(ally).is_empty() and dropped.size() == 1 and (dropped[0] as LootBag).items.has(ring), "a fallen hero drops their backpack where they fell")
    (dropped[0] as LootBag).position += Vector2(4000, 4000)    # nobody near to pick it up
    var uids: Array = sb.pack_of(m).map(func(it): return int(it["uid"]))
    sb._settle_loot("success")
    check(uids.all(func(u): return Game.stash_index(u) >= 0), "out of the tower: the backpacks go to the Master's stash")
    check(Game.stash_index(int(ring["uid"])) < 0 and int(sb.loot_report.get("lost", 0)) >= 1, "a dropped pack nobody picked up is lost (%d lost)" % int(sb.loot_report.get("lost", 0)))
    check(sb.loot_lines().size() >= 2 and res0 != null, "the result screen lists the loot brought home")
    # AI looting rule: an ally on a body does not loot it while a creature is near; it does once safe
    var foe: SandboxEnemy = sb.enemies.filter(func(e): return e.alive)[0]
    var b2 := sb.drop_loot(sb.heroes[2].position, [ItemGen.generate(RandomNumberGenerator.new(), Game._next_uid(), 2, "rare", "dagger")], {})
    foe.position = sb.heroes[2].position + Vector2(120, 0)
    for i in roundi(2.0 / DT):
        sb._tick_loot(DT)
    var waited := is_instance_valid(b2) and not b2.is_empty()
    foe.position = sb.heroes[2].position + Vector2(3000, 3000)
    for i in roundi(6.0 / DT):                             # it may take a nearer body first
        sb._tick_loot(DT)
    var h2: SandboxHero = sb.heroes[2]
    check(waited and not sb.loot_safe(h2.position + Vector2(3000, 3100)) and sb.loot_safe(h2.position) and b2.is_empty(),
        "allies do not loot with a creature within %d px; they do once it is safe (waited %s, safe %s, looted %s, alive %s, target %s, room %d)"
        % [int(LootDefs.LOOT_SAFE_RADIUS), waited, sb.loot_safe(h2.position), b2.is_empty(), h2.alive, h2.target != null, sb.pack_room(h2)])
    sb.mission_type = "defense"
    var bot := MasterBot.new("tactical")
    var far := sb.drop_loot(sb.master_hero.position + Vector2(150, 0), [ItemGen.generate(RandomNumberGenerator.new(), Game._next_uid(), 2, "rare", "ring")], {})
    check(sb.loot_holds_post() and not bot._loot(sb, sb.master_hero, 0.25) and is_instance_valid(far), "defense/survival: the bot never walks off its post to loot")
    sb.mission_type = "combat"
    check(bot._loot(sb, sb.master_hero, 0.25), "elsewhere, with nothing around, the bot goes for the body")
    sb.queue_free()
    await get_tree().process_frame
    # a wipe: everything in the packs is lost
    var sb2 := _screen(5)
    await get_tree().process_frame
    var lost_it := ItemGen.generate(RandomNumberGenerator.new(), Game._next_uid(), 2, "epic", "sword")
    sb2.pack_of(sb2.master_hero).append(lost_it)
    sb2._settle_loot("failed")
    check(Game.stash_index(int(lost_it["uid"])) < 0 and int(sb2.loot_report["lost"]) >= 1, "a failed expedition loses the backpacks")
    sb2.queue_free()
    await get_tree().process_frame


## D-128: a meal in the bag is eaten at the start: more health for the run.
func _meal() -> void:
    _account(51)
    var m: HeroData = Game.master()
    var sb0 := _screen(5)
    await get_tree().process_frame
    var hp0 := sb0.master_hero.max_hp
    sb0.queue_free()
    await get_tree().process_frame
    Game.hq_outputs["meal_stew"] = 1
    check(Game.pack_consumable(m, "meal_stew") == "", "a hearty stew goes into the bag")
    var sb := _screen(5)
    await get_tree().process_frame
    check(sb.master_hero.max_hp > hp0 and not m.bag.has("meal_stew"), "eaten when the expedition starts: max HP %d -> %d" % [hp0, sb.master_hero.max_hp])
    sb.queue_free()
    await get_tree().process_frame
