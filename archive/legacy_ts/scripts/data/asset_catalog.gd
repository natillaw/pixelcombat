class_name AssetCatalog
extends RefCounted
## The one catalogue of asset locations (D-063): no other script writes an asset path by hand. Roots of
## the older packs (read by EnemySprites, CombatVFX, CazArt, MapTiles, ForestArt, TownView,
## SpriteComposer) and every new asset with its frame layout. Licences: docs/ASSET_REGISTRY.md.

# --- roots of the packs already in use (unchanged behaviour) -------------------------------------
const ASSETS_ROOT := "res://assets/"
const HERO_LAYERS := "res://assets/sprites/"                         # Caz character generator (D-023: never modified)
const CAZ_TILES := "res://assets/pixel/caz-base/Tiles/"
const CAZ_CHARACTERS := "res://assets/pixel/caz-base/Characters/"
const PACKS := "res://assets/packs/"                                  # SpritePilot, KILN, Sprite Kitchen, Voxel FX
const PIXEL_CRAWLER_ENEMIES := "res://assets/pixel/enemies/pixel-crawler/"
const PIXEL_CRAWLER_TILES := "res://assets/pixel/tilesets/pixel-crawler/"
const VOXEL_CREATURES := "res://assets/packs/voxel-dungeon-pack-full/creatures/sheets/"
const VOXEL_PROPS := "res://assets/packs/voxel-dungeon-pack-full/props/frames/"
const PROCESSED := "res://assets/processed/"
const PROCESSED_OUTLINE := "res://assets/processed/outline/"           # D-055 contour copies
const PROCESSED_CREATURES := "res://assets/processed/creatures/"       # normalised strips (tools/art_cohesion.gd)

# --- new packs (D-063) ------------------------------------------------------------------------
const NINJA_ENEMIES := "res://assets/pixel/enemies/ninja/"
const NINJA_BOSSES := "res://assets/pixel/bosses/ninja/"
const NINJA_FX := "res://assets/pixel/fx/ninja/"
const ENEMY_ANIM_SET := "res://assets/pixel/enemies/enemy_animations_set/"
const PIXEL_DUNGEON := "res://assets/pixel/tilesets/pixel_dungeon/"
const KIT := "res://assets/pixel/ui/ts_kit/"
const DRAGON := "res://assets/pixel/ui/dragon_regalia/"
const SKILL_ICONS := "res://assets/pixel/icons/kurai_skills/SKILL ICONS.png"     # 8 x 6 icons of 32 px
const SKILL_BORDER := "res://assets/pixel/icons/kurai_skills/Gold Skill Border.png"
const ITEM_ICONS := "res://assets/pixel/icons/caz_mv/MV Icons Complete Sheet Free - ALL.png"   # 16 columns of 32 px
const RAVEN_ICONS_32 := "res://assets/pixel/icons/raven/32x32.png"     # 16 columns of 32 px
const FONT_BODY := "res://assets/fonts/m5x7.ttf"                       # 16 px = 1:1 pixels
const FONT_TITLE := "res://assets/fonts/m6x11.ttf"                     # 16 px = 1:1 pixels
const MUSIC := "res://assets/audio/music/xdeviruchi/"                  # title/town/explore/dungeon/battle/boss/results .ogg
const UI_SFX := "res://assets/audio/ui/kenney/"
const SFX := "res://assets/audio/sfx/ninja/"

