## Test headless de red base (ISSUE P0.3).
##
##   godot --headless --path . --script net/tests/test_net.gd
##
extends SceneTree

const GameServerScript: GDScript = preload("res://net/server.gd")
const GameClientScript: GDScript = preload("res://net/client.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_net (P0.3) ==")
	
	var net_manager: Node = root.get_node_or_null("/root/NetworkManager")
	_check(net_manager != null, "NetworkManager autoload is present at /root/NetworkManager")

	var server: Node = GameServerScript.new()
	var client: Node = GameClientScript.new()
	root.add_child(server)
	root.add_child(client)

	# 1. Test Server start and stop
	var err: Error = server.start(27015, 4)
	_check(err == OK, "server starts successfully on port 27015")
	_check(net_manager.is_server(), "NetworkManager recognizes server mode")
	_check(net_manager.get_local_id() == 1, "server has peer ID 1")

	server.stop()
	_check(not net_manager.is_server(), "server stopped cleanly")

	# 2. Test Client start and stop
	err = client.connect_to_server("127.0.0.1", 27015)
	_check(err == OK, "client initiates connection successfully")
	_check(net_manager.is_client(), "NetworkManager recognizes client mode")

	client.disconnect_from_server()
	_check(not net_manager.is_client(), "client disconnected cleanly")

	server.queue_free()
	client.queue_free()

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
