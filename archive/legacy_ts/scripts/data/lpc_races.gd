class_name LpcRaces
extends RefCounted
## Overhaul LPC phase 5 (D-F): catalogue of the non-human LPC races for future floors (orcs, undead...).
## Visual archetypes only: no stats, not in floors 1-10 (that roster stays bandits). A head goes on the
## human body; outfits are wardrobe_catalog.json visual_ids (to import when a race is used). Sample
## sheet: docs/reports/overhaul/razas.png. Using a race in a floor or giving it stats is PENDING (ask).

const RACES := {
    "orc": {"head": "head/heads/fantasy/heads_orc_male.json", "skin": "green",
        "outfits": {"warrior": ["torso_armour_leather", "weapons_blunt_weapon_blunt_waraxe"], "archer": ["torso_armour_leather", "weapons_ranged_bow_weapon_ranged_bow_normal"], "shaman": ["torso_clothes_robe", "weapons_magic_weapon_magic_gnarled"]}},
    "goblin": {"head": "head/heads/fantasy/heads_goblin.json", "skin": "green",
        "outfits": {"warrior": ["weapons_sword_weapon_sword_dagger"], "archer": ["weapons_ranged_weapon_ranged_crossbow"]}},
    "troll": {"head": "head/heads/fantasy/heads_troll.json", "skin": "pale_green", "outfits": {"warrior": ["weapons_blunt_weapon_blunt_mace"]}},
    "skeleton": {"head": "head/heads/undead/heads_skeleton.json", "skin": "light",
        "outfits": {"warrior": ["weapons_sword_weapon_sword_arming"], "archer": ["weapons_ranged_bow_weapon_ranged_bow_recurve"], "caster": ["weapons_magic_weapon_magic_crystal"]}},
    "zombie": {"head": "head/heads/undead/heads_zombie.json", "skin": "zombie", "outfits": {"warrior": []}},
    "vampire": {"head": "head/heads/undead/heads_vampire.json", "skin": "light", "outfits": {"caster": ["torso_cape_cape_solid"]}},
    "wolfkin": {"head": "head/heads/beast/heads_wolf_male.json", "skin": "fur_grey", "outfits": {"warrior": ["torso_armour_leather"]}},
    "minotaur": {"head": "head/heads/beast/heads_minotaur.json", "skin": "fur_brown", "outfits": {"warrior": ["weapons_blunt_weapon_blunt_waraxe"]}},
    "lizardfolk": {"head": "head/heads/reptile/heads_lizard_male.json", "skin": "green", "outfits": {"warrior": ["weapons_polearm_weapon_polearm_spear"]}},
    "boarman": {"head": "head/heads/beast/heads_boarman.json", "skin": "fur_brown", "outfits": {"warrior": ["weapons_blunt_weapon_blunt_club"]}},
}
