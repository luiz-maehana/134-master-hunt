extends TestSuite
## CoinWorld: total exato, geração determinística, retirada parcial e registro no save.

var world: CoinWorld


func before_all() -> void:
	GameState.reset()
	world = CoinWorld.new()
	world.definition = WorldDefinition.get_default()
	tree.root.add_child(world)


func after_all() -> void:
	world.free()
	GameState.reset()


func test_total_is_exactly_134_million_reais() -> void:
	var sum := 0
	for i in world.chunk_count():
		sum += world._allocation[i]
	check_eq(sum, 13_400_000_000, "soma das fatias de todos os blocos: R$ 134 milhões")
	check_eq(world.remaining_total(), 13_400_000_000, "nada retirado ainda")


func test_piles_sum_to_allocation() -> void:
	# Todos os blocos do bairro inicial + uma amostra fixa do resto da cidade.
	var keys: Array[Vector2i] = []
	var nx := world.definition.chunks_x()
	var nz := world.definition.chunks_z()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for cz in nz:
		for cx in nx:
			var origin := world.chunk_origin(Vector2i(cx, cz))
			if world.layout.district_index_of(world.layout.block_of(origin.x + 8, origin.y + 8)) == 0:
				keys.append(Vector2i(cx, cz))
	for i in 150:
		keys.append(Vector2i(rng.randi() % nx, rng.randi() % nz))
	var mismatches := 0
	var too_many := 0
	for key in keys:
		var piles := world.generate_piles(key)
		var denominations := world.generate_denominations(key)
		var total := 0
		for i in piles.size():
			total += piles[i] * Denomination.value_of(denominations[i])
		if total != world.allocation_of(key):
			mismatches += 1
		if piles.size() > 0 and Array(piles).max() > CoinWorld.MAX_STACK:
			too_many += 1
	check_eq(mismatches, 0, "valor das pilhas = fatia exata (%d blocos)" % keys.size())
	check_eq(too_many, 0, "nenhuma pilha passa de %d moedas" % CoinWorld.MAX_STACK)
	check_eq(world.generate_denominations(keys[0]).size(), world.generate_piles(keys[0]).size(), "cada pilha tem um valor só")
	check_eq(world.generate_piles(keys[0]), world.generate_piles(keys[0]), "geração determinística")


func test_district_shares() -> void:
	var per_district := {}
	for cz in world.definition.chunks_z():
		for cx in world.definition.chunks_x():
			var origin := world.chunk_origin(Vector2i(cx, cz))
			var index := world.layout.district_index_of(world.layout.block_of(origin.x + 8, origin.y + 8))
			per_district[index] = per_district.get(index, 0) + world.allocation_of(Vector2i(cx, cz))
	for i in range(1, world.definition.districts.size()):
		check(per_district[i] > per_district[i - 1], "bairro %d tem mais dinheiro que o %d" % [i, i - 1])
	check(per_district[0] > 10_000, "rua do começo tem dinheiro para começar (%d centavos)" % per_district[0])


func test_partial_take_and_record() -> void:
	GameState.reset()
	var spawn := world.layout.spawn_point()
	# Distância de visão mínima (raio 3 + 1 de folga = 7×7): não depende das opções do jogador.
	world.configure(Settings.coin_detail, 0)
	world.load_around(spawn)
	check(world.active_chunk_count() > 0 and world.active_chunk_count() <= 49, "carrega só o entorno (%d blocos)" % world.active_chunk_count())
	var near := world.find_near(spawn, 30.0, 400)
	var target: Dictionary = {}
	for item in near:
		if int(item.amount) >= 3:
			target = item
			break
	check(not target.is_empty(), "há uma pilha de 3+ moedas por perto")
	if target.is_empty():
		return
	var amount: int = target.amount
	var key: Vector2i = target.key
	check_eq(world.take(key, target.index, 2), 2, "tira 2 da pilha")
	check_eq(world.take(key, target.index, 1_000_000), amount - 2, "tira o resto, nunca mais que o resto")
	check_eq(world.take(key, target.index, 5), 0, "pilha vazia não dá nada")
	check_eq(GameState.world_removed, amount, "total retirado registrado")
	var value := amount * int(target.value)
	check_eq(GameState.world_removed_value, value, "valor retirado registrado")
	check_eq(world.remaining_total(), 13_400_000_000 - value, "restante do mapa")
	check_eq(world.remaining_in(key), world.allocation_of(key) - value, "restante do bloco")
	check(world.find_near(target.position, 0.01, 5).filter(func(i: Dictionary) -> bool: return i.index == target.index and i.key == key).is_empty(), "pilha vazia some das buscas")
	# Sai de perto (descarrega) e volta: o bloco é regenerado com o que foi retirado.
	world.load_around(spawn + Vector3(300, 0, 300))
	check(not world.is_active(key), "bloco descarregado ao se afastar")
	world.load_around(spawn)
	check(world.find_near(target.position, 0.01, 5).filter(func(i: Dictionary) -> bool: return i.index == target.index and i.key == key).is_empty(), "retirada persiste após recarregar")
	check_eq(world.remaining_in(key), world.allocation_of(key) - value, "restante do bloco intacto")
	check_eq(world.take(Vector2i(-5, -5), 0, 10), 0, "bloco inexistente")


