extends GameTool
## Pás (pequena, média, grande): recolhem moedas de perto, numa área à frente dos pés.
## `reach` = distância do centro da área; `area_radius` = tamanho da área;
## `capacity` = moedas por pazada; `use_time` = duração da pazada.

@onready var _visual: Node3D = $Visual
var _rest_rotation := Vector3.ZERO
var _rest_position := Vector3.ZERO


func _ready() -> void:
	_visual.scale = Vector3.ONE * definition.visual_scale
	$Visual/Model.visible = not definition.upgraded_model
	$Visual/ModelUpgraded.visible = definition.upgraded_model
	_rest_rotation = _visual.rotation
	_rest_position = _visual.position


func scoop_center() -> Vector3:
	var forward := -user.body.global_basis.z
	forward.y = 0.0
	return user.body.global_position + forward.normalized() * definition.reach


## Pilhas na área que a pá alcança (sem parede no caminho).
func find_targets() -> Array[Dictionary]:
	if CoinWorld.current == null:
		return []
	var targets: Array[Dictionary] = []
	# Linha de visão uma vez por célula de busca (até a primeira pilha vista nela).
	var sight := {}
	for target in CoinWorld.current.find_near(scoop_center(), definition.area_radius, 1000, definition.capacity):
		var cell: Vector3i = target.cell
		if not sight.has(cell):
			sight[cell] = _has_line_of_sight(target.position + Vector3.UP * 0.05)
		if sight[cell]:
			targets.append(target)
	return targets


func can_use() -> bool:
	return not find_targets().is_empty()


func get_hint() -> String:
	var targets := find_targets()
	if targets.is_empty():
		return ""
	var free := GameState.ledger.free_capacity()
	if free == 0:
		return "Bolsos cheios! Deposite no ponto de coleta"
	var total := 0
	for target in targets:
		total += int(target.amount)
	return "[%s] Recolher %s" % [InputBindings.label_of(&"use_tool"), MoneyFormat.coins(mini(mini(total, definition.capacity), free))]


func _perform() -> void:
	var third := definition.use_time / 3.0
	var dig := create_tween().set_parallel()
	dig.tween_property(_visual, "rotation", _rest_rotation + Vector3(-0.5, 0, 0), third)
	dig.tween_property(_visual, "position", _rest_position + Vector3(0, -0.12, -0.15), third)
	await dig.finished
	_collect(find_targets())
	var lift := create_tween().set_parallel()
	lift.tween_property(_visual, "rotation", _rest_rotation + Vector3(0.45, 0.2, 0), third)
	lift.tween_property(_visual, "position", _rest_position + Vector3(0.05, 0.08, 0), third)
	await lift.finished
	var back := create_tween().set_parallel()
	back.tween_property(_visual, "rotation", _rest_rotation, third)
	back.tween_property(_visual, "position", _rest_position, third)
	await back.finished

