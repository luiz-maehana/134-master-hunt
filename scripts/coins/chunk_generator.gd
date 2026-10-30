class_name ChunkGenerator
extends RefCounted
## Parte pura do mundo de moedas (sem nós nem desenho), usada pelo CoinWorld:
## - allocate(): fatia exata do valor total (centavos) para cada bloco;
## - free_cells(): onde há chão livre em cada bloco;
## - generate(): as pilhas de um bloco, a partir da semente.
##
## Determinística: a mesma cidade e a mesma semente dão sempre as mesmas pilhas.
## generate() pode rodar numa thread (só lê dados que não mudam durante o jogo).

var definition: WorldDefinition
var layout: CityLayout
var chunks_x := 0
var chunks_z := 0
var cells_per_side := 0
## Vector2i -> [PackedInt32Array células livres, PackedFloat32Array alturas]
var _free_cells := {}


func _init(world: WorldDefinition, city: CityLayout) -> void:
	definition = world
	layout = city
	chunks_x = definition.chunks_x()
	chunks_z = definition.chunks_z()
	cells_per_side = int(ceil(definition.chunk_size / CoinWorld.CELL_SIZE))


## Tudo o que decide quantas pilhas cada bloco tem e em que ordem. O save guarda o restante
## por índice de pilha: se isto muda, os índices antigos não valem mais e os blocos já
## recolhidos voltariam cheios. Entra na assinatura do mundo (CoinWorld._ready).
func signature() -> String:
	var parts: Array = [definition.random_seed, CoinWorld.MAX_STACK, Denomination.VALUES]
	for district in definition.districts:
		parts.append([district.id, district.pile_small, district.pile_medium, district.pile_large,
			district.pile_chances, district.denomination_weights])
	return str(hash(str(parts)))


func chunk_origin(key: Vector2i) -> Vector2:
	return Vector2(-layout.half_x + key.x * definition.chunk_size, -layout.half_z + key.y * definition.chunk_size)


## Fatias de todos os blocos. Retorna {allocation: PackedInt64Array (centavos por bloco),
## free_area: PackedFloat32Array (m² livres), chunk_district: PackedByteArray,
## district_totals: PackedInt64Array}. A soma das fatias é exatamente o total.
func allocate() -> Dictionary:
	var n := chunks_x
	var count := chunks_x * chunks_z
	var size := definition.chunk_size
	var weights := PackedFloat64Array()
	weights.resize(count)
	var free_area := PackedFloat32Array()
	free_area.resize(count)
	var total_weight := 0.0
	for cz in chunks_z:
		for cx in chunks_x:
			var origin := chunk_origin(Vector2i(cx, cz))
			var fraction := layout.free_fraction(origin.x, origin.y, size)
			var district := layout.district_at(origin.x + size * 0.5, origin.y + size * 0.5)
			var i := cz * n + cx
			free_area[i] = fraction * size * size
			weights[i] = fraction * district.density_weight
			total_weight += weights[i]
	var allocation := _largest_remainder(weights, total_weight, definition.total_value_cents)
	# Total por bairro (cada bloco de 16 m cabe inteiro num quarteirão, logo num bairro).
	var chunk_district := PackedByteArray()
	chunk_district.resize(count)
	var district_totals := PackedInt64Array()
	district_totals.resize(definition.districts.size())
	district_totals.fill(0)
	for cz in chunks_z:
		for cx in chunks_x:
			var origin := chunk_origin(Vector2i(cx, cz))
			var index := layout.district_index_of(layout.block_of(origin.x + size * 0.5, origin.y + size * 0.5))
			chunk_district[cz * n + cx] = index
			district_totals[index] += allocation[cz * n + cx]
	return {"allocation": allocation, "free_area": free_area, "chunk_district": chunk_district, "district_totals": district_totals}


## Maiores restos: cada bloco recebe o piso da sua fatia e as unidades que sobram do
## arredondamento vão, uma a uma, para os blocos com maior parte fracionária.
static func _largest_remainder(weights: PackedFloat64Array, total_weight: float, total: int) -> PackedInt64Array:
	var result := PackedInt64Array()
	result.resize(weights.size())
	var assigned := 0
	var fractions: Array = []
	for i in weights.size():
		var exact := float(total) * weights[i] / total_weight
		var base := int(floor(exact))
		result[i] = base
		assigned += base
		fractions.append([exact - base, i])
	fractions.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	for k in total - assigned:
		result[fractions[k][1]] += 1
	return result


