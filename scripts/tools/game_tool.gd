class_name GameTool
extends Node3D
## Base das ferramentas equipáveis. Subclasses implementam can_use(), _perform() e get_hint().

signal used

var definition: ToolDefinition
var user: ToolUser
var busy := false


## Usa a ferramenta. Retorna false se ocupada ou sem alvo. Aguardável (termina com a animação).
func try_use() -> bool:
	if busy or not can_use():
		return false
	busy = true
	await _perform()
	busy = false
	used.emit()
	return true


func can_use() -> bool:
	return true


## Ferramentas com controle próprio (segurar, soltar, cancelar) tratam a entrada aqui.
## Retorna true se consumiu o evento; senão vale o padrão (clicar = try_use).
func handle_input(_event: InputEvent) -> bool:
	return false


## Texto contextual da ação disponível agora ("" = nada a fazer).
func get_hint() -> String:
	return ""


func _perform() -> void:
	pass


## Raio da câmera até `definition.reach`, contra a geometria sólida (camada 1).
## Paredes e carros bloqueiam o raio, então nada é alcançado através deles.
func _aim_ray() -> Dictionary:
	var cam := user.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * definition.reach
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [user.body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


## true se nada sólido bloqueia a linha entre a câmera e `target`.
func _has_line_of_sight(target: Vector3) -> bool:
	var from := user.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, target, 1, [user.body.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or from.distance_to(hit.position) >= from.distance_to(target) - 0.15


## Tira moedas das pilhas `targets` (itens de CoinWorld.find_near) até a capacidade da
## ferramenta e o espaço do bolso, põe no bolso e mostra o brilho. Mãos e pás usam.
func _collect(targets: Array[Dictionary]) -> void:
	var budget := mini(definition.capacity, GameState.ledger.free_capacity())
	if budget <= 0:
		if not targets.is_empty():
			GameState.notify("Bolsos cheios! Deposite as moedas no ponto de coleta.")
		return
	var picked := 0
	var value := 0
	for target in targets:
		if picked >= budget:
			break
		var got := CoinWorld.current.take(target.key, target.index, budget - picked)
		picked += got
		value += got * int(target.value)
	if picked > 0:
		GameState.add_carried(picked, value)
		PickupSparkle.burst(user.body.get_parent(), targets[0].position, picked)
