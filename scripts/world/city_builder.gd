class_name CityBuilder
extends Node3D
## Monta a geometria da cidade a partir do CityLayout: chão, gramado, calçadas, prédios, marcos
## (LandmarkBuilder), árvores,
## carros, postes, semáforos, placas, caçambas, floreiras, cones, muros, cercas dos bairros e
## pontos de serviço (depósito + loja).
## Tudo que se repete é desenhado por MultiMesh; colisões são formas simples.

const ASPHALT_MATERIAL := preload("res://assets/textures/city/asphalt_material.tres")
const CONCRETE_MATERIAL := preload("res://assets/textures/city/concrete_material.tres")
const DEPOSIT_SCENE := preload("res://scenes/world/deposit_point.tscn")
const KIOSK_SCENE := preload("res://scenes/world/shop_kiosk.tscn")
const BUILDING_SHADER := preload("res://assets/shaders/building.gdshader")
const LAWN_SHADER := preload("res://assets/shaders/lawn.gdshader")
const TREE_SCENE := "res://assets/third_party/kenney/city-kit-suburban/tree-large.glb"
const SMALL_TREE_SCENE := "res://assets/third_party/kenney/city-kit-suburban/tree-small.glb"
const TREE_COLORMAP := "res://assets/third_party/kenney/city-kit-suburban/Textures/colormap.png"
const TREE_TINT_SHADER := preload("res://assets/shaders/tree_tint.gdshader")
## Ipês (a cara de Brasília): fração das árvores e as cores da copa (amarelo, roxo, branco).
const IPE_SHARE := 22
const IPE_COLORS := [Color(1.0, 0.8, 0.12), Color(0.86, 0.36, 0.72), Color(0.96, 0.94, 0.9)]
## Flores das floreiras floridas: vermelho, amarelo, rosa e lilás.
const FLOWER_COLORS := [Color(0.9, 0.2, 0.25), Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.75), Color(0.7, 0.5, 1.0)]
## Coisas rentes ao chão ou pequenas: a sombra delas não aparece, mas custa uma chamada de
## desenho por cascata de sombra.
const NO_SHADOW := ["Slabs_", "CenterLines", "LaneLines", "Crosswalks", "RoofUnits", "WaterTanks", "Bench_legs",
	"Bins", "BinLids", "BusStopPosts", "BusStopSigns", "Hydrants", "HydrantCaps"]
## Distância (m) até onde os pontos de serviço (loja, depósito, portal) são desenhados; os
## detalhes pequenos (mercadoria, faíscas) somem bem antes, dentro de cada um.
const HUB_VISIBLE := 350.0
## Objetos de rua do CityLayout: tipo -> [modelo, escala].
const PROP_SCENES := {
	&"traffic_light": ["res://assets/third_party/kenney/city-kit-roads/traffic-light.glb", 9.0],
	&"stop_sign": ["res://assets/third_party/kenney/city-kit-roads/road-sign-stop.glb", 5.5],
	&"dumpster": ["res://assets/third_party/kenney/city-kit-roads/dumpster.glb", 6.0],
	&"cone": ["res://assets/third_party/kenney/city-kit-roads/construction-cone.glb", 7.0],
	&"planter": ["res://assets/third_party/kenney/city-kit-suburban/planter.glb", 6.0],
}
## Colisão de objetos finos que não bloqueiam moedas (raio 0 no CityLayout): o jogador não
## atravessa, mas o sorteio das pilhas (e a assinatura do mundo) fica igual.
const THIN_PROP_RADII := {&"stop_sign": 0.12, &"cone": 0.3}
const LAMP_SCENE := "res://assets/third_party/kenney/city-kit-roads/light-curved.glb"
const BARRIER_SCENE := "res://assets/third_party/kenney/city-kit-roads/construction-barrier.glb"
const CAR_SCENES := [
	"res://assets/third_party/kenney/car-kit/sedan.glb",
	"res://assets/third_party/kenney/car-kit/suv.glb",
	"res://assets/third_party/kenney/car-kit/taxi.glb",
	"res://assets/third_party/kenney/car-kit/hatchback-sports.glb",
	"res://assets/third_party/kenney/car-kit/van.glb",
]
const BUILDING_COLORS := [
	Color(0.72, 0.5, 0.4), Color(0.62, 0.64, 0.68), Color(0.85, 0.78, 0.62),
	Color(0.5, 0.58, 0.66), Color(0.78, 0.66, 0.5), Color(0.55, 0.52, 0.48),
	# 6: blocos dos ministérios. Alfa < 0,75 liga o "modo ministério" do shader de fachada
	# (pontas brancas cegas, vidro verde nas fachadas compridas, pilotis no térreo).
	Color(0.9, 0.91, 0.88, 0.5),
]
const FENCE_HEIGHT := 3.0

@export var definition: WorldDefinition

