## Captura de proyectiles con sprites (mago y arquero) en pleno vuelo. Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_projectiles.tscn
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	main.get("session").go_to_training()
	await get_tree().create_timer(0.8).timeout
	var world: CombatWorld = main.get("world")
	for enemy: EnemySim in world.enemies.duplicate():
		enemy.take_damage(1.0e9)
	world.player.safe_zone = true
	world.player.switch_class("mage")
	world.player.set_level(10)
	LegacyKit.apply(world.player)
	world.player.safe_zone = false
	world.player.resource.current_amount = 100.0
	world.add_dummy(world.player.position + Vector2(260, 0), false)
	await get_tree().create_timer(0.3).timeout
	for slot: String in ["m1", "s1", "s3", "m2"]:
		_press(world, slot)
		await get_tree().create_timer(0.4).timeout
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/proj_mage_%s.png" % [dir, slot])
		await get_tree().create_timer(1.2).timeout
	world.player.safe_zone = true
	world.player.switch_class("archer")
	world.player.set_level(10)
	LegacyKit.apply(world.player)
	world.player.safe_zone = false
	await get_tree().create_timer(0.3).timeout
	for slot: String in ["m1", "s1"]:
		_press(world, slot)
		await get_tree().create_timer(0.4).timeout
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/proj_archer_%s.png" % [dir, slot])
		await get_tree().create_timer(1.2).timeout
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)


func _press(world: CombatWorld, slot: String) -> void:
	var message := InputMessage.new()
	message.peer_id = 1
	message.aim_dir = Vector2.RIGHT
	message.actions = {slot: true}
	world.submit_input(message)
