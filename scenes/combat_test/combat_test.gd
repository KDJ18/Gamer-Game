extends Node3D
## Playable scaffold for DESIGN.md section 9, tasks 2 and 4: one fight
## against a 50 HP training dummy, with the three prototype cards and their
## ring timing events, presented in a 3D arena.
##
## Card selection: click a card, press 1-3, or drag it onto the battlefield.
## The timing event itself resolves on Space. F1 toggles assist mode.

const CARD_VIEW_SCENE := preload("res://scenes/ui/card_view.tscn")
const CARD_SLOT_SIZE := Vector2(112, 160)

@onready var ring_widget: RingWidget3D = $RingWidget3D
@onready var player_avatar: MeshInstance3D = $PlayerAvatar
@onready var dummy_avatar: MeshInstance3D = $DummyAvatar
@onready var fx_root: Node3D = $FxRoot

@onready var drop_zone: BattlefieldDropZone = $HUD/Root
@onready var player_status: Label = $HUD/Root/TopLeft/PlayerStatus
@onready var dummy_status: Label = $HUD/Root/TopLeft/DummyStatus
@onready var assist_label: Label = $HUD/Root/TopLeft/AssistLabel
@onready var log_label: RichTextLabel = $HUD/Root/TopLeft/Log
@onready var hand_container: HBoxContainer = $HUD/Root/HandArea/HandContainer

var combat: CombatState
var _card_views: Array[CardView] = []

func _ready() -> void:
	combat = CombatState.new()
	add_child(combat)
	combat.phase_changed.connect(_on_phase_changed)
	combat.card_committed.connect(_on_card_committed)
	combat.timing_resolved.connect(_on_timing_resolved)
	combat.damage_applied.connect(_on_damage_applied)
	combat.enemy_acted.connect(_on_enemy_acted)
	combat.combat_ended.connect(_on_combat_ended)

	ring_widget.pressed.connect(_on_ring_pressed)
	ring_widget.timed_out.connect(_on_ring_timed_out)
	drop_zone.card_dropped.connect(_try_play)

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
	_build_hand_ui()
	_log("[color=gray]A training dummy appears. 50 HP.[/color]")
	_refresh_status()

func _build_hand_ui() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	_card_views.clear()

	for i in combat.hand.size():
		var slot := Control.new()
		slot.custom_minimum_size = CARD_SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_container.add_child(slot)

		var view: CardView = CARD_VIEW_SCENE.instantiate()
		slot.add_child(view)
		view.set_card(combat.hand[i], i)
		view.card_clicked.connect(_try_play)
		_card_views.append(view)

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
	if combat.phase != CombatState.Phase.PLAYER_CHOOSING:
		return
	if index < 0 or index >= combat.hand.size():
		return
	var card: Card = combat.hand[index]
	if not combat.player.can_afford(card):
		_log("[color=orange]Not enough mana for %s.[/color]" % card.display_name)
		return

	if combat.choose_card(card) and index < _card_views.size():
		_card_views[index].play_animation()

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

func _on_damage_applied(target: Combatant, amount: int) -> void:
	var avatar: MeshInstance3D = dummy_avatar if target == combat.enemy else player_avatar
	var color := Color(1.0, 0.4, 0.35) if target == combat.enemy else Color(1.0, 0.75, 0.35)
	_punch_scale(avatar)
	_spawn_damage_label(avatar.global_position + Vector3(0, 1.3, 0), "-%d" % amount, color)

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
	assist_label.text = "Assist mode: %s (F1 to toggle)" % ("ON" if GameSettings.assist_mode_enabled else "off")

	var choosing := combat.phase == CombatState.Phase.PLAYER_CHOOSING
	for i in _card_views.size():
		_card_views[i].set_playable(choosing and combat.player.can_afford(combat.hand[i]))

func _log(text: String) -> void:
	log_label.append_text(text + "\n")

func _punch_scale(mesh: MeshInstance3D) -> void:
	var base_scale := mesh.scale
	var tween := create_tween()
	tween.tween_property(mesh, "scale", base_scale * 1.18, 0.06)
	tween.tween_property(mesh, "scale", base_scale, 0.14)

func _spawn_damage_label(world_pos: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 56
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = world_pos
	fx_root.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", world_pos.y + 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)
