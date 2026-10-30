extends Control
## Tela inicial: arte de capa, Continuar (se houver partida salva), Novo jogo, Opções,
## Créditos e Sair. Opções usa o mesmo painel de abas do menu de pausa; Créditos, a CreditsScreen.
## Na primeira vez que o jogo abre, uma abertura curta: a arte surge do preto com zoom no logo e
## volta ao enquadramento normal antes do menu aparecer. Qualquer tecla ou clique pula.

const GAME_SCENE := "res://scenes/main.tscn"
const ICONS := "res://assets/third_party/kenney/game-icons/"
const ICON_COLOR := Color(0.28, 0.18, 0.04)
## Centro do logo na arte de capa (fração da imagem): o zoom da abertura parte dele.
const LOGO_CENTER := Vector2(0.33, 0.26)
const INTRO_ZOOM := 1.35

## A abertura só toca uma vez por execução (voltar do jogo ao menu não repete).
static var _intro_played := false

@onready var _continue: Button = %Continue
@onready var _new_game: Button = %NewGame
@onready var _options_button: Button = %OptionsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _quit: Button = %Quit
@onready var _summary: Label = %Summary
@onready var _menu: Control = %Menu
@onready var _options_box: Control = %OptionsBox
@onready var _options: TabContainer = %Options

var _confirm_new_game := false
var _intro: Tween
## Web: shaders do jogo já compilados nesta sessão (LoadingScreen.prepare).
static var _prepared := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Aberto pelo atalho "Jogar" (Godot assinado), o título viria com " (DEBUG)".
	get_window().set_deferred("title", "134 Master Hunt")
	%Version.text = "Versão %s · Feito com Godot · Esc volta · F11 tela cheia" % ProjectSettings.get_setting("application/config/version")
	get_tree().paused = false
	GameState.set_screen_open(false)
	for pair in [[_continue, "right.png"], [_new_game, "plus.png"], [_options_button, "gear.png"],
			[_credits_button, "information.png"], [_quit, "exit.png"]]:
		var button: Button = pair[0]
		button.icon = load(ICONS + pair[1])
		button.add_theme_constant_override("icon_max_width", 30)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			button.add_theme_color_override(state, ICON_COLOR)
	_continue.pressed.connect(_start)
	_new_game.pressed.connect(_on_new_game)
	_options_button.pressed.connect(_show_options.bind(0))
	_credits_button.pressed.connect(_show_credits)
	%Back.pressed.connect(_show_menu)
	_quit.pressed.connect(get_tree().quit)
	# No navegador não há o que fechar (a aba fecha o jogo).
	_quit.visible = not OS.has_feature("web")
	_refresh()
	_show_menu()
	resized.connect(_fit_art)
	_fit_art()
	# Web: na primeira vez, compila os shaders do jogo agora (com a tela de carregamento) e volta
	# para cá; começar a partida depois fica rápido. A abertura com o logo espera a volta.
	if WebPlatform.active() and not _prepared:
		_prepared = true
		LoadingScreen.prepare(get_tree(), GAME_SCENE, scene_file_path)
		return
	if not _intro_played:
		_intro_played = true
		_play_intro()


func _play_intro() -> void:
	var art := $Art as TextureRect
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hidden: Array[CanvasItem] = [$Shade, _menu, %Version]
	for item in hidden:
		item.modulate.a = 0.0
	art.scale = Vector2.ONE * INTRO_ZOOM
	_intro = create_tween()
	_intro.tween_interval(0.3)
	_intro.tween_property(black, "color:a", 0.0, 0.9)
	_intro.parallel().tween_callback(Sfx.play.bind(&"chime", 0.0, -6.0)).set_delay(0.35)
	_intro.tween_interval(0.5)
	_intro.tween_property(art, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for item in hidden:
		_intro.parallel().tween_property(item, "modulate:a", 1.0, 0.5).set_delay(0.7)
	_intro.tween_callback(black.queue_free)


## Pula a abertura (tecla, clique ou capturas de tela): vai direto ao fim.
func skip_intro() -> void:
	if _intro != null and _intro.is_running():
		_intro.custom_step(60.0)


func _input(event: InputEvent) -> void:
	if _intro == null or not _intro.is_running():
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		skip_intro()
		get_viewport().set_input_as_handled()


## Arte de capa cobrindo a tela, presa pela esquerda: em telas mais estreitas que 16:9 o corte
## fica do lado direito (atrás do menu), e o logo, à esquerda, aparece sempre inteiro.
func _fit_art() -> void:
	var art := $Art as TextureRect
	var aspect := float(art.texture.get_width()) / art.texture.get_height()
	var height := size.y
	var width := height * aspect
	if width < size.x:
		width = size.x
		height = width / aspect
	art.set_anchors_preset(Control.PRESET_TOP_LEFT)
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = Vector2(0, (size.y - height) * 0.5)
	art.size = Vector2(width, height)
	art.pivot_offset = art.size * LOGO_CENTER


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _options_box.visible:
		_show_menu()
		get_viewport().set_input_as_handled()


## O que já foi encontrado na partida salva (o GameState carrega o save ao iniciar).
func _refresh() -> void:
	var ledger := GameState.ledger
	var has_save := ledger.total_coins_found > 0 or GameState.owned_items.size() > 1 or ledger.carried_coins > 0
	_continue.visible = has_save
	if has_save:
		_summary.text = "Sua partida: %s de %s encontrados (%s)" % [MoneyFormat.brl(ledger.total_value_found_cents),
			MoneyFormat.brl(CoinLedger.GOAL_CENTS), MoneyFormat.progress(ledger.progress_scaled())]
	else:
		_summary.text = "R$ 134 milhões em moedas espalhados pela cidade. Bora catar."
	_new_game.text = "Novo jogo" if has_save else "Começar"
	(_continue if has_save else _new_game).grab_focus()


func _on_new_game() -> void:
	if _continue.visible and not _confirm_new_game:
		_confirm_new_game = true
		_new_game.text = "Apagar a partida salva? Clique de novo"
		return
	GameState.new_game()
	_start()


func _start() -> void:
	LoadingScreen.change_to(get_tree(), GAME_SCENE)


func _show_options(tab: int) -> void:
	_menu.visible = false
	_options_box.visible = true
	_options.current_tab = tab
	%Back.grab_focus()


func _show_credits() -> void:
	CreditsScreen.open(self).closed.connect(_credits_button.grab_focus)


func _show_menu() -> void:
	_options_box.visible = false
	_menu.visible = true
	_confirm_new_game = false
	_refresh()
