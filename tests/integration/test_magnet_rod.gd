extends TestSuite
## Integração da vara com ímã com a cidade real: arremesso dentro do alcance, previsão,
## atração até a capacidade, contagem única, paredes, bairros sem licença, recolher no ar,
## cancelar a mira e troca de ferramenta bloqueada com o ímã fora.

const MAIN_SCENE := "res://scenes/main.tscn"
const READY := 0
const AIMING := 1
const FLYING := 2
const LANDED := 3
const REELING := 4

var main: Node3D
var player: CharacterBody3D
var head: Node3D
var tool_user: ToolUser
var layout: CityLayout


func before_all() -> void:
	GameState.reset()
	main = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	player = main.get_node("Player")
	head = player.get_node("Head")
	tool_user = player.get_node("Head/Camera3D/ToolHolder")
	layout = (main.get_node("City") as CityBuilder).layout
	# Bolso grande para a capacidade da vara não ser limitada pelo bolso.
	for id in [&"pouch", &"backpack", &"magnet_rod_small"]:
		GameState.grant(id)
	await physics_frames(30)


func after_all() -> void:
	main.queue_free()
	await process_frames(2)
	GameState.reset()


func test_rods_in_catalog_and_shop() -> void:
	var rods := ToolCatalog.get_default().variants(&"magnet_rod")
	check_eq(rods.size(), 3, "três varas")
	for i in rods.size():
		check(ShopCatalog.get_default().find(rods[i].id) != null, "%s à venda" % rods[i].display_name)
		check(rods[i].effect_summary().contains("Arremessa"), "resumo explica a vara")
		if i > 0:
			for stat in [&"reach", &"area_radius", &"capacity", &"power", &"reel_speed"]:
				check(float(rods[i].get(stat)) > float(rods[i - 1].get(stat)), "%s melhora %s" % [rods[i].id, stat])
	check(rods[0].reach > ToolCatalog.get_default().find(&"magnet_large").reach, "vara pequena alcança mais longe que o ímã grande")
	check(tool_user.equip(&"magnet_rod_small"), "equipa a vara")
	check(tool_user.slot_groups().has(&"magnet_rod"), "vara ganha um atalho")


func test_throw_lands_within_reach_and_matches_preview() -> void:
	var rod = await _ready_rod()
	var reach: float = rod.definition.reach
	var predicted: PackedVector3Array = rod.predict(1.0)
	var start: Vector3 = player.global_position
	check(rod.get_hint().contains("Mirar"), "dica de mira: '%s'" % rod.get_hint())
	check(rod.throw(1.0), "arremessa")
	check_eq(rod.state, FLYING, "ímã em voo")
	await _wait_until(func() -> bool: return rod.state != FLYING, 400)
	check_eq(rod.state, LANDED, "ímã no chão")
	var landed: Vector3 = rod.magnet_position
	var flat := Vector2(landed.x - start.x, landed.z - start.z).length()
	check(flat <= reach + 1.0, "dentro do alcance (%.1f m de %.0f)" % [flat, reach])
	check(flat > reach * 0.5, "força total vai longe (%.1f m)" % flat)
	check(landed.distance_to(predicted[predicted.size() - 1]) < 1.0, "cai onde a mira previu")
	await _reel_and_wait(rod)


func test_attracts_up_to_capacity_and_counts_once() -> void:
	var rod = await _ready_rod()
	rod.definition.capacity = 3
	var found := GameState.ledger.total_coins_found
	var carried := GameState.ledger.carried_coins
	var removed := GameState.world_removed
	rod.throw(0.6)
	await _wait_until(func() -> bool: return rod.state == LANDED, 400)
	var available: int = rod.held
	for target in rod.get("_pending"):
		available += int(target.amount)
	await _wait_until(func() -> bool: return (rod.get("_pending") as Array).is_empty(), 300)
	check_eq(rod.held, mini(available, 3), "gruda até a capacidade (%d disponíveis)" % available)
	check_eq(GameState.ledger.carried_coins, carried, "no chão, ainda não entrou no bolso")
	check_eq(GameState.world_removed - removed, rod.held, "o que grudou saiu do mundo")
	# O save calcula o bolso como (retirado − encontrado): moedas no ímã não se perdem.
	check_eq(GameState.world_removed - GameState.ledger.total_coins_found, carried + rod.held, "save conta o ímã como bolso")
	var held: int = rod.held
	check(rod.get_hint().contains("Recolher"), "dica de recolher: '%s'" % rod.get_hint())
	await _reel_and_wait(rod)
	check_eq(GameState.ledger.carried_coins - carried, held, "ao voltar, entra no bolso uma vez")
	check_eq(GameState.ledger.total_coins_found, found, "encontradas só no depósito")
	check_eq(rod.held, 0, "ímã vazio")
	_check_invariant()
	rod.definition.capacity = ToolCatalog.get_default().find(&"magnet_rod_small").capacity


