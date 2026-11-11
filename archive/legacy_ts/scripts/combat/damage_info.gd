class_name DamageInfo
extends RefCounted
## One hit travelling through CombatRules.resolve(): who, how much, what kind, crit chance.
## kind: "physical" | "magical" | "true". Tags let passives/equipment react later (D-039).

var amount: float = 0.0
var kind: String = "physical"
var element: String = ""          # P-29 hook (pending): "fire", "ice"... read against Combatant.resistances
var source: Node2D = null
var can_crit: bool = true
var crit_chance: float = 0.0
var rng: RandomNumberGenerator = null
var tags: Array = []
# results
var crit: bool = false
var final: int = 0


static func make(p_amount: float, p_kind: String, p_source: Node2D, p_crit_chance: float = 0.0, p_rng: RandomNumberGenerator = null) -> DamageInfo:
    var d := DamageInfo.new()
    d.amount = p_amount
    d.kind = p_kind
    d.source = p_source
    d.crit_chance = p_crit_chance
    d.rng = p_rng
    d.can_crit = p_rng != null and p_crit_chance > 0.0
    return d
