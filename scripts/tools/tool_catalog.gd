class_name ToolCatalog
extends Resource
## Lista de todas as ferramentas do jogo. A ordem define a ordem dos atalhos (por grupo)
## e, dentro de um grupo, da variante mais simples para a melhor.

const DEFAULT_PATH := "res://data/tools/catalog.tres"
const GROUP_NAMES := {
	&"hands": "Mãos",
	&"shovel": "Pá",
	&"magnet": "Ímã",
	&"magnet_rod": "Vara com ímã",
}

static var _default: ToolCatalog

@export var tools: Array[ToolDefinition] = []


## Solta a referência estática (chamado ao encerrar, evita aviso de recurso em uso).
static func release_cache() -> void:
	_default = null


## Catálogo do jogo, carregado sob demanda (preload criaria dependência circular
## catálogo -> cenas das ferramentas -> scripts que usam o catálogo).
static func get_default() -> ToolCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


static func group_name(group: StringName) -> String:
	return GROUP_NAMES.get(group, String(group).capitalize())


func find(id: StringName) -> ToolDefinition:
	for definition in tools:
		if definition.id == id:
			return definition
	return null


## Grupos na ordem do catálogo, sem repetição.
func groups() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in tools:
		if not result.has(definition.slot_group):
			result.append(definition.slot_group)
	return result


func variants(group: StringName) -> Array[ToolDefinition]:
	var result: Array[ToolDefinition] = []
	for definition in tools:
		if definition.slot_group == group:
			result.append(definition)
	return result
