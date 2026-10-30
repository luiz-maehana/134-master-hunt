class_name Portal
extends StaticBody3D
## Portal ao lado de cada loja: arco de pedra com um disco girando. Apagado até o jogador
## comprar o contrato (PORTAL_ITEM); depois, interagir abre a tela de destinos (PortalMenu).
## Bloqueia o jogador, mas não as moedas (o sorteio do mundo é anterior aos portais).

const PORTAL_ITEM := &"portal_contract"
const SHADER := preload("res://assets/shaders/portal.gdshader")
const WIDTH := 2.6
const HEIGHT := 3.3
const PILLAR := 0.45

static var _disc_material: ShaderMaterial

var _disc: MeshInstance3D
var _light: OmniLight3D
var _sign: Label3D
var _sparkles: CPUParticles3D
var _interactable: Interactable


func _ready() -> void:
	collision_layer = 3
	_build()
	_interactable = Interactable.new()
	add_child(_interactable)
	_interactable.interacted.connect(_on_interacted)
	# Compra, presente e novo jogo passam todos por tools_changed.
	GameState.tools_changed.connect(_refresh)
	_refresh()


func is_active() -> bool:
	return GameState.owns(PORTAL_ITEM)


func _on_interacted(_by: Node) -> void:
	if is_active():
		GameState.request_portal(global_position)
	else:
		Sfx.play(&"ui_error", 0.0, -6.0)
		GameState.notify("Portal desligado: compre o Contrato dos portais na Ferragem.")


func _refresh() -> void:
	var active := is_active()
	_disc.set_instance_shader_parameter(&"active", 1.0 if active else 0.0)
	_light.visible = active
	_sparkles.emitting = active
	_sign.modulate = Color(0.8, 0.65, 1.0) if active else Color(0.55, 0.55, 0.6)
	_interactable.prompt_text = "Portal: viajar para outra loja" if active else "Portal desligado (contrato na Ferragem)"


func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.82, 0.8, 0.76)
	stone.roughness = 0.8
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.72, 0.2)
	gold.metallic = 0.35
	gold.roughness = 0.35
	var half := WIDTH * 0.5 + PILLAR * 0.5
	for side: float in [-1.0, 1.0]:
		_box(Vector3(PILLAR, HEIGHT, PILLAR), Vector3(side * half, HEIGHT * 0.5, 0), stone, true)
		_box(Vector3(PILLAR + 0.1, 0.12, PILLAR + 0.1), Vector3(side * half, HEIGHT - 0.3, 0), gold, false)
	_box(Vector3(WIDTH + PILLAR * 2.0 + 0.3, 0.5, PILLAR + 0.1), Vector3(0, HEIGHT + 0.25, 0), stone, true)
	_box(Vector3(WIDTH + PILLAR * 2.0, 0.15, 1.4), Vector3(0, 0.075, 0), stone, false)
	if _disc_material == null:
		_disc_material = ShaderMaterial.new()
		_disc_material.shader = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT - 0.2)
	quad.material = _disc_material
	_disc = MeshInstance3D.new()
	_disc.mesh = quad
	_disc.position.y = (HEIGHT - 0.2) * 0.5 + 0.15
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	# Corpo fino no vão: o raio de interação acerta o disco (e ninguém atravessa o portal a pé).
	var opening := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, 0.3)
	opening.shape = shape
	opening.position.y = HEIGHT * 0.5
	add_child(opening)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.45, 1.0)
	_light.light_energy = 1.4
	_light.omni_range = 6.0
	_light.position = Vector3(0, 1.6, 0.8)
	add_child(_light)
	_sparkles = _make_sparkles()
	add_child(_sparkles)
	_sign = Label3D.new()
	_sign.text = "PORTAL"
	_sign.font_size = 64
	_sign.outline_size = 10
	_sign.pixel_size = 0.004
	_sign.position = Vector3(0, HEIGHT + 0.25, PILLAR * 0.5 + 0.06)
	add_child(_sign)


## Faíscas lilás subindo devagar pelo disco (só com o portal ligado).
func _make_sparkles() -> CPUParticles3D:
	var sparkles := CPUParticles3D.new()
	sparkles.amount = 24
	sparkles.lifetime = 1.8
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparkles.emission_box_extents = Vector3(WIDTH * 0.45, HEIGHT * 0.4, 0.15)
	sparkles.position.y = HEIGHT * 0.5
	sparkles.direction = Vector3.UP
	sparkles.spread = 25.0
	sparkles.initial_velocity_min = 0.2
	sparkles.initial_velocity_max = 0.5
	sparkles.gravity = Vector3(0, 0.15, 0)
	sparkles.scale_amount_min = 0.6
	sparkles.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0))
	fade.add_point(Vector2(0.2, 1))
	fade.add_point(Vector2(1, 0))
	sparkles.scale_amount_curve = fade
	sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sparkles.visibility_range_end = 80.0
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.65, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.7, 0.45, 1.0)
	material.emission_energy_multiplier = 2.0
	dot.material = material
	sparkles.mesh = dot
	return sparkles


func _box(size: Vector3, at: Vector3, material: Material, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position = at
		add_child(collision)
