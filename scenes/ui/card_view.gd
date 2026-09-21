class_name CardView
extends PanelContainer
## Visual representation of one Card in the hand: a colored frame per card
## type, icon, name, mana cost and damage, plus hover lift and click/drag
## interactions. Purely presentational -- it never touches CombatState
## itself, it just reports what the player did via signals.

signal card_clicked(index: int)

const TYPE_COLORS := {
	"heavy": Color(0.52, 0.18, 0.15),
	"standard": Color(0.16, 0.32, 0.58),
	"light": Color(0.15, 0.42, 0.26),
}
const TYPE_COLOR_DEFAULT := Color(0.24, 0.24, 0.30)
const TYPE_BORDER_TINT := Color(1.0, 1.0, 1.0, 0.35)

const HOVER_LIFT_PX := 16.0
const HOVER_TIME_SEC := 0.12

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var cost_label: Label = %CostLabel
@onready var damage_label: Label = %DamageLabel

var card: Card
var card_index: int = -1
var playable: bool = true

var _base_position: Vector2
var _hover_tween: Tween

func _ready() -> void:
	_base_position = position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_card(p_card: Card, index: int) -> void:
	card = p_card
	card_index = index

	name_label.text = card.display_name
	type_label.text = card.type.capitalize()
	cost_label.text = "MP %d" % card.mana_cost
	damage_label.text = "DMG %d" % int(card.base_damage)

	if card.icon_path != "" and ResourceLoader.exists(card.icon_path):
		icon_rect.texture = load(card.icon_path)

	var frame_color: Color = TYPE_COLORS.get(card.type, TYPE_COLOR_DEFAULT)
	var style := StyleBoxFlat.new()
	style.bg_color = frame_color
	style.border_color = frame_color.lightened(0.4)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	add_theme_stylebox_override("panel", style)

	var tip := "%s  (%d mana, %d base damage)" % [card.display_name, card.mana_cost, int(card.base_damage)]
	if card.has_timing_event():
		tip += "\nTiming event: %.0f ms ring" % card.event.duration_ms
	tooltip_text = tip

func set_playable(p_playable: bool) -> void:
	playable = p_playable
	modulate = Color(1, 1, 1, 1) if playable else Color(0.55, 0.55, 0.55, 0.75)

func play_animation() -> Tween:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", _base_position.y - 80.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_property(self, "scale", Vector2(0.85, 0.85), 0.22)
	return tween

func _on_mouse_entered() -> void:
	if not playable:
		return
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "position:y", _base_position.y - HOVER_LIFT_PX, HOVER_TIME_SEC).set_trans(Tween.TRANS_QUAD)

func _on_mouse_exited() -> void:
	if not playable:
		return
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "position:y", _base_position.y, HOVER_TIME_SEC).set_trans(Tween.TRANS_QUAD)

func _gui_input(event: InputEvent) -> void:
	if not playable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(card_index)

## Standard Godot Control drag-and-drop: dropping the returned data onto a
## Control that implements _can_drop_data/_drop_data (the battlefield, in
## this game) plays the card. The real CardView node never moves, so a drop
## anywhere else is automatically "snap back" -- there's nothing to undo.
func _get_drag_data(at_position: Vector2) -> Variant:
	if not playable:
		return null
	var preview_root := Control.new()
	var ghost := duplicate() as Control
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate.a = 0.85
	ghost.position = -at_position
	preview_root.add_child(ghost)
	set_drag_preview(preview_root)
	return {"card_index": card_index}
