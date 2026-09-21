class_name RingTimingEventTests
extends RefCounted
## Unit tests for RingTimingEvent, checked against the worked examples in
## DESIGN.md section 4 (the three prototype cards at 0 crit chance / 0 cast
## speed). Run headless: godot --headless --script res://tests/run_tests.gd

const WINDOW_TOLERANCE_MS := 1.5

static func _make_ring(duration_ms: float, zone_scale: float, crit_base: float, multipliers: Array) -> RingTimingEvent:
	var event_data := CardEventData.new()
	event_data.duration_ms = duration_ms
	event_data.zone_scale = zone_scale
	event_data.crit_base = crit_base
	event_data.tier_multipliers = {
		RingTimingEvent.Tier.MISS: multipliers[0],
		RingTimingEvent.Tier.GOOD: multipliers[1],
		RingTimingEvent.Tier.GREAT: multipliers[2],
		RingTimingEvent.Tier.CRITICAL: multipliers[3],
	}
	return RingTimingEvent.from_card_event(event_data, CombatantStats.new())

static func test_crushing_blow_windows(t: TestRunner) -> void:
	var ring := _make_ring(1800.0, 1.5, 1.5, [0, 1.15, 1.3, 3.6])
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.CRITICAL), 50.0, WINDOW_TOLERANCE_MS, "crushing blow crit window ~50ms")
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.GOOD), 1090.0, WINDOW_TOLERANCE_MS, "crushing blow good window ~1090ms")
	t.assert_eq(ring.damage_for_tier(14, RingTimingEvent.Tier.CRITICAL), 50, "crushing blow crit damage one-shots the 50 HP dummy")

static func test_fireball_windows(t: TestRunner) -> void:
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.CRITICAL), 64.0, WINDOW_TOLERANCE_MS, "fireball crit window ~64ms")
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.GOOD), 565.0, WINDOW_TOLERANCE_MS, "fireball good window ~565ms")
	t.assert_eq(ring.damage_for_tier(8, RingTimingEvent.Tier.CRITICAL), 16, "fireball crit damage")

static func test_dagger_throw_windows(t: TestRunner) -> void:
	var ring := _make_ring(1100.0, 0.7, 4.0, [0, 1.5, 2, 3])
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.CRITICAL), 81.0, WINDOW_TOLERANCE_MS, "dagger throw crit window ~81ms")
	t.assert_approx(ring.window_ms(RingTimingEvent.Tier.GOOD), 311.0, WINDOW_TOLERANCE_MS, "dagger throw good window ~311ms")
	t.assert_eq(ring.damage_for_tier(4, RingTimingEvent.Tier.CRITICAL), 12, "dagger throw crit damage")

static func test_miss_deals_no_damage(t: TestRunner) -> void:
	# "A miss deals no effect" -- DESIGN.md section 4.
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	t.assert_eq(ring.damage_for_tier(8, RingTimingEvent.Tier.MISS), 0, "miss deals zero damage")

static func test_press_at_event_start_is_a_miss(t: TestRunner) -> void:
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	t.assert_eq(ring.resolve_press(0.0), RingTimingEvent.Tier.MISS, "press at t=0 (ring far from target) is a miss")

static func test_press_dead_center_is_a_critical(t: TestRunner) -> void:
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	var speed := ring.speed_px_per_ms()
	var elapsed_at_target := (RingTimingEvent.RING_START_RADIUS - RingTimingEvent.TARGET_RADIUS) / speed
	t.assert_eq(ring.resolve_press(elapsed_at_target), RingTimingEvent.Tier.CRITICAL, "press when ring radius == target radius is a critical")

static func test_no_press_times_out_to_miss(t: TestRunner) -> void:
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	t.assert_eq(ring.resolve_timeout(), RingTimingEvent.Tier.MISS, "timing out with no press is a miss")

static func test_assist_widens_windows(t: TestRunner) -> void:
	var ring := _make_ring(1100.0, 0.7, 4.0, [0, 1.5, 2, 3])
	var base_good := ring.window_ms(RingTimingEvent.Tier.GOOD)
	ring.assist_enabled = true
	var assisted_good := ring.window_ms(RingTimingEvent.Tier.GOOD)
	t.assert_true(assisted_good > base_good, "assist mode widens the good window")

static func test_assist_min_tier_guarantees_floor_on_timeout(t: TestRunner) -> void:
	var ring := _make_ring(1100.0, 0.7, 4.0, [0, 1.5, 2, 3])
	ring.assist_enabled = true
	ring.assist_min_tier = RingTimingEvent.Tier.GOOD
	t.assert_eq(ring.resolve_timeout(), RingTimingEvent.Tier.GOOD, "assist floor tier applies even on a timeout")

static func test_crit_chance_widens_only_the_crit_zone(t: TestRunner) -> void:
	var ring := _make_ring(1400.0, 1.0, 2.5, [0, 1.25, 1.5, 2])
	var before := ring.zone_half_widths()
	ring.crit_chance_pct = 50.0
	var after := ring.zone_half_widths()
	t.assert_true(after[RingTimingEvent.Tier.CRITICAL] > before[RingTimingEvent.Tier.CRITICAL], "crit chance widens the crit zone")

static func test_zone_widths_respect_caps_when_stats_are_maxed(t: TestRunner) -> void:
	# "Each zone has a floor and a cap so stacked modifiers can't produce
	# impossible or trivial windows" -- DESIGN.md section 4.
	var ring := _make_ring(1800.0, 1.5, 1.5, [0, 1.15, 1.3, 3.6])
	ring.cast_speed = 100.0
	ring.crit_chance_pct = 50.0
	var widths := ring.zone_half_widths()
	t.assert_true(widths[RingTimingEvent.Tier.CRITICAL] <= RingTimingEvent.CRIT_HALF_MAX, "crit half-width stays capped")
	t.assert_true(widths[RingTimingEvent.Tier.GREAT] <= RingTimingEvent.GREAT_HALF_MAX, "great half-width stays capped")
	t.assert_true(widths[RingTimingEvent.Tier.GOOD] <= RingTimingEvent.GOOD_HALF_MAX, "good half-width stays capped")

static func run_all(t: TestRunner) -> void:
	t.current_test = "test_crushing_blow_windows"
	test_crushing_blow_windows(t)
	t.current_test = "test_fireball_windows"
	test_fireball_windows(t)
	t.current_test = "test_dagger_throw_windows"
	test_dagger_throw_windows(t)
	t.current_test = "test_miss_deals_no_damage"
	test_miss_deals_no_damage(t)
	t.current_test = "test_press_at_event_start_is_a_miss"
	test_press_at_event_start_is_a_miss(t)
	t.current_test = "test_press_dead_center_is_a_critical"
	test_press_dead_center_is_a_critical(t)
	t.current_test = "test_no_press_times_out_to_miss"
	test_no_press_times_out_to_miss(t)
	t.current_test = "test_assist_widens_windows"
	test_assist_widens_windows(t)
	t.current_test = "test_assist_min_tier_guarantees_floor_on_timeout"
	test_assist_min_tier_guarantees_floor_on_timeout(t)
	t.current_test = "test_crit_chance_widens_only_the_crit_zone"
	test_crit_chance_widens_only_the_crit_zone(t)
	t.current_test = "test_zone_widths_respect_caps_when_stats_are_maxed"
	test_zone_widths_respect_caps_when_stats_are_maxed(t)
