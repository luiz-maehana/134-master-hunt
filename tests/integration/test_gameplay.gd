extends TestSuite
## Integração com a cidade real: movimento, ferramentas tirando das pilhas, depósito,
## cercas dos bairros, streaming e persistência do mundo.

const MAIN_SCENE := "res://scenes/main.tscn"

var main: Node3D
var player: CharacterBody3D
var head: Node3D
var tool_user: ToolUser
var interactor: Interactor
var world: CoinWorld
var city: CityBuilder
var layout: CityLayout


func before_all() -> void:
	GameState.reset()
	main = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	player = main.get_node("Player")
	head = player.get_node("Head")
	tool_user = player.get_node("Head/Camera3D/ToolHolder")
	interactor = player.get_node("Head/Camera3D/Interactor")
	world = main.get_node("City/CoinWorld")
	city = main.get_node("City")
	layout = city.layout
	await physics_frames(30)


func after_all() -> void:
	main.queue_free()
	await process_frames(2)
	GameState.reset()


func test_city_and_spawn() -> void:
	check(player.is_on_floor(), "jogador nasce no chão")
	check(player.global_position.distance_to(layout.spawn_point()) < 1.0, "no ponto inicial")
	check(world.active_chunk_count() > 0 and world.active_chunk_count() <= 81, "streaming carrega só o entorno (%d blocos)" % world.active_chunk_count())
	check_eq(world.remaining_total(), 13_400_000_000, "R$ 134 milhões no chão")
	check(not world.find_near(player.global_position, 12.0, 5).is_empty(), "há moedas por perto")
	var hud_goal: Label = main.get_node("HUD").get_node("%Goal")
	check(hud_goal.text.contains("134.000.000,00"), "HUD mostra a meta: '%s'" % hud_goal.text)


func test_movement_and_buildings() -> void:
	_place(layout.spawn_point(), 0.0)
	await _hold("move_forward", 30)
	check(layout.spawn_point().z - player.global_position.z > 1.0, "W anda")
	var building := _a_building()
	var rect: Rect2 = building.rect
	_place(Vector3(rect.get_center().x, world.definition.curb_height + 0.05, rect.position.y - 1.5), PI)
	await _hold("move_forward", 90)
	check(player.global_position.z < rect.position.y, "prédio bloqueia (z=%.2f, parede em %.2f)" % [player.global_position.z, rect.position.y])


func test_every_street_object_is_solid() -> void:
	# Ponto a 0,5 m do chão no pé de cada objeto: tem que cair dentro de alguma colisão.
	var space := player.get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	var hollow := {}
	var total := 0
	for key: Vector2i in layout.blocks:
		var info: Dictionary = layout.blocks[key]
		var spots: Array = []
		for prop: Dictionary in info.props:
			spots.append([String(prop.kind), prop.pos])
		for tree: Vector2 in info.trees + info.small_trees:
			spots.append(["árvore", tree])
		for car: Rect2 in info.cars:
			spots.append(["carro", car.get_center()])
		for bench: Dictionary in info.benches:
			spots.append(["banco", bench.pos])
		for bin: Vector2 in info.bins:
			spots.append(["lixeira", bin])
		for stop: Dictionary in info.bus_stops:
			# A colisão fica no vidro do fundo (dá para entrar embaixo da cobertura).
			var back := Vector2(0, -0.65).rotated(-stop.yaw)
			spots.append(["ponto de ônibus", stop.pos + back])
		for hydrant: Vector2 in info.hydrants:
			spots.append(["hidrante", hydrant])
		for spot: Array in spots:
			var at: Vector2 = spot[1]
			query.position = Vector3(at.x, layout.ground_height(at.x, at.y) + 0.5, at.y)
			total += 1
			if space.intersect_point(query, 1).is_empty():
				hollow[spot[0]] = hollow.get(spot[0], 0) + 1
	for lamp: Vector3 in layout.lamps:
		query.position = lamp + Vector3.UP * 0.5
		total += 1
		if space.intersect_point(query, 1).is_empty():
			hollow["poste"] = hollow.get("poste", 0) + 1
	check(total > 100, "a cidade tem objetos de rua (%d)" % total)
	check(hollow.is_empty(), "nenhum objeto de rua deixa atravessar (sem colisão: %s)" % hollow)


