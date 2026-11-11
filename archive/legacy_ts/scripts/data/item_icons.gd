class_name ItemIcons
extends RefCounted
## Which Caz MV icon (AssetCatalog.ITEM_ICONS: 16 columns of 32 px, row-major index) each item base and
## consumable shows. Picked by look: 19 sword, 20 round shield, 16 winged helm, 17 tunic, 33 plate,
## 48 wizard hat, 49 robe, 18 boots, 34 iron boots, 35 axe, 51 staff, 52 ring, 67 bow, 80/81 potions.

const BASES := {
    "sword": 19, "greataxe": 35, "dagger": 235, "mace": 51, "bow": 67, "staff": 51, "wand": 84,
    "shield": 20, "helm": 16, "hood": 48, "mail": 33, "robe": 49, "gloves": 66, "greaves": 34,
    "boots": 18, "ring": 52, "amulet": 237, "charm": 240,
    # pista D: the D-082b kit, the new bows/shields/armour and the bags. "r:N" = the Raven 32 px sheet
    # (AssetCatalog.RAVEN_ICONS_32, 16 columns): 156 sack, 612/613 shields, 219 tanned hide.
    "plain_shirt": 17, "plain_pants": 50, "plain_shoes": 50, "plain_sword": 19, "plain_shield": 20, "plain_dagger": 235,
    "plain_offhand_dagger": 235, "plain_bow": 67, "plain_staff": 51, "plain_club": 51,
    "recurve": 67, "longbow": 67, "crossbow": 67, "kite_shield": "r:613", "bronze_shield": "r:612",
    "leather_cap": 48, "leather_vest": 17, "leather_pants": "r:219", "cloth_pants": 65, "sandals": 50,
    "satchel": "r:156", "backpack": "r:156",
}
## Consumables and books (Raven): 92 tent, 401 arrows, 563 stew, 485 roast, 96/98/102 books, 304 plan.
const CONSUMABLES := {"potion": 80, "antidote": 81, "medicine": 81, "con_potion_major": 80,
    "meal_stew": "r:563", "meal_roast": "r:485", "meal_broth": "r:563", "meal_feast": "r:485", "camp_kit": "r:92", "arrows": "r:401",
    "book_xp": "r:96", "book_skill": "r:98", "book_trade": "r:102", "book_plan": "r:304"}


## 2026-11-02 (owner: "los items solo se muestran como espadas"): every equipment base has its own 32 px
## icon from the rpg_icons pack (assets/pixel/packs/rpg_icons/IconN.png, authorised by the owner).
const RPG_DIR := "res://assets/pixel/packs/rpg_icons/Icon%d.png"
const RPG := {
    "sword": 3, "greataxe": 45, "dagger": 82, "mace": 21, "bow": 102, "recurve": 104, "longbow": 109, "crossbow": 121,
    "staff": 71, "wand": 87, "shield": 152, "kite_shield": 144, "bronze_shield": 141, "helm": 172, "hood": 169,
    "mail": 196, "robe": 187, "gloves": 207, "greaves": 216, "boots": 226, "leather_cap": 165, "leather_vest": 183,
    "leather_pants": 211, "cloth_pants": 212, "sandals": 229, "satchel": 287, "backpack": 289, "ring": 249,
    "amulet": 254, "charm": 256, "plain_shirt": 181, "plain_pants": 213, "plain_shoes": 222, "plain_sword": 1,
    "plain_shield": 143, "plain_dagger": 81, "plain_offhand_dagger": 84, "plain_bow": 101, "plain_staff": 87,
    "plain_club": 25,
    # owner 2026-11-02: jeweller variety and the trinket runes (Icon261-270 runestones, 274 clover)
    "ruby_band": 246, "sapphire_band": 250, "iron_band": 242, "heart_pendant": 257, "sun_pendant": 254, "swift_chain": 251,
    "blood_rune": 265, "bulwark_rune": 261, "shadow_rune": 268, "hawk_rune": 267, "mana_rune": 266, "mercy_rune": 263,
    "thorn_rune": 262, "lucky_clover": 274, "potion": 302, "con_potion_major": 303, "antidote": 282, "medicine": 284,
}
static var _rpg_cache: Dictionary = {}


