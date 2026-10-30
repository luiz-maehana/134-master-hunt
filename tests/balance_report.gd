extends SceneTree
## Relatório de balanceamento (estimativa analítica a partir de data/).
##   godot --headless --path . --script res://tests/balance_report.gd
##
## Não substitui jogar: as premissas abaixo são chutes explícitos. Serve para ver o efeito
## de mudar preços, capacidades e densidades sem precisar jogar horas.
##
## Modelo: cada uso pega min(capacidade, moedas que a ferramenta alcança naquele ponto),
## em que "alcance" = densidade do bairro × área coberta pela ferramenta. Entre usos o
## jogador anda até chão cheio (proporcional ao tamanho da área). A cada bolso cheio há
## uma viagem de ida e volta a um ponto de coleta.
##
## Usa só dados (Resources), sem os scripts que dependem dos autoloads.

const WALK_SPEED := 5.0
const REPOSITION := 0.4
const BASE_CAPACITY := 100
## Ida e volta média até o ponto de coleta do bairro (s).
const DEPOSIT_TRIP := 30.0
## Fração caminhável (chão livre) média de um quarteirão.
const FREE_SHARE := 0.8
## Passo da simulação (min).
const STEP := 0.25
## Fração do tempo em que um robô está de fato recolhendo (o resto: andar até as pilhas e
## esperar o jogador trazê-lo para uma área nova).
const ROBOT_EFFICIENCY := 0.8

var tools: Resource
var shop: Resource
var world: Resource


func _initialize() -> void:
	tools = load("res://data/tools/catalog.tres")
	shop = load("res://data/shop/catalog.tres")
	world = load("res://data/world/city.tres")

	var districts: Array = world.districts
	var stats := _district_stats()
	print("\n## Bairros\n")
	print("| Bairro | Moedas | Área (m²) | Moedas/m² | Pilha média | Centavos por moeda |\n|---|---|---|---|---|---|")
	for i in districts.size():
		var d = districts[i]
		var permits: Array = [] if d.permit_id == &"" else [d.permit_id]
		print("| %s | %s | %s | %.1f | %.0f | %.1f |" % [d.display_name, _group(stats[i].coins), _group(int(stats[i].area)),
			stats[i].coins / stats[i].area, _mean_pile(d), _value_per_coin(permits)])

	print("\n## Ritmo por ferramenta (moedas/min, já com viagens ao depósito)\n")
	var header := "| Ferramenta (bolso) |"
	var sep := "|---|"
	for d in districts:
		header += " %s |" % d.display_name
		sep += "---|"
	print(header + "\n" + sep)
	for setup in [[&"hands", 100], [&"glove", 500], [&"big_glove", 2500], [&"shovel_small", 2500],
			[&"magnet_small", 2500], [&"shovel_medium", 15000], [&"magnet_medium", 15000],
			[&"shovel_large", 15000], [&"magnet_large", 15000], [&"magnet_rod_small", 2500],
			[&"magnet_rod_medium", 15000], [&"magnet_rod_large", 15000], [&"magnet_neodymium", 15000]]:
		var tool_def = _find_tool(setup[0])
		var row := "| %s (%s) |" % [tool_def.display_name, _group(setup[1])]
		for i in districts.size():
			row += " %s |" % _group(int(_rate(tool_def, stats[i].coins / stats[i].area, setup[1], 1.25)))
		print(row)

	_simulate(stats)
	quit()