func test_landmarks_are_solid() -> void:
	# Cada peça visível de um marco (menos os enfeites) tem a sua colisão, e as peças de mesmo
	# material são desenhadas juntas.
	for landmark in layout.landmarks:
		var body := city.get_node("Landmark_%s" % landmark.kind) as StaticBody3D
		var pieces: int = body.get_meta(&"pieces", 0)
		var shapes := 0
		var meshes := 0
		for child in body.get_children():
			if child is CollisionShape3D:
				shapes += 1
			elif child is MeshInstance3D:
				meshes += 1
		check(pieces > 0 and shapes == pieces, "%s: %d peças, %d colisões" % [landmark.kind, pieces, shapes])
		check(meshes < pieces or pieces <= 2, "%s: peças juntadas para desenhar (%d malhas)" % [landmark.kind, meshes])
	# O Teatro (pirâmide) já deixou atravessar: um ponto dentro dele, a 2 m do chão, é sólido.
	for landmark in layout.landmarks:
		if landmark.kind == "theater":
			var rect: Rect2 = landmark.rect
			var query := PhysicsPointQueryParameters3D.new()
			query.position = Vector3(rect.get_center().x, world.definition.curb_height + 2.0, rect.get_center().y)
			check(not player.get_world_3d().direct_space_state.intersect_point(query, 1).is_empty(), "Teatro é sólido por dentro")


func test_portals_travel_between_shops() -> void:
	var portals := city.find_children("Portal_*", "Portal", false, false)
	check_eq(portals.size(), layout.hubs.size(), "um portal em cada loja")
	var menu := main.get_node("PortalMenu") as PortalMenu
	# Sem contrato: o portal fica apagado e não abre a tela.
	GameState.owned_items.erase(Portal.PORTAL_ITEM)
	var start: Dictionary = layout.hubs[0]
	for hub in layout.hubs:
		if layout.district_index_of(hub.block) == 0:
			start = hub
	var portal: Vector3 = start.portal
	_place(portal + Vector3(0, 0.05, -2.5), 0.0)
	_aim_at(portal + Vector3(0, 1.5, 0))
	await physics_frames(3)
	check(interactor.current != null and interactor.current.prompt_text.contains("desligado"), "portal apagado sem contrato")
	interactor.try_interact()
	check(not menu.is_open(), "sem contrato a tela não abre")
	# Com contrato: abre e leva até outra loja liberada (a Rodoviária tem uma só; o Setor
	# Cultural entra só neste teste).
	GameState.grant(&"permit_downtown")
	GameState.grant(Portal.PORTAL_ITEM)
	await process_frames(2)
	check(interactor.current.prompt_text.contains("viajar"), "portal ligado com contrato")
	interactor.try_interact()
	check(menu.is_open(), "tela de destinos aberta")
	var target: Dictionary = {}
	for hub in layout.hubs:
		if hub != start and GameState.is_district_unlocked(layout.definition.districts[layout.district_index_of(hub.block)]):
			target = hub
			break
	check(not target.is_empty(), "há outra loja liberada")
	if target.is_empty():
		return
	menu.call("_travel", target)
	await process_frames(60)
	var arrived: Vector3 = target.portal
	check(player.global_position.distance_to(arrived) < 4.0, "jogador na frente do portal de destino (%.1f m)" % player.global_position.distance_to(arrived))
	check(not GameState.screen_open, "controle volta depois da viagem")
	check(world.is_active(world.key_of(player.global_position)), "moedas carregadas no destino")
	for id: StringName in [Portal.PORTAL_ITEM, &"permit_downtown"]:
		GameState.owned_items.erase(id)
	GameState.tools_changed.emit()


