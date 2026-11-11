class_name FloatingText
extends Node2D
## Damage / heal / status numbers that rise and fade above a unit (combat feedback).
## D-112 (pista C): numbers pop, float on alternating arcs (left/right) so two in a row never overlap,
## and grow with the damage. Colours: white normal, orange crit (big, trembling), green heal, purple
## damage over time, blue mana, grey dodged/blocked. Big numbers only for the Master and for damage
## taken by the party; `compact` (Options) keeps every number small. All world texts (numbers, names)
## live in one layer above the units (WorldTextLayer), never mixed with the map art.

const LIFE := 0.9
const POP_TIME := 0.12               # big numbers (crits) pop in from 1.5x, normal ones from 1.15x
const COLORS := {"normal": Color(1, 1, 1), "crit": Color(1.0, 0.55, 0.12), "heal": Color(0.45, 1.0, 0.5),
    "dot": Color(0.78, 0.45, 1.0), "mana": Color(0.45, 0.65, 1.0), "miss": Color(0.62, 0.62, 0.66),
    "party": Color(1.0, 0.55, 0.45)}
const ARC_X := 14.0                  # px the number drifts sideways along its arc
const STACK_GAP := 9.0               # px between numbers spawned on the same unit within STACK_TIME
const STACK_TIME := 0.35
const SIZE_STEPS := [[0, 1.0], [40, 1.5], [120, 2.0]]   # damage -> text scale (big numbers only)
const LAYER_Z := 60
## Options: true = every number at the small size.
static var compact: bool = false
static var _arc_side: Dictionary = {}    # unit id -> next side (+1 / -1)
static var _stack: Dictionary = {}       # unit id -> [last spawn msec, count]

var text: String = ""
var color: Color = Color.WHITE
var big: bool = false
var life: float = LIFE
var size_mult: float = 1.0
var tremble: bool = false
var _t: float = 0.0
var _side: float = 1.0
var _start: Vector2 = Vector2.ZERO


static func spawn(unit: Node2D, p_text: String, p_color: Color, p_big: bool, p_life: float = LIFE) -> FloatingText:
    if SimMode.on:
        return null                               # D-083 headless simulator: nothing to draw
    if unit == null or not unit.is_inside_tree() or unit.get_parent() == null or not unit.is_visible_in_tree():
        return null                               # nothing pops out of the fog of war
    if not GameMenu.damage_numbers and p_text.lstrip("+-").is_valid_int():
        return null                               # Options: damage numbers off (words like "Crit!" stay)
    var f := FloatingText.new()
    f.text = StringsEs.tx(p_text)
    f.color = p_color
    f.big = p_big
    f.life = p_life
    var id := unit.get_instance_id()
    f._side = float(_arc_side.get(id, 1))
    _arc_side[id] = -int(f._side)
    var now := Time.get_ticks_msec()
    var st: Array = _stack.get(id, [0, 0])
    var n := int(st[1]) + 1 if now - int(st[0]) < int(STACK_TIME * 1000.0) else 0
    _stack[id] = [now, n]
    f._start = (unit.position + Vector2(f._side * 4.0, -40.0 - STACK_GAP * float(mini(n, 4)))).round()
    f.position = f._start
    f.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    world_layer(unit.get_parent()).add_child(f)
    return f


## A combat number. kind: normal, crit, heal, dot, mana, miss. big_allowed: the Master or a party member
## is involved (only those grow with the damage).
static func number(unit: Node2D, amount: int, kind: String, big_allowed: bool, label: String = "") -> FloatingText:
    var txt := label if label != "" else (("+%d" % amount) if kind == "heal" or kind == "mana" else str(amount))
    if kind == "crit" and label == "":
        txt += "!"
    var col: Color = COLORS.get(kind, COLORS["normal"])
    var f := spawn(unit, txt, col, kind == "crit")
    if f == null:
        return null
    f.size_mult = text_scale(amount, kind, big_allowed)
    f.tremble = kind == "crit"
    return f


## Pure: how big a number is drawn.
static func text_scale(amount: int, kind: String, big_allowed: bool) -> float:
    if compact or not big_allowed or kind == "miss" or kind == "dot":
        return 1.0
    var s := 1.0
    for step in SIZE_STEPS:
        if amount >= int(step[0]):
            s = float(step[1])
    if kind == "crit":
        s = maxf(s, 1.5)
    return s


## One Node2D per world that holds every floating text above the units and the map art.
static func world_layer(world: Node) -> Node2D:
    var l := world.get_node_or_null("WorldTextLayer") as Node2D
    if l == null:
        l = Node2D.new()
        l.name = "WorldTextLayer"
        l.z_index = LAYER_Z
        l.z_as_relative = false
        world.add_child(l)
    return l


func _process(delta: float) -> void:
    _t += delta
    var k := clampf(_t / life, 0.0, 1.0)
    # arc: quick rise, sideways drift that eases out, then hangs to be read
    var rise := 26.0 * (1.0 - pow(1.0 - minf(1.0, _t / 0.35), 2.0)) + 10.0 * k
    var side := _side * ARC_X * sin(minf(1.0, _t / 0.5) * PI * 0.5)
    var pos := _start + Vector2(side, -rise)
    if tremble and _t < 0.3:
        pos += Vector2(randi_range(-1, 1), randi_range(-1, 1))
    position = pos.round()                                   # whole pixels
    var pop := 1.0 + (0.5 if big else 0.15) * (1.0 - clampf(_t / POP_TIME, 0.0, 1.0))
    scale = Vector2.ONE * pop * size_mult
    modulate.a = clampf((life - _t) / minf(0.35, life), 0.0, 1.0)   # readable, then a short fade
    if _t >= life:
        queue_free()
    queue_redraw()


func _draw() -> void:
    var font := UIKit.title_font() if big else UIKit.body_font()     # pixel fonts at native size (D-063)
    var size := UIKit.BODY
    var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
    var at := Vector2(-roundf(w * 0.5), 0)
    draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, ArtPalette.OUTLINE)
    draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
