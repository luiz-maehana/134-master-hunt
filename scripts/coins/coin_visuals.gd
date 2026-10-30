class_name CoinVisuals
extends RefCounted
## Malhas e materiais compartilhados das moedas: a moeda (frente/verso no atlas, em duas
## resoluções) e a textura de "tapete" usada ao longe.

const DEFAULT_MATERIAL := "res://assets/textures/coin/coin_material.tres"
const COIN_SHADER := "res://assets/shaders/coin.gdshader"
const COIN_RADIUS := 0.06
const COIN_HEIGHT := 0.012
const COIN_SEGMENTS := 24
## Lados da moeda longe do jogador.
const SIMPLE_SEGMENTS := 8
## Margem interna do disco no atlas, para não amostrar o fundo fora da moeda.
const UV_INSET := 0.97

static var _shared_mesh: ArrayMesh
static var _meshes := {}
static var _carpet_texture: ImageTexture


## Solta os caches estáticos (chamado ao encerrar, evita aviso de recurso em uso).
static func release_cache() -> void:
	_shared_mesh = null
	_meshes.clear()
	_carpet_texture = null


## Malha de uma moeda (moedas soltas, pilhas e efeitos) com o shader dos seis valores.
## Num MultiMesh com dados customizados, o valor vem de denomination_custom(); numa moeda
## solta, de set_denomination().
static func shared_mesh() -> ArrayMesh:
	if _shared_mesh == null:
		_shared_mesh = build_coin_mesh()
		_shared_mesh.surface_set_material(0, coin_material())
	return _shared_mesh


static func coin_material() -> ShaderMaterial:
	var base := load(DEFAULT_MATERIAL) as StandardMaterial3D
	var material := ShaderMaterial.new()
	material.shader = load(COIN_SHADER)
	material.set_shader_parameter("albedo_texture", base.albedo_texture)
	material.set_shader_parameter("normal_texture", base.normal_texture)
	material.set_shader_parameter("normal_scale", base.normal_scale)
	material.set_shader_parameter("metallic", base.metallic)
	material.set_shader_parameter("roughness", base.roughness)
	# Uma linha do atlas por valor (tools/build_coin_textures.gd).
	material.set_shader_parameter("use_atlas", true)
	var faces := PackedVector3Array()
	var rings := PackedVector3Array()
	for i in Denomination.count():
		var face := Denomination.FACE_COLORS[i]
		var ring := Denomination.RING_COLORS[i]
		faces.append(Vector3(face.r, face.g, face.b))
		rings.append(Vector3(ring.r, ring.g, ring.b))
	material.set_shader_parameter("face_colors", faces)
	material.set_shader_parameter("ring_colors", rings)
	return material


## Dado customizado de MultiMesh que escolhe o valor da moeda no shader.
static func denomination_custom(index: int) -> Color:
	return Color(index / 10.0, 0, 0, 0)


## Escolhe o valor de uma moeda solta (MeshInstance3D com shared_mesh()).
static func set_denomination(instance: GeometryInstance3D, index: int) -> void:
	instance.set_instance_shader_parameter(&"denomination_override", float(index))
	instance.scale = Vector3.ONE * Denomination.scale_of(index)


## Mesma moeda com menos lados, para os blocos mais afastados (o mesmo material).
static func simple_mesh() -> ArrayMesh:
	return mesh_with(SIMPLE_SEGMENTS)


## Malha das pilhas com `segments` lados (detalhe das moedas), com o material compartilhado.
static func mesh_with(segments: int) -> ArrayMesh:
	if segments == COIN_SEGMENTS:
		return shared_mesh()
	if not _meshes.has(segments):
		var mesh := build_coin_mesh(segments)
		mesh.surface_set_material(0, shared_mesh().surface_get_material(0))
		_meshes[segments] = mesh
	return _meshes[segments]


## Textura de moedas espalhadas (transparente), projetada no chão ao longe por decalques.
## Gerada uma vez em código: não precisa de arquivo.
static func carpet_texture() -> ImageTexture:
	if _carpet_texture == null:
		var size := 256
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 134
		for i in 420:
			var center := Vector2(rng.randf() * size, rng.randf() * size)
			var radius := rng.randf_range(2.0, 3.5)
			var tone := rng.randf_range(0.75, 1.15)
			for y in range(int(center.y - radius), int(center.y + radius) + 1):
				for x in range(int(center.x - radius), int(center.x + radius) + 1):
					var d := Vector2(x, y).distance_to(center)
					if d <= radius:
						var shade := 1.0 - d / radius * 0.4
						image.set_pixel(posmod(x, size), posmod(y, size), Color(0.78 * tone * shade, 0.45 * tone * shade, 0.26 * tone * shade, 1.0))
		image.generate_mipmaps()
		_carpet_texture = ImageTexture.create_from_image(image)
	return _carpet_texture


## Disco com as duas faces mapeadas no atlas 2:1 (esquerda = frente "1 CENTAVO",
## direita = verso) e a lateral com a cor da borda. Godot usa sentido horário como frente.
static func build_coin_mesh(segments := COIN_SEGMENTS) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var half_h := COIN_HEIGHT * 0.5
	# Lateral: fundo do atlas entre as duas faces, que tem a cor da borda de cada moeda.
	var rim_uv := Vector2(0.5, 0.04)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		var p0 := Vector3(d0.x, 0, d0.y) * COIN_RADIUS
		var p1 := Vector3(d1.x, 0, d1.y) * COIN_RADIUS
		var top := Vector3.UP * half_h
		var bottom := Vector3.DOWN * half_h
		# Frente (y+): +z da moeda = parte de baixo da imagem.
		_add_triangle(vertices, normals, uvs, Vector3.UP,
			[top, top + p0, top + p1],
			[_face_uv(Vector2.ZERO, 0.25), _face_uv(d0, 0.25), _face_uv(d1, 0.25)])
		# Verso (y-): a moeda virada gira 180° em x, então z inverte; assim a imagem não
		# aparece espelhada quando ela cai de coroa.
		_add_triangle(vertices, normals, uvs, Vector3.DOWN,
			[bottom, bottom + p1, bottom + p0],
			[_face_uv(Vector2.ZERO, 0.75), _face_uv(Vector2(d1.x, -d1.y), 0.75), _face_uv(Vector2(d0.x, -d0.y), 0.75)])
		# Lateral.
		var n0 := Vector3(d0.x, 0, d0.y)
		var n1 := Vector3(d1.x, 0, d1.y)
		for tri in [[top + p0, bottom + p0, top + p1, n0, n0, n1], [top + p1, bottom + p0, bottom + p1, n1, n0, n1]]:
			for k in 3:
				vertices.append(tri[k])
				normals.append(tri[k + 3])
				uvs.append(rim_uv)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	# Tangentes são necessárias para o normal map (relevo) funcionar.
	var surface := SurfaceTool.new()
	surface.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
	# Vértices iguais viram um só (centro das faces, bordas): a placa processa bem menos vértices
	# por pilha, e são centenas de milhares de pilhas.
	surface.index()
	surface.generate_tangents()
	return surface.commit()


static func _face_uv(direction: Vector2, center_u: float) -> Vector2:
	return Vector2(center_u + direction.x * 0.25 * UV_INSET, 0.5 + direction.y * 0.5 * UV_INSET)


static func _add_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		normal: Vector3, points: Array, tex: Array) -> void:
	for k in 3:
		vertices.append(points[k])
		normals.append(normal)
		uvs.append(tex[k])