func test_easter_eggs() -> void:
	var secrets := city.get_node("EasterEggs") as CityEasterEggs
	var extras_before := GameState.extras.duplicate(true)
	var money := GameState.ledger.money_cents
	var use := func(node_name: String) -> void:
		Interactable.find_on(secrets.get_node(node_name)).interact(player)
	# Urna: dez votos liberam a conquista.
	for i in CityEasterEggs.VOTES_FOR_LOOP:
		use.call("BallotBox")
	check(GameState.has_achievement(&"democracy_loop"), "urna: Democracia em Loop após 10 votos")
	# Jornal: a mesma pilha muda de manchete a cada leitura.
	for i in 3:
		use.call("Newspaper_0")
	check(GameState.has_achievement(&"newsroom"), "jornal: três versões lidas")
	# Senhor V.: larga um centavo e muda de lugar.
	var before: Vector3 = secrets.get_node("SenhorV").position
	use.call("SenhorV")
	check(secrets.get_node("SenhorV").position != before, "Senhor V. some e aparece em outro lugar")
	check_eq(GameState.ledger.money_cents, money + 1, "Senhor V. deixou cair 1 centavo")
	for i in 2:
		use.call("SenhorV")
	check(GameState.has_achievement(&"complex_structure"), "três encontros com o Senhor V.")
	# Pipoca custa 1 centavo; a moeda lendária dá 1 e some.
	use.call("Popcorn")
	check(GameState.has_achievement(&"popcorn"), "pipoca comprada")
	if secrets.has_node("LegendaryCoin"):
		use.call("LegendaryCoin")
	check(GameState.has_achievement(&"legendary_coin"), "moeda lendária encontrada")
	# Nada disso mexe no mundo de moedas (a meta continua exata).
	check_eq(world.remaining_total() + GameState.world_removed_value, world.definition.total_value_cents, "total do mundo intacto")
	# Conquistas e contadores voltam do save.
	var data := SaveSerializer.to_dict(GameState)
	var copy: Dictionary = JSON.parse_string(JSON.stringify(data))
	var achievements: Array = GameState.extras.achievements.duplicate()
	GameState.extras = {}
	SaveSerializer.apply(GameState, copy)
	check_eq(GameState.extras.get("achievements", []), achievements, "conquistas voltam do save")
	check_eq(int(GameState.extras.get("votes", 0)), CityEasterEggs.VOTES_FOR_LOOP, "votos voltam do save")
	GameState.extras = extras_before


func test_hands_take_one_coin() -> void:
	var pile := await _stand_south_of_pile(1)
	if pile.is_empty():
		return
	var before := GameState.ledger.carried_coins
	var removed := GameState.world_removed
	check(tool_user.get_hint().contains("Pegar"), "dica de pegar: '%s'" % tool_user.get_hint())
	check(await tool_user.use_equipped(), "pega")
	check_eq(GameState.ledger.carried_coins - before, 1, "mãos: 1 moeda")
	check_eq(GameState.world_removed - removed, 1, "1 moeda saiu do mundo")
	_check_invariant()


func test_gloves_take_up_to_capacity() -> void:
	for id in [&"glove", &"big_glove"]:
		GameState.grant(id)
		tool_user.equip(id)
		var pile := await _stand_south_of_pile(1)
		if pile.is_empty():
			return
		var definition := tool_user.equipped_definition()
		var expected := mini(mini(_sum((tool_user.equipped as GameTool).call("find_targets")), definition.capacity), GameState.ledger.free_capacity())
		var before := GameState.ledger.carried_coins
		await tool_user.use_equipped()
		check_eq(GameState.ledger.carried_coins - before, expected, "%s: pega %d (capacidade %d)" % [id, expected, definition.capacity])
	_check_invariant()


func test_shovel_scoops_area() -> void:
	GameState.grant(&"shovel_small")
	tool_user.equip(&"shovel_small")
	var pile := await _stand_south_of_pile(1, 1.0)
	if pile.is_empty():
		return
	var targets: Array = (tool_user.equipped as GameTool).call("find_targets")
	var expected := mini(mini(_sum(targets), tool_user.equipped_definition().capacity), GameState.ledger.free_capacity())
	check(expected > 0, "pá tem moedas na área")
	var before := GameState.ledger.carried_coins
	await tool_user.use_equipped()
	check_eq(GameState.ledger.carried_coins - before, expected, "pá recolhe a área (até a capacidade)")
	_check_invariant()