## Células de PLACE_CELL com chão livre do bloco (e a altura do chão em cada uma). Calculado
## uma vez por bloco: o traçado da cidade não muda. Só na thread principal (usa cache).
func free_cells(key: Vector2i) -> Array:
	var cached: Variant = _free_cells.get(key)
	if cached != null:
		return cached
	var origin := chunk_origin(key)
	var per_side := int(definition.chunk_size / CoinWorld.PLACE_CELL)
	var cells := PackedInt32Array()
	var heights := PackedFloat32Array()
	for j in per_side:
		for i in per_side:
			var x := origin.x + (i + 0.5) * CoinWorld.PLACE_CELL
			var z := origin.y + (j + 0.5) * CoinWorld.PLACE_CELL
			if layout.is_free(x, z):
				cells.append(j * per_side + i)
				heights.append(layout.ground_height(x, z))
	if cells.is_empty():
		# Bloco sem chão livre (raro): tudo no centro, para a soma continuar exata.
		cells.append((per_side / 2) * per_side + per_side / 2)
		heights.append(0.0)
	var result := [cells, heights]
	_free_cells[key] = result
	return result


## Pilhas do bloco `key` somando exatamente `total` centavos, com o que já foi recolhido
## (`saved`: restante por pilha, 255 = intocada) aplicado. `free` vem de free_cells().
func generate(key: Vector2i, total: int, free: Array, saved: PackedByteArray) -> CoinChunk:
	var chunk := CoinChunk.new()
	chunk.key = key
	chunk.cells.resize(cells_per_side * cells_per_side)
	if total <= 0:
		return chunk
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([definition.random_seed, "stacks", key.x, key.y])
	var origin := chunk_origin(key)
	var district := layout.district_at(origin.x + definition.chunk_size * 0.5, origin.y + definition.chunk_size * 0.5)
	var left := total
	while left > 0:
		var denomination := district.roll_denomination(rng)
		# Quando a moeda sorteada não cabe no que falta, usa a maior que cabe (troco miúdo no fim).
		while Denomination.value_of(denomination) > left:
			denomination -= 1
		var value := Denomination.value_of(denomination)
		var amount := mini(mini(district.roll_pile_size(rng), CoinWorld.MAX_STACK), left / value)
		_add_pile(chunk, rng, origin, free, amount, denomination)
		left -= amount * value
	chunk.remaining = chunk.original.duplicate()
	if saved.size() == chunk.remaining.size():
		for i in saved.size():
			if saved[i] != WorldRecord.UNTOUCHED:
				chunk.remaining[i] = mini(saved[i], chunk.original[i])
	return chunk


func _add_pile(chunk: CoinChunk, rng: RandomNumberGenerator, origin: Vector2, free: Array, amount: int, denomination: int) -> void:
	var free_cells_list: PackedInt32Array = free[0]
	var heights: PackedFloat32Array = free[1]
	var per_side := int(definition.chunk_size / CoinWorld.PLACE_CELL)
	var pick := rng.randi() % free_cells_list.size()
	var cell := free_cells_list[pick]
	var x := origin.x + (cell % per_side + rng.randf()) * CoinWorld.PLACE_CELL
	var z := origin.y + (cell / per_side + rng.randf()) * CoinWorld.PLACE_CELL
	var index := chunk.original.size()
	chunk.positions.append(Vector3(x, heights[pick], z))
	chunk.original.append(amount)
	chunk.yaw.append(rng.randf() * TAU)
	chunk.flip.append(1 if rng.randf() < 0.5 else 0)
	chunk.denom.append(denomination)
	var search := mini(int((z - origin.y) / CoinWorld.CELL_SIZE), cells_per_side - 1) * cells_per_side \
		+ mini(int((x - origin.x) / CoinWorld.CELL_SIZE), cells_per_side - 1)
	var list: PackedInt32Array = chunk.cells[search]
	list.append(index)
	chunk.cells[search] = list
