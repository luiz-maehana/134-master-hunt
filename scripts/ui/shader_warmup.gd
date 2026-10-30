class_name ShaderWarmup
extends RefCounted
## Versão web: compila os shaders da cidade aos poucos, atrás da tela de carregamento.
##
## No WebGL (ANGLE sobre Direct3D no Windows) cada shader novo custa ~3 s na primeira vez que
## aparece na tela, e o primeiro quadro do mundo compilava todos juntos (~34 s): o navegador
## achava que a página tinha travado e oferecia fechá-la. Aqui uma câmera alta e ortográfica
## enquadra a cidade inteira (shader só compila para o que está na câmera) e os filhos da
## cidade aparecem um por vez, um quadro para cada: nenhuma trava passa de alguns segundos.

## Quadros de espera depois de mostrar cada parte (o primeiro desenho compila).
const FRAMES_PER_STEP := 2


## Mostra a cidade aos poucos. `progress(fração)` atualiza a barra.
static func run(city: Node3D, progress: Callable) -> void:
	var tree := city.get_tree()
	var viewport := city.get_viewport()
	var previous := viewport.get_camera_3d()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2200.0
	camera.near = 1.0
	camera.far = 600.0
	city.add_child(camera)
	camera.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, -0.35), Vector3.FORWARD), Vector3(0, 250, 120))
	camera.make_current()
	# Peças do mesmo tipo (as 29 lojas, os carros de cada modelo...) usam os mesmos shaders:
	# aparecem juntas, num passo só.
	var groups := {}   # tipo (nome sem números) -> Array[Node3D]
	var digits := RegEx.create_from_string("[0-9_]+")
	for child in city.get_children():
		if child is Node3D and child != camera and not child is Light3D and (child as Node3D).visible:
			if not child.find_children("*", "GeometryInstance3D", true, false).is_empty() or child is GeometryInstance3D:
				(child as Node3D).visible = false
				var kind := digits.sub(String(child.name), "", true)
				if not groups.has(kind):
					groups[kind] = []
				(groups[kind] as Array).append(child)
	# Fora da cidade: o jogador (mão e ferramenta) e os robôs também estreiam numa etapa própria,
	# e o céu começa como cor lisa (o shader do céu é dos mais caros) e volta numa etapa só dele.
	for sibling in city.get_parent().get_children():
		if sibling != city and sibling is Node3D and (sibling as Node3D).visible:
			(sibling as Node3D).visible = false
			groups["fora da cidade: %s" % sibling.name] = [sibling]
	var environment: Environment = null
	var world_environment := city.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		environment = world_environment.environment
	var background := environment.background_mode if environment != null else Environment.BG_SKY
	var ambient := environment.ambient_light_source if environment != null else Environment.AMBIENT_SOURCE_SKY
	if environment != null:
		environment.background_mode = Environment.BG_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.6, 0.62, 0.68)
		environment.background_color = Color(0.55, 0.62, 0.75)
		groups["céu"] = []
		# Efeitos de tela também têm shaders próprios: começam desligados e voltam numa etapa.
		var effects := [environment.glow_enabled, environment.fog_enabled, environment.tonemap_mode]
		environment.glow_enabled = false
		environment.fog_enabled = false
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		groups["efeitos de tela"] = effects
	# Interface do jogo (HUD e menus): escondida até a etapa dela.
	var layers: Array = []
	for sibling in city.get_parent().get_children():
		if sibling is CanvasLayer and (sibling as CanvasLayer).visible:
			(sibling as CanvasLayer).visible = false
			layers.append(sibling)
	groups["interface"] = layers
	var step := 0
	for kind: String in groups:
		if kind == "efeitos de tela":
			var effects: Array = groups[kind]
			environment.glow_enabled = effects[0]
			environment.fog_enabled = effects[1]
			environment.tonemap_mode = effects[2]
		elif kind == "interface":
			for layer: CanvasLayer in groups[kind]:
				layer.visible = true
		else:
			for node: Node3D in groups[kind]:
				node.visible = true
		if kind == "céu":
			environment.background_mode = background
			environment.ambient_light_source = ambient
		for frame in FRAMES_PER_STEP:
			await tree.process_frame
		step += 1
		StartupLog.mark("gráficos: %s" % kind)
		progress.call(float(step) / groups.size())
	if previous != null and is_instance_valid(previous):
		previous.make_current()
	camera.queue_free()
