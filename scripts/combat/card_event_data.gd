class_name CardEventData
extends RefCounted
## Generic timing-event parameters for a card (DESIGN.md section 5).
##
## `kind` selects which event resolver interprets the rest of the fields, so
## new event types (hold-and-release, sequence, mash, reactive — DESIGN.md
## section 4) can be added later without touching Card or CombatState.
## Only "ring" is implemented today.

const KIND_RING := "ring"

var kind: String = KIND_RING

## Ring-specific fields (ignored by other kinds once they exist).
var duration_ms: float = 1000.0
var zone_scale: float = 1.0
var crit_base: float = 2.0
## RingTimingEvent.Tier -> multiplier.
var tier_multipliers: Dictionary = {}

static func from_dict(d: Dictionary) -> CardEventData:
	var data := CardEventData.new()
	data.kind = d.get("kind", KIND_RING)
	data.duration_ms = float(d.get("durationMs", 1000.0))
	data.zone_scale = float(d.get("zoneScale", 1.0))
	data.crit_base = float(d.get("critBase", 2.0))

	var raw: Array = d.get("tierMultipliers", [0.0, 1.0, 1.0, 1.0])
	data.tier_multipliers = {
		RingTimingEvent.Tier.MISS: float(raw[0]),
		RingTimingEvent.Tier.GOOD: float(raw[1]),
		RingTimingEvent.Tier.GREAT: float(raw[2]),
		RingTimingEvent.Tier.CRITICAL: float(raw[3]),
	}
	return data
