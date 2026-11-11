## GameServer — Lógica específica del servidor autoritativo (ISSUE P0.3).
class_name GameServer
extends Node

var port: int = 27015
var max_clients: int = 32


func start(p_port: int = port, p_max_clients: int = max_clients) -> Error:
	port = p_port
	max_clients = p_max_clients
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		return nm.start_server(port, max_clients)
	printerr("GameServer: NetworkManager not found in root")
	return FAILED


func stop() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.stop()
	print("GameServer: Stopped")
