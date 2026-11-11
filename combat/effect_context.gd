## EffectContext — Contexto que viaja a través del pipeline de efectos (ISSUE P1.1).
class_name EffectContext
extends RefCounted

var source: Object = null
var target: Object = null
var amount: float = 0.0
var effect_type: String = "damage" # damage, heal, buff, debuff
var is_critical: bool = false
var mitigated_amount: float = 0.0
var cancelled: bool = false
