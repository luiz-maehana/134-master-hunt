class_name RobotDefinition
extends ShopItem
## Equipamento de coleta automática (robô, trator, caminhão). Cada unidade comprada vira um
## robô no mapa que recolhe as moedas ao redor de onde foi posicionado e deposita sozinho.
## Pode-se ter várias unidades; cada nova custa `price_growth` vezes a anterior.

## Moedas recolhidas por segundo (antes das melhorias).
@export var rate := 10.0
## Raio de trabalho ao redor do ponto onde foi posicionado (m).
@export var radius := 10.0
@export var units := 1
@export var price_growth := 1.25
## Visual: cor da carroceria, escala e velocidade com que anda até as pilhas.
@export var body_color := Color(1.0, 0.75, 0.15)
@export var visual_scale := 1.0
@export var move_speed := 2.0


func max_count() -> int:
	return units


func price_for(owned_count: int) -> int:
	return roundi(price_cents * pow(price_growth, owned_count))


func effect_summary() -> String:
	return "Recolhe %s moedas/s num raio de %s m e deposita sozinho · até %d %s" % [
		MoneyFormat.group(roundi(rate)), MoneyFormat.decimal(radius, 0), units, "unidade" if units == 1 else "unidades"]
