class_name CityLayout
extends RefCounted
## Traçado determinístico da cidade (puro, sem nós): o Eixo Monumental de Brasília em versão
## caricata, comprido em x (oeste → leste), da Rodoviária ao Congresso Nacional.
##
## - Linhas centrais (`open_rows`): o gramado da Esplanada (e, no fim, a Praça dos Três
##   Poderes), sem ruas no meio; as avenidas N1 e S1 o ladeiam, mais largas.
## - Linhas vizinhas ao gramado, no trecho `ministry_columns`: os blocos dos ministérios.
## - Marcos (Catedral, Museu, Congresso, Itamaraty...) em quarteirões fixos (LANDMARKS).
## - O resto: quarteirões comuns (prédios, praças, estacionamentos) com ruas em grade.
##
## A mesma semente sempre gera a mesma cidade.

enum LotType { BUILDINGS, PLAZA, PARKING, HUB, LAWN, PAVED, MINISTRY, LANDMARK }

const CAR_SIZE := Vector2(2.0, 3.6)
const TREE_RADIUS := 0.45
const OBSTACLE_MARGIN := 0.25
## Marcos: [tipo, quarteirões ocupados (x, z, largura, altura), pegada no chão em metros (sem
## moedas; Vector2.ZERO = só visual)]. A pegada fica centrada nos quarteirões.
## Posições conferidas com a vista de satélite (norte = linhas de cima, -z).
const LANDMARKS := [
	[&"bus_station", Rect2i(0, 0, 2, 7), Vector2.ZERO],
	[&"theater", Rect2i(4, 0, 2, 2), Vector2(52, 46)],
	[&"museum", Rect2i(3, 5, 1, 2), Vector2(40, 40)],
	[&"library", Rect2i(4, 6, 1, 1), Vector2(40, 22)],
	[&"cathedral", Rect2i(5, 5, 2, 2), Vector2(40, 40)],
	[&"justice", Rect2i(27, 0, 2, 2), Vector2(60, 52)],
	[&"itamaraty", Rect2i(27, 5, 2, 2), Vector2(60, 52)],
	[&"congress", Rect2i(34, 2, 3, 3), Vector2(110, 120)],
	[&"planalto", Rect2i(40, 0, 2, 2), Vector2(60, 32)],
	[&"supreme_court", Rect2i(40, 5, 2, 2), Vector2(54, 32)],
	[&"flag", Rect2i(42, 3, 1, 1), Vector2(4, 4)],
]
## Pontos de serviço ficam no gramado, alternando entre a beira da N1 e a da S1, a cada
## HUB_SPACING colunas de cada bairro.
const HUB_SPACING := 5
## Distância (m) do centro do ponto de serviço até o portal, a leste da loja.
const PORTAL_OFFSET := 12.0

static var _cache := {}

var definition: WorldDefinition
var half_x := 0.0
var half_z := 0.0
## Vector2i(bx, bz) -> Dictionary {type, buildings: Array[{rect, height, color}], trees,
## small_trees, cars, props: Array[{kind, pos, yaw, radius}], landmark_rects, benches: Array[{pos,
## yaw}] (frente para +z com yaw 0), bins: Array[Vector2], bus_stops: Array[{pos, yaw}], hydrants:
## Array[Vector2]}
var blocks := {}
## Pontos de serviço: {block, deposit: Vector3, kiosk: Vector3, portal: Vector3}. A frente vira para -z.
var hubs: Array[Dictionary] = []
## Postes (posição) e a direção do braço de cada um.
var lamps := PackedVector3Array()
var lamp_yaws := PackedFloat32Array()
## Marcos: {kind, blocks: Rect2i, rect: Rect2 (pegada em metros), area: Rect2 (quarteirões)}.
var landmarks: Array[Dictionary] = []
var _landmark_of := {}   # Vector2i -> índice em `landmarks`


## Traçado em cache (mesma definição = mesmo objeto).
static func for_definition(world: WorldDefinition) -> CityLayout:
	var key := world.get_instance_id()
	if not _cache.has(key):
		_cache[key] = CityLayout.new(world)
	return _cache[key]


static func release_cache() -> void:
	_cache.clear()


