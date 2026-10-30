extends TestSuite
## Compras pelo GameState (sem cena): dinheiro, propriedade e efeitos imediatos.


func before_all() -> void:
	GameState.reset()


func after_all() -> void:
	GameState.reset()


func _price(id: StringName) -> int:
	return ShopCatalog.get_default().find(id).price_cents


func test_purchase_deducts_exact_price() -> void:
	GameState.reset()
	GameState.ledger.register_found(1000)
	check(GameState.purchase(&"glove"), "compra a luva")
	check_eq(GameState.ledger.money_cents, 1000 - _price(&"glove"), "desconta o preço exato")
	check_eq(GameState.ledger.total_coins_found, 1000, "moedas encontradas intactas")
	check_eq(GameState.ledger.recovered_value_cents(), 1000, "valor recuperado intacto")
	check(GameState.owns(&"glove"), "possui a luva")
	check_eq(GameState.tool_for_group(&"hands").id, &"glove", "luva vira a variante das mãos")


func test_cannot_buy_without_money_or_twice() -> void:
	GameState.reset()
	var price := _price(&"glove")
	GameState.ledger.register_found(price - 1)
	check(not GameState.purchase(&"glove"), "sem dinheiro suficiente")
	check_eq(GameState.ledger.money_cents, price - 1, "saldo intacto")
	check(not GameState.owns(&"glove"), "não ganhou a luva")
	GameState.ledger.register_found(1)
	check(GameState.purchase(&"glove"), "com o valor exato compra")
	check_eq(GameState.ledger.money_cents, 0, "saldo zerado")
	GameState.ledger.register_found(10_000)
	check(not GameState.purchase(&"glove"), "não compra duas vezes")
	check_eq(GameState.ledger.money_cents, 10_000, "segunda tentativa não cobra")


func test_requirements_block_purchase() -> void:
	GameState.reset()
	GameState.ledger.money_cents = 100_000_000
	check(not GameState.purchase(&"big_glove"), "luva grande bloqueada sem luva")
	check(not GameState.purchase(&"magnet_medium"), "ímã médio bloqueado")
	check(not GameState.purchase(&"permit_downtown"), "licença exige dinheiro encontrado")
	check(not GameState.purchase(&"nao_existe"), "item inexistente")
	check_eq(GameState.ledger.money_cents, 100_000_000, "nada cobrado")


func test_effects_apply_immediately() -> void:
	GameState.reset()
	GameState.ledger.register_found(100_000)
	check_eq(GameState.ledger.carry_capacity, GameState.BASE_CARRY_CAPACITY, "bolso inicial")
	GameState.purchase(&"pouch")
	check_eq(GameState.ledger.carry_capacity, 600, "pochete")
	GameState.purchase(&"backpack")
	check_eq(GameState.ledger.carry_capacity, 3600, "mochila")
	GameState.purchase(&"sneakers")
	check_eq(GameState.move_speed_multiplier, 1.25, "tênis +25%")
	var downtown := WorldDefinition.get_default().find_district(&"downtown")
	check(not GameState.is_district_unlocked(downtown), "centro começa fechado")
	check(GameState.purchase(&"permit_downtown"), "compra a licença do centro")
	check(GameState.is_district_unlocked(downtown), "centro liberado")
	var spent := _price(&"pouch") + _price(&"backpack") + _price(&"sneakers") + _price(&"permit_downtown")
	check_eq(GameState.ledger.money_cents, 100_000 - spent, "soma exata dos preços")
	check_eq(GameState.ledger.total_spent_cents, spent, "total gasto")
	check_eq(GameState.ledger.total_coins_found, 100_000, "moedas encontradas intactas")


func test_variant_selection() -> void:
	GameState.reset()
	GameState.ledger.register_found(10_000)
	GameState.purchase(&"glove")
	GameState.purchase(&"big_glove")
	check_eq(GameState.tool_for_group(&"hands").id, &"big_glove", "última compra fica selecionada")
	GameState.select_variant(&"glove")
	check_eq(GameState.tool_for_group(&"hands").id, &"glove", "escolhe a luva")
	GameState.select_variant(&"magnet_large")
	check_eq(GameState.tool_for_group(&"hands").id, &"glove", "não seleciona o que não possui")
	GameState.select_variant(&"hands")
	check_eq(GameState.tool_for_group(&"hands").id, &"hands", "volta às mãos")
