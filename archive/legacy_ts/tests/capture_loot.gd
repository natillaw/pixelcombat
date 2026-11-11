extends Control
## Pista D capture (not pass/fail): bodies glowing in their rarity colour, the "Hold F" ring, the loot
## window, and the new gear on the sprites (kite shield, satchel, leather armour, recurve bow, cloth).
## Needs a real renderer:
##   godot --path . --resolution 1280x720 res://tests/capture_loot.tscn
## CAPTURE_DIR = output folder (default user://captures).


func _ready() -> void:
    var dir := OS.get_environment("CAPTURE_DIR") if OS.get_environment("CAPTURE_DIR") != "" else "user://captures"
    DirAccess.make_dir_recursive_absolute(dir)
    Game.autosave = false
    Game.save_path = "user://capture_loot.json"
    Game.new_game()
    Game.rng.seed = 77
    Game.create_master({"first": "Cap", "last": "Master", "class": "class.warrior", "trait": "trait.stubborn",
        "look": {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}})
    Game.starter_summons()
    for f in range(1, 11):
        Game.tower_cleared[str(f)] = 1
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var gear := {"class.warrior": ["kite_shield", "mail", "satchel"], "class.rogue": ["leather_vest", "leather_pants", "leather_cap", "backpack"],
        "class.archer": ["recurve", "leather_vest"], "class.mage": ["robe", "cloth_pants", "hood"], "class.cleric": ["bronze_shield", "robe"]}
    for id in Game.heroes:
        var h: HeroData = Game.heroes[id]
        h.level = 12
        for b in gear.get(h.hero_class, []):
            var it := ItemGen.generate(rng, Game._next_uid(), 3, "rare", String(b))
            if String(b) in ["satchel", "backpack"]:
                it = ItemGen.generate_crafted(rng, Game._next_uid(), ItemLibrary.recipe_id("tannery", String(b), 1), "common")
            Game.stash.append(it)
            Game.equip(h, int(it["uid"]))
    UIKit.fill(self)
    theme = UIKit.make_theme()
    var sb := SandboxScreen.new(5)
    add_child(sb)
    UIKit.fill(sb)
    for i in 20:
        await get_tree().process_frame
    var m := sb.master_hero
    for i in sb.heroes.size():
        sb.heroes[i].position = sb.map.nearest_walkable(m.position + Vector2(36 * i - 72, 40))
    for e in sb.enemies:
        e.position = m.position + Vector2(5000, 5000)
    var k := 0
    for r in ["junk", "uncommon", "rare", "epic", "legendary"]:
        var it := ItemGen.generate_junk(rng, Game._next_uid(), 3, "bandit") if r == "junk" else ItemGen.generate_drop(rng, Game._next_uid(), 3, r, "bandit")
        sb.drop_loot(sb.map.nearest_walkable(m.position + Vector2(-90 + 45 * k, -50)), [it], {"essence": 1} if k == 0 else {})
        k += 1
    for i in 30:
        await get_tree().process_frame
    var tag := "%dx%d" % [get_viewport().size.x, get_viewport().size.y]
    get_viewport().get_texture().get_image().save_png(dir + "/loot_bodies_%s.png" % tag)
    var bag: LootBag = sb.loot_bags[sb.loot_bags.size() - 1]
    m.position = bag.position + Vector2(8, 6)
    for i in range(1, sb.heroes.size()):                 # allies away, or they loot it first
        sb.heroes[i].position = sb.map.nearest_walkable(m.position + Vector2(-60 * i, 140))
    sb.interact_held = true
    for i in 20:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/loot_hold_%s.png" % tag)
    for i in 40:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png(dir + "/loot_window_%s.png" % tag)
    print("CAPTURED ", ProjectSettings.globalize_path(dir))
    get_tree().quit(0)