func test_magnet_pulls_in_front_and_respects_pocket() -> void:
	GameState.grant(&"magnet_small")
	tool_user.equip(&"magnet_small")
	GameState.ledger.carry_capacity = 100_000
	_place(layout.spawn_point(), 0.0)
	await physics_frames(3)
	var magnet: GameTool = tool_user.equipped
	var targets: Array = magnet.call("find_targets")
	check(not targets.is_empty(), "ímã encontra moedas à frente")
	var forward := Vector3(0, 0, -1)
	var behind := 0
	for target in targets:
		var flat: Vector3 = target.position - player.global_position
		flat.y = 0.0
		if flat.length() > 0.4 and forward.dot(flat.normalized()) < 0.25:
			behind += 1
	check_eq(behind, 0, "só puxa o que está à frente")
	var expected := mini(_sum(targets), tool_user.equipped_definition().capacity)
	var before := GameState.ledger.carried_coins
	await tool_user.use_equipped()
	check_eq(GameState.ledger.carried_coins - before, expected, "ímã: %d moedas" % expected)
	GameState.ledger.carry_capacity = GameState.ledger.carried_coins + 3
	_place(layout.spawn_point() + Vector3(4, 0, 0), 0.0)
	await physics_frames(3)
	if magnet.can_use():
		before = GameState.ledger.carried_coins
		await tool_user.use_equipped()
		check_eq(GameState.ledger.carried_coins - before, 3, "bolso com 3 vagas: só 3")
	GameState.recompute_stats()
	_check_invariant()


func test_walls_block_magnet() -> void:
	tool_user.equip(&"magnet_small")
	_place(layout.spawn_point(), 0.0)
	var wall := CSGBox3D.new()
	wall.use_collision = true
	wall.size = Vector3(10, 4, 0.3)
	main.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 2, -1.0)
	await physics_frames(3)
	var beyond := 0
	for target in (tool_user.equipped as GameTool).call("find_targets"):
		if target.position.z < wall.global_position.z:
			beyond += 1
	check_eq(beyond, 0, "nada atrás da parede")
	wall.free()
	await physics_frames(2)


func test_neodymium_pulls_by_itself() -> void:
	var neodymium := ToolCatalog.get_default().find(&"magnet_neodymium")
	check(neodymium.passive, "ímã de neodímio é passivo")
	check(neodymium.reach > ToolCatalog.get_default().find(&"magnet_large").reach, "alcance maior que o do ímã grande")
	GameState.ledger.carry_capacity = GameState.ledger.carried_coins
	GameState.grant(&"magnet_neodymium")
	tool_user.equip(&"magnet_neodymium")
	_place(layout.spawn_point() + Vector3(0, 0, 10), 0.0)
	await physics_frames(3)
	var targets: Array = tool_user.equipped.call("find_targets")
	var behind := 0
	for target in targets:
		var flat: Vector3 = target.position - player.global_position
		if flat.z > 1.0:
			behind += 1
	check(behind > 0, "puxa também o que está atrás")
	var before := GameState.ledger.carried_coins
	await process_frames(10)
	check_eq(GameState.ledger.carried_coins, before, "bolso cheio: não puxa nada")
	GameState.ledger.carry_capacity = 100_000_000
	await process_frames(10)
	check(GameState.ledger.carried_coins > before, "puxa sozinho, sem clicar")
	# Trocar de ferramenta nunca é recusado; e o passivo não fica equipado para os testes seguintes.
	check(tool_user.equip(&"hands"), "troca de ferramenta com o passivo puxando")
	await process_frames(2)
	GameState.recompute_stats()
	_check_invariant()


func test_deposit_counts_coins() -> void:
	var ledger := GameState.ledger
	var carried := ledger.carried_coins
	check(carried > 0, "há moedas no bolso (%d)" % carried)
	var hub: Dictionary = layout.hubs[0]
	var deposit: Vector3 = hub.deposit
	_place(deposit + Vector3(0, 0.05, -2.2), 0.0)
	_aim_at(deposit + Vector3(0, 0.9, -0.36))
	await physics_frames(3)
	check(interactor.current != null and interactor.current.prompt_text.contains("Depositar"), "mira no ponto de coleta")
	var found := ledger.total_coins_found
	interactor.try_interact()
	check_eq(ledger.carried_coins, 0, "bolso vazio")
	check_eq(ledger.total_coins_found - found, carried, "moedas encontradas")
	check_eq(GameState.world_removed, ledger.total_coins_found, "todo retirado foi contabilizado")
	var hud_coins: Label = main.get_node("HUD").get_node("%Coins")
	# O valor "sobe" até o novo em RollingValue.DURATION e termina exato.
	await tree.create_timer(RollingValue.DURATION + 0.15).timeout
	check_eq(hud_coins.text, MoneyFormat.brl(ledger.total_value_found_cents), "HUD mostra o valor encontrado")
	var hud_count: Label = main.get_node("HUD").get_node("%Value")
	check(hud_count.text.contains(MoneyFormat.group(ledger.total_coins_found)), "HUD mostra a quantidade de moedas: '%s'" % hud_count.text)


