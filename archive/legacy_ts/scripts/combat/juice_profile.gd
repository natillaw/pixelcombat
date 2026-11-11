class_name JuiceProfile
extends Resource
## D-110: what one impact looks like (flash, 2 px particles, sprite kick, squash, camera shake, render
## freeze, sound hook). Built from JuiceDefs or loaded from res://assets/juice/<id>.tres when saved.
## Presentation only: JuicePlayer never changes damage, timing or real positions.

const DIR := "res://assets/juice/"

@export var id: String = ""
@export var flash: Color = Color(1, 1, 1)
@export_range(2, 4) var flash_frames: int = 2
@export var particles: Color = Color(0.9, 0.85, 0.75)
@export var extra: Color = Color(0, 0, 0, 0)
@export var amount: int = 5
@export var spread: float = 50.0
@export var speed: float = 70.0
@export var rise: bool = false
@export var kick: int = 1
@export var recoil: int = 0
@export var squash: float = 0.0
@export var shake: float = 0.0
@export var freeze: float = 0.0
@export var sound: String = "hit"
@export var heavy: bool = false

static var _cache: Dictionary = {}


static func from_dict(p_id: String, d: Dictionary) -> JuiceProfile:
    var p := JuiceProfile.new()
    p.id = p_id
    var full := JuiceDefs.DEFAULT.duplicate()
    full.merge(d, true)
    p.flash = full["flash"]
    p.flash_frames = clampi(int(full["flash_frames"]), 2, 4)
    p.particles = full["particles"]
    p.extra = full["extra"]
    p.amount = int(full["amount"])
    p.spread = float(full["spread"])
    p.speed = float(full["speed"])
    p.rise = bool(full["rise"])
    p.kick = int(full["kick"])
    p.recoil = int(full["recoil"])
    p.squash = float(full["squash"])
    p.shake = minf(float(full["shake"]), JuiceDefs.MAX_SHAKE)
    p.freeze = float(full["freeze"])
    p.sound = String(full["sound"])
    p.heavy = bool(full["heavy"])
    return p


static func file_name(p_id: String) -> String:
    return DIR + p_id.replace(".", "_") + ".tres"


## Saved resource first (hand-tuned), else the data table. Unknown ids return null.
static func get_profile(p_id: String) -> JuiceProfile:
    if _cache.has(p_id):
        return _cache[p_id]
    var p: JuiceProfile = null
    var path := file_name(p_id)
    if ResourceLoader.exists(path):
        p = load(path) as JuiceProfile
    if p == null:
        var d := JuiceDefs.raw(p_id)
        if not d.is_empty() or JuiceDefs.TYPE.has(p_id):
            p = from_dict(p_id, d)
    _cache[p_id] = p
    return p


## A copy with the heavy treatment (crit, finishing blow, boss, heavy skill): screen shake (<= 2 px),
## a render-only freeze, longer flash, more particles, a squash.
func boosted() -> JuiceProfile:
    var p: JuiceProfile = duplicate()
    p.shake = minf(maxf(shake, float(JuiceDefs.HEAVY_BOOST["shake"])), JuiceDefs.MAX_SHAKE)
    p.freeze = clampf(maxf(freeze, float(JuiceDefs.HEAVY_BOOST["freeze"])), JuiceDefs.FREEZE_MIN, JuiceDefs.FREEZE_MAX)
    p.flash_frames = int(JuiceDefs.HEAVY_BOOST["flash_frames"])
    p.amount = roundi(float(amount) * float(JuiceDefs.HEAVY_BOOST["amount_mult"]))
    p.squash = maxf(squash, float(JuiceDefs.HEAVY_BOOST["squash"]))
    p.kick = kick + 1
    return p


## A light copy (normal hits): flash + particles + a small kick, never shake or freeze.
func light() -> JuiceProfile:
    var p: JuiceProfile = duplicate()
    p.shake = 0.0
    p.freeze = 0.0
    return p
