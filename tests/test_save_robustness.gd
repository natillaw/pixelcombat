## Guardado robusto: escritura atomica con copia de seguridad y datos corruptos sin romper el juego.
##
##   godot --headless --path . --script tests/test_save_robustness.gd
extends SceneTree

const PATH := "user://test_robust_save.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_save_robustness ==")
	SaveGame.delete(PATH)
	var player := PlayerSim.new()
	player.switch_class("mage")
	player.set_level(4)
	var tower := TowerState.new()
	tower.complete(1)
	_check(SaveGame.write(PATH, player, tower), "se guarda")
	_check(not FileAccess.file_exists(PATH + ".tmp"), "no queda archivo temporal")
	_check(int(SaveGame.read(PATH)["player"]["progress"]["mage"]["level"]) == 4, "se lee el nivel guardado")
	# Segundo guardado: el primero queda como copia.
	player.set_level(6)
	_check(SaveGame.write(PATH, player, tower), "se vuelve a guardar")
	_check(FileAccess.file_exists(PATH + ".bak"), "el guardado anterior queda como .bak")
	# El archivo bueno se corrompe a mitad de escritura: se recupera la copia.
	var broken := FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("{\"version\": 1, \"player\": {\"class_")
	broken.close()
	var recovered := SaveGame.read(PATH)
	_check(not recovered.is_empty() and int(recovered["player"]["progress"]["mage"]["level"]) == 4, "con el archivo roto se recupera la copia (.bak)")
	# Sin copia y roto: vacio, sin errores.
	SaveGame.delete(PATH)
	var junk := FileAccess.open(PATH, FileAccess.WRITE)
	junk.store_string("esto no es json")
	junk.close()
	_check(SaveGame.read(PATH).is_empty(), "un archivo sin sentido se trata como partida vacia")
	SaveGame.delete(PATH)
	_check(not FileAccess.file_exists(PATH), "borrar quita tambien las copias")
	# Datos con tipos equivocados: no rompen la carga.
	var weird_tower := TowerState.from_dict({"floors": "no", "last_floor": "a", "flags": 3, "quests": 5, "world_seed": "x"})
	_check(weird_tower.highest_unlocked() >= 1, "una torre con datos raros se carga con valores por defecto")
	var weird_player := PlayerSim.new()
	weird_player.import_state({"progress": 5, "class_id": 7, "gold": "mucho", "bag": "x", "consumables": 3, "bank": 2, "character": 9})
	_check(weird_player.level >= 1 and ClassCatalog.has_class(weird_player.class_id), "un jugador con datos raros se carga con valores por defecto")
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
