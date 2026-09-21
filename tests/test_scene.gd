extends Node
## Headless unit test entry point, run as an actual scene (not --script) so
## project autoloads (GameSettings, CardDatabase) are initialized normally.
## Run: godot --headless --path . res://tests/test_scene.tscn

func _ready() -> void:
	var t := TestRunner.new()

	print("RingTimingEventTests")
	RingTimingEventTests.run_all(t)

	print("")
	print("CombatStateTests")
	CombatStateTests.run_all(t)

	t.print_summary()
	get_tree().quit(t.exit_code())
