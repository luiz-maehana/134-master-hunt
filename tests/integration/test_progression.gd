extends TestSuite
## Integração da loja e das telas com a cidade real: banca, compras pelo botão, luva,
## capacidade, inventário, barra de ferramentas, configurações e convivência entre telas.

const MAIN_SCENE := "res://scenes/main.tscn"

var main: Node3D
var player: CharacterBody3D
var head: Node3D
var tool_user: ToolUser
var interactor: Interactor
var layout: CityLayout
var shop: MenuScreen
var inventory: MenuScreen
var pause_menu: CanvasLayer


func before_all() -> void:
	GameState.reset()
	main = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	player = main.get_node("Player")
	head = player.get_node("Head")
	tool_user = player.get_node("Head/Camera3D/ToolHolder")
	interactor = player.get_node("Head/Camera3D/Interactor")
	layout = (main.get_node("City") as CityBuilder).layout
	shop = main.get_node("ShopMenu")
	inventory = main.get_node("InventoryMenu")
	pause_menu = main.get_node("PauseMenu")
	await physics_frames(10)


func after_all() -> void:
	GameState.set_screen_open(false)
	main.queue_free()
	await process_frames(2)
	GameState.reset()


func test_kiosk_opens_shop_and_button_buys() -> void:
	var glove_price := ShopCatalog.get_default().find(&"glove").price_cents
	GameState.ledger.register_found(glove_price)
	var kiosk: Vector3 = layout.hubs[0].kiosk
	_place(kiosk + Vector3(0, 0.05, -2.2))
	_aim_at(kiosk + Vector3(0, 0.6, -0.3))
	await physics_frames(3)
	check(interactor.current != null and interactor.current.prompt_text.contains("loja"), "mira na banca")
	interactor.try_interact()
	check(shop.is_open() and GameState.screen_open and not tree.paused, "loja aberta, jogo continua rodando")
	var for_sale := 0
	for item in ShopCatalog.get_default().items:
		if not GameState.owns(item.id):
			for_sale += 1
	var owned_section := 1 if for_sale < ShopCatalog.get_default().items.size() else 0
	check_eq(_rows(shop), for_sale + owned_section, "uma linha por item à venda + seção de comprados")
	var buy := _button_starting_with(shop, "Comprar")
	check(buy != null, "luva disponível para compra")
	if buy != null:
		buy.pressed.emit()
	await process_frames(2)
	check(GameState.owns(&"glove"), "comprou pelo botão")
	check_eq(GameState.ledger.money_cents, 0, "pagou o preço exato")
	check(_button_starting_with(shop, "Comprado") == null, "comprados ficam recolhidos")
	var section := _button_starting_with(shop, "▶ Já comprados")
	check(section != null, "seção de comprados no fim")
	if section != null:
		section.pressed.emit()
		await process_frames(1)
	check(_button_starting_with(shop, "Comprado") != null, "aberta, a seção mostra 'Comprado'")
	check(_button_starting_with(shop, "Comprar") == null, "sem dinheiro, nada mais disponível")
	var text := _all_text(shop)
	check(text.contains("encontrados (você tem"), "itens bloqueados mostram o requisito em reais")
	shop.close()
	check(not shop.is_open() and not GameState.screen_open, "loja fecha e o controle volta")


func test_glove_is_equipped_and_in_hotbar() -> void:
	check_eq(tool_user.equipped_definition().id, &"glove", "luva equipada após a compra")
	var hotbar: ToolHotbar = main.get_node("HUD").get_node("%Hotbar")
	await process_frames(1)
	var active := hotbar.active_slot()
	check(active != null and active.get_meta("tool_id") == &"glove", "barra destaca a luva")
	check(tool_user.equipped_definition().capacity > ToolCatalog.get_default().find(&"hands").capacity, "luva pega mais por vez")


func test_capacity_and_speed_upgrades() -> void:
	GameState.ledger.register_found(1000)
	var walk_before: float = player.get("walk_speed")
	check(GameState.purchase(&"sneakers"), "compra tênis")
	check(is_equal_approx(player.get("walk_speed"), walk_before * 1.25), "anda 25% mais rápido")
	check(GameState.purchase(&"pouch"), "compra pochete")
	check_eq(GameState.ledger.carry_capacity, 600, "bolso maior na hora")
	var pocket: Label = main.get_node("HUD").get_node("%Pocket")
	check(pocket.text.contains("/ 600"), "HUD mostra a capacidade: '%s'" % pocket.text)


func test_hotbar_follows_slots() -> void:
	GameState.grant(&"shovel_small")
	var hotbar: ToolHotbar = main.get_node("HUD").get_node("%Hotbar")
	await process_frames(1)
	check_eq(hotbar.get_child_count(), tool_user.slot_groups().size(), "uma caixa por tipo de ferramenta")
	tool_user.equip_group(&"shovel")
	await process_frames(1)
	check_eq(hotbar.active_slot().get_meta("tool_id"), &"shovel_small", "pá destacada")
	tool_user.equip_group(&"hands")
	await process_frames(1)
	check_eq(hotbar.active_slot().get_meta("tool_id"), GameState.tool_for_group(&"hands").id, "variante das mãos destacada")
	var actives := 0
	for slot in hotbar.get_children():
		if slot.get_meta("active", false):
			actives += 1
	check_eq(actives, 1, "só uma caixa ativa")


