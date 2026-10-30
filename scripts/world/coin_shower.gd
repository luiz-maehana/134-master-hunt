class_name CoinShower
extends CPUParticles3D
## Chuva de moedas douradas caindo no funil do ponto de coleta ao depositar. Uma vez só, mais
## moedas quanto maior o depósito; some sozinha.

static var _mesh: CylinderMesh


## Moedas caindo de um pouco acima de `top` (mundo, boca do funil).
static func burst(parent: Node, top: Vector3, coins: int) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var shower := CoinShower.new()
	shower.amount = clampi(6 + coins / 200, 6, 40)
	parent.add_child(shower)
	shower.global_position = top + Vector3.UP * 1.1
	shower.emitting = true
	shower.finished.connect(shower.queue_free)


func _init() -> void:
	one_shot = true
	explosiveness = 0.6
	lifetime = 0.5
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 0.25
	direction = Vector3.DOWN
	spread = 15.0
	initial_velocity_min = 0.5
	initial_velocity_max = 1.2
	gravity = Vector3(0, -9.8, 0)
	angular_velocity_min = -540.0
	angular_velocity_max = 540.0
	particle_flag_rotate_y = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 0.06
		_mesh.bottom_radius = 0.06
		_mesh.height = 0.012
		_mesh.radial_segments = 10
		_mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.95, 0.75, 0.25)
		material.metallic = 0.7
		material.roughness = 0.3
		material.emission_enabled = true
		material.emission = Color(0.35, 0.25, 0.05)
		_mesh.material = material
	mesh = _mesh
