## Captura de estanques y orillas en varios pisos (renderer real).
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	var session: GameSession = main.get("session")
	var world: CombatWorld = main.get("world")
	var shot_index := 0
	for floor_number: int in [1, 2, 4]:
		for n: int in range(1, floor_number):
			session.tower.complete(n)
		session.go_to_floor(floor_number)
		await get_tree().create_timer(0.8).timeout
		var grid := session.layout.grid
		var seen := 0
		for r: int in range(8, grid.rows - 8, 3):
			for c: int in range(8, grid.cols - 8, 3):
				if grid.get_cell(c, r) == TileGrid.WATER and seen < 2:
					# Un punto libre al sur del agua.
					var spot := grid.cell_center(c, r + 4)
					if grid.get_cell(c, r + 4) != TileGrid.WALL:
						world.player.position = spot
						seen += 1
						world.enemies.clear()
						await get_tree().create_timer(0.5).timeout
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png("%s/water_%d.png" % [dir, shot_index])
						shot_index += 1
	get_tree().quit()
