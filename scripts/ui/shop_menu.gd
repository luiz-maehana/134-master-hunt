extends MenuScreen
## Loja: lista os itens de data/shop/catalog.tres com preço, efeito, requisitos e estado.
## Ordem: à venda, falta dinheiro, bloqueados; o que já foi comprado fica numa seção recolhida
## no fim, e ferramentas piores que uma já possuída (mesmo grupo) deixam de ser oferecidas.

const COLOR_EFFECT := Color(0.55, 0.95, 0.55)
const COLOR_INFO := Color(0.75, 0.75, 0.75)
const COLOR_WARN := Color(1, 0.6, 0.4)
## Ordem das seções por estado.
const ORDER := [ShopRules.Status.AVAILABLE, ShopRules.Status.TOO_EXPENSIVE, ShopRules.Status.LOCKED, ShopRules.Status.NOT_FOR_SALE]

var _show_owned := false


func _ready() -> void:
	close_action = &"interact"
	close_noun = "a loja"
	super()
	GameState.shop_requested.connect(open)


func refresh() -> void:
	super()
	summary_label.text = "Tudo é pago com o dinheiro das moedas depositadas. Gastar não diminui o que você já encontrou para a meta."
	clear_items()
	var ledger := GameState.ledger
	var by_status := {}
	for item in ShopCatalog.get_default().items:
		if _is_obsolete(item):
			continue
		var status := ShopRules.status(item, GameState.owned_items, ledger.money_cents, ledger.total_value_found_cents)
		if not by_status.has(status):
			by_status[status] = []
		by_status[status].append(item)
	for status in ORDER:
		for item: ShopItem in by_status.get(status, []):
			_add_item(item, status)
	var owned: Array = by_status.get(ShopRules.Status.OWNED, [])
	if owned.is_empty():
		return
	var toggle := Button.new()
	toggle.text = ("▼ Já comprados (%d)" if _show_owned else "▶ Já comprados (%d)") % owned.size()
	toggle.theme_type_variation = &"KeyButton"
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.pressed.connect(func() -> void:
		_show_owned = not _show_owned
		refresh())
	items_box.add_child(toggle)
	if _show_owned:
		for item: ShopItem in owned:
			_add_item(item, ShopRules.Status.OWNED)


## Ferramenta não possuída pior (mais barata) que outra do mesmo grupo que o jogador já tem.
static func _is_obsolete(item: ShopItem) -> bool:
	if not item is ToolDefinition or GameState.owns(item.id):
		return false
	for other in ToolCatalog.get_default().variants((item as ToolDefinition).slot_group):
		if other != item and GameState.owns(other.id) and other.price_cents > item.price_cents:
			return true
	return false


func _add_item(item: ShopItem, status: ShopRules.Status) -> void:
	var ledger := GameState.ledger
	var price := ShopRules.next_price(item, GameState.owned_items)
	var lines := [[item.description, COLOR_INFO], [item.effect_summary(), COLOR_EFFECT]]
	if item.max_count() > 1:
		lines.append(["Você tem %d de %d · cada unidade nova custa mais" % [GameState.item_count(item.id), item.max_count()], COLOR_INFO])
	var button_text := ""
	match status:
		ShopRules.Status.OWNED:
			button_text = "Comprado" if item.max_count() == 1 else "Frota completa"
		ShopRules.Status.LOCKED:
			var missing := ShopRules.missing_requirements(item, GameState.owned_items)
			if not missing.is_empty():
				lines.append(["Requer: %s" % _names(missing), COLOR_WARN])
			if ledger.total_value_found_cents < item.required_value_cents:
				lines.append(["Requer %s encontrados (você tem %s)" % [
					MoneyFormat.brl(item.required_value_cents), MoneyFormat.brl(ledger.total_value_found_cents)], COLOR_WARN])
			button_text = "Bloqueado"
		ShopRules.Status.TOO_EXPENSIVE:
			lines.append(["Faltam %s" % MoneyFormat.brl(price - ledger.money_cents), COLOR_WARN])
			button_text = MoneyFormat.brl(price)
		ShopRules.Status.AVAILABLE:
			button_text = "Comprar · %s" % MoneyFormat.brl(price)
	var button := make_row(item.display_name, lines, button_text,
		status == ShopRules.Status.AVAILABLE, status == ShopRules.Status.OWNED, ItemIcons.of(item.id))
	if button != null and status == ShopRules.Status.AVAILABLE:
		button.pressed.connect(_buy.bind(item.id))


## Compra e já mostra o resultado (as outras mudanças esperam o intervalo de atualização).
func _buy(id: StringName) -> void:
	if not GameState.purchase(id):
		Sfx.play(&"ui_error", 0.0, -8.0)
	refresh()


static func _names(ids: Array[StringName]) -> String:
	var names := PackedStringArray()
	for id in ids:
		var tool_def := ToolCatalog.get_default().find(id)
		var item: ShopItem = tool_def if tool_def != null else ShopCatalog.get_default().find(id)
		names.append(item.display_name if item != null else String(id))
	return ", ".join(names)