func _init(world: WorldDefinition) -> void:
	definition = world
	half_x = world.world_size_x() * 0.5
	half_z = world.world_size_z() * 0.5
	_place_landmarks()
	var hub_blocks := _hub_blocks()
	for bx in world.blocks_x:
		for bz in world.blocks_z:
			var key := Vector2i(bx, bz)
			blocks[key] = _generate_block(key, hub_blocks.has(key))
	# Prédios que passam da borda do próprio quarteirão (ministérios): sem moedas no vizinho.
	for key: Vector2i in blocks:
		var cell := Rect2(block_origin(key), Vector2.ONE * definition.block_size)
		for building: Dictionary in blocks[key].buildings:
			var rect: Rect2 = building.rect
			if cell.encloses(rect):
				continue
			for other: Vector2i in blocks:
				if other != key and Rect2(block_origin(other), Vector2.ONE * definition.block_size).intersects(rect):
					(blocks[other].landmark_rects as Array).append(rect)
	# Pegadas dos marcos: sem moedas em nenhum quarteirão que elas tocam.
	for landmark in landmarks:
		var rect: Rect2 = landmark.rect
		if rect.size == Vector2.ZERO:
			continue
		for key: Vector2i in blocks:
			if Rect2(block_origin(key), Vector2.ONE * definition.block_size).intersects(rect):
				(blocks[key].landmark_rects as Array).append(rect)
	for key: Vector2i in blocks:
		_with_solids(blocks[key])
	# Bancos e lixeiras: depois dos obstáculos, com sorteio próprio e fora deles (não mudam onde
	# as moedas nascem; o jogador esbarra, as moedas podem ficar embaixo).
	for key: Vector2i in blocks:
		_add_furniture(key, blocks[key])


# --- Consultas -------------------------------------------------------------------------

func block_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori((x + half_x) / definition.block_size), floori((z + half_z) / definition.block_size))


func block_origin(block: Vector2i) -> Vector2:
	return Vector2(-half_x + block.x * definition.block_size, -half_z + block.y * definition.block_size)


func is_valid_block(block: Vector2i) -> bool:
	return block.x >= 0 and block.y >= 0 and block.x < definition.blocks_x and block.y < definition.blocks_z


## Índice do bairro do quarteirão (0 = o começo, o último = o mais rico).
func district_index_of(block: Vector2i) -> int:
	for i in definition.districts.size():
		if definition.districts[i].area.has_point(block):
			return i
	return definition.districts.size() - 1


func district_at(x: float, z: float) -> DistrictDefinition:
	if not is_inside(x, z):
		return null
	return definition.districts[district_index_of(block_of(x, z))]


func is_inside(x: float, z: float) -> bool:
	return absf(x) < half_x and absf(z) < half_z


## Área do bairro em metros (o retângulo dele; o começo fica dentro do segundo bairro).
func district_rect(index: int) -> Rect2:
	var area := definition.districts[index].area
	return Rect2(block_origin(area.position), Vector2(area.size) * definition.block_size)


## Linha do gramado central (sem ruas no meio).
func is_open_row(row: int) -> bool:
	return row >= definition.open_rows.x and row <= definition.open_rows.y


func is_lawn(block: Vector2i) -> bool:
	return is_open_row(block.y) and block.x < definition.paved_from


func is_paved(block: Vector2i) -> bool:
	return is_open_row(block.y) and block.x >= definition.paved_from


## Os ministérios (e os anexos do Congresso) ocupam as duas linhas de cada lado do gramado, sem
## rua entre elas: são lâminas compridas, com a ponta estreita virada para o eixo.
func is_ministry_row(block: Vector2i) -> bool:
	var rows := [definition.open_rows.x - 2, definition.open_rows.x - 1, definition.open_rows.y + 1, definition.open_rows.y + 2]
	return block.y in rows and (_in_range(block.x, definition.ministry_columns) or is_annex(block))


func is_annex(block: Vector2i) -> bool:
	return _in_range(block.x, definition.annex_columns) and not is_open_row(block.y)


static func _in_range(value: int, range_: Vector2i) -> bool:
	return value >= range_.x and value <= range_.y


## Linha do ministério colada ao gramado (onde fica o prédio; a outra é o resto da lâmina).
func is_inner_ministry_row(block: Vector2i) -> bool:
	return is_ministry_row(block) and (block.y == definition.open_rows.x - 1 or block.y == definition.open_rows.y + 1)