func test_fence_opens_with_permit() -> void:
	var start := layout.district_rect(0)
	var edge := start.end.x
	var middle := start.get_center().y
	_place(Vector3(edge - 2.0, 0.2, middle), -PI * 0.5)
	await _hold("move_forward", 90)
	check(player.global_position.x < edge, "cerca bloqueia o Setor Cultural (x=%.2f, cerca em %.2f)" % [player.global_position.x, edge])
	check(city.is_fenced(&"downtown"), "cerca visível")
	GameState.grant(&"permit_downtown")
	await physics_frames(3)
	check(not city.is_fenced(&"downtown"), "licença abre a cerca")
	_place(Vector3(edge - 2.0, 0.2, middle), -PI * 0.5)
	await _hold("move_forward", 90)
	check(player.global_position.x > edge + 1.0, "passa para o Setor Cultural (x=%.2f)" % player.global_position.x)
	var hud_district: Label = main.get_node("HUD").get_node("%District")
	await process_frames(10)
	check(hud_district.text.contains("Setor Cultural"), "HUD mostra o bairro: '%s'" % hud_district.text)


func test_streaming_keeps_taken_coins() -> void:
	tool_user.equip(&"hands")
	var pile := await _stand_south_of_pile(1)
	if pile.is_empty():
		return
	await tool_user.use_equipped()
	var key: Vector2i = pile.key
	var remaining_before := world.remaining_in(key)
	_place(layout.spawn_point() + Vector3(0, 0, -250), 0.0)
	await process_frames(40)
	check(not world.is_active(key), "bloco antigo descarregado")
	check(world.active_chunk_count() <= 81, "carregados continuam limitados (%d)" % world.active_chunk_count())
	_place(layout.spawn_point(), 0.0)
	await process_frames(40)
	check(world.is_active(key), "bloco recarregado ao voltar")
	check_eq(world.remaining_in(key), remaining_before, "retiradas persistem")
	var still := world.find_near(pile.position, 0.01, 5).filter(func(i: Dictionary) -> bool: return i.key == key and i.index == pile.index)
	var expected_amount: int = int(pile.amount) - 1
	check_eq(still[0].amount if not still.is_empty() else 0, expected_amount, "pilha recarregada com o que sobrou")


func test_save_round_trip_restores_world() -> void:
	var data := GameState.to_save()
	var removed := GameState.world_removed
	var found := GameState.ledger.total_coins_found
	GameState.apply_save(data)
	check_eq(GameState.world_removed, removed, "retirado do mundo restaurado")
	check_eq(GameState.ledger.total_coins_found, found, "encontradas restauradas")
	_check_invariant()


func test_equipment_strip() -> void:
	var box: Container = main.get_node("HUD").get_node("%Equipment")
	var before := box.get_child_count()
	GameState.grant(&"pouch")
	await process_frames(2)
	check_eq(box.get_child_count(), before + 1, "pochete aparece nos equipamentos")
	var names := []
	for entry in box.get_children():
		names.append(str(entry.get_meta("name", "")))
		check((entry as TextureRect).texture != null, "item com ícone")
	check(names.has("Pochete"), "nome do item no HUD: %s" % [names])
	GameState.grant(&"permit_downtown")
	await process_frames(2)
	check_eq(box.get_child_count(), before + 1, "licenças não entram na faixa")
	GameState.owned_items.erase(&"pouch")
	GameState.owned_items.erase(&"permit_downtown")
	GameState.recompute_stats()
	GameState.tools_changed.emit()


