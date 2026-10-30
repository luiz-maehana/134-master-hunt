extends TestSuite
## HUD em várias resoluções e tamanhos de interface: os painéis ficam dentro da tela, sem
## se sobrepor, e nenhum texto fica abaixo do tamanho mínimo.

const MAIN_SCENE := "res://scenes/main.tscn"
const RESOLUTIONS := [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(3840, 2160)]
const MIN_FONT := 16

var main: Node
var _size: Vector2i
var _scale: float


func before_all() -> void:
	GameState.reset()
	_size = tree.root.size
	_scale = Settings.ui_scale
	main = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	for id in [&"glove", &"shovel_small", &"magnet_small", &"magnet_rod_small", &"pouch", &"backpack",
			&"sneakers", &"cart", &"flashlight", &"robot_small", &"robot_small"]:
		GameState.grant(id)
	await physics_frames(10)


func after_all() -> void:
	tree.root.size = _size
	Settings.set_ui_scale(_scale)
	main.queue_free()
	await process_frames(2)
	GameState.reset()


func test_hud_fits_every_resolution() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		await _check_at(resolution, 1.0)
	for scale: float in [Settings.MIN_UI_SCALE, Settings.MAX_UI_SCALE]:
		await _check_at(Vector2i(1280, 720), scale)


func test_minimal_hud() -> void:
	tree.root.size = Vector2i(1920, 1080)
	var hud: Node = main.get_node("HUD")
	var left := hud.get_node("Left") as Control
	var hotbar := hud.get_node("%Hotbar") as Control
	var status := hud.get_node("%Status") as Control
	Settings.set_hud_minimal(true)
	await process_frames(2)
	check(not left.visible, "HUD mínimo: cartões da esquerda escondidos")
	check(not (hud.get_node("%Clock") as Control).visible, "HUD mínimo: sem relógio")
	check(status.visible and (hud.get_node("%Pocket") as Control).is_visible_in_tree(), "HUD mínimo: bolso continua")
	check_eq(hotbar.modulate.a, 1.0, "barra de ferramentas aparece ao ligar")
	await tree.create_timer(2.6).timeout
	check(hotbar.modulate.a < 0.05, "e some sozinha")
	main.get_node("Player/Head/Camera3D/ToolHolder").call("equip", &"magnet_small")
	await process_frames(1)
	check_eq(hotbar.modulate.a, 1.0, "trocar de ferramenta mostra a barra de novo")
	Settings.set_hud_minimal(false)
	await process_frames(2)
	check(left.visible and hotbar.modulate.a == 1.0, "HUD completo de volta")


func _check_at(resolution: Vector2i, scale: float) -> void:
	tree.root.size = resolution
	Settings.set_ui_scale(scale)
	await process_frames(4)
	var hud: Node = main.get_node("HUD")
	var screen: Rect2 = hud.get_viewport().get_visible_rect()
	var rects: Dictionary = hud.panel_rects()
	var tag := "%dx%d @%d%%" % [resolution.x, resolution.y, roundi(scale * 100.0)]
	for name: String in rects:
		var rect: Rect2 = rects[name]
		check(screen.grow(1.0).encloses(rect), "%s: %s dentro da tela (%s em %s)" % [tag, name, rect, screen.size])
	var names := rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			check(not a.grow(-1.0).intersects(b.grow(-1.0)), "%s: %s e %s não se sobrepõem" % [tag, names[i], names[j]])
	var small := []
	for label in hud.find_children("*", "Label", true, false):
		var size: int = (label as Label).get_theme_font_size(&"font_size")
		if (label as Label).is_visible_in_tree() and size < MIN_FONT:
			small.append("%s (%d)" % [label.name, size])
	check(small.is_empty(), "%s: textos com pelo menos %d px: %s" % [tag, MIN_FONT, small])
