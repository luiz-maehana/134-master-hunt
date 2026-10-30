class_name ScreenTransition
## Abre e fecha as telas (loja, inventário, mapa, menu) com um esmaecer curto e o som de
## interface. A tela continua visível durante o esmaecer de fechar: quem chama guarda o próprio
## estado de "aberta" e não deve usar `visible` para isso.

const OPEN_SECONDS := 0.14
const CLOSE_SECONDS := 0.1


static func open(layer: CanvasLayer) -> void:
	_fade(layer, 0.0 if not layer.visible else _alpha(layer), 1.0, OPEN_SECONDS)
	layer.visible = true
	Sfx.play(&"ui_open", 0.03, -10.0)


static func close(layer: CanvasLayer) -> void:
	var tween := _fade(layer, _alpha(layer), 0.0, CLOSE_SECONDS)
	tween.tween_callback(layer.hide)
	Sfx.play(&"ui_close", 0.03, -12.0)


static func _fade(layer: CanvasLayer, from: float, to: float, seconds: float) -> Tween:
	var previous: Tween = layer.get_meta(&"transition") if layer.has_meta(&"transition") else null
	if previous != null and previous.is_valid():
		previous.kill()
	var tween := layer.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for child in layer.get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = from
			tween.tween_property(child, "modulate:a", to, seconds)
	tween.chain()
	layer.set_meta(&"transition", tween)
	return tween


static func _alpha(layer: CanvasLayer) -> float:
	for child in layer.get_children():
		if child is CanvasItem:
			return (child as CanvasItem).modulate.a
	return 1.0
