class_name LoadingScreen
extends CanvasLayer
## Tela de carregamento entre a tela inicial e o jogo. Fica presa à raiz (sobrevive à troca de
## cena) e mostra três etapas: carregar a cena (em thread), montar a cidade e espalhar as
## moedas em volta do jogador (CoinWorld.load_around_async). Enquanto aparece, o jogador fica
## parado (GameState.screen_open). Some com um fade quando as moedas terminam.

const ART := "res://assets/key_art/landscape.png"
const TIPS := [
	"Dica: o ímã atrai as moedas à sua frente; a pá recolhe pilhas inteiras de perto.",
	"Dica: robôs aspiradores trabalham sozinhos e depositam direto, mesmo longe de você.",
	"Dica: o mapa (M) mostra os pontos de coleta, as lojas e onde estão seus robôs.",
	"Dica: o Congresso Nacional tem o metro quadrado mais rico da cidade.",
	"Dica: à noite, as moedas brilham no facho da lanterna (F).",
]

## Quadro acima disto entra na linha do tempo da versão web (StartupLog).
const SLOW_FRAME_MS := 300

static var current: LoadingScreen

var _bar: ProgressBar
var _status: Label
var _path := ""
var _last_frame := 0


## Troca para a cena `path` mostrando a tela de carregamento.
static func change_to(tree: SceneTree, path: String) -> void:
	var screen := show_on(tree)
	StartupLog.mark("cena: pedido")
	screen._path = path
	ResourceLoader.load_threaded_request(path)


## Mostra a tela (ou devolve a que já está aberta).
static func show_on(tree: SceneTree) -> LoadingScreen:
	if current != null and is_instance_valid(current):
		return current
	current = LoadingScreen.new()
	tree.root.add_child.call_deferred(current)
	return current


## O mundo chama ao montar: as moedas em volta do jogador completam a barra.
func track(world: CoinWorld) -> void:
	if not is_node_ready():
		await ready
	set_step("Espalhando as moedas pela Esplanada…", 0.6)
	world.loading_progress.connect(func(fraction: float) -> void: _bar.value = 0.6 + 0.4 * fraction)
	world.loading_finished.connect(_finish, CONNECT_ONE_SHOT)


## Versão web: compila os shaders da cidade aos poucos (ShaderWarmup), com a barra andando.
func warm_up(city: Node3D) -> void:
	if not is_node_ready():
		await ready
	set_step("Preparando os gráficos…", 0.45)
	await ShaderWarmup.run(city, func(fraction: float) -> void: _bar.value = 0.45 + 0.15 * fraction)


func set_step(text: String, value: float) -> void:
	if _status != null:
		_status.text = text
		_bar.value = value


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_screen_open(true)
	var background := ColorRect.new()
	background.color = Color(0.03, 0.03, 0.05)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var art := TextureRect.new()
	art.texture = load(ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.35, 0.35, 0.4)
	add_child(art)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -190
	box.offset_bottom = -70
	box.add_theme_constant_override("separation", UiStyle.SPACE_M)
	add_child(box)
	_status = MenuScreen.make_label("Carregando…", 26, Color(1, 0.85, 0.4))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.theme_type_variation = UiStyle.BAR_GOLD
	box.add_child(_bar)
	var tip := MenuScreen.make_label(TIPS[randi() % TIPS.size()], 18, Color(0.8, 0.8, 0.8))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)


func _process(_delta: float) -> void:
	# Versão web: quadros que seguraram a página (compilar shaders, enviar malhas...).
	var now := Time.get_ticks_msec()
	if _last_frame > 0 and now - _last_frame > SLOW_FRAME_MS:
		StartupLog.mark("quadro lento (%d ms)" % (now - _last_frame))
	_last_frame = now
	if _path == "":
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		set_step("Carregando…", 0.4 * float(progress[0]) if not progress.is_empty() else 0.0)
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene := ResourceLoader.load_threaded_get(_path) as PackedScene
		StartupLog.mark("cena: arquivo carregado")
		_path = ""
		set_step("Montando a Esplanada dos Ministérios…", 0.45)
		# Dois quadros para a mensagem aparecer antes da montagem da cidade (que trava um pouco).
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().change_scene_to_packed(scene)
		StartupLog.mark("cena: montada")
	else:
		# Falhou: tenta do jeito comum (sem progresso).
		var path := _path
		_path = ""
		get_tree().change_scene_to_file(path)


func _finish() -> void:
	StartupLog.mark("moedas em volta prontas")
	_bar.value = 1.0
	GameState.set_screen_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _exit_tree() -> void:
	if current == self:
		current = null
