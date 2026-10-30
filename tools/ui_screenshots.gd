extends SceneTree
## Capturas de todas as telas (capa, créditos, história, HUD, loja, inventário, mapa, menu, HUD mínimo) em várias resoluções,
## para revisar a interface. Precisa de placa de vídeo:
##   godot --path . --script res://tools/ui_screenshots.gd -- <pasta de saída> [LxA ...]
## Sem resoluções, usa as 7 da spec. Não toca no save nem nas preferências do jogador.

const DEFAULT_RESOLUTIONS := ["1024x768", "1280x720", "1366x768", "1920x1080", "1920x1200", "2560x1080", "3840x2160"]

var _out := ""
var _tag := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else OS.get_user_data_dir().path_join("ui_screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	var resolutions: Array = args.slice(1) if args.size() > 1 else DEFAULT_RESOLUTIONS
	var state := root.get_node("GameState")
	state.set("save_enabled", false)
	root.get_node("Settings").set("save_enabled", false)
	for resolution: String in resolutions:
		var parts := resolution.trim_suffix("_noite").split("x")
		root.size = Vector2i(int(parts[0]), int(parts[1]))
		_tag = resolution
		await _capture_all(state)
	print("Capturas salvas em %s" % _out)
	quit()


func _capture_all(state: Node) -> void:
	state.call("reset")
	var title: Node = load("res://scenes/ui/title_screen.tscn").instantiate()
	root.add_child(title)
	title.call("skip_intro")
	state.get("ledger").call("register_found", 25000, 1234567)
	title.call("_refresh")
	await _shot("1_titulo")
	title.call("_show_credits")
	await _shot("1b_creditos", 60)
	for credits in title.find_children("*", "CreditsScreen", true, false):
		credits.free()
	var story: Node = load("res://scripts/ui/story_screen.gd").call("open", title)
	story.call("skip")
	await _shot("1c_historia", 30)
	title.free()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await physics_frame
	# Espera a tela de carregamento sumir (as moedas entram aos poucos com janela).
	while root.get_node_or_null(^"GameState").get("screen_open"):
		await process_frame
	for i in 30:
		await process_frame
	for id in ["glove", "magnet_small", "shovel_small", "magnet_rod_medium", "pouch", "backpack",
			"sneakers", "cart", "flashlight", "robot_small", "robot_small"]:
		state.call("grant", StringName(id))
	state.call("add_carried", 60, 400)
	if _tag.ends_with("_noite"):
		state.set("time_of_day", 0.95)
	state.call("notify", "Depositou 60 moedas: +R$ 4,00")
	await _shot("2_hud", 30)
	for screen: Array in [["ShopMenu", "3_loja"], ["InventoryMenu", "4_inventario"], ["MapMenu", "5_mapa"]]:
		var menu: Node = main.get_node(screen[0])
		menu.call("open")
		await _shot(screen[1])
		menu.call("close")
	main.get_node("PauseMenu").call("set_paused", true)
	await _shot("6_menu")
	main.get_node("PauseMenu").call("set_paused", false)
	var settings := root.get_node("Settings")
	settings.call("set_hud_minimal", true)
	await _shot("7_hud_minimo")
	settings.call("set_hud_minimal", false)
	main.free()
	await process_frame


func _shot(name: String, frames := 12) -> void:
	for i in frames:
		await process_frame
	# As telas esmaecem ao abrir (ScreenTransition.OPEN_SECONDS; o nome da classe aqui
	# compilaria antes dos autoloads, que ela usa).
	await create_timer(0.25).timeout
	var image := root.get_texture().get_image()
	var width := mini(image.get_width(), 1280)
	image.resize(width, int(width * float(image.get_height()) / image.get_width()))
	image.save_png(_out.path_join("%s_%s.png" % [_tag, name]))
