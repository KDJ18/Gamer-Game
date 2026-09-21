class_name TestRunner
extends RefCounted
## Tiny headless-friendly assertion collector. No GUT/addon dependency, so
## `godot --headless --script res://tests/run_tests.gd` works standalone.

var _pass_count := 0
var _fail_count := 0
var current_test := ""

func assert_true(condition: bool, message: String) -> void:
	_record(condition, message)

func assert_eq(actual, expected, message: String) -> void:
	_record(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])

func assert_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	var ok: bool = absf(actual - expected) <= tolerance
	_record(ok, "%s (got %.3f, expected %.3f +/- %.3f)" % [message, actual, expected, tolerance])

func _record(passed: bool, message: String) -> void:
	if passed:
		_pass_count += 1
		print("  PASS  %s :: %s" % [current_test, message])
	else:
		_fail_count += 1
		print("  FAIL  %s :: %s" % [current_test, message])

func print_summary() -> void:
	print("")
	print("%d passed, %d failed" % [_pass_count, _fail_count])

func exit_code() -> int:
	return 0 if _fail_count == 0 else 1
