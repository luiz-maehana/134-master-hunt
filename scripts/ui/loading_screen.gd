class_name LoadingScreen
extends CanvasLayer
## Tela de carregamento entre a tela inicial e o jogo. Fica presa à raiz (sobrevive à troca de
## cena) e mostra três etapas: carregar a cena (em thread), montar a cidade e espalhar as
## moedas em volta do jogador (CoinWorld.load_around_async), com piadas girando por cima da barra.
## Enquanto aparece, o jogador fica parado (GameState.screen_open). Some com um fade quando as
## moedas terminam.

const ART := "res://assets/key_art/landscape.png"
const TIPS := [
	"Dica: o ímã atrai as moedas à sua frente; a pá recolhe pilhas inteiras de perto.",
	"Dica: robôs aspiradores trabalham sozinhos e depositam direto, mesmo longe de você.",
	"Dica: o mapa (M) mostra os pontos de coleta, as lojas e onde estão seus robôs.",
	"Dica: o Congresso Nacional tem o metro quadrado mais rico da cidade.",
	"Dica: à noite, as moedas brilham no facho da lanterna (F).",
]

## Piadas que giram durante o carregamento (sátira genérica, nenhum nome real). A etapa de
## verdade fica numa linha menor, embaixo da barra.
const JOKES := [
	"Escondendo dinheiro na cueca…",
	"Preparando o jatinho de fuga…",
	"Contando os centavos (duas vezes, para garantir)…",
	"Abrindo uma CPI para investigar o carregamento…",
	"Lavando as moedas (só com água e sabão)…",
	"Transferindo o orçamento para outra categoria contábil…",
	"Imprimindo o recibo do recibo…",
	"Pedindo vista do processo de carregamento…",
	"Reunindo o centrão das moedas…",
	"Votando a urgência da barra de progresso…",
	"Licitando a próxima tela (só um concorrente se inscreveu)…",
	"Registrando o cofre no nome de um laranja…",
	"Escondendo moedas atrás do sofá do gabinete…",
	"Negociando a delação premiada dos pixels…",
	"Convocando o Senhor V. para depor (ele não veio)…",
	"Contratando uma consultoria para explicar a consultoria…",
	"Desviando a barra de progresso… para a direita…",
	"Apagando as mensagens do celular…",
	"Prometendo carregar até o fim do mandato…",
	"Construindo um viaduto superfaturado até o jogo…",
	"Fazendo a rachadinha dos pixels…",
	"Guardando o troco em malas de dinheiro vivo…",
	"Remarcando o voo para um destino que não consta no sistema…",
	"Aprovando o orçamento secreto do carregamento…",
	"Enterrando o processo na gaveta…",
	"Reajustando o salário da barra de progresso…",
	"Trocando os centavos por dólar na fronteira…",
	"Juntando recibos de restaurante para a prestação de contas…",
	"Colocando sigilo de 100 anos nos arquivos do jogo…",
	"Arrumando um álibi para o atraso…",
]
## Cada piada fica pelo menos isto na tela.
const JOKE_MS := 2200

## Quadro acima disto entra na linha do tempo da versão web (StartupLog).
const SLOW_FRAME_MS := 300

static var current: LoadingScreen

var _bar: ProgressBar
var _status: Label
var _joke: Label
var _jokes: Array = []
var _next_joke_at := 0
var _path := ""
var _last_frame := 0
## Pré-carga da web (prepare): cena para onde voltar quando terminar.
var _return_to := ""


## Troca para a cena `path` mostrando a tela de carregamento.
static func change_to(tree: SceneTree, path: String) -> void:
	var screen := show_on(tree)
	StartupLog.mark("cena: pedido")
	screen._path = path
	ResourceLoader.load_threaded_request(path)


## Versão web: monta o jogo atrás da tela de carregamento só para compilar os shaders e volta
## para `back_to` (a tela inicial). Os shaders compilados ficam valendo: ao começar a partida, a
## cidade monta em segundos, sem o aquecimento longo.
static func prepare(tree: SceneTree, path: String, back_to: String) -> void:
	change_to(tree, path)
	current._return_to = back_to


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
	set_step("Preparando os gráficos (só na abertura)…" if _return_to != "" else "Preparando os gráficos…", 0.45)
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
	box.offset_top = -230
	box.offset_bottom = -70
	box.add_theme_constant_override("separation", UiStyle.SPACE_M)
	add_child(box)
	_joke = MenuScreen.make_label("", 26, Color(1, 0.85, 0.4))
	_joke.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_joke)
	_show_next_joke()
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.theme_type_variation = UiStyle.BAR_GOLD
	box.add_child(_bar)
	_status = MenuScreen.make_label("Carregando…", 18, UiStyle.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var tip := MenuScreen.make_label(TIPS[randi() % TIPS.size()], 18, Color(0.8, 0.8, 0.8))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)


## Próxima piada, sem repetir até passar por todas.
func _show_next_joke() -> void:
	if _jokes.is_empty():
		_jokes = JOKES.duplicate()
		_jokes.shuffle()
	_joke.text = _jokes.pop_back()
	_next_joke_at = Time.get_ticks_msec() + JOKE_MS


func _process(_delta: float) -> void:
	# Versão web: quadros que seguraram a página (compilar shaders, enviar malhas...).
	var now := Time.get_ticks_msec()
	if _last_frame > 0 and now - _last_frame > SLOW_FRAME_MS:
		StartupLog.mark("quadro lento (%d ms)" % (now - _last_frame))
	_last_frame = now
	if now >= _next_joke_at:
		_show_next_joke()
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
	if _return_to != "":
		# Pré-carga: volta para a tela inicial e só então some (ela aparece pronta por baixo).
		get_tree().change_scene_to_file(_return_to)
		_return_to = ""
		for frame in 3:
			await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not WebPlatform.active():
		# No navegador o mouse só trava num clique (o carregamento passa do tempo do clique em
		# "Começar", e a aba pode nem estar em foco): o jogador clica na tela para olhar em volta.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _exit_tree() -> void:
	if current == self:
		current = null
