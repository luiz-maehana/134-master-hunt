class_name PickupSparkle
extends CPUParticles3D
## Brilho dourado curto onde moedas foram pegas (mãos e pás; ímãs já mostram as moedas
## voando). Uma explosão só, que se apaga sozinha.

static var _mesh: QuadMesh


## Cria o brilho em `position` (mundo), com mais faíscas quanto mais moedas.
static func burst(parent: Node, position_: Vector3, coins: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var sparkle := PickupSparkle.new()
	sparkle.amount = clampi(4 + coins / 20, 4, 24)
	parent.add_child(sparkle)
	sparkle.global_position = position_ + Vector3.UP * 0.05
	sparkle.emitting = true
	sparkle.finished.connect(sparkle.queue_free)


func _init() -> void:
	one_shot = true
	explosiveness = 0.9
	lifetime = 0.45
	local_coords = false
	direction = Vector3.UP
	spread = 55.0
	initial_velocity_min = 0.8
	initial_velocity_max = 1.8
	gravity = Vector3(0, -3.0, 0)
	scale_amount_min = 0.5
	scale_amount_max = 1.0
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	scale_amount_curve = fade
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mesh == null:
		_mesh = QuadMesh.new()
		_mesh.size = Vector2(0.05, 0.05)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_color = Color(1, 0.85, 0.35)
		material.emission_enabled = true
		material.emission = Color(1, 0.8, 0.3)
		_mesh.material = material
	mesh = _mesh
