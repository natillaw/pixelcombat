## LootDrop — un item en el suelo esperando a que el jugador lo recoja.
##
## Lo crea `CombatWorld` al morir un enemigo; el mundo lo recoge cuando el jugador
## se acerca (tras un breve retraso y si hay sitio en la mochila) y lo borra al
## caducar o al cambiar de escenario.
class_name LootDrop
extends RefCounted

## Segundos hasta poder recogerlo (el objeto "salta" antes de quedarse quieto).
const PICKUP_DELAY := 0.4
const PICKUP_RADIUS := 30.0
## Segundos hasta que desaparece.
const LIFETIME := 120.0

var item: Dictionary
var position: Vector2
var age: float = 0.0
## Ya se avisó de que la mochila está llena (para no repetirlo cada tick).
var warned_full: bool = false


func _init(p_item: Dictionary, p_position: Vector2) -> void:
	item = p_item
	position = p_position


func can_pick_up() -> bool:
	return age >= PICKUP_DELAY


func expired() -> bool:
	return age >= LIFETIME