func test_flying_coins_never_stay_in_the_air() -> void:
	# Alvo que some no meio do voo: a moeda some junto, em vez de ficar parada no ar.
	var target := Node3D.new()
	main.add_child(target)
	target.global_position = player.global_position + Vector3(0, 1, 0)
	for i in 3:
		CoinFlight.launch(main, player.global_position + Vector3(10, 0, 0), target, 0, 5.0)
	await process_frames(2)
	check_eq(_flights(), 3, "moedas voando")
	target.queue_free()
	await process_frames(3)
	check_eq(_flights(), 0, "alvo sumiu: nenhuma moeda parada no ar")
	# Voo normal termina sozinho.
	var magnet := Node3D.new()
	main.add_child(magnet)
	CoinFlight.launch(main, player.global_position + Vector3(3, 0, 0), magnet, 0, 0.1)
	await process_frames(20)
	check_eq(_flights(), 0, "voo termina e a moeda some")
	magnet.queue_free()


func _flights() -> int:
	var count := 0
	for node in main.find_children("*", "MeshInstance3D", true, false):
		if node is CoinFlight and not node.is_queued_for_deletion():
			count += 1
	return count


# --- Ajudantes -------------------------------------------------------------------------

## Coloca o jogador 1 m ao sul de uma pilha livre por perto (olhando para ela).
## `offset` = distância; para a pá, o centro da pazada cai na pilha.
func test_district_progress() -> void:
	var total := 0
	for i in world.definition.districts.size():
		total += world.district_total(i)
	check_eq(total, 13_400_000_000, "bairros somam R$ 134 milhões")
	var before := world.district_removed(0)
	tool_user.equip(&"hands")
	var pile := await _stand_south_of_pile(1)
	if pile.is_empty():
		return
	await tool_user.use_equipped()
	check_eq(world.district_removed(0) - before, int(pile.value), "coleta conta no bairro certo (valor da moeda)")
	check_eq(world.district_removed(1), 0, "outro bairro não muda")
	await tree.create_timer(0.3).timeout
	var label: Label = main.get_node("HUD").get_node("%District")
	check(label.text.contains("recolhido") and label.text.contains(world.definition.districts[0].display_name), "HUD mostra o %% do bairro: '%s'" % label.text)
	var inventory: MenuScreen = main.get_node("InventoryMenu")
	inventory.open()
	var texts := PackedStringArray()
	for l in inventory.items_box.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := " | ".join(texts)
	check(joined.contains("Área  —  Setor Cultural") and joined.contains("Fechado"), "inventário lista os bairros e o que está fechado")
	inventory.close()


func _stand_south_of_pile(min_amount: int, offset := 1.0) -> Dictionary:
	var spawn := layout.spawn_point()
	# A busca só vê blocos carregados: o teste anterior pode ter levado o jogador para longe.
	world.load_around(spawn)
	for item in world.find_near(spawn, 40.0, 400):
		if int(item.amount) < min_amount:
			continue
		var pos: Vector3 = item.position
		var stand := pos + Vector3(0, 0, offset)
		if not layout.is_free(stand.x, stand.z) or absf(layout.ground_height(stand.x, stand.z) - pos.y) > 0.01:
			continue
		if not layout.district_at(stand.x, stand.z) == world.definition.districts[0]:
			continue
		_place(Vector3(stand.x, pos.y + 0.05, stand.z), 0.0)
		_aim_at(pos)
		await physics_frames(3)
		if tool_user.equipped.can_use():
			return item
	check(false, "achou uma pilha livre por perto")
	return {}


## Prédio comum mais perto do ponto inicial.
func _a_building() -> Dictionary:
	var spawn := layout.spawn_point()
	var best := {}
	var best_distance := INF
	for key: Vector2i in layout.blocks:
		for building: Dictionary in layout.blocks[key].buildings:
			var d := (building.rect as Rect2).get_center().distance_to(Vector2(spawn.x, spawn.z))
			if d < best_distance:
				best_distance = d
				best = building
	return best


func _check_invariant() -> void:
	check_eq(GameState.world_removed, GameState.ledger.total_coins_found + GameState.ledger.carried_coins,
		"invariante: retirado do mundo = encontradas + no bolso")
	check_eq(GameState.world_removed_value, GameState.ledger.total_value_found_cents + GameState.ledger.carried_value_cents,
		"valor retirado do mundo = valor encontrado + valor no bolso")


static func _sum(targets: Array) -> int:
	var total := 0
	for target in targets:
		total += int(target.amount)
	return total


func _place(pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	head.rotation.x = 0.0
	world.load_around(pos)


func _aim_at(target: Vector3) -> void:
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _hold(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await physics_frames(frames)
	Input.action_release(action)
	await physics_frames(15)
