extends Node
## One more headless check: instantiate the actual playable scene (not just
## its logic classes) and drive it exactly like a player would, to catch
## @onready path typos / signal wiring mistakes that unit tests can't see.
## Run: godot --headless --path . res://tests/test_scene_integration.tscn

func _ready() -> void:
	var scene: Node = load("res://scenes/combat_test/combat_test.tscn").instantiate()
	add_child(scene)

	scene._try_play(0)  # crushing blow
	assert(scene.combat.phase == CombatState.Phase.PLAYER_TIMING_EVENT)

	var ring = scene.combat.current_ring_event()
	var speed: float = ring.speed_px_per_ms()
	var elapsed_at_target: float = (RingTimingEvent.RING_START_RADIUS - RingTimingEvent.TARGET_RADIUS) / speed
	scene._on_ring_pressed(elapsed_at_target)

	assert(scene.combat.phase == CombatState.Phase.COMBAT_OVER)
	assert(scene.combat.enemy.hp == 0)

	print("integration smoke test: OK (dummy defeated via wired-up scene)")
	get_tree().quit(0)
