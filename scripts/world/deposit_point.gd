extends StaticBody3D
## Ponto de coleta: contabiliza as moedas do bolso (moedas encontradas + dinheiro).

@onready var _interactable: Interactable = $Interactable

var _funnel: MeshInstance3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	_build_decor()
	_interactable.interacted.connect(_on_interacted)
	GameState.economy_changed.connect(_refresh)
	_refresh()
	GameState.deposited.connect(func(_amount: int) -> void: _bounce())


func _process(delta: float) -> void:
	_time += delta
	if _ring_material != null:
		# O anel pulsa mais forte quando há moedas no bolso para depositar.
		var strength := 1.6 if GameState.ledger.carried_coins > 0 else 0.5
		_ring_material.emission_energy_multiplier = strength * (0.75 + 0.25 * sin(_time * 3.0))
		_ring.rotation.y = _time * 0.4


## Cofre de moedas: friso dourado, funil no topo, moeda de R$ 1 na frente e anel no chão.
func _build_decor() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.72, 0.2)
	gold.metallic = 0.35
	gold.roughness = 0.35
	_add_box(Vector3(1.3, 0.1, 1.0), 1.45, gold)    # friso
	_add_box(Vector3(1.3, 0.12, 1.0), 0.06, gold)   # base
	_funnel = MeshInstance3D.new()
	var funnel_mesh := CylinderMesh.new()
	funnel_mesh.top_radius = 0.55
	funnel_mesh.bottom_radius = 0.2
	funnel_mesh.height = 0.45
	funnel_mesh.radial_segments = 16
	funnel_mesh.material = gold
	_funnel.mesh = funnel_mesh
	_funnel.position.y = 1.72
	add_child(_funnel)
	var coin := MeshInstance3D.new()
	coin.mesh = CoinVisuals.shared_mesh()
	CoinVisuals.set_denomination(coin, Denomination.VALUES.size() - 1)
	# Moeda grande de pé na frente, acima do letreiro.
	coin.scale = Vector3.ONE * 6.0
	coin.rotation = Vector3(PI * 0.5, 0, 0)
	coin.position = Vector3(0, 0.98, 0.46)
	add_child(coin)
	_build_ring()


func _add_box(size: Vector3, height: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = height
	add_child(instance)


## Anel verde no chão (pulsa em _process).
func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.25
	ring_mesh.outer_radius = 1.4
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 4
	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = Color(0.3, 0.9, 0.45)
	_ring_material.emission_enabled = true
	_ring_material.emission = Color(0.3, 1.0, 0.45)
	ring_mesh.material = _ring_material
	_ring.mesh = ring_mesh
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _bounce() -> void:
	if _funnel == null or not is_inside_tree():
		return
	var tween := create_tween()
	tween.tween_property(_funnel, "scale", Vector3(1.25, 0.8, 1.25), 0.08)
	tween.tween_property(_funnel, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _refresh() -> void:
	var carried := GameState.ledger.carried_coins
	if carried > 0:
		_interactable.prompt_text = "Depositar %s" % MoneyFormat.coins(carried)
	else:
		_interactable.prompt_text = "Ponto de coleta (bolso vazio)"


func _on_interacted(_by: Node) -> void:
	var coins := GameState.ledger.carried_coins
	if GameState.deposit() > 0:
		CoinShower.burst(self, _funnel.global_position + Vector3.UP * 0.25, coins)
	else:
		GameState.notify("Seu bolso está vazio. Vá pegar umas moedas!")