func test_pocket_limits_attraction() -> void:
	var rod = await _ready_rod()
	# Enche o bolso artificialmente (sem tirar do mundo) e desfaz no fim.
	var filler := GameState.ledger.free_capacity() - 2
	GameState.add_carried(filler)
	rod.throw(0.6)
	await _wait_until(func() -> bool: return rod.state == LANDED, 400)
	await _wait_until(func() -> bool: return (rod.get("_pending") as Array).is_empty(), 300)
	check(rod.held <= 2, "só pega o que cabe no bolso (%d)" % rod.held)
	await _reel_and_wait(rod)
	check(GameState.ledger.carried_coins <= GameState.ledger.carry_capacity, "bolso não estoura")
	GameState.ledger.carried_coins -= filler
	GameState.ledger.carried_value_cents -= filler
	_check_invariant()


func test_reel_in_flight_returns_empty() -> void:
	var rod = await _ready_rod()
	var carried := GameState.ledger.carried_coins
	var removed := GameState.world_removed
	rod.throw(1.0)
	await physics_frames(4)
	check(rod.reel(), "recolhe ainda no ar")
	check_eq(rod.state, REELING, "linha sendo recolhida")
	await _wait_until(func() -> bool: return rod.state == READY, 400)
	check_eq(GameState.ledger.carried_coins, carried, "voltou vazia")
	check_eq(GameState.world_removed, removed, "nada saiu do mundo")


func test_walking_away_reels_the_magnet() -> void:
	var rod = await _ready_rod()
	rod.throw(0.6)
	await _wait_until(func() -> bool: return rod.state == LANDED, 400)
	check_eq(rod.state, LANDED, "ímã no chão")
	var away: Vector3 = rod.magnet_position - player.global_position
	away.y = 0.0
	player.global_position -= away.normalized() * rod.definition.reach * 1.5
	await process_frames(3)
	check(rod.state == REELING or rod.state == READY, "linha no limite: recolhe sozinha")
	await _wait_until(func() -> bool: return rod.state == READY, 600)


func test_walls_stop_the_magnet() -> void:
	var rod = await _ready_rod()
	var forward := -player.global_basis.z
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.size = Vector3(12, 8, 0.4)
	main.add_child(wall)
	wall.global_position = player.global_position + forward * 4.0 + Vector3.UP * 4.0
	wall.look_at(wall.global_position + forward, Vector3.UP)
	await physics_frames(3)
	rod.throw(1.0)
	await _wait_until(func() -> bool: return rod.state != FLYING, 400)
	var travelled: float = (rod.magnet_position - player.global_position).dot(forward)
	check(travelled < 4.0, "o ímã para na parede (%.2f m, parede a 4 m)" % travelled)
	await _reel_and_wait(rod)
	wall.free()
	await physics_frames(2)


func test_locked_district_attracts_nothing() -> void:
	var rod = await _ready_rod()
	var start := layout.district_rect(0)
	var removed := GameState.world_removed
	_place(Vector3(start.end.x - 3.5, 0.2, start.get_center().y), -PI * 0.5)
	# Mira alta: a cerca (3 m) para arremessos baixos; um arco alto passa por cima.
	head.rotation.x = 0.9
	await physics_frames(10)
	rod.throw(1.0)
	await _wait_until(func() -> bool: return rod.state != FLYING, 400)
	if rod.magnet_position.x > start.end.x + 0.5:
		check(rod.landed_blocked, "caiu no Setor Cultural sem licença")
		await process_frames(60)
		check_eq(rod.held, 0, "não atrai nada lá")
		check_eq(GameState.world_removed, removed, "nada saiu do mundo")
		check(rod.get_hint().contains("licença"), "dica explica: '%s'" % rod.get_hint())
	else:
		check(false, "o arremesso devia passar a cerca (x=%.1f, cerca em %.1f)" % [rod.magnet_position.x, start.end.x])
	await _reel_and_wait(rod)


func test_cancel_aim_and_switch_lock() -> void:
	var rod = await _ready_rod()
	check(rod.begin_aim(), "começa a mirar")
	check_eq(rod.state, AIMING, "mirando")
	await process_frames(5)
	check(rod.charge > 0.3, "força cresce segurando (%.2f)" % rod.charge)
	rod.cancel_aim()
	check_eq(rod.state, READY, "botão direito cancela")
	check(not rod.busy, "nada foi arremessado")
	rod.throw(1.0)
	check(not tool_user.equip(&"hands"), "não troca de ferramenta com o ímã fora")
	await _reel_and_wait(rod)
	check(tool_user.equip(&"hands"), "troca depois que o ímã volta")


# --- Auxiliares --------------------------------------------------------------------------

func _ready_rod() -> GameTool:
	GameState.deposit()
	_place(layout.spawn_point(), PI * 0.5)
	tool_user.equip(&"magnet_rod_small")
	await physics_frames(5)
	var rod := tool_user.equipped
	await _wait_until(func() -> bool: return not rod.busy, 120)
	return rod


func _reel_and_wait(rod: GameTool) -> void:
	rod.call("reel")
	await _wait_until(func() -> bool: return rod.get("state") == READY, 400)
	await _wait_until(func() -> bool: return not rod.busy, 120)


func _wait_until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await tree.physics_frame


func _place(pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	head.rotation.x = 0.0


func _check_invariant() -> void:
	check_eq(GameState.world_removed, GameState.ledger.total_coins_found + GameState.ledger.carried_coins,
		"retirado do mundo = encontradas + bolso")
	check_eq(GameState.world_removed_value, GameState.ledger.total_value_found_cents + GameState.ledger.carried_value_cents,
		"valor retirado do mundo = valor encontrado + valor no bolso")
