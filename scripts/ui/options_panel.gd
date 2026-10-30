extends TabContainer
## Abas de preferências (Controles, Vídeo, Áudio), usadas no menu de pausa e na
## tela inicial (os créditos têm tela própria, CreditsScreen). Tudo vai direto para o autoload Settings, que salva sozinho.

const ICONS := "res://assets/third_party/kenney/game-icons/"
## Ícones das abas Controles, Vídeo e Áudio.
const TAB_ICONS := ["mouse.png", "gear.png", "audioOn.png"]

@onready var _sensitivity: HSlider = %Sensitivity
@onready var _sensitivity_label: Label = %SensitivityLabel
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _antialias: OptionButton = %Antialias
@onready var _quality: OptionButton = %Quality
@onready var _volume: HSlider = %Volume
@onready var _volume_label: Label = %VolumeLabel
@onready var _ui_scale: HSlider = %UiScale
@onready var _ui_scale_label: Label = %UiScaleLabel
var _hud_minimal: CheckButton
## Controles de vídeo montados em código (ver _build_video_grid): chave -> controle.
var _video := {}


func _ready() -> void:
	for option in Settings.MSAA_OPTIONS:
		_antialias.add_item(option[0])
	for option in Settings.QUALITY_OPTIONS:
		_quality.add_item(option)
	sync()
	Settings.changed.connect(sync)
	_fullscreen.toggled.connect(Settings.set_fullscreen)
	_antialias.item_selected.connect(Settings.set_msaa_index)
	_quality.item_selected.connect(Settings.set_quality_index)
	_sensitivity.min_value = Settings.MIN_SENSITIVITY
	_sensitivity.max_value = Settings.MAX_SENSITIVITY
	_sensitivity.value = Settings.mouse_sensitivity
	_update_sensitivity_label()
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	_volume.value = Settings.volume
	_update_volume_label()
	_volume.value_changed.connect(_on_volume_changed)
	_ui_scale.value = Settings.ui_scale
	_hud_minimal = CheckButton.new()
	_hud_minimal.text = "HUD mínimo (só bolso, dica e avisos)"
	_hud_minimal.add_theme_font_size_override("font_size", 20)
	_hud_minimal.toggled.connect(Settings.set_hud_minimal)
	_ui_scale.add_sibling(_hud_minimal)
	_update_ui_scale_label()
	# Aplica ao soltar o controle: mudar a escala no meio do arrasto mexe o próprio slider.
	_ui_scale.drag_ended.connect(func(_changed: bool) -> void: Settings.set_ui_scale(_ui_scale.value))
	_ui_scale.value_changed.connect(func(_value: float) -> void:
		_update_ui_scale_label()
		if not _ui_scale.is_dragging(): Settings.set_ui_scale(_ui_scale.value))
	_build_video_grid()
	sync()
	for i in TAB_ICONS.size():
		set_tab_icon(i, load(ICONS + TAB_ICONS[i]))
		set_tab_icon_max_width(i, 26)


## Opções de vídeo numa grade de duas colunas (rótulo, controle).
func _build_video_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", UiStyle.SPACE_M)
	grid.add_theme_constant_override("v_separation", UiStyle.SPACE_S)
	var tab := get_node(^"Vídeo") as Control
	tab.add_child(grid)
	tab.move_child(grid, %Fullscreen.get_index() + 1)
	_option(grid, "preset", "Predefinição", Settings.QUALITY_OPTIONS, Settings.apply_preset)
	_option(grid, "coin_detail", "Detalhe das moedas", Settings.COIN_DETAIL_OPTIONS, Settings.set_coin_detail)
	_option(grid, "view_distance", "Distância de visão", Settings.VIEW_DISTANCE_OPTIONS, Settings.set_view_distance)
	var limits: Array = Settings.FPS_LIMIT_OPTIONS.map(func(o: Array) -> String: return o[0])
	_option(grid, "fps_limit_index", "Limite de FPS", limits, Settings.set_fps_limit_index)
	_slider(grid, "render_scale", "Resolução 3D", Settings.MIN_RENDER_SCALE, 1.0, 0.05, Settings.set_render_scale)
	_slider(grid, "fov", "Campo de visão", Settings.MIN_FOV, Settings.MAX_FOV, 1.0, Settings.set_fov)
	var vsync := CheckButton.new()
	vsync.text = "VSync"
	vsync.add_theme_font_size_override("font_size", 20)
	vsync.toggled.connect(Settings.set_vsync)
	grid.add_child(vsync)
	_video["vsync"] = vsync


## Rótulo de uma linha que ocupa a sobra da coluna (sem quebrar letra por letra).
static func _grid_label(title: String) -> Label:
	var label := MenuScreen.make_label(title, 20)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(150, 0)
	return label


func _option(grid: GridContainer, key: String, title: String, items: Array, on_select: Callable) -> void:
	grid.add_child(_grid_label(title))
	var button := OptionButton.new()
	button.custom_minimum_size = Vector2(170, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	for item: String in items:
		button.add_item(item)
	button.item_selected.connect(on_select)
	grid.add_child(button)
	_video[key] = button


func _slider(grid: GridContainer, key: String, title: String, low: float, high: float, step: float, on_change: Callable) -> void:
	var label := _grid_label(title)
	grid.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(170, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Aplica ao soltar (a escala e o campo de visão mudam a tela no meio do arrasto).
	slider.drag_ended.connect(func(_changed: bool) -> void: on_change.call(slider.value))
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s: %s" % [title, ("%d%%" % roundi(value * 100.0)) if key == "render_scale" else ("%d°" % roundi(value))]
		if not slider.is_dragging(): on_change.call(value))
	grid.add_child(slider)
	_video[key] = [slider, label, title]


## Reflete as preferências atuais (F11 também muda a tela cheia com o menu aberto).
func sync() -> void:
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	if _hud_minimal != null:
		_hud_minimal.set_pressed_no_signal(Settings.hud_minimal)
	_antialias.select(Settings.msaa_index)
	_quality.select(Settings.quality_index)
	if not _video.is_empty():
		for key in ["coin_detail", "view_distance", "fps_limit_index"]:
			(_video[key] as OptionButton).select(Settings.get(key))
		(_video.preset as OptionButton).select(Settings.quality_index)
		(_video.vsync as CheckButton).set_pressed_no_signal(Settings.vsync)
		for key in ["render_scale", "fov"]:
			var entry: Array = _video[key]
			(entry[0] as HSlider).set_value_no_signal(Settings.get(key))
			var value: float = Settings.get(key)
			(entry[1] as Label).text = "%s: %s" % [entry[2], ("%d%%" % roundi(value * 100.0)) if key == "render_scale" else ("%d°" % roundi(value))]
	_fullscreen.text = "Tela cheia (%s)" % InputBindings.label_of(&"toggle_fullscreen")


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)
	_update_sensitivity_label()


func _on_volume_changed(value: float) -> void:
	Settings.set_volume(value)
	_update_volume_label()
	Sfx.play(&"clink0", 0.0, -6.0)


func _update_ui_scale_label() -> void:
	_ui_scale_label.text = "Tamanho da interface: %d%%" % roundi(_ui_scale.value * 100.0)


func _update_volume_label() -> void:
	_volume_label.text = "Volume: %d%%" % roundi(Settings.volume * 100.0)


func _update_sensitivity_label() -> void:
	_sensitivity_label.text = "Sensibilidade do mouse: %sx" % MoneyFormat.decimal(Settings.mouse_sensitivity)
