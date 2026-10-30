class_name ShopRules
extends RefCounted
## Regras puras de compra e de efeitos das melhorias (sem nós), testáveis isoladamente.

enum Status { OWNED, AVAILABLE, LOCKED, TOO_EXPENSIVE, NOT_FOR_SALE }

## Tempo de uso mínimo, para nenhuma combinação de melhorias zerar a animação.
const MIN_USE_TIME := 0.1


## OWNED = já tem todas as unidades possíveis (uma, para quase tudo).
static func status(item: ShopItem, owned: Array[StringName], money_cents: int, value_found := 0) -> Status:
	var count := owned.count(item.id)
	if count >= item.max_count():
		return Status.OWNED
	if item.price_cents <= 0:
		return Status.NOT_FOR_SALE
	if not missing_requirements(item, owned).is_empty() or value_found < item.required_value_cents:
		return Status.LOCKED
	if money_cents < item.price_for(count):
		return Status.TOO_EXPENSIVE
	return Status.AVAILABLE


## Preço da próxima unidade para quem possui `owned`.
static func next_price(item: ShopItem, owned: Array[StringName]) -> int:
	return item.price_for(owned.count(item.id))


static func robot_speed_multiplier(upgrades: Array[UpgradeDefinition]) -> float:
	var multiplier := 1.0
	for upgrade in upgrades:
		if upgrade.effect == UpgradeDefinition.Effect.ROBOT_SPEED:
			multiplier += upgrade.amount
	return multiplier


static func missing_requirements(item: ShopItem, owned: Array[StringName]) -> Array[StringName]:
	var missing: Array[StringName] = []
	for requirement in item.requires:
		if not owned.has(requirement):
			missing.append(requirement)
	return missing


static func carry_capacity(base: int, upgrades: Array[UpgradeDefinition]) -> int:
	var capacity := base
	for upgrade in upgrades:
		if upgrade.effect == UpgradeDefinition.Effect.CARRY_CAPACITY:
			capacity += int(upgrade.amount)
	return capacity


static func move_speed_multiplier(upgrades: Array[UpgradeDefinition]) -> float:
	var multiplier := 1.0
	for upgrade in upgrades:
		if upgrade.effect == UpgradeDefinition.Effect.MOVE_SPEED:
			multiplier += upgrade.amount
	return multiplier


## Alcance (m) da melhor lanterna possuída; 0 = sem lanterna.
static func flashlight_range(upgrades: Array[UpgradeDefinition]) -> float:
	var best := 0.0
	for upgrade in upgrades:
		if upgrade.effect == UpgradeDefinition.Effect.FLASHLIGHT:
			best = maxf(best, upgrade.amount)
	return best


## Cópia da ferramenta com os bônus das melhorias do seu grupo. O original não muda.
static func apply_tool_bonuses(definition: ToolDefinition, upgrades: Array[UpgradeDefinition]) -> ToolDefinition:
	var effective: ToolDefinition = definition.duplicate()
	for upgrade in upgrades:
		if upgrade.effect != UpgradeDefinition.Effect.TOOL_STATS or upgrade.tool_group != definition.slot_group:
			continue
		for stat in upgrade.tool_stat_bonus:
			var key := StringName(stat)
			if not ToolDefinition.STAT_LABELS.has(key):
				continue
			var bonus: float = upgrade.tool_stat_bonus[stat]
			if key == &"capacity":
				effective.capacity = maxi(effective.capacity + int(bonus), 1)
			else:
				effective.set(key, float(effective.get(key)) + bonus)
	effective.use_time = maxf(effective.use_time, MIN_USE_TIME)
	return effective