## Meia largura da rua em cada lado do quarteirão [esquerda (-x), cima (-z), direita, baixo]:
## 0 entre dois quarteirões do gramado, avenida (N1, S1) nas bordas do gramado e a via inteira
## (N2, S2) nas bordas norte e sul, que são o limite da área andável.
func margins(block: Vector2i) -> PackedFloat32Array:
	var road := definition.road_half_width
	var avenue := definition.avenue_half_width
	var open := is_open_row(block.y)
	var result := PackedFloat32Array([road, road, road, road])
	if open and block.x > 0:
		result[0] = 0.0
	if open and block.x < definition.blocks_x - 1:
		result[2] = 0.0
	if block.y == definition.open_rows.x or block.y == definition.open_rows.y + 1:
		result[1] = avenue
	elif open:
		result[1] = 0.0
	if block.y == definition.open_rows.y or block.y == definition.open_rows.x - 1:
		result[3] = avenue
	elif open:
		result[3] = 0.0
	# Entre as duas linhas de um ministério não há rua (a lâmina atravessa).
	if is_ministry_row(block):
		if block.y == definition.open_rows.x - 2 or block.y == definition.open_rows.y + 1:
			result[3] = 0.0
		else:
			result[1] = 0.0
	# Marco de vários quarteirões: uma praça só, sem as ruas internas (senão elas entram no prédio).
	var plaza := merged_area(block)
	if plaza.has_area():
		if block.x > plaza.position.x:
			result[0] = 0.0
		if block.x < plaza.end.x - 1:
			result[2] = 0.0
		if block.y > plaza.position.y:
			result[1] = 0.0
		if block.y < plaza.end.y - 1:
			result[3] = 0.0
	if block.y == 0:
		result[1] = definition.outer_road_width
	if block.y == definition.blocks_z - 1:
		result[3] = definition.outer_road_width
	return result


## Quarteirões do marco com pegada que contém `block` (vazio se nenhum). A Rodoviária (sem
## pegada) fica de fora: a plataforma passa por cima das avenidas de propósito.
func merged_area(block: Vector2i) -> Rect2i:
	if not _landmark_of.has(block):
		return Rect2i()
	var landmark: Dictionary = landmarks[_landmark_of[block]]
	return landmark.blocks if (landmark.rect as Rect2).size != Vector2.ZERO else Rect2i()


## Lote do quarteirão (tudo que não é rua), em metros.
func lot_rect(block: Vector2i) -> Rect2:
	var m := margins(block)
	var origin := block_origin(block)
	var size := definition.block_size
	return Rect2(origin.x + m[0], origin.y + m[1], size - m[0] - m[2], size - m[1] - m[3])


## Altura do chão (rua = 0, calçada, lote e gramado = meio-fio).
func ground_height(x: float, z: float) -> float:
	var block := block_of(x, z)
	if not is_valid_block(block):
		return 0.0
	return definition.curb_height if lot_rect(block).has_point(Vector2(x, z)) else 0.0


## true se uma moeda pode estar em (x, z): dentro da cidade e fora de prédios, marcos,
## árvores e carros.
func is_free(x: float, z: float) -> bool:
	if absf(x) > half_x - 1.0 or absf(z) > half_z - 1.0:
		return false
	var info: Dictionary = blocks[block_of(x, z)]
	var p := Vector2(x, z)
	for rect: Rect2 in info.solid_rects:
		if rect.has_point(p):
			return false
	var circles: PackedVector3Array = info.solid_circles
	for circle in circles:
		if (p.x - circle.x) * (p.x - circle.x) + (p.y - circle.y) * (p.y - circle.y) < circle.z * circle.z:
			return false
	return true


## Fração do quadrado [x0, x0+size]² livre para moedas, calculada pela área (rápido).
## O quadrado deve estar dentro de um único quarteirão (blocos de moedas estão).
func free_fraction(x0: float, z0: float, size: float) -> float:
	var limit := Rect2(-half_x + 1.0, -half_z + 1.0, half_x * 2.0 - 2.0, half_z * 2.0 - 2.0)
	var square := Rect2(x0, z0, size, size).intersection(limit)
	if square.size.x <= 0.0 or square.size.y <= 0.0:
		return 0.0
	var free := square.get_area()
	var info: Dictionary = blocks[block_of(x0 + size * 0.5, z0 + size * 0.5)]
	for rect: Rect2 in info.solid_rects:
		free -= rect.intersection(square).get_area()
	var circles: PackedVector3Array = info.solid_circles
	for circle in circles:
		if square.has_point(Vector2(circle.x, circle.y)):
			free -= PI * circle.z * circle.z
	return clampf(free / (size * size), 0.0, 1.0)


