extends SceneTree
## Gera assets/ui/item_icons/<id>.png para os itens da loja que não são ferramentas
## (bolsos, transporte, licenças, lanternas, melhorias e robôs). Os modelos baixados ficam em
## assets/source/item_models/ (fora do jogo exportado) e são lidos direto do arquivo; os
## robôs usam o próprio modelo do jogo. Precisa de placa de vídeo:
##   godot --path . --script res://tools/build_item_icons.gd

const OUT := "res://assets/ui/item_icons/"
const MODELS := "res://assets/source/item_models/"
const SIZE := 128
## Mesmo contorno claro dos ícones das ferramentas.
const ToolIcons := preload("res://tools/build_tool_icons.gd")
## id do item -> [arquivo do modelo, direção da câmera]. Licenças usam o mesmo envelope.
const ITEMS := {
	&"pouch": ["pouch.glb", Vector3(0.6, 0.5, 1.0)],
	&"backpack": ["backpack.glb", Vector3(0.8, 0.4, 1.0)],
	&"sneakers": ["sneakers.glb", Vector3(1.0, 0.7, 0.6)],
	&"cart": ["cart.glb", Vector3(1.0, 0.6, 0.4)],
	&"motor_cart": ["motor_cart.glb", Vector3(1.0, 0.6, 0.7)],
	&"dumpster": ["dumpster.glb", Vector3(0.9, 0.6, 1.0)],
	&"permit_downtown": ["permit.glb", Vector3(0.3, 1.0, 0.5)],
	&"permit_commercial": ["permit.glb", Vector3(0.3, 1.0, 0.5)],
	&"permit_industrial": ["permit.glb", Vector3(0.3, 1.0, 0.5)],
	&"portal_contract": ["permit.glb", Vector3(0.3, 1.0, 0.5)],
	&"robot_batteries": ["robot_batteries.glb", Vector3(0.8, 0.5, 1.0)],
	&"robot_control": ["robot_control.glb", Vector3(0.7, 0.5, 1.0)],
	&"flashlight": ["flashlight.glb", Vector3(0.6, 0.7, 1.0)],
	&"flashlight_tactical": ["flashlight_tactical.glb", Vector3(0.6, 0.7, 1.0)],
	&"flashlight_helmet": ["flashlight_helmet.glb", Vector3(0.8, 0.6, 1.0)],
}
## Cor da faixa de cada licença (a do bairro) e do contrato dos portais (roxo), para diferenciar os envelopes.
const PERMIT_TINT := {
	&"permit_downtown": Color(0.95, 0.85, 0.55),
	&"permit_commercial": Color(0.6, 0.85, 1.0),
	&"permit_industrial": Color(1.0, 0.7, 0.55),
	&"portal_contract": Color(0.75, 0.55, 1.0),
}
const ROBOTS := [&"robot_small", &"robot_tractor", &"robot_truck"]

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE * 4, SIZE * 4)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_8X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	environment.environment.ambient_light_energy = 0.6
	_viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

	for id: StringName in ITEMS:
		var model := _load_glb(MODELS + ITEMS[id][0])
		if model == null:
			continue
		if PERMIT_TINT.has(id):
			_tint(model, PERMIT_TINT[id])
		await _save(id, model, ITEMS[id][1])
	for id: StringName in ROBOTS:
		# Carregado na hora: o script do robô depende dos autoloads (não compila junto deste).
		var robot: Node3D = load("res://scripts/automation/collector_robot.gd").new()
		robot.set("definition", load("res://data/automation/%s.tres" % id))
		robot.process_mode = Node.PROCESS_MODE_DISABLED
		await _save(id, robot, Vector3(0.8, 0.9, 1.0))
	print("Ícones salvos em %s" % OUT)
	quit()


func _load_glb(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		push_error("Não abriu %s" % path)
		return null
	return document.generate_scene(state) as Node3D


static func _tint(model: Node3D, color: Color) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.8
		(node as MeshInstance3D).material_override = material


func _save(id: StringName, model: Node3D, view: Vector3) -> void:
	for child in _stage.get_children():
		child.free()
	_stage.add_child(model)
	await process_frame
	var box := _bounds(model)
	model.position = -box.get_center()
	var radius := box.size.length() * 0.5
	var distance := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 1.02
	_camera.look_at_from_position(view.normalized() * distance, Vector3.ZERO)
	_camera.near = maxf(distance - radius * 2.0, 0.001)
	_camera.far = distance + radius * 2.0
	for i in 3:
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	# Recorta pela área ocupada, num quadrado com margem.
	var used := image.get_used_rect()
	var side := int(maxf(used.size.x, used.size.y) * 1.12)
	var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	square.blit_rect(image, Rect2i(used.get_center() - Vector2i(side, side) / 2, Vector2i(side, side)), Vector2i.ZERO)
	square.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	ToolIcons._outline(square)
	square.save_png(ProjectSettings.globalize_path(OUT + "%s.png" % id))


static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_instance as MeshInstance3D
		if instance.mesh == null:
			continue
		var part := instance.global_transform * instance.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box
