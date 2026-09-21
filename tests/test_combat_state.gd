class_name CombatStateTests
extends RefCounted
## Smoke tests for the turn flow itself (DESIGN.md section 3 / section 9
## task 2): choose card -> pay mana -> resolve event -> apply effect ->
## enemy turn, exercised end to end instead of just the ring math.

static func _make_player(mana: int = 10) -> Combatant:
	var player := Combatant.new("player", "You", 30, mana)
	return player

static func _make_dummy() -> Combatant:
	return Combatant.new("dummy", "Training Dummy", 50, 0, true, 0)

static func test_card_database_loads_three_prototype_cards(t: TestRunner) -> void:
	t.assert_true(CardDatabase.has_card("crushing_blow"), "crushing_blow is loaded from data/cards")
	t.assert_true(CardDatabase.has_card("fireball"), "fireball is loaded from data/cards")
	t.assert_true(CardDatabase.has_card("dagger_throw"), "dagger_throw is loaded from data/cards")
	t.assert_true(CardDatabase.has_card("dagger_barrage"), "dagger_barrage is loaded from data/cards")

static func test_crushing_blow_crit_one_shots_the_dummy(t: TestRunner) -> void:
	var combat := CombatState.new()
	var player := _make_player()
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("crushing_blow")]
	combat.setup(player, dummy, hand)

	combat.choose_card(hand[0])
	t.assert_eq(combat.phase, CombatState.Phase.PLAYER_TIMING_EVENT, "committing a card with an event enters the timing phase")
	t.assert_eq(player.mana, 7, "mana was paid on commit (10 - 3)")

	var ring := combat.current_ring_event()
	var speed := ring.speed_px_per_ms()
	var elapsed_at_target := (RingTimingEvent.RING_START_RADIUS - RingTimingEvent.TARGET_RADIUS) / speed
	combat.resolve_timing_press(elapsed_at_target)

	t.assert_eq(dummy.hp, 0, "a dead-center press one-shots the 50 HP dummy")
	t.assert_eq(combat.phase, CombatState.Phase.COMBAT_OVER, "combat ends immediately when the enemy dies")
	combat.free()

static func test_far_off_press_still_deals_base_damage(t: TestRunner) -> void:
	var combat := CombatState.new()
	var player := _make_player()
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("fireball")]
	combat.setup(player, dummy, hand)

	combat.choose_card(hand[0])
	combat.resolve_timing_press(0.0)  # ring far from target -> miss

	t.assert_eq(dummy.hp, 50 - 8, "a miss still applies fireball's base 8 damage, not less")
	combat.free()

static func test_cannot_afford_card_is_rejected(t: TestRunner) -> void:
	var combat := CombatState.new()
	var player := _make_player(0)
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("crushing_blow")]
	combat.setup(player, dummy, hand)

	var accepted := combat.choose_card(hand[0])
	t.assert_true(not accepted, "choosing an unaffordable card is rejected")
	t.assert_eq(combat.phase, CombatState.Phase.PLAYER_CHOOSING, "phase stays PLAYER_CHOOSING when the card is rejected")
	combat.free()

static func test_dagger_barrage_hit_count_scales_with_accuracy(t: TestRunner) -> void:
	# Dagger Barrage: 1 damage per dagger, and the tier controls how many
	# daggers land -- so damage dealt *is* the dagger count directly.
	var combat := CombatState.new()
	var player := _make_player()
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("dagger_barrage")]
	combat.setup(player, dummy, hand)

	combat.choose_card(hand[0])
	combat.resolve_timing_press(0.0)  # far from target -> miss

	t.assert_eq(dummy.hp, 50 - 1, "a miss still lands exactly 1 dagger (base effect), never 0")
	combat.free()

static func test_dagger_barrage_dead_center_lands_all_daggers(t: TestRunner) -> void:
	var combat := CombatState.new()
	var player := _make_player()
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("dagger_barrage")]
	combat.setup(player, dummy, hand)

	combat.choose_card(hand[0])
	var ring := combat.current_ring_event()
	var speed := ring.speed_px_per_ms()
	var elapsed_at_target := (RingTimingEvent.RING_START_RADIUS - RingTimingEvent.TARGET_RADIUS) / speed
	combat.resolve_timing_press(elapsed_at_target)

	t.assert_eq(dummy.hp, 50 - 6, "a dead-center press lands all 6 daggers for 6 damage")
	combat.free()

static func test_passive_dummy_never_attacks_on_its_turn(t: TestRunner) -> void:
	var combat := CombatState.new()
	var player := _make_player()
	var dummy := _make_dummy()
	var hand: Array[Card] = [CardDatabase.get_card("dagger_throw")]
	combat.setup(player, dummy, hand)

	combat.choose_card(hand[0])
	combat.resolve_timing_press(0.0)  # miss, dummy survives (50 - 4 = 46 HP)

	t.assert_eq(player.hp, player.max_hp, "a passive training dummy deals no damage back")
	t.assert_eq(combat.phase, CombatState.Phase.PLAYER_CHOOSING, "turn returns to the player after a passive enemy turn")
	t.assert_eq(player.mana, player.max_mana, "mana refills between turns")
	combat.free()

static func run_all(t: TestRunner) -> void:
	t.current_test = "test_card_database_loads_three_prototype_cards"
	test_card_database_loads_three_prototype_cards(t)
	t.current_test = "test_crushing_blow_crit_one_shots_the_dummy"
	test_crushing_blow_crit_one_shots_the_dummy(t)
	t.current_test = "test_far_off_press_still_deals_base_damage"
	test_far_off_press_still_deals_base_damage(t)
	t.current_test = "test_cannot_afford_card_is_rejected"
	test_cannot_afford_card_is_rejected(t)
	t.current_test = "test_dagger_barrage_hit_count_scales_with_accuracy"
	test_dagger_barrage_hit_count_scales_with_accuracy(t)
	t.current_test = "test_dagger_barrage_dead_center_lands_all_daggers"
	test_dagger_barrage_dead_center_lands_all_daggers(t)
	t.current_test = "test_passive_dummy_never_attacks_on_its_turn"
	test_passive_dummy_never_attacks_on_its_turn(t)
