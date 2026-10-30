extends TestSuite
## Robôs na loja e no save (sem cena): várias unidades, preço crescente, limite da frota,
## melhorias de velocidade e validação do que vem do arquivo.


func before_all() -> void:
	GameState.reset()


func after_all() -> void:
	GameState.reset()


func _robot(id: StringName) -> RobotDefinition:
	return ShopCatalog.get_default().find(id) as RobotDefinition


func test_price_grows_per_unit() -> void:
	var small := _robot(&"robot_small")
	check_eq(small.price_for(0), small.price_cents, "primeira unidade pelo preço base")
	check_eq(small.price_for(1), roundi(small.price_cents * small.price_growth), "segunda custa mais")
	check(small.price_for(5) > small.price_for(4), "preço sempre sobe")
	var owned: Array[StringName] = [&"hands", &"robot_small", &"robot_small"]
	check_eq(ShopRules.next_price(small, owned), small.price_for(2), "próximo preço conta as unidades possuídas")


func test_fleet_limit() -> void:
	var small := _robot(&"robot_small")
	var owned: Array[StringName] = [&"cart"]
	for i in small.max_count():
		owned.append(small.id)
	check_eq(ShopRules.status(small, owned, 999_999_999, 999_999_999), ShopRules.Status.OWNED, "frota cheia não compra mais")
	owned.pop_back()
	check_eq(ShopRules.status(small, owned, 999_999_999, 999_999_999), ShopRules.Status.AVAILABLE, "abaixo do limite compra")


func test_buying_units_charges_growing_price() -> void:
	GameState.reset()
	GameState.grant(&"cart")
	var small := _robot(&"robot_small")
	GameState.ledger.register_found(small.required_value_cents + small.price_for(0) + small.price_for(1))
	var money := GameState.ledger.money_cents
	check(GameState.purchase(&"robot_small"), "compra o primeiro robô")
	check(GameState.purchase(&"robot_small"), "compra o segundo")
	check_eq(money - GameState.ledger.money_cents, small.price_for(0) + small.price_for(1), "cobrou o preço de cada unidade")
	check_eq(GameState.item_count(&"robot_small"), 2, "duas unidades")
	check_eq(GameState.robots.size(), 2, "dois robôs no mapa")
	check(not (GameState.robots[0].pos as Vector2).is_finite(), "sem cena, robô novo espera a frota dar um lugar")


func test_robot_speed_upgrades_stack() -> void:
	GameState.reset()
	check(is_equal_approx(GameState.robot_speed_multiplier, 1.0), "sem melhorias: 1x")
	GameState.grant(&"robot_batteries")
	check(is_equal_approx(GameState.robot_speed_multiplier, 1.5), "baterias: +50%")
	GameState.grant(&"robot_control")
	check(is_equal_approx(GameState.robot_speed_multiplier, 2.5), "central soma: +100%")


func test_save_keeps_robots_and_validates() -> void:
	GameState.reset()
	GameState.grant(&"robot_small")
	GameState.grant(&"robot_small")
	GameState.move_robot(0, Vector2(12.5, -40.0))
	var data := GameState.to_save()
	GameState.apply_save(data)
	check_eq(GameState.item_count(&"robot_small"), 2, "unidades voltam")
	check_eq(GameState.robots.size(), 2, "robôs voltam")
	check_eq(GameState.robots[0].pos, Vector2(12.5, -40.0), "posição volta")
	# Arquivo adulterado: luva duplicada, robôs demais e posição inválida.
	data["owned"] = ["hands", "glove", "glove", "robot_small"]
	data["robots"] = [["robot_small", "x", 3], ["robot_small", 1.0, 2.0], ["robot_tractor", 0.0, 0.0], 7]
	GameState.apply_save(data)
	check_eq(GameState.item_count(&"glove"), 1, "item único não duplica")
	check_eq(GameState.robots.size(), 1, "só um robô por unidade possuída")
	check(not (GameState.robots[0].pos as Vector2).is_finite(), "posição inválida vira 'sem lugar'")


func test_flashlight_range_uses_best() -> void:
	GameState.reset()
	check_eq(GameState.flashlight_range, 0.0, "sem lanterna, sem luz")
	GameState.grant(&"flashlight")
	var pocket := GameState.flashlight_range
	check(pocket > 0.0, "lanterna de bolso dá luz")
	GameState.grant(&"flashlight_tactical")
	check(GameState.flashlight_range > pocket, "a tática alcança mais")
	var tactical := ShopCatalog.get_default().find(&"flashlight_tactical")
	check(tactical.requires.has(&"flashlight"), "a tática exige a de bolso")
	GameState.reset()


func test_time_of_day_is_saved() -> void:
	GameState.reset()
	GameState.time_of_day = 0.9
	var data := GameState.to_save()
	GameState.reset()
	check_eq(GameState.time_of_day, 0.3, "reset volta para a manhã")
	GameState.apply_save(data)
	check_eq(GameState.time_of_day, 0.9, "hora volta do save")
	data["time_of_day"] = "meia-noite"
	GameState.apply_save(data)
	check_eq(GameState.time_of_day, 0.3, "hora inválida ignorada")
	GameState.time_of_day = 0.75
	check_eq(DayNight.clock_text(), "18:00", "relógio")
	GameState.reset()
