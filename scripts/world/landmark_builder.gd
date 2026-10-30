class_name LandmarkBuilder
extends RefCounted
## Marcos do Eixo Monumental em low poly caricato (formas reconhecíveis, nunca cópia exata, sem
## brasões): Rodoviária, Biblioteca, Museu, Teatro, Catedral, Itamaraty, Justiça,
## Congresso, Planalto, STF e o mastro da bandeira. Feitos de primitivas, com colisões simples.
## A pegada de cada um (sem moedas) vem do CityLayout.

var _parent: Node3D
var _layout: CityLayout
var _body: StaticBody3D
var _glass: ShaderMaterial
var _white: StandardMaterial3D
var _concrete: StandardMaterial3D
var _water: StandardMaterial3D
var _blue_glass: StandardMaterial3D


## Cria todos os marcos de `layout` dentro de `parent`. `glass` = material das fachadas com
## janelas (o mesmo dos prédios, que o ciclo de dia e noite acende).
static func build_all(parent: Node3D, layout: CityLayout, glass: ShaderMaterial) -> void:
	var builder := LandmarkBuilder.new()
	builder._parent = parent
	builder._layout = layout
	builder._glass = glass
	builder._make_materials()
	for landmark in layout.landmarks:
		builder._body = StaticBody3D.new()
		builder._body.name = "Landmark_%s" % landmark.kind
		parent.add_child(builder._body)
		var rect: Rect2 = landmark.rect
		var at := Vector3(rect.get_center().x, layout.definition.curb_height, rect.get_center().y)
		builder.call("_build_%s" % landmark.kind, at, rect, landmark.area)
		builder._add_mesh_collisions()
		builder._merge_meshes()


func _make_materials() -> void:
	_white = _color(Color(0.94, 0.94, 0.91), 0.6)
	_concrete = _color(Color(0.72, 0.71, 0.68), 0.9)
	_water = _color(Color(0.18, 0.42, 0.62), 0.05)
	_water.metallic = 0.4
	_blue_glass = _color(Color(0.45, 0.65, 0.85, 0.45), 0.1)
	_blue_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


