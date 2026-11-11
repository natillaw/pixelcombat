## GameClient — Lógica específica del cliente de red (ISSUE P0.3).
class_name GameClient
extends Node

var address: String = "127.0.0.1"
var port: int = 27015


func connect_to_server(p_address: String = address, p_port: int = port) -> Error:
	address = p_address
	port = p_port
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		return nm.start_client(address, port)
	printerr("GameClient: NetworkManager not found in root")
	return FAILED


func disconnect_from_server() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		nm.stop()
	print("GameClient: Disconnected from server")