var layout: CityLayout
## id do bairro -> nó da cerca que o separa do bairro anterior.
var fences := {}
## Um corpo estático por quarteirão (chão elevado, prédios e objetos). Corpos pequenos
## evitam que o motor físico recalcule uma forma composta gigante a cada forma adicionada.
var _block_bodies := {}
## Fachadas (o ciclo de dia e noite acende as janelas) e postes (onde ficam as luzes).
var building_material: ShaderMaterial
var lamp_transforms: Array[Transform3D] = []


func _ready() -> void:
	if definition == null:
		definition = WorldDefinition.get_default()
	layout = CityLayout.for_definition(definition)
	_build_ground()
	_build_blocks()
	LandmarkBuilder.build_all(self, layout, building_material)
	_build_props()
	_build_road_markings()
	# As formas já estão nos corpos; cada corpo entra na cena uma vez só.
	for body: StaticBody3D in _block_bodies.values():
		add_child(body)
	_build_edges()
	_build_backdrop()
	_build_fences()
	_build_hubs()
	GameState.tools_changed.connect(_refresh_fences)
	_refresh_fences()
	Settings.changed.connect(_apply_quality)
	_apply_quality()
	var day_night := DayNight.new()
	day_night.name = "DayNight"
	day_night.setup($Sun, ($WorldEnvironment as WorldEnvironment).environment, building_material, lamp_transforms)
	add_child(day_night)


## Efeitos (aba Vídeo): Baixa tira SSAO e brilho e encurta as sombras; Média tira só o SSAO;
## Alta liga tudo; Ultra alonga as sombras e suaviza a sombra de contato.
func _apply_quality() -> void:
	var quality := Settings.quality_index
	var environment := get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if environment != null and environment.environment != null:
		environment.environment.ssao_enabled = quality >= 2
		environment.environment.glow_enabled = quality >= 1
		RenderingServer.environment_set_ssao_quality(
			RenderingServer.ENV_SSAO_QUALITY_HIGH if quality >= 3 else RenderingServer.ENV_SSAO_QUALITY_LOW, quality < 3, 0.5, 2, 50, 300)
	var sun := get_node_or_null(^"Sun") as DirectionalLight3D
	if sun != null:
		sun.directional_shadow_max_distance = [50.0, 80.0, 120.0, 180.0][quality]
		sun.shadow_blur = 1.0 if quality == 0 else 1.5


## Cerca do bairro ainda presente? (bloqueia a passagem até comprar a licença)
func is_fenced(district_id: StringName) -> bool:
	return fences.has(district_id) and is_instance_valid(fences[district_id]) and (fences[district_id] as Node3D).visible


func _refresh_fences() -> void:
	for district in definition.districts:
		var fence: Node3D = fences.get(district.id)
		if fence == null:
			continue
		var open := GameState.is_district_unlocked(district)
		fence.visible = not open
		# Sem colisão quando liberado (o nó continua para poder fechar de novo num "novo jogo").
		for shape in fence.find_children("*", "CollisionShape3D", true, false):
			(shape as CollisionShape3D).disabled = open


func _build_ground() -> void:
	var size := Vector3(definition.world_size_x(), 0.2, definition.world_size_z())
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = ASPHALT_MATERIAL
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.position.y = -0.1
	add_child(ground)
	_static_box("GroundBody", Vector3(0, -0.1, 0), size)


## Piso de cada lote: concreto nos quarteirões comuns, grama na Esplanada, pedra na Praça.
static func _ground_materials() -> Dictionary:
	var lawn := ShaderMaterial.new()
	lawn.shader = LAWN_SHADER
	var paved := CONCRETE_MATERIAL.duplicate() as StandardMaterial3D
	paved.albedo_color = Color(0.92, 0.9, 0.84)
	return {&"concrete": CONCRETE_MATERIAL, &"lawn": lawn, &"paved": paved}


func _surface_of(key: Vector2i) -> StringName:
	var landmark := layout.landmark_at(key)
	if not landmark.is_empty() and landmark.kind in [&"bus_station", &"tv_tower"]:
		return &"paved"
	if layout.is_lawn(key):
		return &"lawn"
	if layout.is_paved(key):
		return &"paved"
	return &"concrete"


