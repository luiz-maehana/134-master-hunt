extends TestSuite
## Preferências de qualidade e volume, e sons sintetizados pelo Sfx.

var _quality: int
var _volume: float
var _saved_enabled: bool


func before_all() -> void:
	_saved_enabled = Settings.save_enabled
	Settings.save_enabled = false
	_quality = Settings.quality_index
	_volume = Settings.volume


func after_all() -> void:
	Settings.reset_bindings()
	Settings.set_quality_index(_quality)
	Settings.set_volume(_volume)
	Settings.save_enabled = _saved_enabled


func test_quality_and_volume_are_clamped() -> void:
	Settings.set_quality_index(99)
	check_eq(Settings.quality_index, Settings.QUALITY_OPTIONS.size() - 1, "qualidade acima do máximo")
	Settings.set_quality_index(-3)
	check_eq(Settings.quality_index, 0, "qualidade abaixo do mínimo")
	Settings.set_volume(2.0)
	check_eq(Settings.volume, 1.0, "volume acima do máximo")
	Settings.set_volume(0.0)
	check(AudioServer.is_bus_mute(0), "volume zero silencia")
	Settings.set_volume(0.5)
	check(not AudioServer.is_bus_mute(0), "volume volta a tocar")


func test_sounds_are_synthesized() -> void:
	for sound in ["clink0", "clink3", "pour", "pick0", "pick5", "pick_many", "step", "chime", "whoosh", "click", "buzz", "hum"]:
		var stream: AudioStreamWAV = Sfx._streams.get(sound)
		check(stream != null and stream.data.size() > 1000, "som %s gerado" % sound)
	check_eq((Sfx.hum_stream() as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "motor em loop")
	# Tocar um som desconhecido não quebra.
	Sfx.play(&"nao_existe")
	Sfx.play(&"chime")
	check(true, "tocar sons não quebra")


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key


func test_rebind_swaps_conflicting_actions() -> void:
	Settings.reset_bindings()
	check_eq(InputBindings.label_of(&"jump"), "Espaço", "pular começa no Espaço")
	# E já é "interagir": as duas ações trocam de tecla.
	Settings.rebind(&"jump", _key(KEY_E))
	check_eq(InputBindings.key_code(InputBindings.binding_of(&"jump")), KEY_E, "pular agora no E")
	check_eq(InputBindings.key_code(InputBindings.binding_of(&"interact")), KEY_SPACE, "interagir ficou com o Espaço")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	Settings.rebind(&"use_tool", click)
	check_eq(InputBindings.label_of(&"use_tool"), "Botão direito", "usar ferramenta no botão direito")
	check_eq(InputBindings.label_of(&"tool_cancel"), "Clique", "cancelar foi para o clique")
	var used := {}
	for action in InputBindings.actions():
		var text := InputBindings.to_text(InputBindings.binding_of(action))
		check(not used.has(text), "tecla única: %s" % action)
		used[text] = true
	Settings.reset_bindings()
	check_eq(InputBindings.label_of(&"use_tool"), "Clique", "padrão restaurado")


func test_left_handed_preset() -> void:
	Settings.apply_left_handed()
	check_eq(InputBindings.label_of(&"move_forward"), "Seta ↑", "andar nas setas")
	check_eq(InputBindings.label_of(&"jump"), "Num 0", "pular no teclado numérico")
	check_eq(InputBindings.label_of(&"use_tool"), "Clique", "mouse continua igual")
	Settings.reset_bindings()


func test_bindings_text_and_persistence() -> void:
	check(InputBindings.from_text("k%d" % KEY_ESCAPE) == null, "Esc não pode ser usado")
	check(InputBindings.from_text("x12") == null, "texto inválido ignorado")
	check(InputBindings.from_text("m99") == null, "botão inexistente ignorado")
	check(InputBindings.from_text("k") == null, "texto curto ignorado")
	check(not InputBindings.accepts(_key(KEY_ESCAPE)), "Esc não é aceito na troca")
	var path := Settings.settings_path
	Settings.settings_path = "user://test_settings.cfg"
	Settings.save_enabled = true
	Settings.rebind(&"reel_line", _key(KEY_Q))
	Settings.reset_bindings.call()
	# Reset também salvou; troca de novo e confere o que foi para o arquivo.
	Settings.rebind(&"reel_line", _key(KEY_Q))
	Settings.save_enabled = false
	Settings.reset_bindings()
	check_eq(InputBindings.key_code(InputBindings.binding_of(&"reel_line")), KEY_R, "reset na memória")
	Settings.load_settings()
	check_eq(InputBindings.key_code(InputBindings.binding_of(&"reel_line")), KEY_Q, "tecla trocada volta do arquivo")
	var cfg := ConfigFile.new()
	cfg.load(Settings.settings_path)
	check_eq(cfg.get_section_keys("controls"), PackedStringArray(["reel_line"]), "só a tecla trocada é salva")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.settings_path))
	Settings.settings_path = path
	Settings.reset_bindings()


func test_video_presets_and_limits() -> void:
	var saved := [Settings.quality_index, Settings.coin_detail, Settings.view_distance, Settings.render_scale, Settings.fov, Settings.fps_limit_index]
	Settings.apply_preset(0)
	check_eq(Settings.coin_detail, 0, "Baixa: moedas simples")
	check(Settings.render_scale < 1.0, "Baixa: resolução 3D reduzida")
	check_eq(get_root().scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2, "resolução reduzida usa FSR 2")
	Settings.apply_preset(3)
	check_eq(Settings.view_distance, 1, "Ultra: visão longa")
	check_eq(get_root().scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "resolução nativa sem FSR")
	Settings.set_render_scale(0.1)
	check_eq(Settings.render_scale, Settings.MIN_RENDER_SCALE, "resolução 3D tem mínimo")
	Settings.set_fov(500.0)
	check_eq(Settings.fov, Settings.MAX_FOV, "campo de visão tem máximo")
	Settings.set_fps_limit_index(1)
	check_eq(Engine.max_fps, 60, "limite de 60 FPS")
	Settings.set_fps_limit_index(Settings.FPS_LIMIT_OPTIONS.size() - 1)
	check_eq(Engine.max_fps, 0, "sem limite")
	Settings.quality_index = saved[0]
	Settings.coin_detail = saved[1]
	Settings.view_distance = saved[2]
	Settings.set_render_scale(saved[3])
	Settings.set_fov(saved[4])
	Settings.set_fps_limit_index(saved[5])


func get_root() -> Window:
	return Settings.get_tree().root
