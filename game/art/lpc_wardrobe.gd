class_name LpcWardrobe
extends RefCounted
## Overhaul LPC (D-C, D-D): every summoned hero wears the same plain STARTER_OUTFIT; variety is race,
## body, skin, hair, eyes and beard. The class only adds a visual starter weapon (no stats); an equipped
## item replaces the layer of its slot (phase 5). Ids are LpcComposer pieces (tools/lpc_manifest.json).

const STARTER_OUTFIT := {
    "chest": ["shirt_longsleeve", "tan"],
    "legs": ["pants", "brown"],
    "feet": ["shoes_basic", "leather"],
}
const STARTER_WEAPON_BY_CLASS := {
    "class.warrior": "weapon_arming", "class.rogue": "weapon_dagger", "class.archer": "weapon_bow",
    "class.mage": "weapon_staff", "class.cleric": "weapon_staff", "class.commoner": "weapon_dagger", "class.none": "",
}
## Look pools (heroes): every entry exists in the imported sheets.
const SKINS := ["light", "amber", "olive", "taupe", "bronze", "brown", "black"]
const EYES := ["blue", "green", "brown", "gray"]
const HAIR := ["hair_buzzcut", "hair_bob", "hair_plain"]   # solo piezas con licencia de atribucion (docs/ASSET_REGISTRY.md)
const HAIR_COLORS := ["black", "dark_brown", "chestnut", "light_brown", "blonde", "ginger", "gray", "white", "red"]
const BEARD_CHANCE := 0.3             # male bodies only
## Bandit faction colour (D-E): no hero starter piece may use it.
const BANDIT_COLOR := "maroon"


## A deterministic LPC look from an RNG. race = "human" | "elf" (elves add elven ears).
static func random_look(rng: RandomNumberGenerator, race: String = "human") -> Dictionary:
    var body := "male" if rng.randf() < 0.5 else "female"
    var look := {
        "race": race, "body": body,
        "skin": SKINS[rng.randi() % SKINS.size()],
        "eyes": EYES[rng.randi() % EYES.size()],
        "head": "head_human_" + body,
        "ears": "",   # ears_elven retirado: solo ofrecia CC-BY-SA/GPL
        "hair": HAIR[rng.randi() % HAIR.size()],
        "hair_color": HAIR_COLORS[rng.randi() % HAIR_COLORS.size()],
        "beard": "",
    }
    if body == "male" and rng.randf() < BEARD_CHANCE:
        look["beard"] = "beard_trimmed"
    return look


## [piece, variant] list for a look + class, before equipment (LpcComposer sorts by z).
static func layers_for(look: Dictionary, hero_class: String = "", equipment: Dictionary = {}) -> Array:
    var out: Array = [["body", String(look.get("skin", "light"))],
        [String(look.get("head", "head_human_male")), "%s_%s" % [look.get("skin", "light"), look.get("eyes", "blue")]]]
    if String(look.get("ears", "")) != "":
        out.append([String(look["ears"]), String(look.get("skin", "light"))])
    if String(look.get("hair", "")) != "":
        out.append([String(look["hair"]), String(look.get("hair_color", "black"))])
    if String(look.get("beard", "")) != "":
        out.append([String(look["beard"]), String(look.get("hair_color", "black"))])
    var bare := not bool(equipment.get("_items", false))   # D-082b: a hero with items shows only what it wears
    for slot in STARTER_OUTFIT:
        if equipment.has(slot):
            out.append(equipment[slot])
        elif bare:
            out.append(STARTER_OUTFIT[slot])
    for slot in ["head", "hands", "bag"]:             # extra worn pieces (D-D; D-124 the tanner's bag on the back)
        if equipment.has(slot):
            out.append(equipment[slot])
    if equipment.has("head"):
        out = out.filter(func(p): return not String(p[0]).begins_with("hair_"))   # helms and hoods cover the hair
    var weapon := String(equipment.get("main_hand", [STARTER_WEAPON_BY_CLASS.get(hero_class, "") if bare else ""])[0])
    if weapon != "":
        out.append([weapon, String(equipment["main_hand"][1]) if equipment.has("main_hand") else "default"])
    if equipment.has("off_hand"):
        out.append(equipment["off_hand"])
    return out
