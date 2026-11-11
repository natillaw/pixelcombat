## Skill — Recurso data-driven para habilidades de combate (ISSUE P1.3).
class_name Skill
extends Resource

enum Slot { M1, M2, SPACE, Q, E, R, F, ITEM_1, ITEM_2, ITEM_3, ITEM_4 }
enum TargetingMode { SELF, ENEMY, ALLY, GROUND, DIRECTION, PROJECTILE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.M1
@export var cooldown: float = 0.0
@export var cast_time: float = 0.0
@export var channel_time: float = 0.0
@export var resource_cost: int = 0
@export var resource_generation: int = 0
@export var is_ex: bool = false
@export var is_ultimate: bool = false
@export var base_skill_id: StringName = &""
@export var iframe_duration: float = 0.0
@export var targeting_mode: TargetingMode = TargetingMode.DIRECTION
@export var effects: Array[Resource] = []
@export var vfx_scene: PackedScene = null
@export var sfx: AudioStream = null
@export var animation_name: String = ""
@export var cancel_window_start: float = 0.0
@export var cancel_window_end: float = 0.0