## Na Rodoviária, alguns metros ao norte do primeiro ponto de coleta e da loja, olhando para eles.
func spawn_point() -> Vector3:
	var hub: Dictionary = hubs[0]
	for candidate in hubs:
		if district_index_of(candidate.block) == 0:
			hub = candidate
			break
	var deposit: Vector3 = hub.deposit
	var kiosk: Vector3 = hub.kiosk
	var at := (deposit + kiosk) * 0.5 + Vector3(0, 0, -4.0)
	return Vector3(at.x, ground_height(at.x, at.z) + 0.1, at.z)


func landmark_at(block: Vector2i) -> Dictionary:
	return landmarks[_landmark_of[block]] if _landmark_of.has(block) else {}


# --- Geração ---------------------------------------------------------------------------

func _place_landmarks() -> void:
	for entry: Array in LANDMARKS:
		var area: Rect2i = entry[1]
		var footprint: Vector2 = entry[2]
		var span := Rect2(block_origin(area.position), Vector2(area.size) * definition.block_size)
		var rect := Rect2(span.get_center() - footprint * 0.5, footprint)
		for bx in range(area.position.x, area.end.x):
			for bz in range(area.position.y, area.end.y):
				_landmark_of[Vector2i(bx, bz)] = landmarks.size()
		landmarks.append({"kind": entry[0], "blocks": area, "rect": rect, "area": span})


## Pontos de serviço: o primeiro no meio do bairro inicial; depois, em cada bairro, no gramado,
## alternando entre a beira da N1 e a da S1 (pulando marcos).
func _hub_blocks() -> Dictionary:
	var start: Rect2i = definition.districts[0].area
	var result := {start.position + Vector2i(start.size.x - 1, start.size.y / 2): true}
	for i in range(1, definition.districts.size()):
		var area: Rect2i = definition.districts[i].area
		for bx in range(area.position.x, area.end.x):
			var offset := (bx - area.position.x) % HUB_SPACING
			if offset != 2 and offset != 4:
				continue
			var block := Vector2i(bx, definition.open_rows.x if offset == 2 else definition.open_rows.y)
			if not _landmark_of.has(block) and district_index_of(block) == i:
				result[block] = true
	return result


