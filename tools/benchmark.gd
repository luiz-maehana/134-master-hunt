extends SceneTree
## Benchmark repetível: cada predefinição de vídeo em cada trecho do eixo (de dia e, na Alta, de
## noite com lanterna), olhando para o leste. Grava docs/BENCHMARK.md com quadro médio, pior
## quadro, FPS, tempo de GPU e de CPU do desenho, draw calls, triângulos e memória de vídeo.
## Mede sempre sem VSync e sem limite de FPS (o teto do monitor esconderia as diferenças).
## Precisa de placa de vídeo:
##   godot --path . --resolution 1920x1080 --script res://tools/benchmark.gd
## Não toca no save nem nas preferências do jogador.

const OUT := "res://docs/BENCHMARK.md"
const FRAMES := 240
## [nome, x] de cada trecho (no meio do gramado, z = 0).
const SPOTS := [["Rodoviária", -1500.0], ["Setor Cultural", -1000.0], ["Esplanada", -100.0], ["Congresso", 900.0]]

var _lines := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node("GameState")
	var settings := root.get_node("Settings")
	state.set("save_enabled", false)
	settings.set("save_enabled", false)
	state.call("reset")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	while state.get("screen_open"):
		await process_frame
	for id in ["permit_downtown", "permit_commercial", "permit_industrial", "flashlight", "flashlight_tactical"]:
		state.call("grant", StringName(id))
	var cycle: Node = main.get_node("City/DayNight")
	cycle.set("frozen", true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var adapter := RenderingServer.get_video_adapter_name()
	_lines.append("# Benchmark — 134 Master Hunt\n")
	_lines.append("Gerado por `tools/benchmark.gd` em %s, %s, janela %s. Cada linha: %d quadros parados\nno meio do gramado, olhando para o leste.\n" % [
		Time.get_date_string_from_system(), adapter, root.size, FRAMES])
	_lines.append("| Predefinição | Trecho | Hora | Quadro médio | Pior quadro | FPS | GPU | CPU (desenho) | Draw calls | Triângulos | VRAM usada |")
	_lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
	for preset in settings.get("QUALITY_OPTIONS").size():
		settings.call("apply_preset", preset)
		# A predefinição não mexe nisso, mas as preferências do jogador podem ter limite.
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		for spot: Array in SPOTS:
			await _measure(main, settings, preset, spot, 0.45, "dia")
		if preset == 2:
			await _measure(main, settings, preset, SPOTS[3], 0.0, "noite")
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(_lines) + "\n")
	file.close()
	print("\n".join(_lines))
	print("Salvo em %s" % OUT)
	quit()


func _measure(main: Node, settings: Node, preset: int, spot: Array, hour: float, label: String) -> void:
	root.get_node("GameState").set("time_of_day", hour)
	var cycle: Node = main.get_node("City/DayNight")
	cycle.call("apply")
	var player: Node3D = main.get_node("Player")
	player.global_position = Vector3(spot[1], 0.3, 0)
	player.rotation.y = -PI * 0.5
	player.get_node("Head").rotation.x = -0.1
	var flashlight: Node3D = player.get_node_or_null("Head/Camera3D/Flashlight")
	if flashlight != null:
		flashlight.visible = label == "noite"
	main.get_node("City/CoinWorld").call("load_around", player.global_position)
	for i in 60:
		await process_frame
	var total := 0
	var worst := 0
	var gpu := 0.0
	var cpu := 0.0
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		total += now - last
		worst = maxi(worst, now - last)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu()
	var average := total / float(FRAMES) / 1000.0
	_lines.append("| %s | %s | %s | %.2f ms | %.1f ms | %d | %.2f ms | %.2f ms | %d | %.2f mi | %d MB |" % [
		settings.get("QUALITY_OPTIONS")[preset], spot[0], label, average, worst / 1000.0, roundi(1000.0 / average),
		gpu / FRAMES, cpu / FRAMES,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1_000_000.0,
		roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])
