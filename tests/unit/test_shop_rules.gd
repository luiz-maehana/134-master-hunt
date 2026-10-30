extends TestSuite
## Regras puras da loja e dos efeitos, com os dados reais de data/.

var shop: ShopCatalog
var tools: ToolCatalog


func before_all() -> void:
	shop = ShopCatalog.get_default()
	tools = ToolCatalog.get_default()


func _upgrades(ids: Array) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for id in ids:
		result.append(shop.find(id) as UpgradeDefinition)
	return result


func test_every_item_is_complete() -> void:
	var ids := {}
	var last_price := 0
	var sorted := true
	for item in shop.items:
		check(item.id != &"" and item.display_name != "" and item.description != "", "%s tem id, nome e descrição" % item.id)
		check(item.price_cents > 0, "%s tem preço" % item.id)
		check(item.effect_summary() != "", "%s tem efeito mensurável" % item.id)
		check(not ids.has(item.id), "%s é único" % item.id)
		ids[item.id] = true
		if item.price_cents < last_price:
			sorted = false
		last_price = item.price_cents
		for requirement in item.requires:
			check(tools.find(requirement) != null or shop.find(requirement) != null, "%s: requisito %s existe" % [item.id, requirement])
	check(sorted, "loja em ordem de preço")


func test_status() -> void:
	var glove := shop.find(&"glove")
	var big_glove := shop.find(&"big_glove")
	var owned: Array[StringName] = [&"hands"]
	check_eq(ShopRules.status(glove, owned, glove.price_cents - 1), ShopRules.Status.TOO_EXPENSIVE, "1 centavo a menos")
	check_eq(ShopRules.status(glove, owned, glove.price_cents), ShopRules.Status.AVAILABLE, "preço exato")
	check_eq(ShopRules.status(big_glove, owned, 100_000), ShopRules.Status.LOCKED, "luva grande exige luva")
	check_eq(ShopRules.missing_requirements(big_glove, owned), [&"glove"] as Array[StringName], "falta a luva")
	owned.append(&"glove")
	check_eq(ShopRules.status(glove, owned, 100_000), ShopRules.Status.OWNED, "já possui")
	check_eq(ShopRules.status(big_glove, owned, 100_000), ShopRules.Status.AVAILABLE, "desbloqueada")
	check_eq(ShopRules.status(tools.find(&"hands"), owned, 100_000), ShopRules.Status.OWNED, "mãos já vêm com você")


func test_value_found_requirement() -> void:
	var medium := shop.find(&"magnet_medium")
	var owned: Array[StringName] = [&"hands", &"magnet_small"]
	check_eq(ShopRules.status(medium, owned, 100_000_000, medium.required_value_cents - 1), ShopRules.Status.LOCKED, "1 centavo a menos do requisito")
	check_eq(ShopRules.status(medium, owned, 100_000_000, medium.required_value_cents), ShopRules.Status.AVAILABLE, "requisito exato libera")
	check_eq(ShopRules.status(medium, [&"hands"] as Array[StringName], 100_000_000, 100_000_000), ShopRules.Status.LOCKED, "ainda exige o ímã pequeno")


func test_permits_open_every_district() -> void:
	var world := WorldDefinition.get_default()
	var last_requirement := -1
	for district in world.districts:
		if district.permit_id == &"":
			check(district == world.districts[0], "só o primeiro bairro é livre")
			continue
		var permit := shop.find(district.permit_id) as UpgradeDefinition
		check(permit != null and permit.effect == UpgradeDefinition.Effect.UNLOCK_DISTRICT and permit.district_id == district.id, "licença de %s" % district.id)
		if permit != null:
			check(permit.required_value_cents > last_requirement, "%s pede mais progresso que o anterior" % district.id)
			last_requirement = permit.required_value_cents


func test_carry_and_speed_effects() -> void:
	check_eq(ShopRules.carry_capacity(100, _upgrades([])), 100, "base")
	check_eq(ShopRules.carry_capacity(100, _upgrades([&"pouch", &"backpack", &"cart"])), 33_600, "pochete+mochila+carrinho")
	check_eq(ShopRules.move_speed_multiplier(_upgrades([&"sneakers"])), 1.25, "tênis +25%")
	check_eq(ShopRules.move_speed_multiplier(_upgrades([&"pouch"])), 1.0, "pochete não muda velocidade")


func test_tool_bonus_and_minimum_use_time() -> void:
	var faster := UpgradeDefinition.new()
	faster.effect = UpgradeDefinition.Effect.TOOL_STATS
	faster.tool_group = &"hands"
	faster.tool_stat_bonus = {"use_time": -10.0, "capacity": 4}
	var hands := tools.find(&"hands")
	var result := ShopRules.apply_tool_bonuses(hands, [faster] as Array[UpgradeDefinition])
	check_eq(result.use_time, ShopRules.MIN_USE_TIME, "tempo mínimo respeitado")
	check_eq(result.capacity, hands.capacity + 4, "bônus de capacidade")
	check_eq(hands.capacity, 1, "definição original intacta")
	var magnet := ShopRules.apply_tool_bonuses(tools.find(&"magnet_small"), [faster] as Array[UpgradeDefinition])
	check_eq(magnet.capacity, tools.find(&"magnet_small").capacity, "bônus das mãos não afeta o ímã")


func test_tool_tiers_scale_up() -> void:
	for group in [&"hands", &"shovel", &"magnet"]:
		var variants := tools.variants(group)
		# O ímã tem uma 4ª versão, a passiva (neodímio).
		check(variants.size() == (4 if group == &"magnet" else 3), "%s: número de versões" % group)
		for i in range(1, variants.size()):
			# O passivo puxa menos por vez, mas várias vezes por segundo: compara moedas por segundo.
			var more: bool = variants[i].capacity / variants[i].use_time > variants[i - 1].capacity / variants[i - 1].use_time 				if variants[i].passive else variants[i].capacity > variants[i - 1].capacity
			check(more, "%s: %s pega mais que %s" % [group, variants[i].id, variants[i - 1].id])
			check(variants[i].price_cents > variants[i - 1].price_cents, "%s: %s custa mais" % [group, variants[i].id])
	var magnets := tools.variants(&"magnet")
	check(magnets[0].reach < magnets[1].reach and magnets[1].reach < magnets[2].reach, "alcance do ímã cresce")
	check(magnets[2].capacity >= magnets[1].capacity * 2, "ímã grande é uma evolução significativa")
	check(magnets[3].passive and magnets[3].reach > magnets[2].reach, "neodímio: passivo e com alcance maior que o grande")
	var shovels := tools.variants(&"shovel")
	check(shovels[0].area_radius < shovels[1].area_radius and shovels[1].area_radius < shovels[2].area_radius, "área da pá cresce")
	check(shovels[0].reach < magnets[0].reach, "pá é de perto, ímã é de longe")
