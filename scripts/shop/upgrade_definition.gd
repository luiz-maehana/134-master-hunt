class_name UpgradeDefinition
extends ShopItem
## Melhoria permanente comprada na loja. Valores configuráveis em data/shop/.

enum Effect { CARRY_CAPACITY, TOOL_STATS, MOVE_SPEED, UNLOCK_DISTRICT, ROBOT_SPEED, FLASHLIGHT, PORTALS }

@export var effect: Effect = Effect.CARRY_CAPACITY
## CARRY_CAPACITY: moedas a mais no bolso. MOVE_SPEED e ROBOT_SPEED: fração (0.15 = +15%).
## FLASHLIGHT: alcance da luz, em metros (vale a melhor lanterna possuída).
## PORTALS: liga os portais ao lado das lojas (viajar entre elas). Sem `amount`.
@export var amount := 0.0
## TOOL_STATS: grupo de ferramenta afetado e acréscimo por atributo
## (chaves de ToolDefinition.STAT_LABELS; ex.: {"power": 0.5}).
@export var tool_group: StringName
@export var tool_stat_bonus := {}
## UNLOCK_DISTRICT: bairro liberado (WorldDefinition.districts[].permit_id aponta para este item).
@export var district_id: StringName


func effect_summary() -> String:
	match effect:
		Effect.CARRY_CAPACITY:
			return "Capacidade de transporte +%s moedas" % MoneyFormat.group(int(amount))
		Effect.MOVE_SPEED:
			return "Velocidade de movimento +%d%%" % roundi(amount * 100.0)
		Effect.ROBOT_SPEED:
			return "Todos os robôs recolhem %d%% mais rápido" % roundi(amount * 100.0)
		Effect.FLASHLIGHT:
			return "Luz de %d m à noite (tecla %s liga e desliga)" % [roundi(amount), InputBindings.label_of(&"flashlight")]
		Effect.PORTALS:
			return "Liga os portais ao lado das lojas: viaje para qualquer loja dos bairros liberados"
		Effect.UNLOCK_DISTRICT:
			var district := WorldDefinition.get_default().find_district(district_id)
			return "Libera o bairro %s (abre a cerca)" % (district.display_name if district != null else String(district_id))
		Effect.TOOL_STATS:
			var parts := PackedStringArray()
			for stat: StringName in tool_stat_bonus:
				var bonus: float = tool_stat_bonus[stat]
				var label: String = ToolDefinition.STAT_LABELS.get(StringName(stat), String(stat))
				var value := str(int(bonus)) if stat == &"capacity" else MoneyFormat.decimal(absf(bonus), 2)
				parts.append("%s %s%s" % [label, "+" if bonus >= 0.0 else "-", value])
			return "%s: %s" % [ToolCatalog.group_name(tool_group), ", ".join(parts)]
	return ""
