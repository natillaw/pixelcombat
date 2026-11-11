class_name ArtPalette
extends RefCounted
## The official palette (D-055, D-063), sampled from Caz's heroes and the project kit
## (assets/pixel/ui/ts_kit, outline #190657). The UI, tinted VFX and floating texts only use colours
## from here, so every screen speaks the same visual language.

const OUTLINE := Color("190657")          # every contour (heroes, kit, processed creatures)
const INK := Color("1e130b")              # darkest fill (deep panels, shadows behind text); D-075 wood UI

# UI surfaces (D-075, CraftPix basic UI: dark wood panels, parchment insets, green buttons)
const PANEL := Color("5a3a22")
const PANEL_LIGHT := Color("7a5130")
const PANEL_RIM := Color("2e1b0e")
const PARCHMENT := Color("e8d3a2")

# ramps (dark -> light)
const BLUE := [Color("1b2a6b"), Color("2f4fb0"), Color("4a86e8"), Color("8fc4ff")]
const GOLD := [Color("6b3a12"), Color("b8661e"), Color("f2a83b"), Color("ffe08a")]
const SKIN := [Color("7a3f2e"), Color("c47a55"), Color("f0b78f"), Color("ffe1c6")]
const STONE := [Color("2c2a3a"), Color("55536b"), Color("8c8aa3"), Color("c9c7d9")]
const GREEN := [Color("1d3d1f"), Color("2f6b2c"), Color("5aa83f"), Color("a6e07a")]
const RED := [Color("4a0f1c"), Color("9e2a2b"), Color("e04a3f"), Color("ff9b8a")]

# text
const TEXT := Color("f4ecd8")
const TEXT_MUTED := Color("d6c4a0")
const TEXT_ACCENT := GOLD[3]
const TEXT_BAD := RED[3]
const TEXT_GOOD := GREEN[3]

# gameplay meanings (never colour alone: icons / text go with them, ART_DIRECTION accessibility)
const HP := Color("e04a3f")
const MANA := Color("4a86e8")
const STAMINA := Color("f2a83b")
const XP := Color("a66cff")
const HEAL := Color("7fe07a")
const CRIT := Color("ffd23f")
const BLOCK := Color("8fc4ff")
const DAMAGE_TAKEN := Color("ff8a6b")

## The six item/hero rarities of the kit (D-039): common grey, uncommon green, rare blue, epic purple,
## legendary gold, mythic red. Index = rarity order.
const RARITY_IDS := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
const RARITY := {
    "common": Color("9aa0b3"), "uncommon": Color("5ccf5a"), "rare": Color("4a9cff"),
    "epic": Color("b36cff"), "legendary": Color("ffbf3f"), "mythic": Color("ff4f5e"),
}


## Hero stars -> rarity id for frames and summon effects (5-star cap for now, D-062).
static func rarity_of_stars(stars: int) -> String:
    return RARITY_IDS[clampi(stars - 1, 0, RARITY_IDS.size() - 1)]


static func rarity_color(id: String) -> Color:
    return RARITY.get(id, RARITY["common"])
