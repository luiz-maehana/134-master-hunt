class_name CoinWorld
extends Node3D
## Todo o dinheiro da cidade em moedas (exatamente `definition.total_value_cents`, R$ 134 milhões),
## sem um objeto por moeda. A quantidade de moedas não é fixa: sai do sorteio de cada bloco.
##
## - A cidade é dividida em blocos (`chunk_size`). Cada bloco recebe uma fatia fixa do
##   valor total (centavos), proporcional ao chão livre e à riqueza do bairro; a soma das
##   fatias é exata, e as pilhas de cada bloco somam exatamente a sua fatia.
## - Cada bloco é um "mar" de pilhinhas: até MAX_STACK moedas do mesmo valor empilhadas (a
##   maior vale R$ 10, com 10 moedas de R$ 1). Geradas da semente quando o jogador chega
##   perto; o que já foi recolhido fica em GameState.world_state.
## - Perto: cada bloco (CoinChunk) num MultiMesh (malha mais simples a partir do segundo
##   anel). Longe: tapete de moedas (CoinCarpet). Robôs usam blocos frios (ColdChunks).
## - Buscas usam uma grade de CELL_SIZE por bloco e param ao juntar moedas suficientes.
## - Uma moeda só sai do mundo por `take()`, que nunca devolve mais do que resta.

signal coins_taken(amount: int)

## Moedas numa pilha, no máximo (todas do mesmo valor).
const MAX_STACK := 10
## Raios em blocos (distância de Chebyshev) ao redor do jogador.
## Distância de visão (Settings.view_distance): blocos desenhados em volta do jogador, com
## folga de um bloco para descarregar; decalques de "tapete" até FAR_EXTRA blocos além.
## Nunca menos de 3 blocos (48 m): as moedas reais precisam cobrir o alcance da maior ferramenta
## (ímã e vara, 40 m); com menos, o "tapete" de longe aparecia ao alcance do ímã, parecendo moedas
## que ele não puxava.
const VIEW_RADII := [3, 4, 5]
const FAR_EXTRA := 6
## Detalhe (Settings.coin_detail): [lados da malha perto, lados longe, distância (m) do jogador até o
## bloco em que vale a malha de perto; 0 = só o bloco onde ele está].
const DETAIL_LEVELS := [[10, 6, 0.0], [16, 8, 4.0], [24, 8, 6.0]]
## A partir deste anel (em blocos de 16 m, ~25 m ou mais) as pilhas usam DISTANT_SIDES lados: ali
## cada uma ocupa 1 ou 2 pixels e o formato não aparece, mas são quase todas as pilhas carregadas.
const DISTANT_FROM := 2
const DISTANT_SIDES := 4
## Blocos com malha detalhada (os demais carregados usam a simples).
const ACTIVATIONS_PER_FRAME := 1
## Tempo por quadro gasto montando blocos durante a tela de carregamento.
const LOAD_BUDGET_MS := 24
const STREAM_INTERVAL := 0.2
## Diferença máxima de altura entre o ponto consultado e a pilha.
const MAX_HEIGHT_DELTA := 0.6
## Grade de chão livre onde as pilhas nascem (m).
const PLACE_CELL := 0.5
## Grade de busca dentro de cada bloco (m).
const CELL_SIZE := 2.0
## Pilhas devolvidas por scan_around (robôs pedem mais quando acabam).
const SCAN_LIMIT := 3000

## Blocos frios que ainda podem ser pedidos neste quadro (a frota de robôs repõe). São gerados
## numa thread (ColdChunks); enquanto não ficam prontos, scan_around para e marca
## `last_scan_incomplete` (o robô tenta de novo depois).
var cold_budget := 2
var last_scan_incomplete := false

## Carregamento inicial (load_around_async): fração pronta e fim.
signal loading_progress(fraction: float)
signal loading_finished

## Mundo ativo (as ferramentas consultam por aqui).
static var current: CoinWorld

@export var definition: WorldDefinition
## Nó cuja posição define o que é carregado (o jogador).
@export var tracked: Node3D

