extends Node
## Preferências locais do jogador (autoload "Settings").
## Salvas em user://settings.cfg, fora do repositório.

signal changed

const PATH := "user://settings.cfg"
## Testes usam outro arquivo para nunca tocar nas preferências reais.
var settings_path := PATH
const MIN_SENSITIVITY := 0.2
const MAX_SENSITIVITY := 3.0
## Opções de antialiasing (índice salvo) -> modo MSAA do Godot.
const MSAA_OPTIONS := [
	["Desligado", Viewport.MSAA_DISABLED],
	["2×", Viewport.MSAA_2X],
	["4×", Viewport.MSAA_4X],
	["8×", Viewport.MSAA_8X],
]
const DEFAULT_MSAA := 2
## Efeitos: sombra de contato (SSAO), brilho e distância das sombras. A predefinição (PRESETS)
## ajusta isso e as opções abaixo de uma vez; depois cada uma pode ser mudada sozinha.
const QUALITY_OPTIONS := ["Baixa", "Média", "Alta", "Ultra"]
const DEFAULT_QUALITY := 2
## Detalhe das moedas (lados da malha de perto e de longe; ver CoinWorld.configure).
const COIN_DETAIL_OPTIONS := ["Baixo", "Médio", "Alto"]
## Distância de visão das moedas (blocos de 16 m carregados em volta do jogador).
const VIEW_DISTANCE_OPTIONS := ["Normal", "Longa", "Muito longa"]
const FPS_LIMIT_OPTIONS := [["30", 30], ["60", 60], ["120", 120], ["144", 144], ["Sem limite", 0]]
const MIN_RENDER_SCALE := 0.5
const MIN_FOV := 70.0
const MAX_FOV := 100.0
## Predefinição -> [efeitos, detalhe das moedas, distância de visão, escala de renderização].
const PRESETS := [[0, 0, 0, 0.75], [1, 1, 0, 0.9], [2, 2, 0, 1.0], [3, 2, 1, 1.0]]
## Limites do tamanho da interface (opção da aba Vídeo).
const MIN_UI_SCALE := 0.8
const MAX_UI_SCALE := 1.3

## Multiplicador aplicado à sensibilidade base do controlador.
var mouse_sensitivity := 1.0
var fullscreen := false
var msaa_index := DEFAULT_MSAA
var quality_index := DEFAULT_QUALITY
var coin_detail := 2
var view_distance := 0
## Escala da resolução 3D (1 = nativa; abaixo disso usa AMD FSR 2 para reconstruir).
var render_scale := 1.0
var vsync := true
var fps_limit_index := 4
var fov := 75.0
## Tamanho da interface (multiplica a escala; 1 = padrão).
var ui_scale := 1.0
## HUD mínimo: só bolso, dica, avisos e mira; a barra de ferramentas aparece ao trocar.
var hud_minimal := false
## Volume geral (0 = mudo, 1 = máximo).
var volume := 0.8
## Tecla padrão de cada ação remapeável (do project.godot), em texto.
var _default_bindings := {}
## Testes desligam para nunca alterar as preferências reais do jogador.
var save_enabled := true


func _ready() -> void:
	# F11 deve funcionar também com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in InputBindings.actions():
		_default_bindings[action] = InputBindings.to_text(InputBindings.binding_of(action))
	load_settings()
	apply_display()
	get_tree().root.size_changed.connect(apply_ui_scale)
	apply_audio()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		set_fullscreen(not fullscreen)
		get_viewport().set_input_as_handled()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_changed()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	_changed()


func set_msaa_index(index: int) -> void:
	msaa_index = clampi(index, 0, MSAA_OPTIONS.size() - 1)
	apply_display()
	_changed()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_audio()
	_changed()


