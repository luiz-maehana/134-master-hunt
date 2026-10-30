class_name ToolDefinition
extends ShopItem
## Dados de uma ferramenta. Preço e desempenho ficam aqui (data/tools/), não no código.
## Versões de uma mesma ferramenta (mãos/luva/luva grande) reutilizam a mesma cena de
## comportamento com números diferentes e compartilham um `slot_group` (atalho).

enum Kind { HANDS, SHOVEL, MAGNET, MAGNET_ROD }

const STAT_LABELS := {
	&"use_time": "tempo de uso",
	&"reach": "alcance",
	&"area_radius": "área",
	&"capacity": "moedas por uso",
	&"power": "força",
	&"reel_speed": "recolhimento",
}

@export var kind: Kind = Kind.HANDS
## Grupo do atalho: variantes do mesmo grupo ocupam a mesma tecla.
@export var slot_group: StringName
## Distância de uso, em metros (na vara: distância máxima de arremesso).
@export var reach := 2.0
## Duração de um uso (animação + recarga), em segundos.
@export var use_time := 0.5
## Raio da área afetada, em metros.
@export var area_radius := 0.2
## Máximo de moedas por uso.
@export var capacity := 1
## Ímãs: intensidade da atração (velocidade das moedas até o ímã, m/s).
@export var power := 1.0
## Vara com ímã: velocidade de recolhimento da linha (m/s).
@export var reel_speed := 0.0
## Ímã passivo (neodímio): enquanto equipado, atrai sozinho, em volta toda, a cada `use_time`.
@export var passive := false
## Cena com visual e comportamento (raiz com script que estende GameTool).
@export var scene: PackedScene
## Variação visual (ex.: cor da luva) e escala do modelo na mão.
@export var tint := Color.WHITE
@export var visual_scale := 1.0
## Usa o modelo "reforçado" da cena, quando ela tem um (pás média e grande).
@export var upgraded_model := false


func effect_summary() -> String:
	match kind:
		Kind.HANDS:
			var per_use := "1 moeda por vez" if capacity == 1 else "até %s moedas por vez" % MoneyFormat.group(capacity)
			return "%s · %s s por coleta · alcance %s m" % [
				per_use, MoneyFormat.decimal(use_time), MoneyFormat.decimal(reach, 1)]
		Kind.SHOVEL:
			return "Recolhe até %s moedas por pazada · área %s m · %s s" % [
				MoneyFormat.group(capacity), MoneyFormat.decimal(area_radius, 1), MoneyFormat.decimal(use_time)]
		Kind.MAGNET:
			if passive:
				return "Atrai sozinho, sem clicar: até %s moedas a cada %s s, em volta toda, a %s m · velocidade %s m/s" % [
					MoneyFormat.group(capacity), MoneyFormat.decimal(use_time, 1), MoneyFormat.decimal(reach, 1), MoneyFormat.decimal(power, 1)]
			return "Atrai até %s moedas a %s m · velocidade %s m/s · recarga %s s" % [
				MoneyFormat.group(capacity), MoneyFormat.decimal(reach, 1), MoneyFormat.decimal(power, 1), MoneyFormat.decimal(use_time, 1)]
		Kind.MAGNET_ROD:
			return "Arremessa até %s m · atrai até %s moedas num raio de %s m · atração %s m/s · recolhe a %s m/s" % [
				MoneyFormat.decimal(reach, 0), MoneyFormat.group(capacity), MoneyFormat.decimal(area_radius, 1),
				MoneyFormat.decimal(power, 1), MoneyFormat.decimal(reel_speed, 0)]
	return ""
