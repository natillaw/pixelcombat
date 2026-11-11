## Test headless de autoridad de servidor para hits (ISSUE P0.5).
##
##   godot --headless --path . --script combat/tests/test_hit_authority.gd
##
extends SceneTree

const HitRequestScript: GDScript = preload("res://combat/hit_request.gd")
const HitResolverScript: GDScript = preload("res://combat/hit_resolver.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_hit_authority (P0.5) ==")

	var resolver = HitResolverScript.new()

	# Caso 1: Atacante y objetivo dentro de rango (distancia 30.0 <= 50.0)
	var req_in = HitRequestScript.new()
	req_in.attacker_id = 1
	req_in.target_id = 2
	req_in.tick = 10

	var res_in = resolver.resolve_hit(req_in, Vector2(0, 0), Vector2(30, 0))
	_check(res_in.accepted, "hit within range is accepted by server")
	_check(res_in.damage == 25.0, "server assigns authoritative damage")

	# Caso 2: Atacante y objetivo fuera de rango (distancia 80.0 > 50.0)
	var req_out = HitRequestScript.new()
	req_out.attacker_id = 1
	req_out.target_id = 2
	req_out.tick = 11

	var res_out = resolver.resolve_hit(req_out, Vector2(0, 0), Vector2(80, 0))
	_check(not res_out.accepted, "hit out of range is rejected by server")
	_check(res_out.damage == 0.0, "rejected hit deals zero damage")

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