func _generate_block(key: Vector2i, is_hub: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([definition.random_seed, key.x, key.y])
	var info := {"type": LotType.BUILDINGS, "buildings": [], "trees": [], "small_trees": [], "cars": [],
		"service_points": [], "props": [], "landmark_rects": []}
	var lot := lot_rect(key)
	_add_lamps(key, lot)
	if is_hub:
		_fill_hub(info, rng, key, lot)
	elif _landmark_of.has(key):
		info.type = LotType.LANDMARK
	elif is_lawn(key):
		info.type = LotType.LAWN
		_fill_lawn(info, rng, key, lot)
	elif is_paved(key):
		info.type = LotType.PAVED
	elif is_ministry_row(key):
		_fill_ministry(info, rng, key, lot)
	else:
		# Entre a N1 e a N2 (e a S1 e a S2) fora dos ministérios: jardins e estacionamentos. Os
		# prédios comuns da cidade ficam do lado de fora da barreira, só como cenário.
		_add_corner_props(info, key, lot)
		var area := lot.grow(-definition.sidewalk_width)
		if rng.randf() < 0.6:
			_fill_plaza(info, rng, area)
		else:
			_fill_parking(info, rng, area)
	return info


## Postes nos cantos do lote que dão para rua (no gramado, só ao longo das avenidas). Nunca
## dentro (nem colados) da pegada de um marco. Postes não bloqueiam moedas.
func _add_lamps(key: Vector2i, lot: Rect2) -> void:
	var m := margins(key)
	var inset := 0.6
	if m[1] > 0.0:
		for x: float in [lot.position.x + inset, lot.end.x - inset]:
			_add_lamp(Vector3(x, definition.curb_height, lot.position.y + inset), PI * 0.75)
	if m[3] > 0.0 and is_open_row(key.y):
		for x: float in [lot.position.x + inset, lot.end.x - inset]:
			_add_lamp(Vector3(x, definition.curb_height, lot.end.y - inset), -PI * 0.25)


func _add_lamp(at: Vector3, yaw: float) -> void:
	for landmark in landmarks:
		if (landmark.rect as Rect2).grow(2.0).has_point(Vector2(at.x, at.z)):
			return
	lamps.append(at)
	lamp_yaws.append(yaw)


## Na esquina de baixo: semáforo em metade dos quarteirões, placa de PARE nos outros.
func _add_corner_props(info: Dictionary, key: Vector2i, lot: Rect2) -> void:
	if (key.x + key.y) % 2 == 0:
		_add_prop(info, &"traffic_light", lot.end - Vector2.ONE * 0.6, PI * 0.25, 0.3)
	else:
		_add_prop(info, &"stop_sign", Vector2(lot.position.x + 0.6, lot.end.y - 0.6), -PI * 0.5, 0.0)


## Ponto de serviço: ponto de coleta e loja, floreiras e árvores. No gramado fica no meio do
## lote (não há calçada na frente).
func _fill_hub(info: Dictionary, rng: RandomNumberGenerator, key: Vector2i, lot: Rect2) -> void:
	info.type = LotType.HUB
	var open := is_open_row(key.y)
	var front := lot.get_center().y - 6.0 if open else lot.position.y + definition.sidewalk_width + 1.5
	var mid := lot.get_center().x
	hubs.append({"block": key, "deposit": Vector3(mid - 3.0, definition.curb_height, front), "kiosk": Vector3(mid + 3.0, definition.curb_height, front),
		# Portal depois da floreira da loja. Não bloqueia moedas (o sorteio fica igual ao de antes dele).
		"portal": Vector3(mid + PORTAL_OFFSET, definition.curb_height, front)})
	info.service_points = [Vector2(mid - 3.0, front), Vector2(mid + 3.0, front)]
	for side: float in [-1.0, 1.0]:
		_add_prop(info, &"planter", Vector2(mid + side * 7.5, front), 0.0, 1.2)
	if not open:
		var area := lot.grow(-definition.sidewalk_width)
		_scatter_trees(info, rng, Rect2(area.position + Vector2(0, 8), area.size - Vector2(0, 8)), 6)


## Gramado: aberto, com algumas árvores perto das avenidas.
func _fill_lawn(info: Dictionary, rng: RandomNumberGenerator, key: Vector2i, lot: Rect2) -> void:
	var m := margins(key)
	if m[1] > 0.0 or m[3] > 0.0:
		var edge := lot.position.y + 3.0 if m[1] > 0.0 else lot.end.y - 3.0
		for i in rng.randi_range(0, 2):
			info.small_trees.append(Vector2(lot.position.x + 4.0 + rng.randf() * (lot.size.x - 8.0), edge))


## Bloco de ministério: lâmina de ~17 m × ~80 m, comprida no sentido norte–sul, ocupando as duas
## linhas do ministério. O prédio fica no quarteirão colado ao gramado; o outro só tem o resto dela.
func _fill_ministry(info: Dictionary, rng: RandomNumberGenerator, key: Vector2i, lot: Rect2) -> void:
	info.type = LotType.MINISTRY
	if not is_inner_ministry_row(key):
		return
	var outer_row := key.y - 1 if key.y < definition.open_rows.x else key.y + 1
	var both := lot.merge(lot_rect(Vector2i(key.x, outer_row))).grow(-definition.sidewalk_width - 1.5)
	var width := 17.0
	info.buildings.append({
		"rect": Rect2(both.get_center().x - width * 0.5, both.position.y, width, both.size.y),
		# Anexos do Congresso são mais baixos que os ministérios.
		"height": rng.randf_range(18.0, 22.0) if is_annex(key) else rng.randf_range(32.0, 36.0),
		"color": 6,
	})


## Praça: árvores e floreiras soltas.
func _fill_plaza(info: Dictionary, rng: RandomNumberGenerator, area: Rect2) -> void:
	info.type = LotType.PLAZA
	_scatter_trees(info, rng, area.grow(-1.0), rng.randi_range(6, 12))
	var inner := area.grow(-3.0)
	for i in rng.randi_range(2, 4):
		_add_prop(info, &"planter", inner.position + Vector2(rng.randf(), rng.randf()) * inner.size, rng.randf() * TAU, 1.2)


## Estacionamento: duas fileiras de carros e alguns cones no meio.
func _fill_parking(info: Dictionary, rng: RandomNumberGenerator, area: Rect2) -> void:
	info.type = LotType.PARKING
	for row: float in [area.position.y + area.size.y * 0.3, area.position.y + area.size.y * 0.7]:
		var x := area.position.x + 2.0
		while x + CAR_SIZE.x < area.end.x - 1.0:
			if rng.randf() < 0.6:
				info.cars.append(Rect2(x, row - CAR_SIZE.y * 0.5, CAR_SIZE.x, CAR_SIZE.y))
			x += CAR_SIZE.x + 0.7
	for i in rng.randi_range(1, 3):
		_add_prop(info, &"cone", Vector2(area.position.x + 1.5 + rng.randf() * (area.size.x - 3.0), area.get_center().y), 0.0, 0.0)


## Bancos à beira das avenidas no gramado (virados para ele) e nas praças (virados para dentro),
## com uma lixeira entre cada par. Só onde o chão está livre.
func _add_furniture(key: Vector2i, info: Dictionary) -> void:
	info.benches = []
	info.bins = []
	info.bus_stops = []
	info.hydrants = []
	var lot := lot_rect(key)
	# Hidrante na calçada de cima das praças e estacionamentos, a poucos metros da esquina (na
	# esquina fica o poste; nas de baixo, semáforo ou placa).
	if info.type == LotType.PLAZA or info.type == LotType.PARKING:
		var corner := lot.position + Vector2(3.0, 0.9)
		if _fits(corner, 0.3):
			info.hydrants.append(corner)
	var rows: Array = []   # [z, yaw]
	if info.type == LotType.LAWN:
		var m := margins(key)
		if m[1] > 0.0:
			rows.append([lot.position.y + 2.0, 0.0])
		if m[3] > 0.0:
			rows.append([lot.end.y - 2.0, PI])
	elif info.type == LotType.PLAZA:
		var area := lot.grow(-definition.sidewalk_width)
		rows.append([area.position.y + 1.0, 0.0])
		rows.append([area.end.y - 1.0, PI])
	if rows.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([definition.random_seed, "furniture", key.x, key.y])
	for row: Array in rows:
		var z: float = row[0]
		var center := lot.get_center().x + rng.randf_range(-6.0, 6.0)
		var placed := 0
		for dx: float in [-4.0, 4.0]:
			var spot := Vector2(center + dx, z)
			if _fits(spot, 1.2):
				info.benches.append({"pos": spot, "yaw": row[1]})
				placed += 1
		if placed > 0 and _fits(Vector2(center, z), 0.5):
			info.bins.append(Vector2(center, z))
	# Ponto de ônibus na ponta oeste da beira da avenida, a cada três colunas, de frente para ela.
	if info.type == LotType.LAWN and key.x % 3 == 0:
		for row: Array in rows:
			var stop := Vector2(lot.position.x + 6.0, row[0] - 0.4 if row[1] == 0.0 else row[0] + 0.4)
			if _fits(stop, 2.0):
				info.bus_stops.append({"pos": stop, "yaw": PI if row[1] == 0.0 else 0.0})


## Chão livre num raio `half` em volta de `spot` (centro e quatro pontas).
func _fits(spot: Vector2, half: float) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(half, 0), Vector2(-half, 0), Vector2(0, half), Vector2(0, -half)]:
		if not is_free(spot.x + offset.x, spot.y + offset.y):
			return false
	return true


