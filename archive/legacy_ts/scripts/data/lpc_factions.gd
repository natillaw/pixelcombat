class_name LpcFactions
extends RefCounted
## Overhaul LPC (D-E): the bandit band are LPC humans with one fixed outfit per type and one faction
## colour (maroon scarves, hoods and capes over dark leather). Inside a type only body, skin, hair and
## beard vary (VARIANTS looks per type, from the type's own seed). No hero starter piece uses the
## colour (LpcWardrobe.BANDIT_COLOR, tested).

const COLOR := "maroon"
const VARIANTS := 4
## type -> [[piece, variant], ...] (pieces from tools/lpc_manifest.json) and the attack it plays.
const BANDIT := {
    "bandido_maton": {"outfit": [["shirt_sleeveless", "charcoal"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["bandana", "maroon"], ["weapon_mace", "default"]], "attack": "slash"},
    "bandido_arquero": {"outfit": [["armour_leather", "walnut_iron"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["hood", "maroon"], ["weapon_bow", "default"]], "attack": "shoot"},
    "bandido_degollador": {"outfit": [["armour_leather", "black_iron"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["bandana", "maroon"], ["weapon_dagger", "default"]], "attack": "slash"},
    "bandido_bruto": {"outfit": [["armour_leather", "walnut_iron"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["helmet_barbarian", "iron_maroon"], ["weapon_waraxe", "default"]], "attack": "slash"},
    "bandido_mago": {"outfit": [["shirt_sleeveless", "charcoal"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["hood", "maroon"], ["weapon_staff_red", "default"]], "attack": "spellcast"},
    "bandido_chaman": {"outfit": [["shirt_longsleeve", "tan"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["hood", "maroon"], ["weapon_staff_green", "default"]], "attack": "spellcast"},
    "capitan_bandido": {"outfit": [["armour_leather", "black_iron"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["cape", "maroon"], ["eyepatch", "default"], ["bandana", "maroon"], ["weapon_arming", "default"]], "attack": "slash"},
    "jefe_baron_carmesi": {"outfit": [["armour_plate", "iron"], ["pants", "charcoal"], ["shoes_basic", "leather"], ["cape", "maroon"], ["helmet_horned", "gold"], ["weapon_longsword", "default"]], "attack": "slash", "body": "male"},
}


static func has(id: String) -> bool:
    return BANDIT.has(id)


## The look of the n-th variant of a bandit type (deterministic).
static func look(id: String, n: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(id) + n * 7919
    var lk := LpcWardrobe.random_look(rng, "human")
    if BANDIT[id].has("body"):
        lk["body"] = BANDIT[id]["body"]
        lk["head"] = "head_human_" + String(lk["body"])
    if String(lk["body"]) == "female":
        lk["beard"] = ""
    return lk


## [piece, variant] layers: the variant's body, head, hair and beard, then the fixed outfit.
static func layers(id: String, n: int) -> Array:
    var lk := look(id, n)
    var out: Array = LpcWardrobe.layers_for(lk).filter(func(p): return not LpcWardrobe.STARTER_OUTFIT.values().has(p))
    var outfit: Array = BANDIT[id]["outfit"]
    if outfit.any(func(p): return String(p[0]).begins_with("hood") or String(p[0]).begins_with("helmet")):
        out = out.filter(func(p): return not String(p[0]).begins_with("hair_"))   # a hood or helmet hides the hair
    return out + outfit
