## Nombres en espanol y paridad de contenido: toda skill tiene display_name y hud_label_es, las 4 clases tienen >= 14
## habilidades y las nuevas funcionan en combate (proyectiles, zonas, buffs).
extends SceneTree

var _checks: int = 0
var _failures: int = 0
const DT := 1.0 / 60.0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_names()
	_test_parity()
	_test_new_skills_work()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_names() -> void:
	var missing: Array = []
	var long_labels: Array = []
	for class_id: String in ClassCatalog.all_ids():
		for id: StringName in SkillCatalog.ids_for_class(class_id):
			var skill := SkillCatalog.skill(id)
			if not skill.has("display_name") or not skill.has("hud_label_es"):
				missing.append(String(id))
			elif String(skill["hud_label_es"]).length() > 10:
				long_labels.append(String(id))
			if SkillIcons.texture(String(id)) == null and not bool(skill.get("retired", false)):
				missing.append("icono:" + String(id))
	_check(missing.is_empty(), "todas las skills tienen nombre en espanol, etiqueta e icono %s" % str(missing))
	_check(long_labels.is_empty(), "las etiquetas del HUD caben (<= 10 letras) %s" % str(long_labels))
	_check(SkillCatalog.display_name(SkillCatalog.skill(&"fireball")) == "Bola de fuego", "Fireball se muestra como Bola de fuego")


func _test_parity() -> void:
	for class_id: String in ClassCatalog.all_ids():
		var count := SkillCatalog.ids_for_class(class_id).size()
		_check(count >= 14, "%s tiene %d habilidades (>= 14)" % [class_id, count])
	for id: String in ["poison_arrow", "snare_trap", "volley", "marked_prey", "stunning_arrow", "blazing_arrow", "arcane_missiles", "flame_wave", "gravity_well"]:
		var skill := SkillCatalog.skill(StringName(id))
		_check(not skill.is_empty() and bool(skill.get("world", false)), "%s existe y se aprende en el Gremio" % id)


func _cast(class_id: String, id: String, enemy_at: Vector2) -> Dictionary:
	var world := CombatWorld.new(61)
	world.player.safe_zone = true
	world.player.switch_class(class_id)
	world.player.set_level(10)
	world.player.safe_zone = false
	world.player.position = Vector2(300, 300)
	world.player.learned_skills.append(id)
	world.player.loadout["S1"] = SkillCatalog.skill(StringName(id))
	world.player.resource.current_amount = world.player.resource.max_amount
	var enemy := world.add_enemy(&"bandit_thug", enemy_at)
	enemy.invulnerable = false
	var health := enemy.health
	var aim := (enemy_at - world.player.position).normalized()
	for tick: int in range(180):
		var message := InputMessage.new()
		message.tick = tick
		message.peer_id = 1
		message.aim_dir = aim
		message.target_pos = enemy_at
		message.actions = {"s1": tick < 3}
		world.submit_input(message)
		world.step(DT)
	return {"world": world, "enemy": enemy, "damage": health - enemy.health}


func _test_new_skills_work() -> void:
	for entry: Array in [["archer", "poison_arrow"], ["archer", "volley"], ["archer", "stunning_arrow"], ["archer", "blazing_arrow"], ["mage", "arcane_missiles"], ["mage", "flame_wave"]]:
		var result := _cast(String(entry[0]), String(entry[1]), Vector2(420, 300))
		_check(float(result["damage"]) > 0.0, "%s hace dano (%.0f)" % [entry[1], float(result["damage"])])
	var poison := _cast("archer", "poison_arrow", Vector2(420, 300))
	_check((poison["enemy"] as EnemySim).statuses.has("poison") or float(poison["damage"]) > 20.0, "la flecha venenosa envenena")
	var trap := _cast("archer", "snare_trap", Vector2(510, 300))
	_check(float(trap["damage"]) > 0.0 or (trap["enemy"] as EnemySim).statuses.has("slow"), "la trampa de lazo afecta a los enemigos de la zona")
	var well := _cast("mage", "gravity_well", Vector2(520, 300))
	_check(float(well["damage"]) > 0.0 or (well["enemy"] as EnemySim).statuses.has("slow"), "el pozo de gravedad afecta a los enemigos de la zona")
