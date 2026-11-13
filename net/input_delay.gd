## InputDelay — retrasa el input del jugador N ticks para sentir el juego con latencia (solo pruebas: Ajustes >
## Accesibilidad y musica > "Latencia simulada"). Con 0 ticks no hace nada. No toca la simulacion: solo decide que
## InputMessage recibe cada tick, como si el comando hubiera tardado en llegar al servidor.
class_name InputDelay
extends RefCounted

const TICK_MS := 1000.0 / 60.0

var _queue: Array = []


## Ticks de retraso para `milliseconds` de latencia.
static func ticks_for(milliseconds: int) -> int:
	return int(round(float(milliseconds) / TICK_MS))


## Mete el mensaje de este tick y devuelve el que le toca a la simulacion ahora: el de hace `delay_ticks`
## ticks, o uno neutro (sin movimiento ni acciones) mientras todavia no ha llegado ninguno.
func push(message: InputMessage, delay_ticks: int) -> InputMessage:
	if delay_ticks <= 0:
		_queue.clear()
		return message
	_queue.append(message)
	while _queue.size() > delay_ticks + 1:
		_queue.pop_front()                       # se bajo la latencia: se descartan los mas viejos para no acumular
	if _queue.size() > delay_ticks:
		return _queue.pop_front()
	var neutral := InputMessage.new()
	neutral.tick = message.tick
	neutral.peer_id = message.peer_id
	neutral.aim_dir = message.aim_dir
	neutral.target_pos = message.target_pos
	neutral.move_dir = Vector2.ZERO
	neutral.actions = {}
	return neutral


func clear() -> void:
	_queue.clear()
