class_name Card
extends RefCounted
## A card's static, data-driven definition (DESIGN.md section 5). Loaded
## from JSON by CardDatabase — adding a card is a data change, not new code.

var id: String = ""
var display_name: String = ""
var type: String = "standard"  # "heavy" | "standard" | "light" | ...
var mana_cost: int = 0
var base_damage: float = 0.0
## null if this card has no timing event (most of the deck, per design:
## "about a quarter to a third of a deck" should have one).
var event: CardEventData = null

static func from_dict(d: Dictionary) -> Card:
	var card := Card.new()
	card.id = d.get("id", "")
	card.display_name = d.get("name", card.id)
	card.type = d.get("type", "standard")
	card.mana_cost = int(d.get("manaCost", 0))
	card.base_damage = float(d.get("baseDamage", 0.0))
	if d.get("event") is Dictionary:
		card.event = CardEventData.from_dict(d["event"])
	return card

func has_timing_event() -> bool:
	return event != null