func _build_blocks() -> void:
	var slab_height := definition.curb_height + 0.2
	var materials := _ground_materials()
	var slabs := {}   # piso -> Array[Transform3D]
	for surface: StringName in materials:
		slabs[surface] = [] as Array[Transform3D]
	var building_transforms: Array[Transform3D] = []
	var building_colors: Array[Color] = []
	var roof_transforms: Array[Transform3D] = []
	var units: Array[Transform3D] = []
	var tanks: Array[Transform3D] = []
	var rooftop_rng := RandomNumberGenerator.new()
	rooftop_rng.seed = definition.random_seed + 7
	for key: Vector2i in layout.blocks:
		var bodies := _body_for(key)
		var lot := layout.lot_rect(key)
		var center := Vector3(lot.get_center().x, definition.curb_height - slab_height * 0.5, lot.get_center().y)
		var slab_size := Vector3(lot.size.x, slab_height, lot.size.y)
		(slabs[_surface_of(key)] as Array).append(Transform3D(Basis.from_scale(slab_size), center))
		var slab_shape := BoxShape3D.new()
		slab_shape.size = slab_size
		_add_shape(bodies, slab_shape, center)
		var info: Dictionary = layout.blocks[key]
		for building: Dictionary in info.buildings:
			var rect: Rect2 = building.rect
			var height: float = building.height
			var middle := Vector3(rect.get_center().x, definition.curb_height + height * 0.5, rect.get_center().y)
			building_transforms.append(Transform3D(Basis.from_scale(Vector3(rect.size.x, height, rect.size.y)), middle))
			building_colors.append(BUILDING_COLORS[building.color])
			roof_transforms.append(Transform3D(Basis.from_scale(Vector3(rect.size.x + 0.4, 0.3, rect.size.y + 0.4)),
				Vector3(middle.x, definition.curb_height + height + 0.15, middle.z)))
			_add_rooftop(rect, definition.curb_height + height + 0.3, rooftop_rng, units, tanks)
			var shape := BoxShape3D.new()
			shape.size = Vector3(rect.size.x, height, rect.size.y)
			_add_shape(bodies, shape, middle)
	for surface: StringName in materials:
		var mesh := BoxMesh.new()
		mesh.material = materials[surface]
		var list: Array[Transform3D] = []
		list.assign(slabs[surface])
		_multimesh("Slabs_%s" % surface, mesh, list)
	var box := BoxMesh.new()
	building_material = ShaderMaterial.new()
	building_material.shader = BUILDING_SHADER
	box.material = building_material
	_multimesh("Buildings", box, building_transforms, building_colors)
	_multimesh("Roofs", _box_mesh(Color(0.25, 0.24, 0.24), 1.0), roof_transforms)
	_multimesh("RoofUnits", _box_mesh(Color(0.7, 0.71, 0.72), 0.6), units)
	_multimesh("WaterTanks", _tank_mesh(), tanks)


## Caixa unitária (escalada por instância) com cor chapada.
static func _box_mesh(color: Color, roughness: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh.material = material
	return mesh


## Caixa d'água azul (cilindro unitário, escalado por instância).
static func _tank_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.55
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.42, 0.75)
	material.roughness = 0.5
	mesh.material = material
	return mesh


## Aparelhos de ar-condicionado e, às vezes, uma caixa d'água azul no telhado.
func _add_rooftop(rect: Rect2, top: float, rng: RandomNumberGenerator, units: Array[Transform3D], tanks: Array[Transform3D]) -> void:
	var inner := rect.grow(-1.5)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	for i in rng.randi_range(1, 3):
		var size := Vector3(rng.randf_range(0.8, 1.6), rng.randf_range(0.5, 0.9), rng.randf_range(0.8, 1.4))
		var spot := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		units.append(Transform3D(Basis.from_scale(size), Vector3(spot.x, top + size.y * 0.5, spot.y)))
	if rng.randf() < 0.6:
		var spot := inner.position + Vector2(rng.randf(), rng.randf()) * inner.size
		var scale := rng.randf_range(1.6, 2.4)
		tanks.append(Transform3D(Basis.from_scale(Vector3(scale, scale * 0.8, scale)), Vector3(spot.x, top + scale * 0.4, spot.y)))


## Faixas: amarela tracejada no meio de cada rua, brancas nas avenidas do eixo, e faixas de
## pedestre nas pontas de cada trecho de rua que cruza outra.
func _build_road_markings() -> void:
	var dashes: Array[Transform3D] = []
	var lanes: Array[Transform3D] = []
	var zebra: Array[Transform3D] = []
	var size := definition.block_size
	var x0 := -layout.half_x
	var z0 := -layout.half_z
	# Ruas ao longo de x (entre as linhas k-1 e k).
	for k in range(1, definition.blocks_z):
		var line := z0 + k * size
		for bx in definition.blocks_x:
			var half := layout.margins(Vector2i(bx, k))[1]
			if half <= 0.0:
				continue
			var from := x0 + bx * size + maxf(_v_road(bx, k - 1), _v_road(bx, k)) + 2.0
			var to := x0 + (bx + 1) * size - maxf(_v_road(bx + 1, k - 1), _v_road(bx + 1, k)) - 2.0
			_dash_line(dashes, Vector2(from, line), Vector2(to, line))
			if half > definition.road_half_width:
				for offset: float in [-half * 0.5, half * 0.5]:
					_dash_line(lanes, Vector2(from, line + offset), Vector2(to, line + offset))
	# Ruas ao longo de z (entre as colunas k-1 e k), trecho por linha.
	for k in range(1, definition.blocks_x):
		var line := x0 + k * size
		for bz in definition.blocks_z:
			if _v_road(k, bz) <= 0.0:
				continue
			var m := layout.margins(Vector2i(k, bz))
			var top := z0 + bz * size + m[1]
			var bottom := z0 + (bz + 1) * size - m[3]
			_dash_line(dashes, Vector2(line, top + 3.5), Vector2(line, bottom - 3.5))
			for end: float in [top + 1.6, bottom - 1.6]:
				_crosswalk(zebra, Vector2(line, end))
	_multimesh("CenterLines", _marking_mesh(Color(0.92, 0.75, 0.2)), dashes)
	_multimesh("LaneLines", _marking_mesh(Color(0.88, 0.88, 0.85)), lanes)
	_multimesh("Crosswalks", _marking_mesh(Color(0.88, 0.88, 0.85)), zebra)


