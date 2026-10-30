class_name ShopCatalog
extends Resource
## Itens à venda, na ordem em que aparecem na loja.

const DEFAULT_PATH := "res://data/shop/catalog.tres"

static var _default: ShopCatalog

@export var items: Array[ShopItem] = []


## Solta a referência estática (chamado ao encerrar, evita aviso de recurso em uso).
static func release_cache() -> void:
	_default = null


static func get_default() -> ShopCatalog:
	if _default == null:
		_default = load(DEFAULT_PATH)
	return _default


func find(id: StringName) -> ShopItem:
	for item in items:
		if item.id == id:
			return item
	return null