static func texture(base_id: String) -> Texture2D:
    if RPG.has(base_id):
        var path := RPG_DIR % int(RPG[base_id])
        if not _rpg_cache.has(path) and ResourceLoader.exists(path):
            _rpg_cache[path] = load(path)
        if _rpg_cache.has(path):
            return _rpg_cache[path]
    var ref = BASES.get(base_id, CONSUMABLES.get(base_id, 19))
    var sheet := AssetCatalog.ITEM_ICONS
    if ref is String:                                      # "r:N" = Raven sheet
        sheet = AssetCatalog.RAVEN_ICONS_32
        ref = int(String(ref).trim_prefix("r:"))
    var idx: int = int(ref)
    if not ResourceLoader.exists(sheet):
        return null
    var at := AtlasTexture.new()
    at.atlas = load(sheet)
    at.region = Rect2((idx % 16) * 32, (idx / 16) * 32, 32, 32)
    return at


static func skill_texture(skill_id: String) -> Texture2D:
    if not ResourceLoader.exists(AssetCatalog.SKILL_ICONS):
        return null
    var idx := SkillIcons.index_of(skill_id)
    var at := AtlasTexture.new()
    at.atlas = load(AssetCatalog.SKILL_ICONS)
    at.region = Rect2((idx % 8) * 32, (idx / 8) * 32, 32, 32)
    return at


## An item slot: Dragon Regalia frame for the equipment slot, the item's icon inside (16 px from the
## 32 px icon at x0.5 would blur: the 32 px icon is shown whole on a 32 px frame), rarity tint on the rim.
static func slot_control(slot: String, item: Dictionary) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(32, 32)
    var frame := TextureRect.new()
    var fpath := String(AssetCatalog.SLOT_FRAMES.get(slot, AssetCatalog.SLOT_FRAMES[""]))
    frame.texture = load(fpath) if ResourceLoader.exists(fpath) else null
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    c.add_child(frame)
    if not item.is_empty():
        var col := ItemDefs.rarity_color(String(item.get("rarity", "common")))   # D-123: the rarity colour of the item data
        var r := ColorRect.new()
        r.color = Color(col, 0.35)
        r.position = Vector2(2, 2)
        r.size = Vector2(28, 28)
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        c.add_child(r)
        var ic := TextureRect.new()
        ic.texture = texture(String(item.get("base", "")))
        ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if ItemDefs.is_junk(item):
            ic.modulate = Color(0.6, 0.6, 0.6)               # junk looks worn out
        c.add_child(ic)
        var rim := ReferenceRect.new()                       # rarity border
        rim.editor_only = false
        rim.border_color = col
        rim.border_width = 1.0
        rim.size = Vector2(32, 32)
        rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        c.add_child(rim)
    return c


## A label with the item's name in its rarity colour (loot window, lists).
static func name_label(item: Dictionary, font_size: int = 12) -> Label:
    var l := UIKit.label(String(item.get("name", "?")), font_size, ItemDefs.rarity_color(String(item.get("rarity", "common"))))
    return l


## Tooltip text: name, rarity, stats and affixes; vs = the item now equipped in that slot (▲ / ▼).
static func tooltip(item: Dictionary, vs: Dictionary = {}) -> String:
    if item.is_empty():
        return ""
    var lines: Array = [ItemDefs.item_label(item)]
    var st: Dictionary = item.get("stats", {})
    var other: Dictionary = vs.get("stats", {}) if not vs.is_empty() else {}
    for k in st:
        var v := float(st[k])
        var mark := ""
        if not vs.is_empty():
            var o := float(other.get(k, 0.0))
            mark = "  ▲ +%s" % _num(v - o) if v > o else ("  ▼ %s" % _num(v - o) if v < o else "  =")
        lines.append("%s %s%s" % [String(k).to_upper(), _num(v), mark])
    if not vs.is_empty():
        for k in other:
            if not st.has(k):
                lines.append("%s 0  ▼ -%s" % [String(k).to_upper(), _num(float(other[k]))])
    for a in item.get("affixes", []):
        lines.append("· %s" % str(a.get("name", a)) if a is Dictionary else "· %s" % str(a))
    var proc := ItemDefs.proc_text(String(item.get("base", "")))
    if proc != "":
        lines.append("✦ " + proc)                        # trinket passive (owner 2026-11-02)
    if String(item.get("set", "")) != "":
        lines.append("Set: %s" % String(ItemDefs.SETS.get(String(item["set"]), {}).get("name", item["set"])))
    return "\n".join(lines)


static func _num(v: float) -> String:
    return str(roundi(v)) if absf(v - roundf(v)) < 0.001 else "%.2f" % v