## Meia largura da rua entre as colunas k-1 e k na linha `row` (0 no gramado e nas praças dos marcos).
func _v_road(k: int, row: int) -> float:
	if k <= 0 or k >= definition.blocks_x or row < 0 or row >= definition.blocks_z:
		return 0.0
	return layout.margins(Vector2i(k, row))[0]


## Traços de 2 m a cada 4 m de `from` a `to` (uma reta paralela a x ou a z).
static func _dash_line(out: Array[Transform3D], from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	if length < 2.0:
		return
	var direction := (to - from) / length
	var along_x := absf(direction.x) > 0.5
	var t := 0.0
	while t + 2.0 <= length:
		var center := from + direction * (t + 1.0)
		var scale := Vector3(2.0, 1.0, 0.18) if along_x else Vector3(0.18, 1.0, 2.0)
		out.append(Transform3D(Basis.from_scale(scale), Vector3(center.x, 0.006, center.y)))
		t += 4.0


## Faixa de pedestre atravessando uma rua ao longo de z, no ponto `at`.
func _crosswalk(out: Array[Transform3D], at: Vector2) -> void:
	var road := definition.road_half_width
	var stripe := -road + 0.6
	while stripe < road - 0.4:
		out.append(Transform3D(Basis.from_scale(Vector3(0.45, 1.0, 2.4)), Vector3(at.x + stripe, 0.006, at.y)))
		stripe += 0.9


static func _marking_mesh(color: Color) -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	plane.material = material
	return plane


func _build_props() -> void:
	# Listas de transformações por tipo de objeto, preenchidas quarteirão a quarteirão.
	var placed := {&"trees": [] as Array[Transform3D], &"small_trees": [] as Array[Transform3D], &"props": {}, &"cars": [],
		&"ipes": [] as Array[Transform3D], &"ipes_colors": [] as Array[Color], &"small_ipes": [] as Array[Transform3D], &"small_ipes_colors": [] as Array[Color],
		&"flowers": [] as Array[Transform3D], &"flowers_colors": [] as Array[Color]}
	for kind: StringName in PROP_SCENES:
		placed.props[kind] = [] as Array[Transform3D]
	for i in CAR_SCENES.size():
		placed.cars.append([] as Array[Transform3D])
	var rng := RandomNumberGenerator.new()
	rng.seed = definition.random_seed
	var shapes := _prop_shapes()
	for key: Vector2i in layout.blocks:
		_place_block_props(key, layout.blocks[key], rng, shapes, placed)
	_scene_multimesh("Trees", TREE_SCENE, placed.trees)
	_scene_multimesh("SmallTrees", SMALL_TREE_SCENE, placed.small_trees)
	var ipe_material := ShaderMaterial.new()
	ipe_material.shader = TREE_TINT_SHADER
	ipe_material.set_shader_parameter(&"colormap", load(TREE_COLORMAP))
	_scene_multimesh("Ipes", TREE_SCENE, placed.ipes, null, placed.ipes_colors, ipe_material)
	_scene_multimesh("SmallIpes", SMALL_TREE_SCENE, placed.small_ipes, null, placed.small_ipes_colors, ipe_material)
	_scene_multimesh("FlowerPlanters", PROP_SCENES[&"planter"][0], placed.flowers, null, placed.flowers_colors, ipe_material)
	for kind: StringName in PROP_SCENES:
		var list: Array[Transform3D] = []
		list.assign(placed.props[kind])
		_scene_multimesh("Props_%s" % kind, PROP_SCENES[kind][0], list)
	for i in CAR_SCENES.size():
		var list: Array[Transform3D] = []
		list.assign(placed.cars[i])
		_scene_multimesh("Cars%d" % i, CAR_SCENES[i], list)
	_build_lamps(shapes.lamp)
	_build_furniture()


## Formas de colisão compartilhadas (árvore, poste, carro).
static func _prop_shapes() -> Dictionary:
	var tree := CylinderShape3D.new()
	tree.radius = 0.25
	tree.height = 4.0
	var lamp := CylinderShape3D.new()
	lamp.radius = 0.15
	lamp.height = 6.0
	var car := BoxShape3D.new()
	car.size = Vector3(CityLayout.CAR_SIZE.x, 1.6, CityLayout.CAR_SIZE.y)
	return {"tree": tree, "lamp": lamp, "car": car}


## Árvores, objetos de rua e carros de um quarteirão, com as colisões no corpo dele.
func _place_block_props(key: Vector2i, info: Dictionary, rng: RandomNumberGenerator, shapes: Dictionary, placed: Dictionary) -> void:
	var bodies := _body_for(key)
	for tree: Vector2 in info.trees:
		var pos := Vector3(tree.x, definition.curb_height, tree.y)
		_add_tree(placed, &"trees", &"ipes", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(6.5, 9.0)), pos))
		_add_shape(bodies, shapes.tree, pos + Vector3.UP * 2.0)
	for tree: Vector2 in info.small_trees:
		var pos := Vector3(tree.x, definition.curb_height, tree.y)
		_add_tree(placed, &"small_trees", &"small_ipes", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(6.0, 8.0)), pos))
		_add_shape(bodies, shapes.tree, pos + Vector3.UP * 2.0)
	for prop: Dictionary in info.props:
		var pos := Vector3(prop.pos.x, layout.ground_height(prop.pos.x, prop.pos.y), prop.pos.y)
		var scale: float = PROP_SCENES[prop.kind][1]
		var xform := Transform3D(Basis(Vector3.UP, prop.yaw).scaled(Vector3.ONE * scale), pos)
		# Metade das floreiras florida (pela posição, como os ipês).
		var spot := absi(hash(Vector2i(roundi(pos.x * 10.0), roundi(pos.z * 10.0))))
		if prop.kind == &"planter" and spot % 2 == 0:
			(placed.flowers as Array).append(xform)
			(placed.flowers_colors as Array).append(FLOWER_COLORS[(spot >> 1) % FLOWER_COLORS.size()])
		else:
			(placed.props[prop.kind] as Array).append(xform)
		var radius: float = prop.radius if prop.radius > 0.0 else THIN_PROP_RADII.get(prop.kind, 0.0)
		if radius > 0.0:
			var shape := CylinderShape3D.new()
			shape.radius = radius
			shape.height = 2.0
			_add_shape(bodies, shape, pos + Vector3.UP)
	for car: Rect2 in info.cars:
		var pos := Vector3(car.get_center().x, definition.curb_height, car.get_center().y)
		var flip := PI if rng.randf() < 0.5 else 0.0
		var cars: Array = placed.cars
		(cars[rng.randi() % cars.size()] as Array).append(Transform3D(Basis(Vector3.UP, flip).scaled(Vector3.ONE * 1.25), pos))
		_add_shape(bodies, shapes.car, pos + Vector3.UP * 0.8)


