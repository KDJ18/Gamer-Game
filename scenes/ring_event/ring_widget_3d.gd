class_name RingWidget3D
extends Node3D
## 3D presentation of a RingTimingEvent: a flat shader-driven "magic circle"
## on the arena floor showing the zone bands and the shrinking marker.
##
## Same public API as the 2D RingWidget (start / pressed / timed_out) so
## CombatState and the scene controller don't care which one is in use --
## only the renderer changed, not the timing math or the game logic.

## px -> world units. DESIGN.md's ring geometry constants (ringStartRadius
## 115, targetRadius 40, ringEndRadius 6) are prototype pixel units; this
## just rescales them to a circle a couple of meters across on the floor.
const WORLD_UNITS_PER_PX := 1.0 / 30.0

signal pressed(elapsed_ms: float)
signal timed_out()

@onready var zone_plane: MeshInstance3D = $ZonePlane

var ring_event: RingTimingEvent
var elapsed_ms: float = 0.0
var running: bool = false

func _ready() -> void:
	visible = false

func start(event: RingTimingEvent) -> void:
	ring_event = event
	elapsed_ms = 0.0
	running = true
	visible = true

	var mat: ShaderMaterial = zone_plane.material_override
	var widths := ring_event.zone_half_widths()
	mat.set_shader_parameter("target_radius", RingTimingEvent.TARGET_RADIUS * WORLD_UNITS_PER_PX)
	mat.set_shader_parameter("good_half", widths[RingTimingEvent.Tier.GOOD] * WORLD_UNITS_PER_PX)
	mat.set_shader_parameter("great_half", widths[RingTimingEvent.Tier.GREAT] * WORLD_UNITS_PER_PX)
	mat.set_shader_parameter("crit_half", widths[RingTimingEvent.Tier.CRITICAL] * WORLD_UNITS_PER_PX)
	_update_marker()

func stop() -> void:
	running = false
	visible = false

func _process(delta: float) -> void:
	if not running:
		return
	elapsed_ms += delta * 1000.0
	if elapsed_ms >= ring_event.duration_ms:
		elapsed_ms = ring_event.duration_ms
		_update_marker()
		running = false
		timed_out.emit()
		return
	_update_marker()

func _update_marker() -> void:
	var mat: ShaderMaterial = zone_plane.material_override
	var radius := ring_event.radius_at(elapsed_ms) * WORLD_UNITS_PER_PX
	mat.set_shader_parameter("ring_radius", radius)

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		var press_ms := elapsed_ms
		running = false
		pressed.emit(press_ms)
		get_viewport().set_input_as_handled()
