class_name CombatantStats
extends RefCounted
## Everything a timing event needs about the player executing it: their
## combat stats (cast_speed, crit_chance_pct) plus their own accessibility
## settings (assist_enabled, calibration_ms). Bundled together so
## RingTimingEvent.from_card_event() takes one argument per player instead
## of four, and so each player's assist/calibration stays independent of
## everyone else's in a multiplayer fight.

var cast_speed: float = 0.0        # 0..100
var crit_chance_pct: float = 0.0   # 0..50
var assist_enabled: bool = false
var calibration_ms: float = 0.0

func _init(p_cast_speed: float = 0.0, p_crit_chance_pct: float = 0.0, p_assist_enabled: bool = false, p_calibration_ms: float = 0.0) -> void:
	cast_speed = p_cast_speed
	crit_chance_pct = p_crit_chance_pct
	assist_enabled = p_assist_enabled
	calibration_ms = p_calibration_ms
