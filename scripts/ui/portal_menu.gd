class_name PortalMenu
extends MenuScreen
## Destinos dos portais: todas as lojas dos bairros liberados, da Rodoviária ao Congresso, com
## o marco mais perto e a distância. Escolher uma escurece a tela, leva o jogador para a frente
## do portal de lá (virado para a loja) e carrega as moedas em volta antes de clarear.

const COLOR_INFO := Color(0.75, 0.75, 0.75)
const FADE_SECONDS := 0.25
## Portal de onde o jogador saiu (mais perto que isto = "você está aqui").
const HERE_RADIUS := 20.0
## Nome dos marcos (CityLayout.LANDMARKS) na lista de destinos.
const LANDMARK_NAMES := {
	&"bus_station": "Rodoviária", &"theater": "Teatro Nacional", &"museum": "Museu Nacional",
	&"library": "Biblioteca Nacional", &"cathedral": "Catedral", &"justice": "Palácio da Justiça",
	&"itamaraty": "Itamaraty", &"congress": "Congresso Nacional", &"planalto": "Palácio do Planalto",
	&"supreme_court": "Supremo Tribunal Federal", &"flag": "Mastro da Bandeira",
}

var layout: CityLayout
var player: CharacterBody3D
var coin_world: CoinWorld

var _from := Vector3.ZERO
var _fade: ColorRect


func setup(city_layout: CityLayout, player_node: CharacterBody3D, world: CoinWorld) -> void:
	layout = city_layout
	player = player_node
	coin_world = world


func _ready() -> void:
	close_action = &"interact"
	close_noun = "os portais"
	super()
	GameState.portal_requested.connect(func(from: Vector3) -> void:
		_from = from
		open())
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 60
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.04, 0.14, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)


func refresh() -> void:
	super()
	summary_label.text = "Escolha a loja de destino. Só aparecem as dos bairros liberados."
	clear_items()
	var counts := {}
	for hub in layout.hubs:
		var district := layout.district_index_of(hub.block)
		counts[district] = int(counts.get(district, 0)) + 1
		if not GameState.is_district_unlocked(layout.definition.districts[district]):
			continue
		var portal: Vector3 = hub.portal
		var meters := Vector2(portal.x - _from.x, portal.z - _from.z).length()
		var here := meters < HERE_RADIUS
		var title := "%s · loja %d" % [layout.definition.districts[district].display_name, counts[district]]
		var lines := [["%s · %s" % [_place_of(hub), "você está aqui" if here else "a %s m daqui" % MoneyFormat.group(roundi(meters))], COLOR_INFO]]
		var button := make_row(title, lines, "Aqui" if here else "Viajar", not here, here)
		if not here:
			button.pressed.connect(_travel.bind(hub))


## "perto do Teatro Nacional, lado norte" (marco mais perto e de que lado do eixo).
func _place_of(hub: Dictionary) -> String:
	var portal: Vector3 = hub.portal
	var best := ""
	var best_distance := INF
	for landmark in layout.landmarks:
		var center: Vector2 = (landmark.area as Rect2).get_center()
		var distance := center.distance_to(Vector2(portal.x, portal.z))
		if distance < best_distance:
			best_distance = distance
			best = LANDMARK_NAMES.get(landmark.kind, "")
	var row: int = hub.block.y
	var side := "lado norte" if row <= layout.definition.open_rows.x else ("lado sul" if row >= layout.definition.open_rows.y else "no eixo")
	return "perto de: %s, %s" % [best, side] if best != "" else side


func _travel(hub: Dictionary) -> void:
	close()
	GameState.set_screen_open(true)
	Sfx.play(&"whoosh", 0.0, -2.0)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	await tween.finished
	# Na frente do portal de destino (ao norte), olhando para oeste: a loja e o ponto de coleta.
	var portal: Vector3 = hub.portal
	GameState.bump("portal_trips")
	var arrival := Vector3(portal.x, layout.ground_height(portal.x, portal.z - 2.5) + 0.1, portal.z - 2.5)
	player.global_position = arrival
	player.velocity = Vector3.ZERO
	player.rotation.y = PI * 0.5
	GameState.player_position = arrival
	coin_world.load_around(arrival)
	Sfx.play(&"chime", 0.0, -6.0)
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	await tween.finished
	GameState.set_screen_open(false)
