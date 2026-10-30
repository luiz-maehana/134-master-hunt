class_name TestSuite
extends RefCounted
## Base mínima de testes. Métodos `test_*` são executados em ordem de declaração;
## podem ser corrotinas (usar await). Ver tests/run_tests.gd.

var tree: SceneTree
var checks := 0
var failures := PackedStringArray()
var current_test := ""


func before_all() -> void:
	pass


func after_all() -> void:
	pass


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append("%s: %s" % [current_test, label])
		printerr("    [FAIL] ", label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (esperado %s, obtido %s)" % [label, var_to_str(expected), var_to_str(actual)])


func physics_frames(count: int) -> void:
	for i in count:
		await tree.physics_frame


func process_frames(count: int) -> void:
	for i in count:
		await tree.process_frame
