## Captura de los nodos de recoleccion con sprites (mineral, hierbas y arboles) en un piso generado. Renderer
## real, fuera de pantalla:
##   CAPTURE_DIR=$PWD/screenshots godot --position 12000,12000 --path . res://tests/capture_resources.tscn
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
	await get_tree().create_timer(0.5).timeout
	var session: GameSession = main.get("session")
	var world: CombatWorld = main.get("world")
	session.go_to_floor(1)
	await get_tree().create_timer(0.8).timeout
	var shots := 0
	for kind: String in ["ore", "herb", "wood"]:
		for node: ResourceNode in world.resource_nodes:
			if node.kind == kind:
				world.player.position = node.position + Vector2(-70, 30)
				await get_tree().create_timer(0.5).timeout
				await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("%s/res_%s.png" % [dir, kind])
				shots += 1
				break
	print("CAPTURE DONE (%d) -> %s" % [shots, dir])
	get_tree().quit(0)