## Árvore comum ou ipê. A escolha vem da posição (não do sorteio), para não mudar mais nada da
## cidade; a cor também.
static func _add_tree(placed: Dictionary, normal: StringName, ipe: StringName, xform: Transform3D) -> void:
	var spot := absi(hash(Vector2i(roundi(xform.origin.x * 10.0), roundi(xform.origin.z * 10.0))))
	if spot % 100 >= IPE_SHARE:
		(placed[normal] as Array).append(xform)
		return
	(placed[ipe] as Array).append(xform)
	# Branco é o mais raro.
	var color: Color = IPE_COLORS[0 if spot % 7 < 3 else (1 if spot % 7 < 6 else 2)]
	(placed[StringName(String(ipe) + "_colors")] as Array).append(color)


## Bancos (assento e encosto de madeira, pés de metal) e lixeiras verdes, com colisão só para
## o jogador (não bloqueiam moedas).
func _build_furniture() -> void:
	var parts := {&"seat": [] as Array[Transform3D], &"back": [] as Array[Transform3D], &"legs": [] as Array[Transform3D],
		&"bins": [] as Array[Transform3D], &"lids": [] as Array[Transform3D],
		&"roofs": [] as Array[Transform3D], &"glass": [] as Array[Transform3D], &"posts": [] as Array[Transform3D],
		&"plates": [] as Array[Transform3D], &"hydrants": [] as Array[Transform3D], &"hydrant_caps": [] as Array[Transform3D]}
	var bench_shape := BoxShape3D.new()
	bench_shape.size = Vector3(1.7, 0.9, 0.55)
	var bin_shape := CylinderShape3D.new()
	bin_shape.radius = 0.3
	bin_shape.height = 0.9
	var ground := definition.curb_height
	for key: Vector2i in layout.blocks:
		var info: Dictionary = layout.blocks[key]
		for bench: Dictionary in info.benches:
			var at := Transform3D(Basis(Vector3.UP, bench.yaw), Vector3(bench.pos.x, ground, bench.pos.y))
			(parts.seat as Array).append(at * Transform3D(Basis.from_scale(Vector3(1.6, 0.07, 0.45)), Vector3(0, 0.45, 0)))
			(parts.back as Array).append(at * Transform3D(Basis(Vector3.RIGHT, -0.15).scaled(Vector3(1.6, 0.35, 0.06)), Vector3(0, 0.78, -0.21)))
			for x: float in [-0.68, 0.68]:
				(parts.legs as Array).append(at * Transform3D(Basis.from_scale(Vector3(0.07, 0.45, 0.42)), Vector3(x, 0.225, 0)))
			var body := _body_for(key)
			var collision := CollisionShape3D.new()
			collision.shape = bench_shape
			collision.transform = at * Transform3D(Basis(), Vector3(0, 0.45, 0))
			body.add_child(collision)
		for stop: Dictionary in info.bus_stops:
			_add_bus_stop(key, Transform3D(Basis(Vector3.UP, stop.yaw), Vector3(stop.pos.x, ground, stop.pos.y)), parts)
		for hydrant: Vector2 in info.hydrants:
			var spot := Vector3(hydrant.x, ground, hydrant.y)
			(parts.hydrants as Array).append(Transform3D(Basis.from_scale(Vector3(0.28, 0.55, 0.28)), spot + Vector3.UP * 0.28))
			(parts.hydrant_caps as Array).append(Transform3D(Basis.from_scale(Vector3(0.42, 0.09, 0.12)), spot + Vector3.UP * 0.4))
			(parts.hydrant_caps as Array).append(Transform3D(Basis.from_scale(Vector3(0.2, 0.08, 0.2)), spot + Vector3.UP * 0.6))
			_add_shape(_body_for(key), bin_shape, spot + Vector3.UP * 0.45)
		for bin: Vector2 in info.bins:
			var pos := Vector3(bin.x, ground, bin.y)
			(parts.bins as Array).append(Transform3D(Basis.from_scale(Vector3(0.55, 0.8, 0.55)), pos + Vector3.UP * 0.4))
			(parts.lids as Array).append(Transform3D(Basis.from_scale(Vector3(0.6, 0.06, 0.6)), pos + Vector3.UP * 0.83))
			_add_shape(_body_for(key), bin_shape, pos + Vector3.UP * 0.45)
	var wood := _box_mesh(Color(0.58, 0.38, 0.2), 0.8)
	var metal := _box_mesh(Color(0.2, 0.21, 0.23), 0.5)
	for name: StringName in [&"seat", &"back"]:
		_multimesh_list("Bench_%s" % name, wood, parts[name])
	_multimesh_list("Bench_legs", metal, parts.legs)
	var bin_mesh := _tank_mesh()
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.2, 0.45, 0.27)
	green.roughness = 0.7
	bin_mesh.material = green
	_multimesh_list("Bins", bin_mesh, parts.bins)
	_multimesh_list("BinLids", _box_mesh(Color(0.15, 0.16, 0.17), 0.6), parts.lids)
	_multimesh_list("BusStopRoofs", _box_mesh(Color(0.85, 0.86, 0.88), 0.5), parts.roofs)
	_multimesh_list("BusStopPosts", metal, parts.posts)
	var glass := BoxMesh.new()
	var glass_material := StandardMaterial3D.new()
	glass_material.albedo_color = Color(0.6, 0.8, 0.95, 0.35)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.roughness = 0.1
	glass.material = glass_material
	_multimesh_list("BusStopGlass", glass, parts.glass)
	_multimesh_list("BusStopSigns", _box_mesh(Color(0.15, 0.35, 0.8), 0.4), parts.plates)
	var hydrant := _tank_mesh()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.82, 0.12, 0.1)
	red.roughness = 0.5
	hydrant.material = red
	_multimesh_list("Hydrants", hydrant, parts.hydrants)
	_multimesh_list("HydrantCaps", _box_mesh(Color(0.72, 0.1, 0.08), 0.5), parts.hydrant_caps)