## Bloco 100% recolhido nunca volta a ter moedas: nem ao recarregar perto, nem gerado frio (robôs).
func test_emptied_chunk_stays_empty() -> void:
	var spawn := world.layout.spawn_point()
	world.load_around(spawn)
	var key := world.key_of(spawn)
	var piles := world.generate_piles(key).size()
	for i in piles:
		world.take(key, i, 1_000_000)
	check_eq(world.coins_in(key), 0, "bloco esvaziado")
	check_eq(world.remaining_in(key), 0, "nada de valor restante")
	world.load_around(spawn + Vector3(300, 0, 300))
	check(not world.is_active(key), "bloco descarregado")
	world._cold.erase(key)
	check_eq(world.coins_in(key), 0, "gerado de novo sem desenho: continua vazio")
	world._cold.erase(key)
	world.load_around(spawn)
	check(world.is_active(key), "bloco recarregado")
	check_eq(world.coins_in(key), 0, "recarregado perto: continua vazio")
	check(world.find_near(spawn, 4.0, 100).filter(func(i: Dictionary) -> bool: return i.key == key).is_empty(), "nenhuma pilha nas buscas")
	GameState.reset()


## Bloco frio gerado em thread: mesmas pilhas da geração direta; resultado defasado descartado.
func test_threaded_cold_chunks() -> void:
	var nx := world.definition.chunks_x()
	var nz := world.definition.chunks_z()
	var key := Vector2i(nx - 3, nz - 4)
	var direct := world.generate_piles(key)
	world.request_cold(key)
	check(world._cold.is_pending(key), "geração pedida")
	world.finish_pending()
	check(not world._cold.is_pending(key), "geração terminada")
	check(world._cold.has(key), "bloco frio pronto")
	var cold: CoinChunk = world._cold.get_chunk(key)
	var piles := PackedInt32Array()
	for amount in cold.original:
		piles.append(amount)
	check_eq(piles, direct, "mesmas pilhas da geração direta")
	check_eq(world.pile_sum(key), world.remaining_in(key), "soma exata")
	# Outro bloco: pedido em thread, mas alguém tira moedas dele antes de ficar pronto.
	var other := Vector2i(nx - 5, nz - 4)
	world.request_cold(other)
	var taken := world.take(other, 0, 1)
	world.finish_pending()
	check_eq(taken, 1, "retirada direta enquanto a thread trabalhava")
	check_eq(world.pile_sum(other), world.remaining_in(other), "resultado defasado não desfaz a retirada")
	GameState.reset()
	world._cold.clear()


## As moedas reais (blocos carregados) sempre cobrem o alcance da maior ferramenta: além delas
## só há o "tapete" desenhado, que parece moeda mas não pode ser pego.
func test_loaded_area_covers_every_tool() -> void:
	var farthest := 0.0
	for tool in ToolCatalog.get_default().tools:
		farthest = maxf(farthest, tool.reach + tool.area_radius)
	var nearest_edge: float = CoinWorld.VIEW_RADII.min() * world.definition.chunk_size
	check(nearest_edge >= farthest, "moedas reais até %.0f m cobrem a ferramenta mais longa (%.0f m)" % [nearest_edge, farthest])


## Detalhe pela distância: o bloco do jogador com a malha de perto, os de longe com poucos lados.
func test_mesh_detail_by_distance() -> void:
	GameState.reset()
	world.configure(2, 2)
	var spawn := world.layout.spawn_point()
	world.load_around(spawn)
	world._streamer.update(spawn)
	var center := world.key_of(spawn)
	var near_mesh := CoinVisuals.mesh_with(CoinWorld.DETAIL_LEVELS[2][0])
	var distant_mesh := CoinVisuals.mesh_with(CoinWorld.DISTANT_SIDES)
	var own: CoinChunk = world._chunks[center]
	check(own.multimesh.mesh == near_mesh, "bloco do jogador com a malha detalhada")
	var far_ok := true
	var far_count := 0
	for key: Vector2i in world._chunks:
		if CoinWorld.chebyshev(key, center) >= CoinWorld.DISTANT_FROM:
			far_count += 1
			if (world._chunks[key] as CoinChunk).multimesh.mesh != distant_mesh:
				far_ok = false
	check(far_count > 0 and far_ok, "blocos a partir do anel %d com %d lados (%d blocos)" % [CoinWorld.DISTANT_FROM, CoinWorld.DISTANT_SIDES, far_count])
	world.configure(Settings.coin_detail, Settings.view_distance)