var layout: CityLayout
## Fatia de cada bloco, em centavos.
var _allocation := PackedInt64Array()
var _free_area := PackedFloat32Array()
## Blocos desenhados (perto do jogador): o mesmo dicionário do ChunkStreamer.
var _chunks := {}
var _streamer: ChunkStreamer
## Blocos sem desenho (longe do jogador, usados por robôs).
var _cold: ColdChunks
var _districts: DistrictTally
var _generator: ChunkGenerator
var _stream_timer := 0.0
var _chunks_x := 0
var _chunks_z := 0
var _cells_per_side := 0


func _ready() -> void:
	if definition == null:
		definition = WorldDefinition.get_default()
	layout = CityLayout.for_definition(definition)
	_generator = ChunkGenerator.new(definition, layout)
	_chunks_x = _generator.chunks_x
	_chunks_z = _generator.chunks_z
	_cells_per_side = _generator.cells_per_side
	var plan := _generator.allocate()
	_allocation = plan.allocation
	_free_area = plan.free_area
	_districts = DistrictTally.new(_chunks_x, plan.chunk_district, plan.district_totals)
	_cold = ColdChunks.new(_generator, generate_chunk)
	_streamer = ChunkStreamer.new(self, _cold)
	_chunks = _streamer.chunks
	var allocation := str(hash(_allocation))
	GameState.check_world_signature("%s|%s" % [allocation, _generator.signature()], allocation)
	current = self
	configure(Settings.coin_detail, Settings.view_distance)
	Settings.changed.connect(func() -> void: configure(Settings.coin_detail, Settings.view_distance))


## Detalhe das moedas e distância de visão (opções de vídeo), aplicados na hora.
func configure(detail: int, distance: int) -> void:
	_streamer.configure(detail, distance)


func _exit_tree() -> void:
	# Nenhuma thread pode terminar depois que este nó sumir.
	_cold.wait_all()
	if current == self:
		current = null


func _process(delta: float) -> void:
	_stream_timer -= delta
	if _stream_timer <= 0.0 and tracked != null:
		_stream_timer = STREAM_INTERVAL
		_streamer.update(tracked.global_position)
	_streamer.step()
	_cold.collect(is_active)


## Carrega na hora tudo ao redor de `position` (ao iniciar ou após teleporte).
func load_around(position_: Vector3) -> void:
	_streamer.load_now(position_)


## Carrega o entorno aos poucos (tela de carregamento): vários blocos por quadro, até
## LOAD_BUDGET_MS, avisando o progresso. Termina com `loading_finished`.
func load_around_async(position_: Vector3) -> void:
	_streamer.load_async(position_)


# --- Consultas -------------------------------------------------------------------------

func key_of(position_: Vector3) -> Vector2i:
	return Vector2i(floori((position_.x + layout.half_x) / definition.chunk_size), floori((position_.z + layout.half_z) / definition.chunk_size))


func chunk_origin(key: Vector2i) -> Vector2:
	return _generator.chunk_origin(key)


func is_valid_key(key: Vector2i) -> bool:
	return key.x >= 0 and key.y >= 0 and key.x < _chunks_x and key.y < _chunks_z


func chunk_count() -> int:
	return _chunks_x * _chunks_z


func allocation_of(key: Vector2i) -> int:
	return _allocation[key.y * _chunks_x + key.x] if is_valid_key(key) else 0


## Chão livre do bloco (m²), onde as pilhas podem nascer.
func free_area_of(key: Vector2i) -> float:
	return _free_area[key.y * _chunks_x + key.x] if is_valid_key(key) else 0.0


## Valor (centavos) que ainda está no chão do bloco.
func remaining_in(key: Vector2i) -> int:
	return allocation_of(key) - int(GameState.world_entry(key).get("v", 0))


## Valor (centavos) que ainda está no chão da cidade.
func remaining_total() -> int:
	return definition.total_value_cents - GameState.world_removed_value


## Valor (centavos) que o bairro tinha no início do jogo.
func district_total(index: int) -> int:
	return _districts.total(index)


## Valor (centavos) já retirado do bairro (no bolso ou depositado).
func district_removed(index: int) -> int:
	return _districts.removed(index)


## Fração recolhida do bairro, de 0 a 1.
func district_progress(index: int) -> float:
	return _districts.progress(index)


func active_chunk_count() -> int:
	return _chunks.size()


func is_active(key: Vector2i) -> bool:
	return _chunks.has(key)


