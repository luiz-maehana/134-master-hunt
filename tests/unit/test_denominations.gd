extends TestSuite
## Valores de moeda: tamanhos, sorteio por bairro (determinístico), bolso e depósito com
## valor, e saves de antes dos valores (tudo era de 1 centavo).


func after_all() -> void:
	GameState.reset()


func test_six_values_growing_in_size() -> void:
	check_eq(Denomination.VALUES, [1, 5, 10, 25, 50, 100] as Array[int], "1, 5, 10, 25, 50 centavos e R$ 1")
	for i in range(1, Denomination.count()):
		check(Denomination.SCALES[i] > Denomination.SCALES[i - 1], "%s maior que %s" % [Denomination.NAMES[i], Denomination.NAMES[i - 1]])
	check(is_equal_approx(Denomination.SCALES[-1], 1.0), "R$ 1 tem o tamanho da moeda original")


func test_districts_get_richer() -> void:
	var world := WorldDefinition.get_default()
	var previous := 0.0
	for district in world.districts:
		var average := Denomination.average_value(district.denomination_weights)
		check(average > previous, "%s vale mais por moeda (%.1f centavos)" % [district.display_name, average])
		previous = average
	var start: DistrictDefinition = world.districts[0]
	check(start.denomination_weights[4] == 0.0 and start.denomination_weights[5] == 0.0, "Rua do Começo sem 50 centavos nem R$ 1")
	check(world.districts[-1].denomination_weights[5] > 0.0, "Distrito Industrial tem R$ 1")


func test_roll_is_deterministic_and_follows_weights() -> void:
	var district: DistrictDefinition = WorldDefinition.get_default().districts[-1]
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 134
	b.seed = 134
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 4000:
		var roll := district.roll_denomination(a)
		var again := district.roll_denomination(b)
		if i < 3:
			check_eq(roll, again, "mesma semente, mesmo valor")
		counts[roll] += 1
	var total := 0.0
	for w in district.denomination_weights:
		total += w
	for i in counts.size():
		var expected := 4000.0 * district.denomination_weights[i] / total
		check(absf(counts[i] - expected) < 4000.0 * 0.03, "%s perto do peso (%d de ~%d)" % [Denomination.NAMES[i], counts[i], roundi(expected)])


func test_pocket_and_deposit_carry_value() -> void:
	var ledger := CoinLedger.new()
	ledger.carry_capacity = 100
	check(ledger.add_carried(3, 75), "3 moedas de 25 centavos")
	check(ledger.add_carried(2), "2 de 1 centavo (sem valor informado)")
	check_eq(ledger.carried_coins, 5, "bolso conta moedas")
	check_eq(ledger.carried_value_cents, 77, "e guarda o valor")
	check_eq(ledger.free_capacity(), 95, "capacidade é em moedas, não em valor")
	ledger.deposit_carried()
	check_eq(ledger.total_coins_found, 5, "meta conta 5 moedas")
	check_eq(ledger.money_cents, 77, "dinheiro pelo valor")
	check_eq(ledger.recovered_value_cents(), 77, "valor recuperado")
	check_eq(ledger.carried_value_cents, 0, "bolso zera o valor")


func test_old_save_restarts_with_notice() -> void:
	GameState.reset()
	GameState.apply_save({
		"version": 2, "coins_found": 500, "money_cents": 420,
		"world": {"10,10": {"r": 530, "p": {"0": 3}}},
	})
	check_eq(GameState.ledger.total_coins_found, 0, "save de antes das pilhinhas recomeça")
	check(GameState.pending_notice.contains("134 milhões"), "e avisa: '%s'" % GameState.pending_notice)
	GameState.pending_notice = ""


func test_value_survives_save() -> void:
	GameState.reset()
	GameState.record_world_take(Vector2i(10, 10), 0, 2, 8, 800, 40)
	GameState.ledger.register_found(5, 500)
	GameState.ledger.add_carried(3, 300)
	GameState.apply_save(GameState.to_save())
	check_eq(GameState.world_removed_value, 800, "valor retirado do mundo")
	check_eq(GameState.ledger.total_value_found_cents, 500, "valor encontrado")
	check_eq(GameState.ledger.carried_coins, 3, "bolso pela invariante")
	check_eq(GameState.ledger.carried_value_cents, 300, "valor do bolso pela invariante")
	var data := GameState.to_save()
	check_eq(int(data["world"]["10,10"]["v"]), 800, "save grava o valor por bloco")
	check_eq(int(data["world"]["10,10"]["n"]), 40, "e quantas pilhas o bloco tem")