## Ponto de ônibus (frente aberta para +z local): cobertura, vidro no fundo, quatro postes, banco e
## a placa azul no poste ao lado. Colisão só no fundo (dá para entrar embaixo da cobertura).
func _add_bus_stop(key: Vector2i, at: Transform3D, parts: Dictionary) -> void:
	(parts.roofs as Array).append(at * Transform3D(Basis.from_scale(Vector3(3.2, 0.12, 1.5)), Vector3(0, 2.45, 0)))
	(parts.glass as Array).append(at * Transform3D(Basis.from_scale(Vector3(3.0, 1.7, 0.05)), Vector3(0, 1.3, -0.65)))
	for x: float in [-1.5, 1.5]:
		for z: float in [-0.65, 0.6]:
			(parts.posts as Array).append(at * Transform3D(Basis.from_scale(Vector3(0.08, 2.4, 0.08)), Vector3(x, 1.2, z)))
	(parts.seat as Array).append(at * Transform3D(Basis.from_scale(Vector3(2.4, 0.06, 0.4)), Vector3(0, 0.45, -0.35)))
	for x: float in [-1.0, 1.0]:
		(parts.legs as Array).append(at * Transform3D(Basis.from_scale(Vector3(0.06, 0.45, 0.36)), Vector3(x, 0.225, -0.35)))
	(parts.posts as Array).append(at * Transform3D(Basis.from_scale(Vector3(0.06, 2.7, 0.06)), Vector3(2.0, 1.35, 0.5)))
	(parts.plates as Array).append(at * Transform3D(Basis.from_scale(Vector3(0.5, 0.36, 0.04)), Vector3(2.0, 2.55, 0.5)))
	var back := BoxShape3D.new()
	back.size = Vector3(3.2, 2.4, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = back
	collision.transform = at * Transform3D(Basis(), Vector3(0, 1.2, -0.65))
	_body_for(key).add_child(collision)


func _multimesh_list(node_name: String, mesh: Mesh, list: Array) -> void:
	var typed: Array[Transform3D] = []
	typed.assign(list)
	_multimesh(node_name, mesh, typed)


## Postes de todos os quarteirões (o ciclo de dia e noite usa as posições para as luzes).
func _build_lamps(shape: Shape3D) -> void:
	var lamps: Array[Transform3D] = []
	for i in layout.lamps.size():
		var lamp := layout.lamps[i]
		# Braço do poste virado para a rua mais perto (o traçado diz a direção).
		lamps.append(Transform3D(Basis(Vector3.UP, layout.lamp_yaws[i]).scaled(Vector3.ONE * 9.0), lamp))
		_add_shape(_body_for(layout.block_of(lamp.x, lamp.z)), shape, lamp + Vector3.UP * 3.0)
	_scene_multimesh("Lamps", LAMP_SCENE, lamps)
	lamp_transforms = lamps


func _build_edges() -> void:
	var size_x := definition.world_size_x()
	var size_z := definition.world_size_z()
	# [centro, tamanho] de cada muro: norte, sul, oeste e leste.
	var walls := [
		[Vector3(0, 3.0, -layout.half_z - 0.5), Vector3(size_x + 2.0, 6.0, 1.0)],
		[Vector3(0, 3.0, layout.half_z + 0.5), Vector3(size_x + 2.0, 6.0, 1.0)],
		[Vector3(-layout.half_x - 0.5, 3.0, 0), Vector3(1.0, 6.0, size_z + 2.0)],
		[Vector3(layout.half_x + 0.5, 3.0, 0), Vector3(1.0, 6.0, size_z + 2.0)],
	]
	for i in walls.size():
		var mesh := BoxMesh.new()
		mesh.size = walls[i][1]
		mesh.material = CONCRETE_MATERIAL
		var wall := MeshInstance3D.new()
		wall.mesh = mesh
		wall.position = walls[i][0]
		add_child(wall)
		_static_box("Edge%d" % i, walls[i][0], walls[i][1])


## Cercas nas bordas entre quarteirões de bairros diferentes. Cada borda pertence ao bairro mais
## rico dos dois lados: some quando a licença dele é comprada.
func _build_fences() -> void:
	var segments := {}   # índice do bairro -> Array de [início, fim] (Vector2)
	var size := definition.block_size
	for key: Vector2i in layout.blocks:
		var here := layout.district_index_of(key)
		var origin := layout.block_origin(key)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other := key + step
			if not layout.is_valid_block(other):
				continue
			var there := layout.district_index_of(other)
			if there == here:
				continue
			var owner := maxi(here, there)
			var start := origin + Vector2(size, 0) if step.x == 1 else origin + Vector2(0, size)
			if not segments.has(owner):
				segments[owner] = []
			segments[owner].append([start, origin + Vector2(size, size)])
	for owner: int in segments:
		var district := definition.districts[owner]
		var fence := StaticBody3D.new()
		fence.name = "Fence_%s" % district.id
		add_child(fence)
		var barriers: Array[Transform3D] = []
		for segment: Array in segments[owner]:
			_add_fence_segment(fence, barriers, segment[0], segment[1], district)
		_scene_multimesh("Barriers", BARRIER_SCENE, barriers, fence)
		fences[district.id] = fence


func _add_fence_segment(fence: StaticBody3D, barriers: Array[Transform3D], start: Vector2, end: Vector2, district: DistrictDefinition) -> void:
	var along_x := absf(end.x - start.x) > 0.5
	var length := start.distance_to(end)
	var middle := (start + end) * 0.5
	var ground := layout.ground_height(middle.x, middle.y)
	var shape := BoxShape3D.new()
	shape.size = Vector3(length + 0.4, FENCE_HEIGHT, 0.4) if along_x else Vector3(0.4, FENCE_HEIGHT, length + 0.4)
	_add_shape(fence, shape, Vector3(middle.x, ground + FENCE_HEIGHT * 0.5, middle.y))
	var t := 0.0
	while t <= length:
		var at := start.lerp(end, t / length)
		barriers.append(Transform3D(Basis(Vector3.UP, PI * 0.5 if along_x else 0.0).scaled(Vector3.ONE * 8.0),
			Vector3(at.x, layout.ground_height(at.x, at.y), at.y)))
		t += 1.8
	# Placas só onde se anda mais (o gramado do eixo e o bairro inicial), dos dois lados.
	var open_top := -layout.half_z + definition.open_rows.x * definition.block_size
	var open_bottom := -layout.half_z + (definition.open_rows.y + 1) * definition.block_size
	if middle.y < open_top or middle.y > open_bottom:
		return
	for facing: float in [1.0, -1.0]:
		var label := Label3D.new()
		label.text = "%s\nLicença à venda na Ferragem do Seu Zé" % district.display_name.to_upper()
		label.font_size = 64
		label.outline_size = 10
		label.pixel_size = 0.006
		# Uma placa para cada lado: sem dupla face, para o texto não aparecer espelhado.
		label.double_sided = false
		label.modulate = Color(1, 0.85, 0.3)
		var normal := Vector3(0, 0, facing) if along_x else Vector3(facing, 0, 0)
		label.position = Vector3(middle.x, ground + 2.2, middle.y) + normal * 0.3
		label.rotation.y = atan2(normal.x, normal.z)
		fence.add_child(label)


func _build_hubs() -> void:
	for hub in layout.hubs:
		var deposit: Node3D = DEPOSIT_SCENE.instantiate()
		var kiosk: Node3D = KIOSK_SCENE.instantiate()
		for node: Node3D in [deposit, kiosk]:
			add_child(node)
			# Frente (z local) virada para a rua ao norte (-z).
			node.rotation.y = PI
		deposit.global_position = hub.deposit
		kiosk.global_position = hub.kiosk
		var portal := Portal.new()
		portal.name = "Portal_%d_%d" % [hub.block.x, hub.block.y]
		add_child(portal)
		portal.rotation.y = PI
		portal.global_position = hub.portal
		for node: Node3D in [deposit, kiosk, portal]:
			for child in node.find_children("*", "GeometryInstance3D", true, false):
				var geometry := child as GeometryInstance3D
				if geometry.visibility_range_end <= 0.0:
					geometry.visibility_range_end = HUB_VISIBLE


# --- Utilidades ------------------------------------------------------------------------

func _body_for(block: Vector2i) -> StaticBody3D:
	if not _block_bodies.has(block):
		var body := StaticBody3D.new()
		body.name = "Block_%d_%d" % [block.x, block.y]
		_block_bodies[block] = body
	return _block_bodies[block]


func _static_box(node_name: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	_add_shape(body, shape, Vector3.ZERO)
	body.position = center
	return body


static func _add_shape(body: CollisionObject3D, shape: Shape3D, center: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)


func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color] = [], parent: Node3D = null, material: Material = null) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = not colors.is_empty()
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	for prefix: String in NO_SHADOW:
		if node_name.begins_with(prefix):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(instance)


