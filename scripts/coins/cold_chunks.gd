class_name ColdChunks
extends RefCounted
## Blocos "frios": gerados sem desenho, longe do jogador, para os robôs. Gerar um bloco denso
## custa 7–15 ms, então os pedidos dos robôs rodam numa thread (request); os dados que dependem
## do jogo (células livres e o que já foi recolhido) são copiados na thread principal, e a
## thread só lê o que não muda (traçado, sorteio, alocação).

## Vector2i -> CoinChunk pronto.
var _chunks := {}
## Vector2i -> [id da tarefa, resultado (Array de 1), cópia do recolhido].
var _pending := {}
## (key, free, saved) -> CoinChunk. Roda também fora da thread principal.
var _generate: Callable
var _generator: ChunkGenerator


func _init(generator: ChunkGenerator, generate: Callable) -> void:
	_generator = generator
	_generate = generate


func has(key: Vector2i) -> bool:
	return _chunks.has(key)


func is_pending(key: Vector2i) -> bool:
	return _pending.has(key)


func get_chunk(key: Vector2i) -> CoinChunk:
	return _chunks.get(key)


func erase(key: Vector2i) -> void:
	_chunks.erase(key)


func clear() -> void:
	_chunks.clear()


## Tira o bloco daqui (ele vai virar o bloco desenhado). Null se não havia.
func take_chunk(key: Vector2i) -> CoinChunk:
	var chunk: CoinChunk = _chunks.get(key)
	_chunks.erase(key)
	return chunk


## Bloco frio, gerado agora (na thread principal) se ainda não existe.
func chunk_or_generate(key: Vector2i) -> CoinChunk:
	var chunk: CoinChunk = _chunks.get(key)
	if chunk == null:
		chunk = _generate.call(key, [], null)
		_chunks[key] = chunk
	return chunk


## Começa a gerar o bloco numa thread (se ainda não existe nem está sendo gerado).
func request(key: Vector2i) -> void:
	if _pending.has(key) or _chunks.has(key):
		return
	# Build sem threads (versão web): gera aqui mesmo; o orçamento por quadro (cold_budget) limita.
	if not OS.has_feature("threads"):
		_chunks[key] = _generate.call(key, [], null)
		return
	var free: Array = _generator.free_cells(key)
	var saved: PackedByteArray = GameState.world_entry(key).get("rem", PackedByteArray()).duplicate()
	var result := []
	var task := WorkerThreadPool.add_task(_generate_into.bind(result, key, free, saved), false, "Bloco de moedas")
	_pending[key] = [task, result, saved]


func _generate_into(result: Array, key: Vector2i, free: Array, saved: PackedByteArray) -> void:
	result.append(_generate.call(key, free, saved))


## Recebe os blocos prontos (`wait`: espera os que faltam). Descarta o resultado se `is_hot`
## diz que o bloco já está desenhado, ou se algo foi recolhido dele depois da cópia (a soma
## exata vem antes de tudo).
func collect(is_hot: Callable, wait := false) -> void:
	if _pending.is_empty():
		return
	for key: Vector2i in _pending.keys():
		var entry: Array = _pending[key]
		if not wait and not WorkerThreadPool.is_task_completed(entry[0]):
			continue
		WorkerThreadPool.wait_for_task_completion(entry[0])
		_pending.erase(key)
		var result: Array = entry[1]
		if result.is_empty() or is_hot.call(key) or _chunks.has(key):
			continue
		var now: PackedByteArray = GameState.world_entry(key).get("rem", PackedByteArray())
		if now != entry[2]:
			continue
		_chunks[key] = result[0]


## Nenhuma thread pode terminar depois que o mundo sumir.
func wait_all() -> void:
	for key: Vector2i in _pending.keys():
		WorkerThreadPool.wait_for_task_completion(_pending[key][0])
	_pending.clear()