func test_inventory_lists_and_equips() -> void:
	check(inventory.open(), "Tab abre o inventário")
	check(GameState.screen_open and not tree.paused, "tela aberta, jogo continua")
	var text := _all_text(inventory)
	for name in ["Mãos vazias", "Luva de trabalho", "Pá pequena", "Pochete", "Tênis de corrida"]:
		check(text.contains(name), "lista %s" % name)
	var equip := _button_starting_with(inventory, "Equipar")
	check(equip != null, "há variante para equipar")
	if equip != null:
		equip.pressed.emit()
	await process_frames(2)
	check(_button_starting_with(inventory, "Equipada") != null, "uma ferramenta marcada como equipada")
	inventory.close()
	check(not GameState.screen_open, "fecha e volta ao jogo")


func test_display_settings() -> void:
	var start_msaa := Settings.msaa_index
	Settings.set_msaa_index(3)
	check_eq(tree.root.msaa_3d, Viewport.MSAA_8X, "antialiasing aplicado")
	Settings.set_msaa_index(99)
	check_eq(Settings.msaa_index, Settings.MSAA_OPTIONS.size() - 1, "índice fora da faixa é limitado")
	Settings.set_msaa_index(start_msaa)
	var full := Settings.fullscreen
	pause_menu.set_paused(true)
	var checkbox: CheckButton = pause_menu.get_node("%Tabs").get_node("%Fullscreen")
	checkbox.button_pressed = not full
	check_eq(Settings.fullscreen, not full, "caixa 'Tela cheia' muda a preferência")
	var f11 := InputEventAction.new()
	f11.action = &"toggle_fullscreen"
	f11.pressed = true
	tree.root.push_input(f11)
	await process_frames(1)
	check_eq(Settings.fullscreen, full, "F11 alterna (mesmo pausado)")
	check_eq(checkbox.button_pressed, full, "menu acompanha o F11")
	pause_menu.set_paused(false)


func test_esc_closes_screen_instead_of_pausing() -> void:
	shop.open()
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	tree.root.push_input(esc)
	await process_frames(2)
	check(not shop.is_open(), "Esc fecha a loja")
	# O menu ainda pode estar esmaecendo do teste anterior: o que vale é o estado de aberto.
	check(not pause_menu.get("_paused"), "e não abre o menu por cima")
	pause_menu.set_paused(true)
	check(not inventory.open(), "inventário não abre com o menu aberto")
	pause_menu.set_paused(false)


func test_credits_screen() -> void:
	pause_menu.set_paused(true)
	var button: Button = null
	for child in pause_menu.find_children("*", "Button", true, false):
		if (child as Button).text == "Créditos":
			button = child
	check(button != null, "menu tem o botão Créditos")
	button.pressed.emit()
	await process_frames(2)
	var credits := pause_menu.find_children("*", "CreditsScreen", true, false)
	check_eq(credits.size(), 1, "créditos abrem por cima do menu")
	var text := ""
	for label in credits[0].find_children("*", "Label", true, false):
		text += (label as Label).text + "
"
	check(text.contains("Poly by Google") and text.contains("CC BY 3.0") and text.contains("Fredoka"), "créditos com as atribuições CC BY e a fonte")
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	tree.root.push_input(esc)
	await tree.create_timer(0.3).timeout
	check(pause_menu.find_children("*", "CreditsScreen", true, false).is_empty(), "Esc fecha os créditos")
	check(pause_menu.get("_paused"), "e o menu continua aberto")
	pause_menu.set_paused(false)


func test_story_before_new_game() -> void:
	pause_menu.set_paused(true)
	var found := GameState.ledger.total_coins_found
	var button: Button = pause_menu.get("_new_game")
	button.pressed.emit()
	button.pressed.emit()
	await process_frames(2)
	var stories := pause_menu.find_children("*", "StoryScreen", true, false)
	check_eq(stories.size(), 1, "recomeçar mostra a história antes")
	var text := ""
	for label in stories[0].find_children("*", "Label", true, false):
		text += (label as Label).text
	check(text.contains("134") and text.contains("moedas") and text.contains("ficção"), "a história fala das moedas e avisa que é ficção")
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	tree.root.push_input(esc)
	await tree.create_timer(0.3).timeout
	check(pause_menu.find_children("*", "StoryScreen", true, false).is_empty(), "Esc (Voltar) fecha a história")
	check_eq(GameState.ledger.total_coins_found, found, "e não apaga o progresso")
	check(pause_menu.get("_paused"), "e o menu continua aberto")
	# Continuar avisa uma vez só (Continuar e Voltar não valem os dois).
	var story := StoryScreen.open(tree.root)
	var accepted := [0]
	story.accepted.connect(func() -> void: accepted[0] += 1)
	var continue_button: Button = story.get("_continue")
	continue_button.pressed.emit()
	continue_button.pressed.emit()
	story.close()
	check_eq(accepted[0], 1, "Continuar começa a partida uma vez")
	pause_menu.set_paused(false)
	pause_menu.set_paused(false)


func _rows(menu: MenuScreen) -> int:
	return menu.items_box.get_child_count()


func _button_starting_with(menu: MenuScreen, prefix: String) -> Button:
	for button in menu.items_box.find_children("*", "Button", true, false):
		if (button as Button).text.begins_with(prefix):
			return button
	return null


func _all_text(menu: MenuScreen) -> String:
	var parts := PackedStringArray()
	for label in menu.items_box.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return "\n".join(parts)


func _place(pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	head.rotation.x = 0.0


func _aim_at(target: Vector3) -> void:
	var to := target - head.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
