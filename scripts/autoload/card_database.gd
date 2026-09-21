extends Node
## Autoload singleton. Loads every card definition under res://data/cards/
## (DESIGN.md section 5: "adding a card should be a data change, not new
## code").

var _cards: Dictionary = {}  # id -> Card

func _ready() -> void:
	load_all()

func load_all(path: String = "res://data/cards") -> void:
	_cards.clear()
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("CardDatabase: could not open %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_card_file("%s/%s" % [path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_card_file(file_path: String) -> void:
	var text := FileAccess.get_file_as_string(file_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CardDatabase: invalid card JSON at %s" % file_path)
		return

	var card := Card.from_dict(parsed)
	if card.id == "":
		push_warning("CardDatabase: card at %s has no id" % file_path)
		return
	_cards[card.id] = card

func get_card(id: String) -> Card:
	return _cards.get(id)

func has_card(id: String) -> bool:
	return _cards.has(id)

func all_cards() -> Array:
	return _cards.values()