## Um MultiMesh por malha do modelo (Kenney GLB), compondo a transformação local da malha.
func _scene_multimesh(node_name: String, scene_path: String, transforms: Array[Transform3D], parent: Node3D = null,
		colors: Array[Color] = [], material: Material = null) -> void:
	if transforms.is_empty():
		return
	var root: Node3D = (load(scene_path) as PackedScene).instantiate()
	var part := 0
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var local := _relative_transform(root, mesh_instance as Node3D)
		var composed: Array[Transform3D] = []
		for t in transforms:
			composed.append(t * local)
		_multimesh("%s_%d" % [node_name, part], (mesh_instance as MeshInstance3D).mesh, composed, colors, parent, material)
		part += 1
	root.free()


static func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		t = (current as Node3D).transform * t
		current = current.get_parent()
	return t


## Cenário além da barreira (N2 e S2): chão e os prédios dos setores vizinhos, sem colisão e
## sem moedas. Só para a cidade não acabar no muro.
func _build_backdrop() -> void:
	var depth := 260.0
	var size_x := definition.world_size_x() + depth * 2.0
	var ground := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size_x, 0.2, definition.world_size_z() + depth * 2.0)
	plane.material = ASPHALT_MATERIAL
	ground.mesh = plane
	ground.position.y = -0.12
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = definition.random_seed + 99
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for side: float in [-1.0, 1.0]:
		var x := -size_x * 0.5
		while x < size_x * 0.5:
			var width := rng.randf_range(18.0, 40.0)
			for row in 3:
				var deep := rng.randf_range(16.0, 30.0)
				var z := side * (layout.half_z + 18.0 + row * 70.0 + deep * 0.5)
				var district := definition.districts[layout.district_index_of(layout.block_of(clampf(x, -layout.half_x + 1.0, layout.half_x - 1.0), 0.0))]
				var height := rng.randf_range(district.building_height.x, district.building_height.y) * (1.6 if row > 0 else 1.0)
				transforms.append(Transform3D(Basis.from_scale(Vector3(width, height, deep)), Vector3(x + width * 0.5, height * 0.5, z)))
				colors.append(BUILDING_COLORS[rng.randi() % 6])
			x += width + rng.randf_range(12.0, 30.0)
	var box := BoxMesh.new()
	box.material = building_material
	_multimesh("Backdrop", box, transforms, colors)
