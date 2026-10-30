extends TestSuite
## Automação com a cidade real: robôs aparecem perto do jogador, recolhem dentro do raio,
## depositam sozinhos sem contar duas vezes, trabalham longe (blocos frios) sem divergir do
## que aparece ao chegar perto, avisam quando a área acaba e voltam do save.

const MAIN_SCENE := "res://scenes/main.tscn"

var main: Node3D
var player: CharacterBody3D
var world: CoinWorld
var fleet: RobotFleet
var layout: CityLayout


func before_all() -> void:
	GameState.reset()
	main = load(MAIN_SCENE).instantiate()
	tree.root.add_child(main)
	player = main.get_node("Player")
	world = main.get_node("City/CoinWorld")
	fleet = main.get_node("RobotFleet")
	layout = world.layout
	await physics_frames(20)


func after_all() -> void:
	main.queue_free()
	await process_frames(2)
	GameState.reset()


func test_bought_robot_appears_near_player() -> void:
	player.global_position = layout.spawn_point()
	GameState.grant(&"robot_small")
	await physics_frames(2)
	check_eq(fleet.count(), 1, "um robô no mapa")
	var robot := fleet.robot(0)
	var pos := Vector2(player.global_position.x, player.global_position.z)
	check(robot.home.distance_to(pos) < RobotFleet.PLACE_AHEAD + 0.5, "aparece perto do jogador")
	check((GameState.robots[0].pos as Vector2).is_finite(), "posição guardada para o save")
	var hud_robots: Label = main.get_node("HUD").get_node("%Robots")
	await tree.create_timer(0.3).timeout
	check(hud_robots.visible and hud_robots.text.contains("Robôs"), "HUD mostra a frota: '%s'" % hud_robots.text)


func test_robot_collects_within_radius_and_deposits() -> void:
	var robot := fleet.robot(0)
	var home := Vector3(robot.home.x, 0, robot.home.y)
	for target in world.scan_around(home, robot.definition.radius):
		var p := world.pile_position(Vector2i(target.x, target.y), target.z)
		if Vector2(p.x - home.x, p.z - home.z).length() > robot.definition.radius + 0.01:
			check(false, "pilha fora do raio na lista do robô")
			return
	fleet._deliver()
	var found := GameState.ledger.total_coins_found
	var removed := GameState.world_removed
	await physics_frames(120)
	fleet._deliver()
	var gained := GameState.ledger.total_coins_found - found
	check(gained > 0, "robô recolheu e depositou sozinho (%d)" % gained)
	check_eq(GameState.world_removed - removed, gained, "cada moeda contada uma vez")
	check_eq(GameState.ledger.carried_coins, 0, "não passa pelo bolso")
	check_eq(GameState.ledger.money_cents, GameState.ledger.total_value_found_cents, "vira dinheiro na hora (pelo valor das moedas)")
	_check_invariant()


func test_robot_works_far_away_consistently() -> void:
	# Canto do Setor Cultural (liberado só neste teste), longe do jogador: o bloco fica "frio".
	GameState.grant(&"permit_downtown")
	var bounds := layout.district_rect(1)
	var far := Vector2(bounds.position.x + 10.0, bounds.end.y - 10.0)
	while not layout.is_free(far.x, far.y):
		far += Vector2(1.5, -1.5)
	var key := world.key_of(Vector3(far.x, 0, far.y))
	check(not world.is_active(key), "bloco longe do jogador não está carregado")
	GameState.move_robot(0, far)
	await physics_frames(2)
	var removed := GameState.world_removed
	await physics_frames(120)
	fleet._deliver()
	check(GameState.world_removed > removed, "robô trabalha mesmo longe")
	check_eq(world.pile_sum(key), world.remaining_in(key), "bloco frio bate com o registro")
	# Chegando perto, o bloco ganha desenho com as mesmas pilhas.
	player.global_position = Vector3(far.x, 0.1, far.y)
	world.load_around(player.global_position)
	check(world.is_active(key), "bloco carregado ao chegar perto")
	check_eq(world.pile_sum(key), world.remaining_in(key), "o que aparece é o que restou")
	_check_invariant()
	GameState.owned_items.erase(&"permit_downtown")
	GameState.recompute_stats()
	player.global_position = layout.spawn_point()
	world.load_around(player.global_position)


func test_robot_goes_idle_and_warns() -> void:
	var robot := fleet.robot(0)
	var original := robot.definition
	var tiny: RobotDefinition = original.duplicate()
	tiny.radius = 0.01
	robot.definition = tiny
	var warnings: Array[String] = []
	var on_notice := func(text: String) -> void: warnings.append(text)
	GameState.notified.connect(on_notice)
	robot.relocate(robot.home)
	await physics_frames(10)
	check(robot.idle, "sem moedas no raio: para")
	check(warnings.any(func(t: String) -> bool: return t.contains("limpou a área")), "avisa o jogador")
	check_eq(fleet.idle_count(), 1, "frota conta o parado")
	GameState.notified.disconnect(on_notice)
	robot.definition = original
	fleet.bring_here(0)
	await physics_frames(3)
	check(not robot.idle, "trazido para outro lugar, volta a trabalhar")


func test_inventory_brings_robot() -> void:
	var inventory: MenuScreen = main.get_node("InventoryMenu")
	var spawn := layout.spawn_point()
	GameState.move_robot(0, Vector2(spawn.x + 30.0, spawn.z))
	player.global_position = layout.spawn_point()
	inventory.open()
	var button: Button = null
	for b in inventory.items_box.find_children("*", "Button", true, false):
		if (b as Button).text == "Trazer para cá":
			button = b
	check(button != null, "inventário tem 'Trazer para cá'")
	if button != null:
		button.pressed.emit()
	await process_frames(2)
	var pos := Vector2(player.global_position.x, player.global_position.z)
	check(fleet.robot(0).home.distance_to(pos) < RobotFleet.PLACE_AHEAD + 0.5, "robô veio para perto")
	inventory.close()


func test_save_restores_fleet() -> void:
	GameState.grant(&"robot_small")
	await physics_frames(2)
	var homes: Array[Vector2] = []
	for i in fleet.count():
		homes.append(fleet.robot(i).home)
	fleet._deliver()
	GameState.apply_save(GameState.to_save())
	await physics_frames(2)
	check_eq(fleet.count(), homes.size(), "mesma frota")
	for i in homes.size():
		check(fleet.robot(i).home.distance_to(homes[i]) < 0.01, "robô %d no mesmo lugar" % i)


func _check_invariant() -> void:
	check_eq(GameState.world_removed, GameState.ledger.total_coins_found + GameState.ledger.carried_coins,
		"retirado do mundo = encontradas + bolso")
	check_eq(GameState.world_removed_value, GameState.ledger.total_value_found_cents + GameState.ledger.carried_value_cents,
		"valor retirado do mundo = valor encontrado + valor no bolso")