## Liga `event` à ação. Se outra ação já usava essa tecla, ela fica com a tecla antiga desta
## (troca), para nenhuma ação ficar sem tecla nem duas com a mesma.
func rebind(action: StringName, event: InputEvent) -> void:
	if not InputBindings.actions().has(action) or InputBindings.to_text(event) == "":
		return
	var old := InputBindings.binding_of(action)
	for other in InputBindings.actions():
		if other != action and InputBindings.same(InputBindings.binding_of(other), event) and old != null:
			_set_binding(other, InputBindings.from_text(InputBindings.to_text(old)))
	_set_binding(action, InputBindings.from_text(InputBindings.to_text(event)))
	_changed()


func reset_bindings() -> void:
	for action: StringName in _default_bindings:
		_set_binding(action, InputBindings.from_text(_default_bindings[action]))
	_changed()


## Setas e teclado numérico (mouse na mão esquerda); o resto volta ao padrão.
func apply_left_handed() -> void:
	for action: StringName in _default_bindings:
		_set_binding(action, InputBindings.from_text(InputBindings.LEFT_HANDED.get(action, _default_bindings[action])))
	_changed()


func default_binding(action: StringName) -> String:
	return _default_bindings.get(action, "")


func _set_binding(action: StringName, event: InputEvent) -> void:
	if event == null or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


func apply_audio() -> void:
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func set_ui_scale(value: float) -> void:
	ui_scale = clampf(snappedf(value, 0.05), MIN_UI_SCALE, MAX_UI_SCALE)
	apply_display()
	_changed()


## A interface segue a ALTURA da tela (1080 virtuais × ui_scale), também em telas mais estreitas
## que 16:9: o modo "expand" sozinho escalaria pela largura e, em 4:3, tudo ficaria com metade do
## tamanho. A largura virtual então varia, e o HUD se reorganiza.
func apply_ui_scale() -> void:
	var root := get_tree().root
	var size := Vector2(root.size)
	var base := Vector2(root.content_scale_size)
	if size.x <= 0.0 or size.y <= 0.0 or base.x <= 0.0 or base.y <= 0.0:
		return
	var fit := minf(size.x / base.x, size.y / base.y)
	root.content_scale_factor = ui_scale * (size.y / base.y) / fit


func set_quality_index(index: int) -> void:
	quality_index = clampi(index, 0, QUALITY_OPTIONS.size() - 1)
	_changed()


## Aplica a predefinição `index` (efeitos, moedas, distância e escala de uma vez).
func apply_preset(index: int) -> void:
	var preset: Array = PRESETS[clampi(index, 0, PRESETS.size() - 1)]
	quality_index = preset[0]
	coin_detail = preset[1]
	view_distance = preset[2]
	render_scale = preset[3]
	apply_display()
	_changed()


func set_coin_detail(index: int) -> void:
	coin_detail = clampi(index, 0, COIN_DETAIL_OPTIONS.size() - 1)
	_changed()


func set_view_distance(index: int) -> void:
	view_distance = clampi(index, 0, VIEW_DISTANCE_OPTIONS.size() - 1)
	_changed()


func set_render_scale(value: float) -> void:
	render_scale = clampf(snappedf(value, 0.05), MIN_RENDER_SCALE, 1.0)
	apply_display()
	_changed()


func set_hud_minimal(value: bool) -> void:
	hud_minimal = value
	_changed()


func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()
	_changed()


func set_fps_limit_index(index: int) -> void:
	fps_limit_index = clampi(index, 0, FPS_LIMIT_OPTIONS.size() - 1)
	apply_display()
	_changed()


func set_fov(value: float) -> void:
	fov = clampf(roundf(value), MIN_FOV, MAX_FOV)
	_changed()


## Aplica tela cheia e antialiasing na janela principal.
func apply_display() -> void:
	get_tree().root.msaa_3d = MSAA_OPTIONS[msaa_index][1]
	var root := get_tree().root
	# FSR 2 só existe no Forward+ (não no navegador): lá a escala menor usa o filtro simples.
	var fsr := render_scale < 0.999 and not OS.has_feature("web")
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr else Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = render_scale
	Engine.max_fps = FPS_LIMIT_OPTIONS[fps_limit_index][1]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	apply_ui_scale()
	# Sem janela (testes/headless) não há modo de tela para mudar.
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## No navegador (WebGL 2, renderizador Compatibility) o jogo começa leve: predefinição Baixa, sem
## MSAA e resolução nativa. Só vale no primeiro acesso; o que o jogador mudar fica salvo.
func _web_defaults() -> void:
	quality_index = 0
	coin_detail = 0
	view_distance = 0
	msaa_index = 0
	render_scale = 1.0