## Partida simulada em passos de STEP minutos: o jogador coleta com a melhor ferramenta no
## melhor bairro liberado, os robôs trabalham e, sempre que dá, compra o item disponível
## mais barato (robôs, várias unidades). Termina quando os R$ 134 milhões foram encontrados.
func _simulate(stats: Array) -> void:
	print("\n## Partida simulada (compra sempre o item disponível mais barato)\n")
	print("| Compra | Preço | Aos (h) | Moedas encontradas | Moedas/min depois |\n|---|---|---|---|---|")
	var owned: Array = [&"hands"]
	var found := 0.0
	var money := 0.0
	var minutes := 0.0
	var goal := float(world.total_value_cents)
	var found_value := 0.0
	var milestones := {}
	while found_value < goal and minutes < 60.0 * 200.0:
		var bought := true
		while bought:
			bought = false
			var best: Resource = null
			var best_price := INF
			for item in shop.items:
				var count := owned.count(item.id)
				if count >= item.max_count() or item.required_value_cents > found_value:
					continue
				if not item.requires.all(func(r: StringName) -> bool: return owned.has(r)):
					continue
				var price: float = item.price_for(count)
				if price <= money and price < best_price:
					best = item
					best_price = price
			if best != null:
				money -= best_price
				owned.append(best.id)
				bought = true
				var count := owned.count(best.id)
				var label: String = best.display_name if best.max_count() == 1 else "%s #%d" % [best.display_name, count]
				if best.max_count() == 1 or count == 1 or count == best.max_count() or best.get("rate") != null and best.rate >= 400.0:
					print("| %s | %s | %.2f | %s | %s |" % [label, _brl(int(best_price)), minutes / 60.0, _group(int(found)), _group(int(_total_rate(owned, stats)))])
		var rate := _total_rate(owned, stats)
		var per_coin := _value_per_coin(owned)
		var got := minf(rate * STEP, (goal - found_value) / per_coin)
		found += got
		found_value += got * per_coin
		money += got * per_coin
		minutes += STEP
		for mark in [100_000_000, 1_000_000_000, 5_000_000_000, 10_000_000_000]:
			if found_value >= mark and not milestones.has(mark):
				milestones[mark] = minutes / 60.0
	print("\n| Marco | Aos (h) |\n|---|---|")
	for mark in milestones:
		print("| %s | %.1f |" % [_brl(mark), milestones[mark]])
	print("\n**Tempo total para encontrar os R$ 134.000.000,00: ~%.1f h** (%s moedas; alvo: ~8 h).\n" % [minutes / 60.0, _group(int(found))])


## Moedas/min: mão (melhor ferramenta e bolso) + robôs.
func _total_rate(owned: Array, stats: Array) -> float:
	var speed := 1.0
	for id in owned:
		var item = shop.find(id)
		if item != null and item.get("effect") == 4:
			speed += item.amount
	var robots := 0.0
	for id in owned:
		var item = shop.find(id)
		if item != null and item.get("rate") != null:
			robots += item.rate * 60.0
	return _best_rate(owned, stats) + robots * speed * ROBOT_EFFICIENCY
func _rate(tool_def: Resource, density: float, pocket: int, speed: float) -> float:
	if tool_def.kind == 3:
		return _rod_rate(tool_def, density, pocket, speed)
	var area: float
	match tool_def.kind:
		1: area = PI * tool_def.area_radius * tool_def.area_radius            # pá
		2: area = PI * tool_def.reach * tool_def.reach * (1.0 if tool_def.passive else 150.0 / 360.0)  # ímã (cone; passivo: em volta)
		_: area = PI * tool_def.area_radius * tool_def.area_radius            # mãos
	var available: float = density * area
	var per_use: float = minf(tool_def.capacity, maxf(available, 1.0))
	# Se a área esvazia antes de encher a capacidade, é preciso andar até chão cheio.
	var walk: float = REPOSITION + (sqrt(area) / (WALK_SPEED * speed) if available <= tool_def.capacity else 0.0)
	var rate: float = 60.0 * per_use / (tool_def.use_time + walk)
	return rate / (1.0 + DEPOSIT_TRIP / speed * rate / 60.0 / pocket)


func _best_rate(owned: Array, stats: Array) -> float:
	var best := 0.0
	for i in world.districts.size():
		var d = world.districts[i]
		if d.permit_id != &"" and not owned.has(d.permit_id):
			continue
		best = maxf(best, _best_in(owned, stats[i]))
	return best


