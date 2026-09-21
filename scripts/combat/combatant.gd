class_name Combatant
extends RefCounted
## Mutable in-fight state for one side of combat: a player or an enemy
## (including a passive training dummy, DESIGN.md section 9 task 4).

var id: String
var display_name: String
var max_hp: int
var hp: int
var max_mana: int
var mana: int
var cast_speed: float = 0.0        # 0..100
var crit_chance_pct: float = 0.0   # 0..50

## True for a training dummy: it never acts on its "turn".
var is_passive: bool = false
var attack_damage: int = 0

func _init(p_id: String, p_display_name: String, p_max_hp: int, p_max_mana: int, p_is_passive: bool = false, p_attack_damage: int = 0) -> void:
	id = p_id
	display_name = p_display_name
	max_hp = p_max_hp
	hp = p_max_hp
	max_mana = p_max_mana
	mana = p_max_mana
	is_passive = p_is_passive
	attack_damage = p_attack_damage

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)

func can_afford(card: Card) -> bool:
	return mana >= card.mana_cost

func pay_mana(card: Card) -> void:
	mana = maxi(0, mana - card.mana_cost)

func refill_mana() -> void:
	mana = max_mana

func to_combatant_stats(assist_enabled: bool = false, calibration_ms: float = 0.0) -> CombatantStats:
	return CombatantStats.new(cast_speed, crit_chance_pct, assist_enabled, calibration_ms)
