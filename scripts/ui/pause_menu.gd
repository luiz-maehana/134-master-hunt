extends CanvasLayer
## Menu (Esc): libera o mouse e mostra as preferências em abas (cena options_panel, a mesma
## da tela inicial). O jogo continua rodando por trás (robôs, relógio, HUD).

const ICONS := "res://assets/third_party/kenney/game-icons/"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const ICON_COLOR := Color(0.28, 0.18, 0.04)

@onready var _resume: Button = %Resume
@onready var _new_game: Button = %NewGame
@onready var _main_menu: Button = %MainMenu
@onready var _quit: Button = %Quit
var _credits: Button
var _achievements: Button

var _confirm_new_game := false
## Aberto (o menu ainda fica visível enquanto esmaece ao fechar).
var _paused := false


func _ready() -> void:
	visible = false
	_credits = _quit.duplicate() as Button
	_credits.unique_name_in_owner = false
	_credits.text = "Créditos"
	_quit.add_sibling(_credits)
	_quit.get_parent().move_child(_credits, _quit.get_index())
	_achievements = _quit.duplicate() as Button
	_achievements.unique_name_in_owner = false
	_achievements.text = "Conquistas"
	_credits.add_sibling(_achievements)
	_credits.get_parent().move_child(_achievements, _credits.get_index())
	for pair in [[_new_game, "return.png"], [_main_menu, "home.png"], [_achievements, "trophy.png"], [_credits, "information.png"], [_quit, "exit.png"]]:
		var button: Button = pair[0]
		button.icon = load(ICONS + pair[1])
		button.add_theme_constant_override("icon_max_width", 26)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			button.add_theme_color_override(state, ICON_COLOR)
	_resume.pressed.connect(set_paused.bind(false))
	_new_game.pressed.connect(_on_new_game)
	_main_menu.pressed.connect(_on_main_menu)
	_quit.pressed.connect(_on_quit)
	# No navegador não há o que fechar (a aba fecha o jogo).
	_quit.visible = not OS.has_feature("web")
	_achievements.pressed.connect(_open_achievements)
	_credits.pressed.connect(func() -> void: CreditsScreen.open(self).closed.connect(_resume.grab_focus))


## Trocou de aba ou de janela no meio do jogo: pausa e solta o mouse. Assim o jogo não fica
## pedindo o mouse travado sem foco (no Chrome isso podia sumir com o ponteiro das outras abas).
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and is_inside_tree():
		if not GameState.screen_open:
			set_paused(true)
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Outra tela (loja, inventário, mapa) está aberta: ela trata o Esc.
		if GameState.screen_open and not _paused:
			return
		set_paused(not _paused)
		get_viewport().set_input_as_handled()


## Fecha o menu e abre as conquistas (uma tela de cada vez).
func _open_achievements() -> void:
	set_paused(false)
	if AchievementsMenu.current != null:
		AchievementsMenu.current.open()


func set_paused(paused: bool) -> void:
	if paused != _paused:
		if paused:
			ScreenTransition.open(self)
		else:
			ScreenTransition.close(self)
	_paused = paused
	GameState.set_screen_open(paused)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	_confirm_new_game = false
	_new_game.text = "Recomeçar partida"
	if paused:
		_resume.grab_focus()


func _on_new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		_new_game.text = "Apagar progresso? Clique de novo"
		return
	GameState.new_game()
	set_paused(false)
	get_tree().reload_current_scene()


## Salva e volta para a tela inicial.
func _on_main_menu() -> void:
	GameState.save_game()
	GameState.set_screen_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_quit() -> void:
	GameState.save_game()
	get_tree().quit()
