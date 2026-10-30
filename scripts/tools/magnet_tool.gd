extends GameTool
## Ímã (pequeno, médio, grande): atrai moedas das pilhas à frente do jogador.
## `reach` = alcance da atração; `power` = velocidade das moedas (m/s, intensidade);
## `capacity` = máximo de moedas por uso; `use_time` = recarga.
## Ímã passivo (neodímio, `definition.passive`): enquanto equipado, atrai sozinho a cada
## `use_time`, em volta toda (sem o cone à frente), só com espaço no bolso.
##
## A busca usa os blocos do CoinWorld ao alcance, não a cena inteira. Paredes bloqueiam,
## e cada moeda é contabilizada no momento em que é atraída (CoinWorld.take), uma única vez.

## Cosseno do meio-ângulo do cone de atração à frente (~75°).
const FORWARD_CONE := 0.25
## Moedas sempre atraídas, mesmo atrás, se muito perto dos pés.
const CLOSE_RANGE := 0.4
## Limite de moedas animadas voando por uso (as demais contam igual, sem animação).
const MAX_FLYING := 30
## Pilhas de até 10 moedas: o ímã grande (8.000) precisa de ~1.000 pilhas por uso.
const MAX_CANDIDATES := 2500
## Verificações de linha de visão por uso, uma por célula de busca (as mais próximas primeiro).
const MAX_SIGHT_CHECKS := 120
## A dica (10x por segundo) reaproveita a última busca por este tempo.
const HINT_CACHE_SECONDS := 0.3

@onready var _magnet: Node3D = $Magnet
var _rest := Vector3.ZERO
var _cached: Array[Dictionary] = []
var _cached_at := -100.0
## Passivo: tempo até o próximo puxão.
var _cooldown := 0.0


func _ready() -> void:
	_magnet.scale = Vector3.ONE * definition.visual_scale
	_rest = _magnet.position


## O passivo não usa try_use: puxa sem ficar ocupado, para a troca de ferramenta nunca
## ser recusada (e a ferramenta pode sumir a qualquer momento sem um await pendente).
func _process(delta: float) -> void:
	if not definition.passive:
		return
	_cooldown -= delta
	if _cooldown > 0.0 or GameState.ledger.free_capacity() <= 0 or not can_use():
		return
	_cooldown = definition.use_time
	_cached_at = -100.0
	_pull()
	used.emit()


## O passivo ignora o clique.
func handle_input(event: InputEvent) -> bool:
	return definition.passive and event.is_action_pressed("use_tool")


## Pilhas que este uso atrairia (até completar a capacidade, com linha de visão).
func find_targets() -> Array[Dictionary]:
	if CoinWorld.current == null:
		return []
	var origin := user.body.global_position
	var forward := Vector3.ZERO
	if not definition.passive:
		forward = -user.body.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
	var targets: Array[Dictionary] = []
	var coins := 0
	# Linha de visão uma vez por célula (até a primeira pilha vista nela).
	var sight := {}
	var candidates := CoinWorld.current.find_near(origin, definition.reach, MAX_CANDIDATES,
		definition.capacity + definition.capacity / 4, forward, FORWARD_CONE, CLOSE_RANGE)
	for candidate in candidates:
		var cell: Vector3i = candidate.cell
		if not sight.has(cell):
			if sight.size() >= MAX_SIGHT_CHECKS:
				break
			sight[cell] = _has_line_of_sight((candidate.position as Vector3) + Vector3.UP * 0.05)
		if not sight[cell]:
			continue
		targets.append(candidate)
		coins += int(candidate.amount)
		if coins >= definition.capacity:
			break
	return targets


func can_use() -> bool:
	return not _recent_targets().is_empty()


func _recent_targets() -> Array[Dictionary]:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _cached_at > HINT_CACHE_SECONDS:
		_cached = find_targets()
		_cached_at = now
	return _cached


func get_hint() -> String:
	var targets := _recent_targets()
	if targets.is_empty():
		return ""
	var free := GameState.ledger.free_capacity()
	if free == 0:
		return "Bolsos cheios! Deposite no ponto de coleta"
	var coins := 0
	for target in targets:
		coins += int(target.amount)
	coins = mini(mini(coins, definition.capacity), free)
	if definition.passive:
		return "Atraindo %s sozinho" % MoneyFormat.coins(coins)
	return "[%s] Atrair %s" % [InputBindings.label_of(&"use_tool"), MoneyFormat.coins(coins)]


func _perform() -> void:
	_pull()
	await get_tree().create_timer(definition.use_time, false).timeout


## Um puxão: conta as moedas na hora e anima algumas voando até o ímã.
func _pull() -> void:
	var targets := find_targets()
	var budget := mini(GameState.ledger.free_capacity(), definition.capacity)
	var claimed := 0
	var value := 0
	var flights := PackedVector3Array()
	var flight_denoms := PackedByteArray()
	for target in targets:
		if claimed >= budget:
			break
		var got := CoinWorld.current.take(target.key, target.index, budget - claimed)
		if got <= 0:
			continue
		claimed += got
		value += got * int(target.value)
		if flights.size() < MAX_FLYING:
			flights.append(target.position)
			flight_denoms.append(int(target.denomination))
	if claimed > 0:
		GameState.add_carried(claimed, value)
	elif not targets.is_empty():
		GameState.notify("Bolsos cheios! Deposite as moedas no ponto de coleta.")
	# O passivo puxa várias vezes por segundo: som e tranco mais discretos.
	Sfx.play(&"whoosh", 0.12, -14.0 if definition.passive else -6.0)
	var pulse := create_tween()
	pulse.tween_property(_magnet, "position", _rest + Vector3(0, 0.03, -0.12) * (0.3 if definition.passive else 1.0), 0.12)
	pulse.tween_property(_magnet, "position", _rest, 0.25)
	_animate_flights(flights, flight_denoms)


## Moedas voando até o ímã (só efeito visual; a contagem já foi feita).
func _animate_flights(positions: PackedVector3Array, denoms: PackedByteArray) -> void:
	var world := user.body.get_parent()
	for i in positions.size():
		var duration := positions[i].distance_to(_magnet.global_position) / maxf(definition.power, 0.1)
		CoinFlight.launch(world, positions[i], _magnet, denoms[i], duration)
