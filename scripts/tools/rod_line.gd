class_name RodLine
extends RefCounted
## Desenho da vara com ímã sem estado próprio: a linha caída entre a ponta e o ímã, a
## trajetória prevista (tracejada) e o material chapado dessas fitas.

const WIDTH := 0.004
const SEGMENTS := 16


## Pontos da linha de `a` até `b`, caindo no meio (`sag_factor` × comprimento) e nunca
## abaixo do ponto mais baixo das pontas (o ímã no chão).
static func sag_points(a: Vector3, b: Vector3, sag_factor: float) -> PackedVector3Array:
	var sag := a.distance_to(b) * sag_factor
	var floor_y := minf(a.y, b.y) + 0.02
	var points := PackedVector3Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var point := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
		point.y = maxf(point.y, floor_y)
		points.append(point)
	return points


## Fita voltada para a câmera ao longo dos pontos (mais larga ao longe, para não sumir).
static func ribbon(mesh: ImmediateMesh, points: PackedVector3Array, dashed: bool, camera: Vector3) -> void:
	mesh.clear_surfaces()
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		if dashed and i % 2 == 1:
			continue
		var p0 := points[i]
		var p1 := points[i + 1]
		var side0 := _side(p0, p1 - p0, camera)
		var side1 := _side(p1, p1 - p0, camera)
		for vertex in [p0 - side0, p0 + side0, p1 + side1, p0 - side0, p1 + side1, p1 - side1]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()


static func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func _side(point: Vector3, direction: Vector3, camera: Vector3) -> Vector3:
	var width := WIDTH + 0.0012 * camera.distance_to(point)
	return direction.cross(camera - point).normalized() * width
