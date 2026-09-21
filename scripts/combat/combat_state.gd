class_name CombatState
extends Node
## Minimal combat state machine (DESIGN.md section 3 & section 9 task 2):
## choose card (untimed) -> pay mana -> resolve timing event -> apply
## effect -> enemy turn, on strict alternating turns.
##
## UI-agnostic: it emits signals and exposes current_ring_event() so a scene
## can draw the ring and feed back a press, but has no drawing code itself.

enum Phase { PLAYER_CHOOSING, PLAYER_TIMING_EVENT, ENEMY_TURN, COMBAT_OVER }

signal phase_changed(phase: Phase)
signal card_committed(card: Card)
signal timing_resolved(card: Card, tier: int, damage: int)
signal damage_applied(target: Combatant, amount: int)
signal enemy_acted(damage: int)
signal combat_ended(victor: Combatant)

var player: Combatant
var enemy: Combatant
var hand: Array[Card] = []

var phase: Phase = Phase.PLAYER_CHOOSING

var _pending_card: Card = null
var _pending_ring: RingTimingEvent = null

func setup(p_player: Combatant, p_enemy: Combatant, p_hand: Array[Card]) -> void:
	player = p_player
	enemy = p_enemy
	hand = p_hand
	phase = Phase.PLAYER_CHOOSING
	phase_changed.emit(phase)

## Card selection is untimed by design (DESIGN.md: "Players can think as
## long as they want"). This pays mana and, if the card has a timing event,
## starts it; otherwise the card resolves immediately at base effect.
func choose_card(card: Card) -> bool:
	if phase != Phase.PLAYER_CHOOSING:
		return false
	if not player.can_afford(card):
		return false

	player.pay_mana(card)
	_pending_card = card
	card_committed.emit(card)

	if card.has_timing_event():
		_pending_ring = RingTimingEvent.from_card_event(
			card.event,
			player.to_combatant_stats(GameSettings.assist_mode_enabled, GameSettings.input_calibration_ms)
		)
		phase = Phase.PLAYER_TIMING_EVENT
		phase_changed.emit(phase)
	else:
		_resolve_effect(RingTimingEvent.Tier.MISS)
	return true

## The ring currently being played, or null outside PLAYER_TIMING_EVENT.
func current_ring_event() -> RingTimingEvent:
	return _pending_ring

## The player pressed at `elapsed_ms` since the event started.
func resolve_timing_press(elapsed_ms: float) -> void:
	if phase != Phase.PLAYER_TIMING_EVENT:
		return
	_resolve_effect(_pending_ring.resolve_press(elapsed_ms))

## The event ran out with no press.
func resolve_timing_timeout() -> void:
	if phase != Phase.PLAYER_TIMING_EVENT:
		return
	_resolve_effect(_pending_ring.resolve_timeout())

func _resolve_effect(tier: int) -> void:
	var card := _pending_card
	var damage: int
	if _pending_ring != null:
		damage = _pending_ring.damage_for_tier(card.base_damage, tier)
	else:
		damage = roundi(card.base_damage)

	enemy.take_damage(damage)
	timing_resolved.emit(card, tier, damage)
	damage_applied.emit(enemy, damage)

	_pending_card = null
	_pending_ring = null

	if not enemy.is_alive():
		_end_combat(player)
		return

	_run_enemy_turn()

func _run_enemy_turn() -> void:
	phase = Phase.ENEMY_TURN
	phase_changed.emit(phase)

	if not enemy.is_passive:
		player.take_damage(enemy.attack_damage)
		enemy_acted.emit(enemy.attack_damage)
		damage_applied.emit(player, enemy.attack_damage)

		if not player.is_alive():
			_end_combat(enemy)
			return

	player.refill_mana()
	phase = Phase.PLAYER_CHOOSING
	phase_changed.emit(phase)

func _end_combat(victor: Combatant) -> void:
	phase = Phase.COMBAT_OVER
	phase_changed.emit(phase)
	combat_ended.emit(victor)
