extends SceneTree
## Mede o carregamento como na versão web (capa → tela de carregamento → jogo): tempo total e
## pior quadro, com a linha do tempo [carga] no console. Use o tradutor de shaders do Chrome:
##   godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle \
##     --script res://tools/web_load_check.gd -- <captura.png> --simular-web
## O Windows guarda os shaders compilados: a primeira medição é a mais fiel.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var state := root.get_node("GameState")
	state.set("save_enabled", false)
	root.get_node("Settings").set("save_enabled", false)
	state.call("reset")
	var loading: Script = load("res://scripts/ui/loading_screen.gd")
	var t := Time.get_ticks_msec()
	var worst := 0
	var last := t
	loading.call("change_to", self, "res://scenes/main.tscn")
	for i in 5:
		await process_frame
	while Time.get_ticks_msec() - t < 240000:
		await process_frame
		var now := Time.get_ticks_msec()
		worst = maxi(worst, now - last)
		last = now
		if Time.get_ticks_msec() - t > 3000 and not state.get("screen_open"):
			break
	print("Carregamento: total %d ms, pior quadro %d ms" % [Time.get_ticks_msec() - t, worst])
	await create_timer(2.0).timeout
	root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	quit()
