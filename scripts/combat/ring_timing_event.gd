class_name RingTimingEvent
extends RefCounted
## Standalone timing-event resolver for the "ring" event type (DESIGN.md section 4).
##
## Has no Node/scene dependency: it is constructed from card event parameters
## and player stats, and turns a press (or a timeout) into an outcome tier.
## Geometry and tier math are pure functions so they can be unit-tested
## without spinning up a scene tree.

enum Tier { MISS, GOOD, GREAT, CRITICAL }

const RING_START_RADIUS := 115.0
const TARGET_RADIUS := 40.0
const RING_END_RADIUS := 6.0

const CRIT_HALF_MIN := 1.5
const CRIT_HALF_MAX := 22.0
const GREAT_HALF_MAX := 32.0
const GOOD_HALF_MAX := 40.0

## Card event parameters (see CardEventData).
var duration_ms: float
var zone_scale: float
var crit_base: float
## Tier -> multiplier, e.g. {MISS: 0.0, GOOD: 1.25, GREAT: 1.5, CRITICAL: 2.0}
var tier_multipliers: Dictionary

## Player stats.
var cast_speed: float = 0.0       # 0..100
var crit_chance_pct: float = 0.0  # 0..50

## Accessibility (DESIGN.md section 4: "include an assist option from the start").
var assist_enabled: bool = false
var assist_window_multiplier: float = 1.6
## When assist is on, guarantee at least this tier regardless of timing.
## Tier.MISS (default) means "no floor, just wider windows".
var assist_min_tier: int = Tier.MISS

## Input latency calibration, in ms. A positive value shifts the effective
## press time earlier, compensating for players who consistently press late
## due to input/display latency.
var calibration_ms: float = 0.0

func _init(p_duration_ms: float, p_zone_scale: float, p_crit_base: float, p_tier_multipliers: Dictionary) -> void:
	duration_ms = p_duration_ms
	zone_scale = p_zone_scale
	crit_base = p_crit_base
	tier_multipliers = p_tier_multipliers

static func from_card_event(event_data: CardEventData, stats: CombatantStats) -> RingTimingEvent:
	var ring := RingTimingEvent.new(
		event_data.duration_ms,
		event_data.zone_scale,
		event_data.crit_base,
		event_data.tier_multipliers
	)
	ring.cast_speed = stats.cast_speed
	ring.crit_chance_pct = stats.crit_chance_pct
	ring.assist_enabled = stats.assist_enabled
	ring.calibration_ms = stats.calibration_ms
	return ring

## Ring shrink speed, in px/ms. Constant for a given card duration.
func speed_px_per_ms() -> float:
	return (RING_START_RADIUS - RING_END_RADIUS) / duration_ms

## Half-width, in px, of each named zone: {CRITICAL: .., GREAT: .., GOOD: ..}.
## Formula and clamps from DESIGN.md section 4.
func zone_half_widths() -> Dictionary:
	var add := 0.05 * cast_speed
	var crit := clampf(crit_base + 0.5 * add + 0.2 * crit_chance_pct, CRIT_HALF_MIN, CRIT_HALF_MAX)
	var great := minf(GREAT_HALF_MAX, maxf(crit + 4.0, 12.0 * zone_scale + add))
	var good := minf(GOOD_HALF_MAX, maxf(great + 4.0, 22.0 * zone_scale + add))

	if assist_enabled:
		crit *= assist_window_multiplier
		great *= assist_window_multiplier
		good *= assist_window_multiplier

	return {
		Tier.CRITICAL: crit,
		Tier.GREAT: great,
		Tier.GOOD: good,
	}

## How long (ms) the ring spends inside a given zone. This is the value to
## tune/display by, per DESIGN.md's "tune by the millisecond window" rule.
func window_ms(tier: int) -> float:
	var widths := zone_half_widths()
	if not widths.has(tier):
		return 0.0
	return 2.0 * widths[tier] / speed_px_per_ms()

## Ring radius (px) at a given elapsed time since the event started.
func radius_at(elapsed_ms: float) -> float:
	var t := clampf(elapsed_ms, 0.0, duration_ms)
	return RING_START_RADIUS - speed_px_per_ms() * t

## Resolve a press at `elapsed_ms` since the event started into an outcome tier.
func resolve_press(elapsed_ms: float) -> int:
	var calibrated_ms := elapsed_ms - calibration_ms
	var radius := radius_at(calibrated_ms)
	var d := absf(radius - TARGET_RADIUS)
	var widths := zone_half_widths()

	var tier := Tier.MISS
	if d <= widths[Tier.CRITICAL]:
		tier = Tier.CRITICAL
	elif d <= widths[Tier.GREAT]:
		tier = Tier.GREAT
	elif d <= widths[Tier.GOOD]:
		tier = Tier.GOOD

	if assist_enabled and assist_min_tier > tier:
		tier = assist_min_tier
	return tier

## No press before the ring reaches its minimum radius: a miss (DESIGN.md:
## "If the player never presses, the event resolves ... effectively a miss"),
## unless assist guarantees a floor tier.
func resolve_timeout() -> int:
	if assist_enabled and assist_min_tier > Tier.MISS:
		return assist_min_tier
	return Tier.MISS

## Card damage for a resolved tier. A miss deals no effect (DESIGN.md section
## 4): enforced by tier_multipliers[MISS] == 0.0 on all cards, not by
## special-casing here.
func damage_for_tier(base_damage: float, tier: int) -> int:
	var multiplier: float = tier_multipliers.get(tier, 0.0)
	return roundi(base_damage * multiplier)

static func tier_name(tier: int) -> String:
	match tier:
		Tier.MISS: return "Miss"
		Tier.GOOD: return "Good"
		Tier.GREAT: return "Great"
		Tier.CRITICAL: return "Critical"
		_: return "Unknown"
