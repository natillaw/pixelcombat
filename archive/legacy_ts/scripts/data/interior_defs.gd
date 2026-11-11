class_name InteriorDefs
extends RefCounted
## Owner, 2026-10-31: buildings you can enter. Clicking a building in the town shows its interior
## (scenes baked from the CraftPix Tiled maps by tools/bake_tmx.py into assets/pixel/interiors/) with
## the heroes assigned to it standing at their work spots. Nobody assigned = nothing is made there.
## spots = where workers stand, in pixels of the baked picture (the feet). Outdoor buildings (farm,
## lumber camp, mine, warehouse, tower gate) have no interior.

const ROOT := "res://assets/pixel/interiors/"
const SCENES := {
    "smithy": {"png": "smithy_interior", "spots": [[150, 112], [118, 128], [190, 128]]},
    "chapel": {"png": "chapel_interior", "spots": [[176, 150], [140, 170], [212, 170]]},
    "home": {"png": "home_interior", "spots": [[200, 230], [170, 210], [240, 210], [300, 150]]},
    "guild": {"png": "guild_hall_1f", "spots": [[168, 110], [130, 150], [210, 150]]},
    "guild_upper": {"png": "guild_hall_2f", "spots": [[168, 110], [130, 150], [210, 150]]},
    "temple": {"png": "temple_interior", "spots": [[176, 150], [140, 175], [212, 175]]},
}
const BY_BUILDING := {
    "blacksmith": "smithy", "workshop": "smithy", "jeweler": "smithy",
    "alchemy": "chapel", "infirmary": "chapel",
    "kitchen": "home", "common": "home", "dorm_1": "home", "dorm_2": "home", "dorm_3": "home", "dorm_4": "home",
    "town_hall": "guild", "war_room": "guild", "barracks": "guild", "training_grounds": "guild", "library": "guild_upper",
    "summon_circle": "temple", "memorial": "temple", "ascension": "temple",
}


## The building seen from outside in the town (baked from the same packs, ground excluded). Drawn at
## x1, bottom-centre on the plot's door; buildings not listed keep the procedural house.
const EXTERIOR := {
    "blacksmith": "bld_smithy", "workshop": "bld_smithy", "jeweler": "bld_home",
    "infirmary": "bld_chapel", "alchemy": "bld_chapel", "ascension": "bld_chapel", "library": "bld_chapel",
    "town_hall": "bld_chapel", "kitchen": "bld_home", "common": "bld_home", "dorm_1": "bld_home", "dorm_2": "bld_home",
    "dorm_3": "bld_home", "dorm_4": "bld_home", "barracks": "bld_home", "war_room": "bld_home", "farm": "bld_home",
    "warehouse": "bld_home", "memorial": "bld_temple", "summon_circle": "bld_temple",
}


static var _ext_cache := {}


static func exterior_for(building_id: String) -> Texture2D:
    var n := String(EXTERIOR.get(building_id, ""))
    if n == "" or not ResourceLoader.exists(ROOT + n + ".png"):
        return null
    if not _ext_cache.has(n):
        var img := (load(ROOT + n + ".png") as Texture2D).get_image()
        img.convert(Image.FORMAT_RGBA8)
        _ext_cache[n] = ImageTexture.create_from_image(img)   # drawn like the town's procedural houses
    return _ext_cache[n]


static func scene_for(building_id: String) -> Dictionary:
    var key := String(BY_BUILDING.get(building_id, ""))
    if key == "" or not ResourceLoader.exists(ROOT + String(SCENES[key]["png"]) + ".png"):
        return {}
    return SCENES[key]
