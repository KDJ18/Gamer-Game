extends Node
## Autoload singleton. The *local* player's accessibility settings
## (DESIGN.md section 4: assist option + input latency calibration).
##
## Multiplayer-safe by construction: this only ever holds the local
## player's own preferences and is read when building that local player's
## CombatantStats. It is never sent over the network and never affects
## anyone else's timing resolution.

signal assist_mode_changed(enabled: bool)
signal calibration_changed(calibration_ms: float)

var assist_mode_enabled: bool = false
var assist_window_multiplier: float = 1.6
var input_calibration_ms: float = 0.0

func set_assist_mode(enabled: bool) -> void:
	assist_mode_enabled = enabled
	assist_mode_changed.emit(enabled)

func set_calibration_ms(calibration_ms: float) -> void:
	input_calibration_ms = calibration_ms
	calibration_changed.emit(calibration_ms)

## A short calibration pass: given (target_ms, pressed_ms) samples from a
## rhythm warm-up tap, sets calibration to the average lead/lag so a player
## who consistently presses late (or early) gets compensated for it.
func calibrate_from_samples(samples: Array) -> void:
	if samples.is_empty():
		return
	var total := 0.0
	for pair in samples:
		total += (pair[1] - pair[0])  # pressed_ms - target_ms; positive = late
	set_calibration_ms(total / samples.size())
