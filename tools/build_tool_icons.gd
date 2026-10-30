extends SceneTree
## Gera assets/ui/tool_icons/<id>.png: cada ferramenta do catálogo fotografada a partir do
## próprio modelo 3D (fundo transparente), com a cor da variante. Variantes do mesmo grupo
## usam o mesmo enquadramento (o da maior), então o ímã pequeno aparece um pouco menor.
## Um contorno claro ajuda a ler o ícone sobre os painéis escuros.
## Precisa de placa de vídeo (não roda com --headless):
##   godot --path . --script res://tools/build_tool_icons.gd

const OUT := "res://assets/ui/tool_icons/"
const SIZE := 128
## Nós que não fazem parte do visual da ferramenta parada.
const SKIP := ["Line", "Preview", "Ring", "Stuck", "Arm"]
## De onde a câmera olha cada tipo (as ferramentas apontam para -z, como na mão do jogador).
const VIEWS := {
	&"magnet": Vector3(0.35, 1.0, 0.5),
	&"shovel": Vector3(0.6, 1.0, 0.35),
	&"hands": Vector3(0.5, 0.9, 0.6),
}

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

	var catalog := ToolCatalog.get_default()
	for group in catalog.groups():
		var variants := catalog.variants(group)
		var biggest := 0.0
		for definition in variants:
			biggest = maxf(biggest, definition.visual_scale)
		# Mesmo recorte para o grupo inteiro (o da área ocupada por todas as variantes).
		var images: Array[Image] = []
		var used := Rect2i()
		for definition in variants:
			var image: Image = await _render(definition, lerpf(0.75, 1.0, definition.visual_scale / biggest), VIEWS.get(group, Vector3(1, 0.35, 0.2)))
			images.append(image)
			var part := image.get_used_rect()
			used = part if used.size == Vector2i.ZERO else used.merge(part)
		var side := int(maxf(used.size.x, used.size.y) * 1.12)
		var corner := used.get_center() - Vector2i(side, side) / 2
		for i in variants.size():
			var square := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
			square.blit_rect(images[i], Rect2i(corner, Vector2i(side, side)), Vector2i.ZERO)
			square.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			_outline(square)
			square.save_png(ProjectSettings.globalize_path(OUT + "%s.png" % variants[i].id))
	print("Ícones salvos em %s" % OUT)
	quit()


func _render(definition: ToolDefinition, relative: float, view: Vector3) -> Image:
	_stage.scale = Vector3.ONE
	for child in _stage.get_children():
		child.free()
	var model: Node3D = definition.scene.instantiate()
	# O _ready da ferramenta aplica cor e modelo da variante; sem processar, não precisa de
	# jogador nem mundo.
	model.set("definition", definition)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	_stage.add_child(model)
	# A escala do visual fica por conta do enquadramento (relative).
	for child in model.get_children():
		if child is Node3D and child.name in ["Hand", "Magnet", "Visual"]:
			(child as Node3D).scale = Vector3.ONE
	for path in SKIP:
		var node := model.find_child(path, true, false)
		if node != null:
			node.queue_free()
	await process_frame
	# Enquadra pela caixa do modelo em tamanho cheio; depois aplica a escala relativa.
	var box := _bounds(model)
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	model.position = -center
	_stage.scale = Vector3.ONE * relative
	var direction := view.normalized()
	var distance := radius / sin(deg_to_rad(_camera.fov * 0.5)) * 1.02
	_camera.look_at_from_position(direction * distance, Vector3.ZERO)
	# Inclina a imagem: o comprimento da ferramenta fica na diagonal.
	_camera.rotate_object_local(Vector3.BACK, deg_to_rad(-35.0))
	_camera.near = maxf(distance - radius * 2.0, 0.01)
	_camera.far = distance + radius * 2.0
	for i in 3:
		await process_frame
	var image := _viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Contorno claro de 2 px em volta do desenho, para ler bem sobre fundo escuro.
static func _outline(image: Image) -> void:
	var source := image.duplicate() as Image
	var edge := Color(1, 0.97, 0.88)
	for y in image.get_height():
		for x in image.get_width():
			var own := source.get_pixel(x, y)
			if own.a >= 0.99:
				continue
			var near := 0.0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < image.get_width() and ny < image.get_height():
						near = maxf(near, source.get_pixel(nx, ny).a)
			if near > 0.0:
				# Desenho por cima do contorno, preservando a borda suave.
				var outline := Color(edge, near * 0.9)
				image.set_pixel(x, y, outline.blend(own))


static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh_instance as MeshInstance3D
		if instance.mesh == null or instance.is_queued_for_deletion():
			continue
		var part := instance.global_transform * instance.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box
