extends SceneTree
## Executa todos os testes.
##   godot --headless --path . --script res://tests/run_tests.gd
## Código de saída 0 = tudo passou.

const SUITES := [
	"res://tests/unit/test_money_format.gd",
	"res://tests/unit/test_ui_style.gd",
	"res://tests/unit/test_coin_ledger.gd",
	"res://tests/unit/test_city_layout.gd",
	"res://tests/unit/test_coin_world.gd",
	"res://tests/unit/test_shop_rules.gd",
	"res://tests/unit/test_purchases.gd",
	"res://tests/unit/test_save_game.gd",
	"res://tests/unit/test_robot_rules.gd",
	"res://tests/unit/test_denominations.gd",
	"res://tests/unit/test_achievements.gd",
	"res://tests/unit/test_settings_audio.gd",
	"res://tests/integration/test_gameplay.gd",
	"res://tests/integration/test_progression.gd",
	"res://tests/integration/test_magnet_rod.gd",
	"res://tests/integration/test_automation.gd",
	"res://tests/integration/test_ui_layout.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Nunca tocar no save real do jogador durante os testes.
	root.get_node("GameState").set("save_enabled", false)
	root.get_node("Settings").set("save_enabled", false)
	var total_checks := 0
	var all_failures := PackedStringArray()
	for path in SUITES:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			all_failures.append("%s: não compilou" % path)
			printerr("\n== %s: ERRO DE COMPILAÇÃO" % path.get_file())
			continue
		var suite: TestSuite = script.new()
		suite.tree = self
		print("\n== %s" % path.get_file())
		await suite.before_all()
		for method in _test_methods(suite):
			suite.current_test = method
			var failures_before := suite.failures.size()
			await suite.call(method)
			print("  [%s] %s" % ["OK" if suite.failures.size() == failures_before else "FAIL", method])
		await suite.after_all()
		total_checks += suite.checks
		all_failures.append_array(suite.failures)
	print("\n%d verificações, %d falhas." % [total_checks, all_failures.size()])
	for failure in all_failures:
		printerr("  - ", failure)
	quit(1 if not all_failures.is_empty() else 0)


## Métodos test_* declarados no script da suíte, na ordem do arquivo.
func _test_methods(suite: TestSuite) -> PackedStringArray:
	var names := PackedStringArray()
	for method in (suite.get_script() as Script).get_script_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	return names
