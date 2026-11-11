class_name SimMode
extends RefCounted
## D-083: switches for the headless combat simulator (tools/sim). Off in the game: every value here is
## neutral, so normal play is unchanged. On: no sprites, effects, floating numbers, map art, fog drawing,
## HUD or result screen; the rules, items, AI and bots are exactly the game's.

static var on: bool = false
## Mixed into the expedition's seeds (loot rolls, creature and hero combat dice, altar side). 0 = the game.
static var run_seed: int = 0
## Optional enemy multipliers (config "enemies"): health, damage, how many per encounter.
static var enemy_hp: float = 1.0
static var enemy_dmg: float = 1.0
static var enemy_count: float = 1.0
## Multiplies the autonomous heroes' aim error (config bot.aim_error_mult).
static var aim_error_mult: float = 1.0


static func reset() -> void:
    on = false
    run_seed = 0
    enemy_hp = 1.0
    enemy_dmg = 1.0
    enemy_count = 1.0
    aim_error_mult = 1.0
