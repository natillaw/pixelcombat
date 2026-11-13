## Vignette — oscurece suavemente los bordes de la pantalla para dar atmosfera. La fuerza
## depende del escenario: la ciudad apenas, los pisos mas oscuros segun su bioma.
class_name Vignette
extends ColorRect

const STRENGTH := {
	"town": 0.20, "forest": 0.55, "cave": 0.70, "ruins": 0.60, "swamp": 0.62, "desert": 0.38,
	"ice": 0.42, "volcano": 0.58, "crypt": 0.74, "sky": 0.30, "void": 0.76,
}

var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float strength = 0.5;\nuniform vec3 tint = vec3(1.0);\nuniform float wash = 0.0;\nvoid fragment() {\n\tvec2 uv = UV - vec2(0.5);\n\tfloat d = length(uv * vec2(1.05, 1.0));\n\tfloat a = smoothstep(0.28, 0.78, d) * strength;\n\tvec3 dark = vec3(0.01, 0.015, 0.04);\n\tvec3 c = mix(tint, dark, clamp(a / (a + wash + 0.0001), 0.0, 1.0));\n\tCOLOR = vec4(c, clamp(a + wash, 0.0, 1.0));\n}\n"
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material


func apply_layout(layout: FloorLayout) -> void:
	if _material == null:
		return
	var strength := float(STRENGTH.get(layout.biome, 0.5))
	var tint := Vector3.ONE
	var wash := 0.0
	# Cada piso de la torre tiene su ambiente (data/lore.json > floors > ambient): color de fondo y fuerza del borde.
	if layout.kind == FloorLayout.KIND_FLOOR:
		var ambient: Dictionary = Lore.floor_info(layout.floor_number).get("ambient", {})
		if not ambient.is_empty():
			var color: Array = ambient["tint"]
			tint = Vector3(float(color[0]), float(color[1]), float(color[2]))
			wash = float(ambient["wash"])
			strength = clampf(strength * float(ambient["vignette_mult"]), 0.0, 0.9)
	_material.set_shader_parameter("strength", strength)
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("wash", wash)