func _best_in(owned: Array, stat: Dictionary) -> float:
	var pocket := BASE_CAPACITY
	var speed := 1.0
	for id in owned:
		var item = shop.find(id)
		if item != null and item.get("effect") == 0:
			pocket += int(item.amount)
		if item != null and item.get("effect") == 2:
			speed += item.amount
	var best := 0.0
	for id in owned:
		var tool_def = _find_tool(id)
		if tool_def != null:
			best = maxf(best, _rate(tool_def, stat.coins / stat.area, pocket, speed))
	return best


func _district_stats() -> Array:
	var result: Array = []
	# Quarteirões de cada bairro: cada um pertence ao primeiro bairro cuja área o contém.
	var counts := []
	counts.resize(world.districts.size())
	counts.fill(0)
	for bx in world.blocks_x:
		for bz in world.blocks_z:
			var index: int = world.districts.size() - 1
			for i in world.districts.size():
				if (world.districts[i].area as Rect2i).has_point(Vector2i(bx, bz)):
					index = i
					break
			counts[index] += 1
	for i in world.districts.size():
		var d = world.districts[i]
		result.append({"blocks": counts[i], "area": counts[i] * world.block_size * world.block_size * FREE_SHARE, "weight": d.density_weight})
	var total_weight := 0.0
	for s in result:
		total_weight += s.area * s.weight
	for s in result:
		s.value = float(world.total_value_cents) * s.area * s.weight / total_weight
	for i in result.size():
		result[i].coins = result[i].value / _mean_value(world.districts[i])
	return result


## Valor médio (centavos) de uma moeda do bairro.
static func _mean_value(d: Resource) -> float:
	var weights: PackedFloat32Array = d.denomination_weights
	var total := 0.0
	var sum := 0.0
	for i in weights.size():
		total += weights[i]
		sum += weights[i] * [1, 5, 10, 25, 50, 100][i]
	return sum / total if total > 0.0 else 1.0


func _find_tool(id: StringName) -> Resource:
	for t in tools.tools:
		if t.id == id:
			return t
	return null


static func _mean_pile(d: Resource) -> float:
	var c: Vector3 = d.pile_chances
	var total := c.x + c.y + c.z
	return (c.x * (d.pile_small.x + d.pile_small.y) + c.y * (d.pile_medium.x + d.pile_medium.y) + c.z * (d.pile_large.x + d.pile_large.y)) * 0.5 / total


static func _group(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out


static func _brl(cents: int) -> String:
	return "R$ %s,%02d" % [_group(cents / 100), cents % 100]


## Vara: cada arremesso escolhe chão cheio a até `reach`, então não há caminhada; o ciclo é
## mirar + voo + atração + recolher (~3/4 do alcance) + pausa.
func _rod_rate(tool_def: Resource, density: float, pocket: int, speed: float) -> float:
	var area: float = PI * tool_def.area_radius * tool_def.area_radius
	var per_use: float = minf(minf(tool_def.capacity, pocket), maxf(density * area, 1.0))
	var flight: float = sqrt(2.0 * tool_def.reach / 14.0)
	var cycle: float = 0.6 + flight + tool_def.area_radius / tool_def.power + tool_def.reach * 0.75 / tool_def.reel_speed + tool_def.use_time
	var rate: float = 60.0 * per_use / cycle
	return rate / (1.0 + DEPOSIT_TRIP / speed * rate / 60.0 / pocket)


## Centavos por moeda no bairro mais rico liberado (onde o jogador e os robôs trabalham).
func _value_per_coin(owned: Array) -> float:
	var value := 1.0
	for d in world.districts:
		if d.permit_id == &"" or owned.has(d.permit_id):
			var weights: PackedFloat32Array = d.denomination_weights
			var total := 0.0
			var sum := 0.0
			for i in weights.size():
				total += weights[i]
				sum += weights[i] * [1, 5, 10, 25, 50, 100][i]
			value = sum / total if total > 0.0 else 1.0
	return value
