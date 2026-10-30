class_name ChunkStreamer
extends RefCounted
## Blocos desenhados em volta do jogador: quais entram, quais saem e com que malha. Entram
## aos poucos (ACTIVATIONS_PER_FRAME), ou vários por quadro na tela de carregamento; além do
## raio de visão fica só o tapete de moedas (CoinCarpet).

## Vector2i -> CoinChunk desenhado (o CoinWorld consulta o mesmo dicionário).
var chunks := {}
var _world: CoinWorld
var _cold: ColdChunks
var _carpet: CoinCarpet
## Blocos com pilhas alteradas neste quadro (buffer reenviado inteiro no fim do quadro).
var _dirty := {}    # Vector2i -> CoinChunk
var _queue: Array[Vector2i] = []
var _center := Vector2i(-99999, -99999)
var _loading_total := 0
var _near_radius := 3
var _unload_radius := 4
var _far_radius := 9
var _detail_meters := 4.0
## Última posição do jogador (a malha de perto segue a distância real até cada bloco).
var _position := Vector3.ZERO
var _near_mesh: ArrayMesh
var _far_mesh: ArrayMesh
var _distant_mesh: ArrayMesh


func _init(world: CoinWorld, cold: ColdChunks) -> void:
	_world = world
	_cold = cold
	_carpet = CoinCarpet.new(world)


## Detalhe das moedas e distância de visão (opções de vídeo). Aplica na hora: troca a malha
## dos blocos carregados e refaz o entorno do jogador.
func configure(detail: int, distance: int) -> void:
	var level: Array = CoinWorld.DETAIL_LEVELS[clampi(detail, 0, CoinWorld.DETAIL_LEVELS.size() - 1)]
	var near: int = CoinWorld.VIEW_RADII[clampi(distance, 0, CoinWorld.VIEW_RADII.size() - 1)]
	var near_mesh := CoinVisuals.mesh_with(level[0])
	if near_mesh == _near_mesh and near == _near_radius and level[2] == _detail_meters:
		return
	_near_mesh = near_mesh
	_far_mesh = CoinVisuals.mesh_with(level[1])
	_distant_mesh = CoinVisuals.mesh_with(CoinWorld.DISTANT_SIDES)
	_detail_meters = level[2]
	_near_radius = near
	_unload_radius = near + 1
	_far_radius = near + CoinWorld.FAR_EXTRA
	for chunk: CoinChunk in chunks.values():
		chunk.set_mesh(_mesh_for(chunk.key))
	# Força o recálculo do entorno.
	var center := _center
	_center = Vector2i(-99999, -99999)
	if center.x > -99999:
		var origin := _world.chunk_origin(center)
		update(Vector3(origin.x + 8.0, 0, origin.y + 8.0))


## Recalcula o que deve estar desenhado em volta de `position_`. Dentro do mesmo bloco só
## ajusta a malha dos vizinhos (perto ou longe); ao mudar de bloco, refaz o entorno.
func update(position_: Vector3) -> void:
	_position = position_
	var center := _world.key_of(position_)
	if center == _center:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var chunk: CoinChunk = chunks.get(center + Vector2i(dx, dz))
				if chunk != null:
					_set_detail(chunk)
		return
	_center = center
	for key: Vector2i in chunks.keys():
		if CoinWorld.chebyshev(key, center) > _unload_radius:
			_deactivate(key)
		else:
			_set_detail(chunks[key])
	var wanted: Array[Vector2i] = []
	for dx in range(-_near_radius, _near_radius + 1):
		for dz in range(-_near_radius, _near_radius + 1):
			var key := center + Vector2i(dx, dz)
			if _world.is_valid_key(key) and not chunks.has(key):
				wanted.append(key)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return CoinWorld.chebyshev(a, center) < CoinWorld.chebyshev(b, center))
	_queue = wanted
	_carpet.refresh(_center, _near_radius, _far_radius, chunks)


## Carrega na hora tudo ao redor de `position_` (ao iniciar ou após teleporte).
func load_now(position_: Vector3) -> void:
	update(position_)
	while not _queue.is_empty():
		_activate(_queue.pop_front())
	if _loading_total > 0:
		_loading_total = 0
		_world.loading_finished.emit()


## Carrega o entorno aos poucos (tela de carregamento): vários blocos por quadro, até
## LOAD_BUDGET_MS, avisando o progresso. Termina com `loading_finished` do mundo.
func load_async(position_: Vector3) -> void:
	update(position_)
	_loading_total = maxi(_queue.size(), 1)
	if _queue.is_empty():
		_loading_total = 0
		_world.loading_finished.emit.call_deferred()


## Uma vez por quadro: desenha os próximos blocos da fila e reenvia os alterados.
func step() -> void:
	if _loading_total > 0:
		var start := Time.get_ticks_msec()
		while not _queue.is_empty() and Time.get_ticks_msec() - start < CoinWorld.LOAD_BUDGET_MS:
			_activate(_queue.pop_front())
		_world.loading_progress.emit(1.0 - float(_queue.size()) / _loading_total)
		if _queue.is_empty():
			_loading_total = 0
			_world.loading_finished.emit()
	else:
		for i in mini(CoinWorld.ACTIVATIONS_PER_FRAME, _queue.size()):
			_activate(_queue.pop_front())
	for chunk: CoinChunk in _dirty.values():
		chunk.upload()
	_dirty.clear()


## A pilha `index` mudou. Não usa set_instance_transform: com FSR2/TAA o MultiMesh tem dois
## buffers (quadro atual e anterior, para os vetores de movimento) e a atualização parcial só
## chega a um deles. O ímã mexe em centenas de pilhas de uma vez e as pilhas já recolhidas
## piscavam de volta na tela (moedas "fantasma", sem interação). Reenviar o buffer inteiro,
## uma vez por quadro (step), mantém os dois iguais.
func mark_dirty(chunk: CoinChunk, index: int) -> void:
	if chunk.node == null:
		return
	chunk.write_stack(index)
	_dirty[chunk.key] = chunk


func _activate(key: Vector2i) -> void:
	if chunks.has(key) or CoinWorld.chebyshev(key, _center) > _unload_radius:
		return
	# Um bloco frio (usado por robôs) vira o ativo: mesmos dados, só ganha desenho.
	var chunk := _cold.take_chunk(key)
	if chunk == null:
		chunk = _world.generate_chunk(key)
	chunk.build_visuals(_world, _mesh_for(key))
	chunks[key] = chunk
	_carpet.remove(key)


func _deactivate(key: Vector2i) -> void:
	var chunk: CoinChunk = chunks.get(key)
	if chunk != null:
		chunk.free_visuals()
	chunks.erase(key)
	_dirty.erase(key)


func _set_detail(chunk: CoinChunk) -> void:
	chunk.set_mesh(_mesh_for(chunk.key))


## Malha pela distância: detalhada nos blocos a até `_detail_meters` do jogador, a de longe logo
## depois e, a partir de DISTANT_FROM blocos, a de poucos lados (a pilha ocupa 1 ou 2 pixels ali).
func _mesh_for(key: Vector2i) -> ArrayMesh:
	var ring := CoinWorld.chebyshev(key, _center)
	if ring <= 1:
		var size := _world.definition.chunk_size
		var area := Rect2(_world.chunk_origin(key), Vector2(size, size))
		var spot := Vector2(_position.x, _position.z)
		var nearest := spot.clamp(area.position, area.end)
		if nearest.distance_to(spot) <= _detail_meters:
			return _near_mesh
	return _far_mesh if ring < CoinWorld.DISTANT_FROM else _distant_mesh
