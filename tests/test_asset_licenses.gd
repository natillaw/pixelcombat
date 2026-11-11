## Guarda de licencias del LPC.
##
##   godot --headless --path . --script tests/test_asset_licenses.gd
##
## Toda pieza del indice LPC debe ofrecer una licencia de solo atribucion
## (OGA-BY, CC-BY o CC0). Evita que vuelvan capas que solo ofrecen CC-BY-SA o
## GPL (ver docs/ASSET_REGISTRY.md).
extends SceneTree

const ROOT := "res://assets/pixel/lpc/"
const SAFE_PREFIXES := ["CC0", "OGA-BY", "CC-BY 3.0", "CC-BY 4.0", "MIT"]

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_asset_licenses (LPC) ==")
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "lpc_index.json"))
	_check(index is Dictionary, "lpc_index.json se puede leer")
	if index is Dictionary:
		var pieces: Dictionary = (index as Dictionary).get("pieces", {})
		_check(pieces.size() > 0, "el indice tiene piezas")
		for piece_id: String in pieces:
			var licenses: Array = pieces[piece_id].get("licenses", [])
			_check(_has_attribution_only(licenses), "%s ofrece licencia de solo atribucion (%s)" % [piece_id, ", ".join(licenses)])
			_check(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT + piece_id)), "%s tiene carpeta de sprites" % piece_id)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _has_attribution_only(licenses: Array) -> bool:
	for license: String in licenses:
		for prefix: String in SAFE_PREFIXES:
			if license.begins_with(prefix):
				return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("   FAIL %s" % label)
