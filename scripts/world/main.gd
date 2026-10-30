extends Node3D
## Cena principal: coloca o jogador (no início ou onde parou), liga o streaming de moedas
## à posição dele, dá a lanterna à câmera e guarda a posição para o save.

const PORTAL_MENU := preload("res://scenes/ui/portal_menu.tscn")

@export var city: CityBuilder
@export var coin_world: CoinWorld
@export var player: CharacterBody3D

var _position_timer := 0.0


func _ready() -> void:
	var spawn := city.layout.spawn_point()
	var saved: Variant = GameState.player_position
	if saved is Vector3 and _is_safe(saved):
		spawn = saved
	else:
		# Partida nova: de costas para a cerca, olhando a praça com a loja e o ponto de coleta.
		player.rotation.y = PI
	player.global_position = spawn
	player.velocity = Vector3.ZERO
	coin_world.tracked = player
	var flashlight := Flashlight.new()
	flashlight.name = "Flashlight"
	player.get_node(^"Head/Camera3D").add_child(flashlight)
	var map := MapMenu.new()
	map.name = "MapMenu"
	map.setup(city.layout, player)
	add_child(map)
	var portals: PortalMenu = PORTAL_MENU.instantiate()
	portals.name = "PortalMenu"
	portals.setup(city.layout, player, coin_world)
	add_child(portals)
	# Com janela: as moedas entram aos poucos atrás da tela de carregamento. Sem janela (testes),
	# tudo de uma vez, como antes.
	if DisplayServer.get_name() == "headless":
		coin_world.load_around(spawn)
	else:
		var screen := LoadingScreen.show_on(get_tree())
		# Na web os shaders são compilados aos poucos antes (ver ShaderWarmup).
		if WebPlatform.active():
			await screen.warm_up(city)
		screen.track(coin_world)
		coin_world.load_around_async(spawn)


func _process(delta: float) -> void:
	_position_timer -= delta
	if _position_timer <= 0.0:
		_position_timer = 1.0
		GameState.player_position = player.global_position


## Posição salva só vale se for chão livre num bairro liberado.
func _is_safe(pos: Vector3) -> bool:
	var layout := city.layout
	var district := layout.district_at(pos.x, pos.z)
	return district != null and GameState.is_district_unlocked(district) and layout.is_free(pos.x, pos.z)
