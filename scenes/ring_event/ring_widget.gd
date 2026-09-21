class_name RingWidget
extends Control
## Visual + input front-end for a RingTimingEvent (DESIGN.md section 4):
## a shrinking ring marker over a concentric target, resolved on Space so
## it can never be confused with the number-key card selection.
##
## All the actual math lives in RingTimingEvent; this only draws and
## forwards input.

## Reports raw timing only; CombatState (not this widget) is the source of
## truth for turning it into a tier, since that resolution needs to stay
## authoritative for an eventual server-driven multiplayer fight.
signal pressed(elapsed_ms: float)
signal timed_out()

const GOOD_COLOR := Color(0.20, 0.75, 0.30)
const GREAT_COLOR := Color(0.85, 0.75, 0.15)
const CRIT_COLOR := Color(0.80, 0.20, 0.20)
const BG_COLOR := Color(0.11, 0.11, 0.15)
const MARKER_COLOR := Color(1.0, 1.0, 1.0)

var ring_event: RingTimingEvent
var elapsed_ms: float = 0.0
var running: bool = false

func start(event: RingTimingEvent) -> void:
	ring_event = event
	elapsed_ms = 0.0
	running = true
	visible = true
	queue_redraw()

func stop() -> void:
	running = false
	visible = false

func _process(delta: float) -> void:
	if not running:
		return
	elapsed_ms += delta * 1000.0
	if elapsed_ms >= ring_event.duration_ms:
		elapsed_ms = ring_event.duration_ms
		_finish()
		timed_out.emit()
		return
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		var press_ms := elapsed_ms
		_finish()
		pressed.emit(press_ms)
		get_viewport().set_input_as_handled()

func _finish() -> void:
	running = false
	queue_redraw()

func _draw() -> void:
	if ring_event == null:
		return

	var center := size / 2.0
	var target := RingTimingEvent.TARGET_RADIUS
	var widths := ring_event.zone_half_widths()
	var good: float = widths[RingTimingEvent.Tier.GOOD]
	var great: float = widths[RingTimingEvent.Tier.GREAT]
	var crit: float = widths[RingTimingEvent.Tier.CRITICAL]

	# Painter's algorithm, outside in: good band, then great, then crit...
	draw_circle(center, target + good, GOOD_COLOR)
	draw_circle(center, target + great, GREAT_COLOR)
	draw_circle(center, target + crit, CRIT_COLOR)
	# ...then punch the inner holes back out (d = |r - target| means each
	# zone is an annulus around target, not a filled disc down to r = 0).
	var inner_after_crit := target - crit
	if inner_after_crit > 0.0:
		draw_circle(center, inner_after_crit, GREAT_COLOR)
	var inner_after_great := target - great
	if inner_after_great > 0.0:
		draw_circle(center, inner_after_great, GOOD_COLOR)
	var inner_after_good := target - good
	if inner_after_good > 0.0:
		draw_circle(center, inner_after_good, BG_COLOR)

	var ring_radius := ring_event.radius_at(elapsed_ms)
	draw_arc(center, ring_radius, 0.0, TAU, 64, MARKER_COLOR, 3.0, true)