## Tower creatures drawn from new pixel packs (Phase B). Each source is turned by tools/art_cohesion.gd
## into right-facing strips PROCESSED_CREATURES/<id>/{idle,run,attack,hurt,death}.png (contour + palette),
## missing animations being made in code by EnemySprites. layout:
##   "grid4"  = Ninja monster sheet, 4 columns (down, up, left, right) x 4 walk rows of `frame` px;
##   "char"   = Ninja character: Idle.png / Walk.png (4 dirs) / Attack.png (4 dirs) / Dead.png;
##   "strips" = horizontal strips per animation (`files`), frames of `frame` px, facing right.
## scale = integer drawing scale (pixel art is never scaled by a fraction). recolor = hue shift (degrees).
const CREATURES := {
    "rat": {"src": NINJA_ENEMIES + "Mouse/SpriteSheet.png", "layout": "grid4", "frame": 16, "scale": 2},
    "bat": {"src": NINJA_ENEMIES + "BlueBat/SpriteSheet.png", "layout": "grid4", "frame": 16, "scale": 2},
    "slime_green": {"src": NINJA_ENEMIES + "Slime2/Slime2.png", "layout": "grid4", "frame": 16, "scale": 2},
    "slime_blue": {"src": NINJA_ENEMIES + "Slime/Slime.png", "layout": "grid4", "frame": 16, "scale": 2},
    "mushroom_red": {"src": NINJA_ENEMIES + "Mushroom/mushroom.png", "layout": "grid4", "frame": 16, "scale": 2},
    "mushroom_blue": {"src": NINJA_ENEMIES + "Mushroom2/mushroom2.png", "layout": "grid4", "frame": 16, "scale": 2},
    "mushroom_purple": {"src": NINJA_ENEMIES + "Mushroom2/mushroom2.png", "layout": "grid4", "frame": 16, "scale": 2, "recolor": 70.0},
    "spider": {"src": NINJA_ENEMIES + "SpiderRed/SpriteSheet.png", "layout": "grid4", "frame": 16, "scale": 2},
    "goblin": {"src": NINJA_ENEMIES + "DemonGreen/", "layout": "char", "frame": 16, "scale": 2},
    # big creatures stay at x2-x3: at x4 the 16 px art turned into blocks next to Caz's x1 heroes (review)
    "hobgoblin": {"src": NINJA_ENEMIES + "DemonRed/", "layout": "char", "frame": 16, "scale": 2},
    "orc_brute": {"src": NINJA_ENEMIES + "Bear/SpriteSheet.png", "layout": "grid4", "frame": 16, "scale": 2},
    "golem": {"src": NINJA_ENEMIES + "Grey_Trex/SpriteSheet.png", "layout": "grid4", "frame": 16, "scale": 3},
    # bosses (floors 5 and 10): strips facing the viewer; idle / walk (run) / hit (hurt) / attack
    "orc_chieftain": {"src": NINJA_BOSSES + "DemonCyclop/", "layout": "strips", "frame": 50, "scale": 2,
        "files": {"idle": "Idle.png", "run": "Walk.png", "hurt": "Hit.png"}},
    "warlord": {"src": NINJA_BOSSES + "GiantRacoon/", "layout": "strips", "frame": 60, "scale": 2,
        "files": {"idle": "Idle.png", "run": "Jump.png", "attack": "Attack.png", "hurt": "Charge.png"}},
    # training ground skeletons: complete 32 px strips
    "skeleton_base": {"src": ENEMY_ANIM_SET, "layout": "strips", "frame": 32, "scale": 1,
        "files": {"idle": "enemies-skeleton1_idle.png", "run": "enemies-skeleton1_movement.png", "attack": "enemies-skeleton1_attack.png",
            "hurt": "enemies-skeleton1_take_damage.png", "death": "enemies-skeleton1_death.png"}},
    "skeleton_warrior": {"src": ENEMY_ANIM_SET, "layout": "strips", "frame": 32, "scale": 1,
        "files": {"idle": "enemies-skeleton2_idle.png", "run": "enemies-skeleton2_movemen.png", "attack": "enemies-skeleton2_attack.png",
            "hurt": "enemies-skeleton2_take_damage.png", "death": "enemies-skeleton2_death.png"}},
}


