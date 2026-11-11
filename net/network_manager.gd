## NetworkManager — Singleton de gestión de red (ISSUE P0.3).
## Orquesta la creación de servidor (host) y cliente, y expone señales de conexión.
extends Node

signal connected_to_server()
signal connection_failed()
signal server_disconnected()
signal peer_connected(id: int)
signal peer_disconnected(id: int)

const DEFAULT_PORT: int = 27015
const DEFAULT_MAX_CLIENTS: int = 32

var _peer: ENetMultiplayerPeer = null
var _is_server_flag: bool = false
var _is_client_flag: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_server(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, max_clients)
	if err != OK:
		printerr("NetworkManager: Failed to create server on port %d: %s" % [port, err])
		return err
	multiplayer.multiplayer_peer = _peer
	_is_server_flag = true
	_is_client_flag = false
	print("NetworkManager: Server started on port %d" % port)
	return OK


func start_client(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(address, port)
	if err != OK:
		printerr("NetworkManager: Failed to create client connecting to %s:%d: %s" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = _peer
	_is_server_flag = false
	_is_client_flag = true
	print("NetworkManager: Client connecting to %s:%d" % [address, port])
	return OK


func stop() -> void:
	if _peer:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	_is_server_flag = false
	_is_client_flag = false
	print("NetworkManager: Stopped network")


func is_server() -> bool:
	return _is_server_flag


func is_client() -> bool:
	return _is_client_flag


func get_local_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 0


func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected: %d" % id)
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected: %d" % id)
	peer_disconnected.emit(id)


func _on_connected_to_server() -> void:
	print("NetworkManager: Connected to server successfully (ID: %d)" % get_local_id())
	connected_to_server.emit()


func _on_connection_failed() -> void:
	printerr("NetworkManager: Connection to server failed")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("NetworkManager: Server disconnected")
	server_disconnected.emit()