func load_settings() -> void:
	if OS.has_feature("web"):
		_web_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	var sensitivity: Variant = cfg.get_value("input", "mouse_sensitivity", 1.0)
	if sensitivity is float or sensitivity is int:
		mouse_sensitivity = clampf(float(sensitivity), MIN_SENSITIVITY, MAX_SENSITIVITY)
	var full: Variant = cfg.get_value("display", "fullscreen", false)
	if full is bool:
		fullscreen = full
	var msaa: Variant = cfg.get_value("display", "msaa_index", DEFAULT_MSAA)
	if msaa is int:
		msaa_index = clampi(msaa, 0, MSAA_OPTIONS.size() - 1)
	for action: StringName in _default_bindings:
		var saved: Variant = cfg.get_value("controls", String(action), "")
		if saved is String and saved != "":
			_set_binding(action, InputBindings.from_text(saved))
	var vol: Variant = cfg.get_value("audio", "volume", 0.8)
	if vol is float or vol is int:
		volume = clampf(float(vol), 0.0, 1.0)
	var scale: Variant = cfg.get_value("display", "ui_scale", 1.0)
	if scale is float or scale is int:
		ui_scale = clampf(float(scale), MIN_UI_SCALE, MAX_UI_SCALE)
	var quality: Variant = cfg.get_value("display", "quality_index", DEFAULT_QUALITY)
	if quality is int:
		quality_index = clampi(quality, 0, QUALITY_OPTIONS.size() - 1)
	coin_detail = _int_setting(cfg, "coin_detail", coin_detail, COIN_DETAIL_OPTIONS.size() - 1)
	view_distance = _int_setting(cfg, "view_distance", view_distance, VIEW_DISTANCE_OPTIONS.size() - 1)
	fps_limit_index = _int_setting(cfg, "fps_limit_index", fps_limit_index, FPS_LIMIT_OPTIONS.size() - 1)
	render_scale = clampf(_number_setting(cfg, "render_scale", render_scale), MIN_RENDER_SCALE, 1.0)
	fov = clampf(_number_setting(cfg, "fov", fov), MIN_FOV, MAX_FOV)
	var sync: Variant = cfg.get_value("display", "vsync", vsync)
	if sync is bool:
		vsync = sync
	var minimal: Variant = cfg.get_value("display", "hud_minimal", hud_minimal)
	if minimal is bool:
		hud_minimal = minimal


## Inteiro de [display] entre 0 e `top`; o valor atual se faltar ou for inválido.
static func _int_setting(cfg: ConfigFile, key: String, current: int, top: int) -> int:
	var value: Variant = cfg.get_value("display", key, current)
	return clampi(value, 0, top) if value is int else current


static func _number_setting(cfg: ConfigFile, key: String, current: float) -> float:
	var value: Variant = cfg.get_value("display", key, current)
	return float(value) if (value is float or value is int) and is_finite(float(value)) else current


func save_settings() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "msaa_index", msaa_index)
	cfg.set_value("display", "quality_index", quality_index)
	cfg.set_value("display", "ui_scale", ui_scale)
	for key in ["coin_detail", "view_distance", "render_scale", "vsync", "fps_limit_index", "fov", "hud_minimal"]:
		cfg.set_value("display", key, get(key))
	cfg.set_value("audio", "volume", volume)
	# Só as teclas trocadas: mudanças futuras nos padrões continuam valendo.
	for action: StringName in _default_bindings:
		var current := InputBindings.to_text(InputBindings.binding_of(action))
		if current != _default_bindings[action]:
			cfg.set_value("controls", String(action), current)
	cfg.save(settings_path)


func _changed() -> void:
	changed.emit()
	save_settings()
