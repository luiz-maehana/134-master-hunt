extends SceneTree
## Planta 2D do traçado, para revisar ruas, lotes e marcos sem abrir o jogo. Rua escura, lote
## claro, gramado verde, prédios cinza, pegada dos marcos vermelha (área em laranja), postes
## amarelos, objetos de rua magenta, pilares da Rodoviária azuis. 1 px = 1 m, ampliada 2x, em
## faixas de 640 m:
##   godot --headless --path . --script res://tools/layout_plan.gd -- <pasta de saída>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Scripts carregados aqui (e não por class_name): dependem de autoloads que ainda não existem
	# quando este arquivo é compilado.
	var def = load("res://scripts/world/world_definition.gd").call("get_default")
	var layout = load("res://scripts/world/city_layout.gd").call("for_definition", def)
	var w := int(layout.half_x * 2.0)
	var h := int(layout.half_z * 2.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var x: float = px - layout.half_x + 0.5
			var z: float = py - layout.half_z + 0.5
			var b: Vector2i = layout.block_of(x, z)
			var c := Color(0.25, 0.25, 0.27)
			if layout.ground_height(x, z) > 0.0:
				c = Color(0.55, 0.75, 0.45) if layout.is_lawn(b) else Color(0.78, 0.76, 0.72)
			img.set_pixel(px, py, c)
	for key in layout.blocks:
		var info: Dictionary = layout.blocks[key]
		for bld in info.buildings:
			_fill(img, layout, bld.rect, Color(0.45, 0.45, 0.5))
	for lm in layout.landmarks:
		_fill(img, layout, lm.rect, Color(0.85, 0.25, 0.2))
		_outline(img, layout, lm.area, Color(1, 0.6, 0.1))
	# Pilares da Rodoviária (mesma conta do LandmarkBuilder).
	for lm in layout.landmarks:
		if lm.kind == &"bus_station":
			var area: Rect2 = lm.area
			var length := area.size.y * 0.45
			var pillars := int(length / 16.0)
			for i in pillars + 1:
				var pz := area.get_center().y - length * 0.5 + length * i / pillars
				for dx in [-21.0, 21.0]:
					if layout.ground_height(area.get_center().x + dx, pz - 1.0) > 0.0 and layout.ground_height(area.get_center().x + dx, pz + 1.0) > 0.0:
						_fill(img, layout, Rect2(area.get_center().x + dx - 1.5, pz - 1.5, 3, 3), Color(0.1, 0.3, 1))
			_outline(img, layout, Rect2(area.get_center().x - 23, area.get_center().y - length * 0.5, 46, length), Color(0.1, 0.3, 1))
	for key in layout.blocks:
		for p in layout.blocks[key].props:
			_fill(img, layout, Rect2(p.pos - Vector2.ONE, Vector2(2, 2)), Color(1, 0, 1))
	for lamp in layout.lamps:
		_fill(img, layout, Rect2(Vector2(lamp.x, lamp.z) - Vector2.ONE, Vector2(2, 2)), Color(1, 1, 0))
	var out: String = OS.get_cmdline_user_args()[0]
	var i := 0
	for x0 in range(0, w, 640):
		var part := img.get_region(Rect2i(x0, 0, mini(640, w - x0), h))
		part.resize(part.get_width() * 2, part.get_height() * 2, Image.INTERPOLATE_NEAREST)
		part.save_png(out.path_join("plan_%d.png" % i))
		i += 1
	quit()


func _fill(img: Image, layout, r: Rect2, c: Color) -> void:
	var x0 := int(r.position.x + layout.half_x)
	var z0 := int(r.position.y + layout.half_z)
	for px in range(maxi(x0, 0), mini(x0 + int(ceil(r.size.x)), img.get_width())):
		for py in range(maxi(z0, 0), mini(z0 + int(ceil(r.size.y)), img.get_height())):
			img.set_pixel(px, py, c)


func _outline(img: Image, layout, r: Rect2, c: Color) -> void:
	_fill(img, layout, Rect2(r.position, Vector2(r.size.x, 1)), c)
	_fill(img, layout, Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
	_fill(img, layout, Rect2(r.position, Vector2(1, r.size.y)), c)
	_fill(img, layout, Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), c)
