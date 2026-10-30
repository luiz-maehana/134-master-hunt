extends TestSuite
## Traçado da cidade: determinismo, chão livre e bairros.

var world: WorldDefinition
var layout: CityLayout


func before_all() -> void:
	world = WorldDefinition.get_default()
	layout = CityLayout.for_definition(world)


func test_deterministic() -> void:
	var other := CityLayout.new(world)
	var same := true
	for key: Vector2i in layout.blocks:
		var a: Dictionary = layout.blocks[key]
		var b: Dictionary = other.blocks[key]
		if a.type != b.type or a.buildings.size() != b.buildings.size() or a.trees.size() != b.trees.size() or a.cars.size() != b.cars.size():
			same = false
			break
	check(same, "mesma semente gera a mesma cidade")
	check_eq(other.hubs.size(), layout.hubs.size(), "mesmos pontos de serviço")


func test_free_ground() -> void:
	var spawn := layout.spawn_point()
	check(layout.is_free(spawn.x, spawn.z), "ponto inicial é chão livre")
	check(layout.district_index_of(layout.block_of(spawn.x, spawn.z)) == 0, "ponto inicial dentro do bairro inicial")
	check(spawn.y >= layout.ground_height(spawn.x, spawn.z), "ponto inicial acima do chão")
	var inside_buildings := 0
	var checked := 0
	for key: Vector2i in layout.blocks:
		for building: Dictionary in (layout.blocks[key] as Dictionary).buildings:
			var center: Vector2 = (building.rect as Rect2).get_center()
			checked += 1
			if layout.is_free(center.x, center.y):
				inside_buildings += 1
	var ministries := (world.ministry_columns.y - world.ministry_columns.x + 1) * 2
	check(checked >= ministries, "ministérios dos dois lados do eixo (%d prédios)" % checked)
	check_eq(inside_buildings, 0, "dentro de prédio nunca é chão livre")
	check(not layout.is_free(layout.half_x + 5.0, 0.0), "fora da cidade não é chão livre")


func test_free_fraction_matches_sampling() -> void:
	var worst := 0.0
	for key: Vector2i in [Vector2i(10, 10), Vector2i(3, 7), Vector2i(15, 2), Vector2i(0, 0)]:
		var origin := layout.block_origin(key)
		var x0 := origin.x + 16.0
		var z0 := origin.y + 16.0
		var hits := 0
		for i in 40:
			for j in 40:
				if layout.is_free(x0 + (i + 0.5) * 0.4, z0 + (j + 0.5) * 0.4):
					hits += 1
		worst = maxf(worst, absf(hits / 1600.0 - layout.free_fraction(x0, z0, 16.0)))
	check(worst < 0.06, "área calculada bate com amostragem (erro máx. %.3f)" % worst)


func test_districts_grow_along_the_axis() -> void:
	var start: Rect2i = world.districts[0].area
	check_eq(layout.district_index_of(start.position), 0, "Rodoviária = primeiro bairro")
	var row := world.open_rows.x + 1
	var last := -1
	var ordered := true
	for bx in range(start.end.x, world.blocks_x):
		var index := layout.district_index_of(Vector2i(bx, row))
		if index < last:
			ordered = false
		last = index
	check(ordered, "bairros ficam mais ricos para o leste")
	check_eq(last, world.districts.size() - 1, "ponta leste = último bairro (Congresso)")
	check(world.world_size_x() > world.world_size_z() * 2.0, "mapa comprido, não quadrado")
	var congress := {}
	for landmark in layout.landmarks:
		if landmark.kind == &"congress":
			congress = landmark
	check(not congress.is_empty(), "o Congresso está no mapa")
	if not congress.is_empty():
		var block: Rect2i = congress.blocks
		check_eq(layout.district_index_of(block.position), world.districts.size() - 1, "Congresso fica no bairro mais rico")
		var footprint: Rect2 = congress.rect
		check(not layout.is_free(footprint.get_center().x, footprint.get_center().y), "sem moedas dentro do Congresso")
	var lawn := layout.block_origin(Vector2i(20, row)) + Vector2.ONE * 24.0
	check_eq(layout.ground_height(lawn.x - 24.0, lawn.y), world.curb_height, "gramado sem rua entre os quarteirões")
	check(layout.hubs.size() >= world.districts.size(), "pontos de serviço em todos os bairros (%d)" % layout.hubs.size())
	for hub in layout.hubs:
		check(not layout.is_free(hub.deposit.x, hub.deposit.z), "nada nasce em cima do ponto de coleta")


## Nenhuma rua entra num marco: a pegada inteira (com 3 m de folga) é praça, nunca pista.
## E nenhum poste fica dentro dela.
func test_landmarks_sit_on_plazas() -> void:
	for landmark in layout.landmarks:
		var rect: Rect2 = landmark.rect
		if rect.size == Vector2.ZERO:
			continue
		var area := rect.grow(3.0)
		var on_road := 0
		var step := 2.0
		var x := area.position.x
		while x <= area.end.x:
			var z := area.position.y
			while z <= area.end.y:
				if layout.ground_height(x, z) <= 0.0:
					on_road += 1
				z += step
			x += step
		check_eq(on_road, 0, "%s: nenhuma pista dentro da pegada" % landmark.kind)
		var lamps_inside := 0
		for lamp in layout.lamps:
			if rect.has_point(Vector2(lamp.x, lamp.z)):
				lamps_inside += 1
		check_eq(lamps_inside, 0, "%s: nenhum poste dentro" % landmark.kind)


## Bancos e lixeiras: sobre lote (nunca na pista) e fora de árvores, carros e prédios.
func test_furniture_on_free_ground() -> void:
	var total := 0
	var bad := 0
	for key: Vector2i in layout.blocks:
		var info: Dictionary = layout.blocks[key]
		var spots: Array = info.bins.duplicate()
		for bench: Dictionary in info.benches:
			spots.append(bench.pos)
		for spot: Vector2 in spots:
			total += 1
			if layout.ground_height(spot.x, spot.y) <= 0.0 or not layout.is_free(spot.x, spot.y):
				bad += 1
	check(total > 100, "a cidade tem bancos e lixeiras (%d)" % total)
	check_eq(bad, 0, "todos sobre lote livre")
