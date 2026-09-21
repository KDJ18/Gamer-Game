extends Control
## Playable scaffold for DESIGN.md section 9, tasks 2 and 4: one fight
## against a 50 HP training dummy, with the three prototype cards and their
## ring timing events. Number keys choose a card (untimed); Space resolves
## the timing event; F1 toggles assist mode.

@onready var ring_widget: RingWidget = $RingWidget
@onready var player_status: Label = $UI/PlayerStatus
@onready var dummy_status: Label = $UI/DummyStatus
@onready var hand_label: Label = $UI/HandLabel
@onready var assist_label: Label = $UI/AssistLabel
@onready var log_label: RichTextLabel = $UI/Log

var combat: CombatState

func _ready() -> void:
	combat = CombatState.new()
	add_child(combat)
	combat.phase_changed.connect(_on_phase_changed)
	combat.card_committed.connect(_on_card_committed)
	combat.timing_resolved.connect(_on_timing_resolved)
	combat.enemy_acted.connect(_on_enemy_acted)
	combat.combat_ended.connect(_on_combat_ended)

	ring_widget.pressed.connect(_on_ring_pressed)
	ring_widget.timed_out.connect(_on_ring_timed_out)

	_start_fight()

func _start_fight() -> void:
	var player := Combatant.new("player", "You", 30, 10)
	var dummy := Combatant.new("dummy", "Training Dummy", 50, 0, true, 0)

	var hand: Array[Card] = []
	for id in ["crushing_blow", "fireball", "dagger_throw"]:
		var card: Card = CardDatabase.get_card(id)
		if card != null:
			hand.append(card)

	combat.setup(player, dummy, hand)
	_log("[color=gray]A training dummy appears. 50 HP.[/color]")
	_refresh_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		GameSettings.set_assist_mode(not GameSettings.assist_mode_enabled)
		_refresh_status()
		return

	if combat == null or combat.phase != CombatState.Phase.PLAYER_CHOOSING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _try_play(0)
			KEY_2: _try_play(1)
			KEY_3: _try_play(2)

func _try_play(index: int) -> void:
	if index < 0 or index >= combat.hand.size():
		return
	var card: Card = combat.hand[index]
	if not combat.player.can_afford(card):
		_log("[color=orange]Not enough mana for %s.[/color]" % card.display_name)
		return
	combat.choose_card(card)

func _on_phase_changed(phase: CombatState.Phase) -> void:
	if phase == CombatState.Phase.PLAYER_TIMING_EVENT:
		ring_widget.start(combat.current_ring_event())
	_refresh_status()

func _on_card_committed(card: Card) -> void:
	_log("You play %s (%d mana)." % [card.display_name, card.mana_cost])

func _on_ring_pressed(elapsed_ms: float) -> void:
	combat.resolve_timing_press(elapsed_ms)

func _on_ring_timed_out() -> void:
	combat.resolve_timing_timeout()

func _on_timing_resolved(card: Card, tier: int, damage: int) -> void:
	_log("  -> %s: %d damage." % [RingTimingEvent.tier_name(tier), damage])

func _on_enemy_acted(damage: int) -> void:
	_log("[color=red]Training Dummy hits you for %d.[/color]" % damage)

func _on_combat_ended(victor: Combatant) -> void:
	if victor == combat.player:
		_log("[color=lime]Training dummy defeated![/color]")
	else:
		_log("[color=red]You were defeated.[/color]")
	_refresh_status()

func _refresh_status() -> void:
	if combat.player == null:
		return
	player_status.text = "You  HP %d/%d   Mana %d/%d" % [
		combat.player.hp, combat.player.max_hp, combat.player.mana, combat.player.max_mana
	]
	dummy_status.text = "Training Dummy  HP %d/%d" % [combat.enemy.hp, combat.enemy.max_hp]

	var lines := PackedStringArray()
	for i in combat.hand.size():
		var card: Card = combat.hand[i]
		lines.append("[%d] %s  (%d mana, %d dmg)" % [i + 1, card.display_name, card.mana_cost, card.base_damage])
	hand_label.text = "\n".join(lines)

	assist_label.text = "Assist mode: %s (F1 to toggle)" % ("ON" if GameSettings.assist_mode_enabled else "off")

func _log(text: String) -> void:
	log_label.append_text(text + "\n")
