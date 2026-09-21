class_name Card
extends RefCounted
## A card's static, data-driven definition (DESIGN.md section 5). Loaded
## from JSON by CardDatabase — adding a card is a data change, not new code.

var id: String = ""
var display_name: String = ""
var type: String = "standard"  # "heavy" | "standard" | "light" | ...
var mana_cost: int = 0
var base_damage: float = 0.0
## Path to the card's icon art (res://assets/icons/...). Empty is valid --
## the card view falls back to a type-colored placeholder.
var icon_path: String = ""
## Multi-hit flavor, e.g. "dagger" for Dagger Barrage: total damage is
## really `hit_count * damage_per_hit`, and the UI should say "N daggers
## hit" rather than just a damage number. Empty means this card doesn't
## have that flavor -- most cards don't.
var hit_label: String = ""
var damage_per_hit: float = 1.0
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
	card.icon_path = d.get("icon", "")
	card.hit_label = d.get("hitLabel", "")
	card.damage_per_hit = float(d.get("damagePerHit", 1.0))
	if d.get("event") is Dictionary:
		card.event = CardEventData.from_dict(d["event"])
	return card

## For multi-hit cards, how many "hits" (e.g. daggers) a resolved damage
## total represents. Empty hit_label means this card has no such concept.
func hit_count_for_damage(damage: int) -> int:
	if hit_label == "":
		return 0
	return int(round(damage / maxf(damage_per_hit, 0.0001)))

func has_timing_event() -> bool:
	return event != null