## Obstáculos prontos para consulta rápida: retângulos já com a margem e círculos (x, z, raio).
func _with_solids(info: Dictionary) -> void:
	var rects: Array[Rect2] = []
	for building: Dictionary in info.buildings:
		rects.append((building.rect as Rect2).grow(OBSTACLE_MARGIN))
	for car: Rect2 in info.cars:
		rects.append(car.grow(OBSTACLE_MARGIN))
	for rect: Rect2 in info.landmark_rects:
		rects.append(rect.grow(OBSTACLE_MARGIN))
	var circles := PackedVector3Array()
	for tree: Vector2 in info.trees:
		circles.append(Vector3(tree.x, tree.y, TREE_RADIUS + OBSTACLE_MARGIN))
	for point: Vector2 in info.service_points:
		circles.append(Vector3(point.x, point.y, 1.4))
	for tree: Vector2 in info.small_trees:
		circles.append(Vector3(tree.x, tree.y, TREE_RADIUS * 0.7 + OBSTACLE_MARGIN))
	for prop: Dictionary in info.props:
		if prop.radius > 0.0:
			circles.append(Vector3(prop.pos.x, prop.pos.y, prop.radius + OBSTACLE_MARGIN))
	info.solid_rects = rects
	info.solid_circles = circles


func _scatter_trees(info: Dictionary, rng: RandomNumberGenerator, area: Rect2, count: int) -> void:
	for i in count:
		# Um terço das árvores é da versão pequena.
		var spot := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		(info.small_trees if rng.randf() < 0.35 else info.trees).append(spot)


## Objeto de rua: `radius` > 0 bloqueia moedas e o jogador (círculo no chão).
static func _add_prop(info: Dictionary, kind: StringName, pos: Vector2, yaw: float, radius: float) -> void:
	info.props.append({"kind": kind, "pos": pos, "yaw": yaw, "radius": radius})