static func _color(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


# --- Peças -------------------------------------------------------------------------------

## Caixa unitária escalada (as fachadas com janelas dependem da escala, não do tamanho da malha).
func _box(size: Vector3, center: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.material = material
	instance.mesh = mesh
	instance.transform = Transform3D(Basis.from_euler(rotation).scaled(size), center)
	_body.add_child(instance)
	return instance


func _cylinder(top: float, bottom: float, height: float, center: Vector3, material: Material, segments := 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	_body.add_child(instance)
	return instance


func _dome(radius: float, center: Vector3, material: Material, upside_down := false) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	mesh.radial_segments = 24
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	if upside_down:
		instance.rotation.x = PI
	_body.add_child(instance)


## Colisão de cada peça com o formato da própria malha (vértices já transformados; o motor de
## física monta o casco convexo, sem a limpeza do Godot, que custava ~20 s na abertura), para
## nada atravessar: pirâmide do Teatro, colunas da Catedral, cúpulas. Peças marcadas como
## enfeite ("decor": espelhos d'água, faixas, a bandeira) ficam sem colisão.
func _add_mesh_collisions() -> void:
	var pieces := 0
	for node in _body.get_children():
		var instance := node as MeshInstance3D
		if instance == null or instance.has_meta("decor") or instance.mesh == null:
			continue
		var hull := instance.mesh.create_convex_shape(false, false) as ConvexPolygonShape3D
		var points := PackedVector3Array()
		for point in hull.points:
			points.append(instance.transform * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		_body.add_child(collision)
		pieces += 1
	_body.set_meta(&"pieces", pieces)


## Junta as peças de cada material comum (StandardMaterial3D) numa malha só: a Catedral, por
## exemplo, eram dezenas de chamadas de desenho (e o dobro com sombra) e vira uma por material.
## As fachadas com janelas (ShaderMaterial) ficam separadas: o desenho delas depende da escala
## de cada peça.
func _merge_meshes() -> void:
	var groups := {}   # Material -> SurfaceTool
	for node in _body.get_children():
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null or instance.mesh.get_surface_count() != 1:
			continue
		var material: Material = (instance.mesh as PrimitiveMesh).material if instance.mesh is PrimitiveMesh else instance.mesh.surface_get_material(0)
		if not material is StandardMaterial3D:
			continue
		var tool: SurfaceTool = groups.get(material)
		if tool == null:
			tool = SurfaceTool.new()
			groups[material] = tool
		tool.append_from(instance.mesh, 0, instance.transform)
		_body.remove_child(instance)
		instance.queue_free()
	for material: Material in groups:
		var tool: SurfaceTool = groups[material]
		tool.set_material(material)
		var merged := MeshInstance3D.new()
		merged.mesh = tool.commit()
		_body.add_child(merged)


func _water_pool(rect: Rect2, y: float) -> void:
	var pool := _box(Vector3(rect.size.x, 0.1, rect.size.y), Vector3(rect.get_center().x, y + 0.05, rect.get_center().y), _water)
	pool.set_meta("decor", true)


## Colunata em volta de um retângulo: colunas finas e uma laje no topo.
func _colonnade(rect: Rect2, base: float, height: float, spacing: float) -> void:
	var steps_x := maxi(1, roundi(rect.size.x / spacing))
	var steps_z := maxi(1, roundi(rect.size.y / spacing))
	for i in steps_x + 1:
		var x := rect.position.x + rect.size.x * i / steps_x
		for z: float in [rect.position.y, rect.end.y]:
			_box(Vector3(0.8, height, 0.8), Vector3(x, base + height * 0.5, z), _white)
	for i in range(1, steps_z):
		var z := rect.position.y + rect.size.y * i / steps_z
		for x: float in [rect.position.x, rect.end.x]:
			_box(Vector3(0.8, height, 0.8), Vector3(x, base + height * 0.5, z), _white)
	_box(Vector3(rect.size.x + 2.0, 1.0, rect.size.y + 2.0), Vector3(rect.get_center().x, base + height + 0.5, rect.get_center().y), _white)


# --- Marcos (oeste → leste) --------------------------------------------------------------

## Rodoviária: plataforma de concreto atravessando o eixo (norte–sul) sobre pilares, por cima
## do gramado; o ponto de serviço inicial fica embaixo dela.
func _build_bus_station(_at: Vector3, _rect: Rect2, area: Rect2) -> void:
	var center := Vector3(area.get_center().x, 0.0, area.get_center().y)
	var width := 46.0
	var length := area.size.y * 0.45
	_box(Vector3(width, 1.2, length), center + Vector3(0, 7.5, 0), _concrete)
	var pillars := int(length / 16.0)
	for i in pillars + 1:
		var z := center.z - length * 0.5 + length * i / pillars
		# Pilares nas bordas, longe do ponto de serviço (que fica no meio), e nunca na pista:
		# onde a plataforma passa por cima de uma avenida, o vão fica livre.
		for x: float in [-21.0, 21.0]:
			if _layout.ground_height(center.x + x, z - 1.0) > 0.0 and _layout.ground_height(center.x + x, z + 1.0) > 0.0:
				_cylinder(0.7, 0.7, 7.0, Vector3(center.x + x, 3.6, z), _concrete, 8)


## Biblioteca Nacional: bloco branco com uma faixa escura de janelas.
func _build_library(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	_box(Vector3(rect.size.x, 14, rect.size.y), at + Vector3(0, 7, 0), _white)
	_box(Vector3(rect.size.x + 0.2, 2.0, rect.size.y + 0.2), at + Vector3(0, 9, 0), _concrete)


## Museu Nacional: cúpula branca baixa e a rampa curva (aqui reta) até a porta.
func _build_museum(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	var radius := rect.size.x * 0.5
	_dome(radius, at, _white)
	_box(Vector3(18, 0.6, 3), at + Vector3(radius * 0.6, 4.0, -radius - 1.0), _white, Vector3(0, 0, 0.35))


## Teatro Nacional: pirâmide truncada.
func _build_theater(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	var instance := _cylinder(6.0, rect.size.x * 0.68, 22, at + Vector3(0, 11, 0), _concrete, 4)
	instance.rotation.y = PI * 0.25


## Catedral: dezesseis colunas curvas (duas retas cada) presas num anel, com o vidro azul.
func _build_cathedral(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	var base := rect.size.x * 0.45
	_cylinder(8.0, base - 1.0, 18, at + Vector3(0, 9, 0), _blue_glass, 16)
	for i in 16:
		var angle := TAU * i / 16.0
		var out := Vector3(cos(angle), 0, sin(angle))
		var low := at + out * base
		var waist := at + out * 5.0 + Vector3(0, 14, 0)
		var top := at + out * 9.0 + Vector3(0, 26, 0)
		_column_between(low, waist)
		_column_between(waist, top)
	_cylinder(5.2, 5.2, 1.0, at + Vector3(0, 14, 0), _white, 16)


func _column_between(a: Vector3, b: Vector3) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.material = _white
	instance.mesh = mesh
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, up, side.cross(up)).scaled(Vector3(1.2, a.distance_to(b), 1.2))
	instance.transform = Transform3D(basis, (a + b) * 0.5)
	_body.add_child(instance)


## Itamaraty: caixa de vidro dentro de uma colunata de arcos (aqui colunas), sobre o espelho d'água.
func _build_itamaraty(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	_water_pool(rect, at.y)
	var inner := rect.grow(-6.0)
	_box(Vector3(inner.size.x, 14, inner.size.y), at + Vector3(0, 7, 0), _glass)
	_colonnade(rect.grow(-1.5), at.y, 15, 4.5)


## Palácio da Justiça (ao norte): o mesmo desenho, com as cascatas na fachada virada para o eixo.
func _build_justice(at: Vector3, rect: Rect2, area: Rect2) -> void:
	_build_itamaraty(at, rect, area)
	for i in 5:
		var x := rect.position.x + 4.0 + (rect.size.x - 8.0) * i / 4.0
		_box(Vector3(1.6, 12, 0.3), Vector3(x, at.y + 7, rect.end.y - 1.2), _water)


## Congresso Nacional: plataforma baixa com a cúpula do Senado (norte) e a "tigela" da Câmara
## (sul), as duas torres no fundo e o espelho d'água na frente.
func _build_congress(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	var platform := Vector3(rect.size.x * 0.75, 8, rect.size.y * 0.6)
	var center := at + Vector3(-rect.size.x * 0.05, platform.y * 0.5, 0)
	_box(platform, center, _white)
	var top := at.y + platform.y
	_dome(15.0, Vector3(center.x, top, at.z - platform.z * 0.27), _white)
	_cylinder(24.0, 8.0, 12.0, Vector3(center.x, top + 6.0, at.z + platform.z * 0.27), _white, 24)
	# As duas torres coladas: faces largas de vidro para o eixo (oeste), pontas brancas.
	var towers_x := rect.end.x - 8.0
	for z: float in [-9.0, 9.0]:
		var tower := _box(Vector3(8, 96, 16), Vector3(towers_x, at.y + 48, at.z + z), _glass)
		tower.set_instance_shader_parameter(&"ministry_mode", true)
	_box(Vector3(6, 6, 3), Vector3(towers_x, at.y + 62, at.z), _white)
	_water_pool(Rect2(rect.position.x, at.z - rect.size.y * 0.4, rect.size.x * 0.1, rect.size.y * 0.8), at.y)


## Palácio do Planalto: vidro baixo sob uma laje branca, com colunas nas bordas.
func _build_planalto(at: Vector3, rect: Rect2, _area: Rect2) -> void:
	_box(Vector3(rect.size.x - 6.0, 9, rect.size.y - 6.0), at + Vector3(0, 4.5, 0), _glass)
	_colonnade(rect.grow(-0.5), at.y, 11, 6.0)
	_box(Vector3(12, 0.6, 4), at + Vector3(0, 3.0, -rect.size.y * 0.5 - 3.0), _white, Vector3(0.25, 0, 0))


## Supremo Tribunal Federal: o mesmo desenho, menor.
func _build_supreme_court(at: Vector3, rect: Rect2, area: Rect2) -> void:
	_build_planalto(at, rect, area)


## Mastro da bandeira na Praça dos Três Poderes (pano verde e amarelo, sem brasão).
func _build_flag(at: Vector3, _rect: Rect2, _area: Rect2) -> void:
	_cylinder(0.4, 0.6, 60, at + Vector3(0, 30, 0), _white, 8)
	for cloth: MeshInstance3D in [
			_box(Vector3(0.2, 9, 14), at + Vector3(0, 54, 7.5), _color(Color(0.1, 0.55, 0.25), 0.8)),
			_box(Vector3(0.25, 6, 6), at + Vector3(0, 54, 7.5), _color(Color(0.98, 0.82, 0.1), 0.8), Vector3(PI * 0.25, 0, 0))]:
		cloth.set_meta("decor", true)
