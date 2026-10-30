extends StaticBody3D
## Banca da loja na rua: interagir abre a tela da loja.

const GLOVE := preload("res://assets/third_party/quaternius/glove.glb")
const MAGNET := preload("res://assets/third_party/poly_by_google/magnet.glb")
const SHOVEL := preload("res://assets/third_party/kenney/survival-kit/tool-shovel.glb")
const SHOVEL_UPGRADED := preload("res://assets/third_party/kenney/survival-kit/tool-shovel-upgraded.glb")
const ROD := preload("res://assets/third_party/quaternius/fishing_rod.glb")
## Distância (m) até onde a mercadoria do balcão e do painel aparece.
const WARES_VISIBLE := 60.0

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.interacted.connect(func(_by: Node) -> void: GameState.request_shop())
	_build_decor()


## Detalhes da Ferragem: toldo listrado, placa de madeira, painel no fundo com uma pá e uma
## vara penduradas, e no balcão os modelos das ferramentas que o jogo usa (luva, ímã, pá, vara)
## e uma pilhinha de moedas.
func _build_decor() -> void:
	var white := _material(Color(0.95, 0.93, 0.88))
	for i in 5:
		_box($Awning, Vector3(0.19, 0.065, 1.1), Vector3(-0.76 + i * 0.38, 0, 0), white)
	var wood := _material(Color(0.42, 0.27, 0.15))
	_box(self, Vector3(1.85, 0.38, 0.03), Vector3(0, 1.65, 0.075), wood)
	var board := _material(Color(0.78, 0.66, 0.46))
	_box(self, Vector3(1.6, 0.9, 0.04), Vector3(0, 1.55, -0.3), board)
	# Penduradas no painel do fundo.
	# Pá de lâmina para baixo (o "pé" do modelo fica em cima, preso no gancho).
	_model(SHOVEL_UPGRADED, Vector3(-0.45, 1.85, -0.24), Vector3(0, 0, PI), 0.7)
	_model(ROD, Vector3(0.3, 1.15, -0.24), Vector3(0, 0, -0.35), 0.85)
	# Mercadoria no balcão.
	var glove := _model(GLOVE, Vector3(-0.6, 1.07, 0.12), Vector3(0, 0.4, 0), 0.26)
	_tint(glove, Color(0.95, 0.75, 0.15))
	_model(MAGNET, Vector3(-0.32, 1.06, 0.1), Vector3(0, -0.5, 0), 0.22)
	_model(SHOVEL, Vector3(0.58, 1.08, 0.05), Vector3(0, 0.3, PI * 0.5), 0.55)
	for i in 4:
		var coin := MeshInstance3D.new()
		coin.mesh = CoinVisuals.shared_mesh()
		CoinVisuals.set_denomination(coin, Denomination.VALUES.size() - 1)
		coin.position = Vector3(-0.05, 1.05 + (i + 0.5) * coin.scale.y * CoinVisuals.COIN_HEIGHT, 0.18)
		add_child(coin)


## Modelo `scene` com o maior lado medindo `size` metros, apoiado em `at` (base do modelo).
func _model(scene: PackedScene, at: Vector3, rotation_: Vector3, size: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation = rotation_
	add_child(holder)
	var model: Node3D = scene.instantiate()
	holder.add_child(model)
	# Mercadoria some de longe (são várias malhas por loja, 29 lojas).
	for child in model.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).visibility_range_end = WARES_VISIBLE
	var box := _bounds(model, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0:
		var scale_ := size / longest
		model.scale = Vector3.ONE * scale_
		# Centro no x/z e a base em y = 0.
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale_
	return holder


static func _bounds(node: Node3D, xform: Transform3D) -> AABB:
	var box := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = xform * (node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		if not child is Node3D:
			continue
		var inner := _bounds(child, xform * (child as Node3D).transform)
		if inner.size == Vector3.ZERO:
			continue
		box = box.merge(inner) if found else inner
		found = true
	return box


static func _tint(root: Node, color: Color) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		(node as MeshInstance3D).material_override = material


func _box(parent: Node, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


static func _material(color: Color, roughness := 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
