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
	var step := 0
	for kind: String in groups:
		for node: Node3D in groups[kind]:
			node.visible = true
		for frame in FRAMES_PER_STEP:
			await tree.process_frame
		step += 1
		StartupLog.mark("gráficos: %s" % kind)
		progress.call(float(step) / groups.size())
	if previous != null and is_instance_valid(previous):
		previous.make_current()
	camera.queue_free()
