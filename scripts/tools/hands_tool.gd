extends GameTool
## Mãos, luva e luva grande: pegam moedas das pilhas sob a mira.
## `capacity` = moedas por coleta (tira só parte de uma pilha, se for o caso);
## `area_radius` = tolerância da mira (a luva grande junta pilhas vizinhas);
## `use_time` = velocidade. `tint`/`visual_scale` mudam o visual da mão.
##
## A mão é flutuante (sem braço), com a palma para baixo, montada em peças: palma, quatro dedos
## de duas falanges e o polegar. Ao pegar, ela desce e fecha os dedos; depois volta e abre.

## Cor da mão sem luva.
const SKIN := Color(0.86, 0.64, 0.5)
## Dedos: posição do nó dos dedos na palma (x) e comprimento de cada falange (m).
const FINGERS := [[-0.03, 0.042, 0.034], [-0.01, 0.047, 0.037], [0.01, 0.045, 0.035], [0.03, 0.036, 0.028]]
const FINGER_WIDTH := 0.017
const PALM := Vector3(0.085, 0.026, 0.09)
## Quanto cada articulação dobra com a mão fechada (rad).
const CURL_BASE := 1.25
const CURL_TIP := 1.35
const THUMB_CURL := 0.9

@onready var _hand: Node3D = $Hand
var _rest := Vector3.ZERO
var _rest_rotation := Vector3.ZERO
## Articulações dos dedos: [nó da base, nó do meio] por dedo; e a do polegar.
var _joints: Array[Array] = []
var _thumb: Node3D
var _time := 0.0


func _ready() -> void:
	_rest = _hand.position
	_rest_rotation = _hand.rotation
	_hand.scale = Vector3.ONE * definition.visual_scale
	var gloved := definition.tint != Color.WHITE
	var material := StandardMaterial3D.new()
	material.albedo_color = definition.tint if gloved else SKIN
	material.roughness = 0.9
	_build_hand(material, gloved)
	set_grip(0.0)


func _process(delta: float) -> void:
	# Flutuando: sobe e desce de leve quando está parada.
	_time += delta
	if not busy:
		_hand.position = _rest + Vector3(0, sin(_time * 2.0) * 0.004, 0)


## 0 = mão aberta, 1 = fechada (dedos dobrados para baixo, sob a palma).
func set_grip(amount: float) -> void:
	for joint: Array in _joints:
		(joint[0] as Node3D).rotation.x = -CURL_BASE * amount
		(joint[1] as Node3D).rotation.x = -CURL_TIP * amount
	if _thumb != null:
		_thumb.rotation = Vector3(-0.2 - 0.5 * amount, 0.5 - THUMB_CURL * amount, 0)


func _build_hand(material: Material, gloved: bool) -> void:
	_part(_hand, PALM, Vector3.ZERO, material)
	if gloved:
		# Punho da luva, um pouco mais largo e escuro.
		var cuff := StandardMaterial3D.new()
		cuff.albedo_color = (material as StandardMaterial3D).albedo_color.darkened(0.25)
		cuff.roughness = 0.9
		_part(_hand, Vector3(PALM.x + 0.012, PALM.y + 0.012, 0.035), Vector3(0, 0, PALM.z * 0.5 + 0.012), cuff)
	for finger: Array in FINGERS:
		var base := Node3D.new()
		base.position = Vector3(finger[0], 0, -PALM.z * 0.5)
		_hand.add_child(base)
		_part(base, Vector3(FINGER_WIDTH, 0.019, finger[1]), Vector3(0, 0, -finger[1] * 0.5), material)
		var middle := Node3D.new()
		middle.position = Vector3(0, 0, -finger[1])
		base.add_child(middle)
		_part(middle, Vector3(FINGER_WIDTH * 0.95, 0.017, finger[2]), Vector3(0, 0, -finger[2] * 0.5), material)
		_joints.append([base, middle])
	# Polegar: sai do lado esquerdo da palma (mão direita, palma para baixo).
	_thumb = Node3D.new()
	_thumb.position = Vector3(-PALM.x * 0.5, -0.004, 0.01)
	_hand.add_child(_thumb)
	_part(_thumb, Vector3(0.02, 0.019, 0.05), Vector3(-0.006, 0, -0.025), material)


static func _part(parent: Node3D, size: Vector3, center: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## Pilhas sob a mira. Itens de CoinWorld.find_near.
func find_targets() -> Array[Dictionary]:
	if CoinWorld.current == null:
		return []
	var hit := _aim_ray()
	if hit.is_empty():
		return []
	return CoinWorld.current.find_near(hit.position, definition.area_radius, 64, definition.capacity)


func can_use() -> bool:
	return not find_targets().is_empty()


func get_hint() -> String:
	var targets := find_targets()
	if targets.is_empty():
		return ""
	var free := GameState.ledger.free_capacity()
	if free == 0:
		return "Bolsos cheios! Deposite no ponto de coleta"
	var amount := mini(mini(_sum(targets), definition.capacity), free)
	return "[%s] Pegar %s" % [InputBindings.label_of(&"use_tool"), "moeda" if amount == 1 else MoneyFormat.coins(amount)]


func _perform() -> void:
	var half := definition.use_time * 0.5
	# Desce e avança abrindo bem os dedos, e fecha no fim da descida.
	var reach_down := create_tween().set_parallel()
	var target := _rest + Vector3(-0.04, -0.17, -0.26)
	if definition.capacity > 10:
		# Luva grande: varre de lado, juntando as pilhas vizinhas.
		target = _rest + Vector3(0.1, -0.18, -0.28)
		reach_down.tween_property(_hand, "rotation", _rest_rotation + Vector3(0, 0.5, 0), half)
	reach_down.tween_property(_hand, "position", target, half).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	reach_down.tween_method(set_grip, 0.0, -0.15, half * 0.6)
	reach_down.tween_method(set_grip, -0.15, 1.0, half * 0.4).set_delay(half * 0.6)
	await reach_down.finished
	# Revalida no momento da coleta: a mira pode ter mudado durante a animação.
	_collect(find_targets())
	var back := create_tween().set_parallel()
	back.tween_property(_hand, "position", _rest, half).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	back.tween_property(_hand, "rotation", _rest_rotation, half)
	back.tween_method(set_grip, 1.0, 0.0, half).set_delay(half * 0.3)
	await back.finished


static func _sum(targets: Array[Dictionary]) -> int:
	var total := 0
	for target in targets:
		total += int(target.amount)
	return total
