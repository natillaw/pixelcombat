## WarriorLook — the canonical LPC look of the playable Warrior.
##
## Uses the imported LPC sheets from assets/pixel/lpc (Universal LPC Spritesheet
## Character Generator). Armour plate + barbute + longsword are layered by
## LpcComposer using the z-order from lpc_index.json.
class_name WarriorLook
extends RefCounted

const LOOK := {
	"body": "male",
	"skin": "light",
	"eyes": "blue",
	"head": "head_human_male",
	"hair": "hair_buzzcut",
	"hair_color": "dark_brown",
	"beard": "beard_trimmed",
}

const EQUIPMENT := {
	"_items": true,
	"chest": ["armour_plate", "steel"],
	"legs": ["legs_plate", "steel"],
	"hands": ["gloves", "steel"],
	"feet": ["boots_basic", "leather"],
	"head": ["helmet_barbuta", "steel"],
	"main_hand": ["weapon_longsword", "default"],
}


static func frames() -> SpriteFrames:
	return LpcComposer.build_frames_for(LOOK, "class.player", EQUIPMENT)


static func portrait() -> Texture2D:
	return LpcComposer.pose_texture_for(LOOK, "class.player", "idle", EQUIPMENT)