## Pilhas com moedas a até `radius` de `point` (no plano), da mais próxima à mais distante.
## Só blocos carregados (perto do jogador). Para de procurar quando juntou `max_count` pilhas
## ou `max_coins` moedas (as células são visitadas da mais próxima para a mais distante).
## `facing` (opcional): só pilhas à frente (cosseno >= `min_dot`), exceto a até `close_range`.
## Itens: {key, index, cell, amount, position, distance, value, denomination}.
func find_near(point: Vector3, radius: float, max_count: int, max_coins := -1,
		facing := Vector3.ZERO, min_dot := -2.0, close_range := 0.0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var coins := 0
	for cell in _cells_around(point, radius, false):
		var chunk: CoinChunk = _chunks.get(Vector2i(cell.x, cell.y))
		for i in chunk.cells[cell.z]:
			var amount := chunk.remaining[i]
			if amount == 0:
				continue
			var pos := chunk.positions[i]
			if absf(pos.y - point.y) > MAX_HEIGHT_DELTA:
				continue
			var flat := Vector2(pos.x - point.x, pos.z - point.z)
			var distance := flat.length()
			if distance > radius:
				continue
			if facing != Vector3.ZERO and distance > close_range and Vector2(facing.x, facing.z).dot(flat / maxf(distance, 0.0001)) < min_dot:
				continue
			found.append({"key": chunk.key, "index": i, "cell": cell, "amount": amount, "position": pos, "distance": distance,
				"value": Denomination.value_of(chunk.denom[i]), "denomination": chunk.denom[i]})
			coins += amount
		if found.size() >= max_count or (max_coins > 0 and coins >= max_coins):
			break
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	return found.slice(0, max_count)


## Retira até `max_amount` moedas da pilha. Retorna quantas saíram (0 se vazia/inexistente).
## Vale também para blocos longe do jogador (robôs): esses ficam "frios", sem desenho.
func take(key: Vector2i, index: int, max_amount: int) -> int:
	if not is_valid_key(key) or max_amount <= 0:
		return 0
	var chunk := _any_chunk(key)
	if index < 0 or index >= chunk.remaining.size():
		return 0
	var amount := mini(chunk.remaining[index], max_amount)
	if amount <= 0:
		return 0
	chunk.remaining[index] -= amount
	GameState.record_world_take(key, index, chunk.remaining[index], amount,
		amount * Denomination.value_of(chunk.denom[index]), chunk.remaining.size())
	_streamer.mark_dirty(chunk, index)
	coins_taken.emit(amount)
	return amount


## Pilhas com moedas a até `radius` de `point`, em bairros liberados, das células mais
## próximas para as mais distantes, carregadas ou não (até SCAN_LIMIT; quem usa pede de novo
## quando acabam). Itens: Vector3i(cx, cz, índice).
func scan_around(point: Vector3, radius: float) -> Array[Vector3i]:
	var found: Array[Vector3i] = []
	last_scan_incomplete = false
	for cell in _cells_around(point, radius, true):
		var key := Vector2i(cell.x, cell.y)
		var chunk: CoinChunk = _chunks.get(key)
		if chunk == null:
			chunk = _cold.get_chunk(key)
		if chunk == null:
			# Ainda não gerado: pede em thread e para aqui (o robô tenta de novo depois).
			if cold_budget > 0 and not _cold.is_pending(key):
				cold_budget -= 1
				request_cold(key)
			last_scan_incomplete = true
			break
		for i in chunk.cells[cell.z]:
			if chunk.remaining[i] == 0:
				continue
			var pos := chunk.positions[i]
			if Vector2(pos.x - point.x, pos.z - point.z).length() <= radius:
				found.append(Vector3i(cell.x, cell.y, i))
		if found.size() >= SCAN_LIMIT:
			break
	return found


## Valor (centavos) das pilhas do bloco como estão agora (carregado ou não). Deve ser sempre
## igual a remaining_in(key): é o que os testes conferem.
func pile_sum(key: Vector2i) -> int:
	return _any_chunk(key).value_left()


## Moedas (quantidade) das pilhas do bloco como estão agora.
func coins_in(key: Vector2i) -> int:
	return _any_chunk(key).coins_left()


## Valor de uma moeda da pilha, em centavos (carregada ou não).
func value_of_pile(key: Vector2i, index: int) -> int:
	var chunk := _any_chunk(key)
	return Denomination.value_of(chunk.denom[index]) if index >= 0 and index < chunk.denom.size() else 1


## Posição de uma pilha (carregada ou não).
func pile_position(key: Vector2i, index: int) -> Vector3:
	var chunk := _any_chunk(key)
	return chunk.positions[index] if index >= 0 and index < chunk.positions.size() else Vector3.ZERO


## Centro de uma célula de busca (para verificar linha de visão uma vez por célula).
@warning_ignore("integer_division")
func cell_center(cell: Vector3i) -> Vector3:
	var origin := chunk_origin(Vector2i(cell.x, cell.y))
	var x := origin.x + (cell.z % _cells_per_side + 0.5) * CELL_SIZE
	var z := origin.y + (cell.z / _cells_per_side + 0.5) * CELL_SIZE
	return Vector3(x, layout.ground_height(x, z), z)


## Gera as pilhas de um bloco sem desenhar (testes e verificações). Soma = fatia do bloco.
func generate_piles(key: Vector2i) -> PackedInt32Array:
	var piles := PackedInt32Array()
	for amount in generate_chunk(key).original:
		piles.append(amount)
	return piles


## Valores (índices de Denomination) das pilhas geradas de um bloco (testes).
func generate_denominations(key: Vector2i) -> PackedByteArray:
	return generate_chunk(key).denom


## Começa a gerar um bloco frio numa thread (robôs longe do jogador).
func request_cold(key: Vector2i) -> void:
	if is_valid_key(key) and not _chunks.has(key):
		_cold.request(key)


## Espera todas as gerações em andamento (antes de sair da cena ou em testes).
func finish_pending() -> void:
	_cold.collect(is_active, true)


## Células (cx, cz, índice) que tocam o círculo, da mais próxima para a mais distante.
## `include_cold`: também blocos não carregados (só em bairros liberados).
func _cells_around(point: Vector3, radius: float, include_cold: bool) -> Array[Vector3i]:
	var low := key_of(point - Vector3(radius, 0, radius))
	var high := key_of(point + Vector3(radius, 0, radius))
	var cells: Array[Vector3i] = []
	var distances := {}
	var half := definition.chunk_size * 0.5
	for cx in range(maxi(low.x, 0), mini(high.x, _chunks_x - 1) + 1):
		for cz in range(maxi(low.y, 0), mini(high.y, _chunks_z - 1) + 1):
			var key := Vector2i(cx, cz)
			var origin := chunk_origin(key)
			if not _chunks.has(key) and (not include_cold or remaining_in(key) <= 0):
				continue
			if include_cold:
				var district := layout.district_at(origin.x + half, origin.y + half)
				if district == null or not GameState.is_district_unlocked(district):
					continue
			for j in _cells_per_side:
				for i in _cells_per_side:
					var x0 := origin.x + i * CELL_SIZE
					var z0 := origin.y + j * CELL_SIZE
					# Distância do ponto até o retângulo da célula.
					var dx := maxf(maxf(x0 - point.x, 0.0), point.x - (x0 + CELL_SIZE))
					var dz := maxf(maxf(z0 - point.z, 0.0), point.z - (z0 + CELL_SIZE))
					var d := dx * dx + dz * dz
					if d <= radius * radius:
						var cell := Vector3i(cx, cz, j * _cells_per_side + i)
						cells.append(cell)
						distances[cell] = d
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return distances[a] < distances[b])
	return cells


## O bloco desenhado, ou o frio (gerado agora se preciso).
func _any_chunk(key: Vector2i) -> CoinChunk:
	var chunk: CoinChunk = _chunks.get(key)
	return chunk if chunk != null else _cold.chunk_or_generate(key)


## Gera as pilhas do bloco (ChunkGenerator). `free` e `saved` vêm prontos quando a geração
## roda numa thread (ColdChunks); senão são lidos aqui.
func generate_chunk(key: Vector2i, free: Array = [], saved: Variant = null) -> CoinChunk:
	if free.is_empty():
		free = _generator.free_cells(key)
	var taken: PackedByteArray = saved if saved != null else GameState.world_entry(key).get("rem", PackedByteArray())
	return _generator.generate(key, allocation_of(key), free, taken)


## Distância em blocos (Chebyshev).
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
