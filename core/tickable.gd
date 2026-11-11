## Base para todo objeto de simulación que recibe ticks del [TickManager].
##
## Es [RefCounted] y no [Node] a propósito:
## - La simulación no debe depender del árbol de escena (orden de nodos,
##   pausa del árbol, _process). Un RefCounted no tiene nada de eso.
## - Se puede instanciar y testear en headless sin escena.
## - Un Node que necesite lógica de juego compone un Tickable (p. ej. un
##   componente "simulación" que el nodo de presentación lee en _process),
##   en lugar de heredar de él. Así la frontera sim/presentación es explícita.
##
## Ciclo de vida: el TickManager mantiene una referencia fuerte mientras el
## Tickable está registrado; se libera al desregistrarlo si nadie más lo usa.
class_name Tickable
extends RefCounted


## Llamado una vez por tick de simulación. [param tick_number] empieza en 1
## y es idéntico para todos los Tickables dentro del mismo tick.
## [param delta] es fijo: 1.0 / ticks_por_segundo.
func _on_tick(_tick_number: int, _delta: float) -> void:
	pass


## Llamado al registrarse en el TickManager (antes de recibir su primer tick).
func _on_register() -> void:
	pass


## Llamado al salir del TickManager (después de su último tick).
func _on_unregister() -> void:
	pass
