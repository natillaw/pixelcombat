## ResourceNode — un nodo de recoleccion del mundo (veta de mineral, hierba, arbol).
##
## El jugador lo recolecta con clic izquierdo estando cerca y quieto; tras el tiempo
## del tipo (`gather_seconds` en data/materials.json) da materiales del tier del
## piso y se agota. Cada vez que se entra a un piso sus nodos vuelven (como los
## enemigos), asi que nunca queda un piso sin recursos.
class_name ResourceNode
extends RefCounted

## A que distancia del cursor debe estar el nodo para contar como clicado.
const CLICK_RADIUS := 24.0
## A que distancia del jugador se puede recolectar.
const GATHER_RANGE := 60.0

var kind: String
var tier: int
var position: Vector2
var depleted: bool = false


func _init(p_kind: String, p_tier: int, p_position: Vector2) -> void:
	kind = p_kind
	tier = p_tier
	position = p_position


func material_id() -> String:
	return MaterialCatalog.material_id(kind, tier)


func gather_seconds() -> float:
	return float(MaterialCatalog.kind(kind)["gather_seconds"])


func display_name() -> String:
	return MaterialCatalog.display_name(material_id())