## Kit UI pieces: [path, nine-slice margin or 0, frame width or 0 for single images].
const UI := {
    "panel": [KIT + "ui/panel.png", 4, 0],
    "bar_frame": [KIT + "ui/bar_frame.png", 2, 0],
    "bar_hp": [KIT + "ui/bar_fill_hp.png", 0, 0],
    "bar_mana": [KIT + "ui/bar_fill_mana.png", 0, 0],
    "bar_stamina": [KIT + "ui/bar_fill_stamina.png", 0, 0],
    "bar_xp": [KIT + "ui/bar_fill_xp.png", 0, 0],
    "dragon_frame": [DRAGON + "20240707dragon9SlicesB.png", 12, 0],
    "dragon_frame_big": [DRAGON + "20240707dragon9SlicesA.png", 24, 0],
    "dragon_button": [DRAGON + "20240709dragonButtonA-Sheet.png", 10, 100],   # 4 states: rest, hover, pressed, disabled
    "dragon_header": [DRAGON + "20240707dragonHeaderA.png", 12, 0],
    "dragon_tab": [DRAGON + "20240707dragonTabA-Sheet.png", 6, 39],
    "dragon_slot": [DRAGON + "20240713dragonFilledFrame-Sheet.png", 6, 32],    # 4 states
    "dragon_close": [DRAGON + "20240713dragonCloseButton-Sheet.png", 0, 24],
}

## Equipment slot frames (D-060: the 8 active slots match the Dragon Regalia frames).
const SLOT_FRAMES := {
    "main_hand": DRAGON + "20240713dragonWeaponFrame.png", "off_hand": DRAGON + "20240713dragonShieldFrame.png",
    "head": DRAGON + "20240713dragonHeadFrame.png", "chest": DRAGON + "20240713dragonChestFrame.png",
    "legs": DRAGON + "20240713dragonPantsFrame.png", "feet": DRAGON + "20240713dragonBootsFrame.png",
    "ring1": DRAGON + "20240713dragonRingFrame.png", "amulet": DRAGON + "20240713dragonNeckFrame.png",
    "": DRAGON + "20240713dragonEmptyFrame.png",
}

## Kit icons (16 px): orders, social, resources, stars, rarity gems, status.
static func icon(id: String) -> String:
    return KIT + "icons/" + id + ".png"


## Kit summon effects per rarity: circle (8 frames of 64), beam (6 of 24), card back (40 x 56).
static func summon(kind: String, rarity: String) -> String:
    return KIT + "summon/%s_%s.png" % [kind, rarity]


static func world(id: String) -> String:
    return KIT + "world/" + id + ".png"


## Every path the catalogue promises (tests check that all of them exist).
static func all_paths() -> Array:
    var out: Array = [SKILL_ICONS, SKILL_BORDER, ITEM_ICONS, RAVEN_ICONS_32, FONT_BODY, FONT_TITLE]
    for k in UI:
        out.append(String(UI[k][0]))
    for k in SLOT_FRAMES:
        out.append(String(SLOT_FRAMES[k]))
    for c in CREATURES.values():
        var src := String(c["src"])
        if String(c["layout"]) == "grid4":
            out.append(src)
        elif String(c["layout"]) == "char":
            for f in ["Idle.png", "Walk.png", "Attack.png", "Dead.png"]:
                out.append(src + f)
        else:
            for f in (c["files"] as Dictionary).values():
                out.append(src + String(f))
    for r in ["title", "town", "explore", "dungeon", "battle", "boss", "results"]:
        out.append(MUSIC + r + ".ogg")
    for i in ["order_move", "order_attack", "order_hold", "order_follow", "order_retreat", "social_trust", "social_obedience",
            "social_composure", "res_food", "res_wood", "res_stone", "res_gem", "star_full", "star_empty"]:
        out.append(icon(i))
    return out


## D-082b: LPC shields available in ../_vendor/lpc for future items (sheet definition -> variants). Not
## imported nor assigned yet; only the round wooden one (shield_round, brown) is in the game (starter kit).
const LPC_SHIELDS_RESERVED := {
    "weapons/shields/shield_round.json": ["black", "gold", "green", "silver", "yellow"],
    "weapons/shields/shield_kite.json": [], "weapons/shields/shield_spartan.json": [],
    "weapons/shields/heater": [], "weapons/shields/scutum": [], "weapons/shields/engrailed": [],
}
