class_name EasterEggKit
extends RefCounted
## Peças dos segredos da cidade (CityEasterEggs, EscapeEasterEggs): caixas coloridas, letreiros,
## pessoas em blocos, nuvem de fumaça e objetos com que o jogador interage (E). Nada aqui entra
## no sorteio das moedas.

const FONT_SIZE := 64


## Corpo físico que o jogador não atravessa e com o qual interage (E). `action` sem argumentos.
static func interactive(parent: Node3D, node_name: String, at: Vector3, size: Vector3, prompt: String, action: Callable) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 3
	body.position = at
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	var interactable := Interactable.new()
	interactable.prompt_text = prompt
	interactable.interacted.connect(func(_by: Node) -> void: action.call())
	body.add_child(interactable)
	return body


static func box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


static func label(parent: Node3D, text: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var label_3d := Label3D.new()
	label_3d.text = text
	label_3d.font_size = FONT_SIZE
	label_3d.outline_size = 8
	label_3d.pixel_size = pixel
	label_3d.modulate = color
	label_3d.position = at
	label_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_3d.visibility_range_end = 250.0
	parent.add_child(label_3d)
	return label_3d


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.8
	if color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result


## Pessoa em blocos (1,9 m), de frente para +z: terno, camisa, gravata, cabelo e, se pedido,
## óculos escuros e maleta.
static func person(parent: Node3D, suit: Color, tie: Color, glasses := true, briefcase := true) -> void:
	var cloth := material(suit)
	var skin := material(Color(0.85, 0.68, 0.55))
	for x: float in [-0.12, 0.12]:
		box(parent, Vector3(0.16, 0.85, 0.2), Vector3(x, 0.43, 0), cloth)
	box(parent, Vector3(0.5, 0.7, 0.28), Vector3(0, 1.2, 0), cloth)
	box(parent, Vector3(0.14, 0.45, 0.02), Vector3(0, 1.3, 0.145), material(Color(0.95, 0.95, 0.95)))
	box(parent, Vector3(0.06, 0.38, 0.02), Vector3(0, 1.28, 0.157), material(tie))
	for x: float in [-0.31, 0.31]:
		box(parent, Vector3(0.12, 0.65, 0.18), Vector3(x, 1.18, 0), cloth)
	box(parent, Vector3(0.28, 0.32, 0.28), Vector3(0, 1.73, 0), skin)
	box(parent, Vector3(0.3, 0.08, 0.3), Vector3(0, 1.91, -0.01), material(Color(0.12, 0.1, 0.08)))
	if glasses:
		box(parent, Vector3(0.26, 0.06, 0.02), Vector3(0, 1.76, 0.145), material(Color(0.02, 0.02, 0.02)))
	if briefcase:
		box(parent, Vector3(0.12, 0.35, 0.45), Vector3(0.42, 0.75, 0), material(Color(0.25, 0.15, 0.08)))


## Mala executiva (fechada) com alça.
static func suitcase(parent: Node3D, at: Vector3, color: Color) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	parent.add_child(holder)
	box(holder, Vector3(0.7, 0.5, 0.22), Vector3(0, 0.25, 0), material(color))
	box(holder, Vector3(0.24, 0.06, 0.06), Vector3(0, 0.53, 0), material(Color(0.1, 0.1, 0.1)))
	return holder


## Nuvem de fumaça cinza em `at` (mundo).
static func puff(parent: Node3D, at: Vector3) -> void:
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.amount = 24
	smoke.lifetime = 0.9
	smoke.local_coords = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.4
	smoke.direction = Vector3.UP
	smoke.spread = 80.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0, 0.5, 0)
	var ball := SphereMesh.new()
	ball.radius = 0.18
	ball.height = 0.36
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = material(Color(0.7, 0.7, 0.72, 0.8))
	smoke.mesh = ball
	parent.add_child(smoke)
	smoke.global_position = at + Vector3.UP * 1.0
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)


## Dá `cents` centavos para a carteira (achados dos segredos; não contam para a meta).
static func give_cents(cents: int) -> void:
	GameState.ledger.money_cents += cents
	GameState.economy_changed.emit()
