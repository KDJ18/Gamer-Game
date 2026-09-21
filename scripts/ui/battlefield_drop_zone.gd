class_name BattlefieldDropZone
extends Control
## Accepts a CardView's drag-and-drop payload anywhere on the HUD. Since the
## real CardView node never moves during a drag (only a preview follows the
## mouse -- see CardView._get_drag_data), a drop anywhere that ISN'T this
## zone needs no "snap back" handling: there's nothing to undo.

signal card_dropped(card_index: int)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("card_index")

func _drop_data(_at_position: Vector2, data) -> void:
	card_dropped.emit(data["card_index"])
