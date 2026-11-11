## LootDrop — un item en el suelo esperando a que el jugador lo recoja.
##
## Lo crea `CombatWorld` al morir un enemigo; el jugador lo recoge haciendo clic
## izquierdo sobre el, estando cerca (tras un breve retraso y si hay sitio en la
## mochila). Se borra al caducar o al cambiar de escenario.
class_name LootDrop
extends RefCounted

## Segundos hasta poder recogerlo (el objeto "salta" antes de quedarse quieto).
const PICKUP_DELAY := 0.4
## A que distancia del jugador se puede recoger (clic izquierdo sobre el item).
const PICKUP_RANGE := 56.0
## A que distancia del cursor debe estar el item para contar como clicado.
const CLICK_RADIUS := 20.0
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
