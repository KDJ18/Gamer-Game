# Card RPG: Design Handoff

Working notes exported from a design chat, for use in Claude Code. Drop this in the repo root (as `DESIGN.md`, or merge into `CLAUDE.md`) and build from it.

**Engine and language: Godot 4 (GDScript).** Scope: multiplayer/online is planned (not yet designed), so combat state should stay server-authoritative-friendly rather than assuming a single local player. Decided 2026-09-21.

Sections are marked **Decided**, **Prototype values** (tuned in a browser demo, placeholders to be re-tuned in the real game), or **Open**.

---

## 1. Pitch (Decided)

A persistent, free-roam RPG with turn-based card combat. Think Wizard101 crossed with Slay the Spire 2, with an added skill element: some cards trigger a short timing event when played, and hitting it well makes the card stronger.

- Persistent character and card collection (not run-based, not a roguelike reset).
- Tone: mysterious / edgy.
- Multi-world, multi-time setting (details not yet designed).
- Combat is the main differentiator: timing events on cards, plus card and skill/class stacking.

## 2. Core structure (Decided)

- **World:** walkable, possibly open-world. NPCs offer quests and shop menus.
- **Dungeons:** risk/reward. The player chooses what to wager before entering (see section 6).
- **Progression:** XP from quests, killing mobs, and dungeons. Unlocks levels, skills, cards, cosmetics, areas.
- **Character creation:** appearance and name customization.
- **Input:** number keys select cards. Timing events use a different key (space) so the two can't be confused.

### Classes (Decided list, roles not designed)
Weapon Master, Mage/Warlock, Cleric, Shield Bearer, Augmenter.
- Weapon Master starts with the same 5 common cards.
- Open: whether classes can be combined ("class stacking") and whether cards are class-locked.

### NPCs and items (Decided)
- NPCs: shopkeepers (spells, skills, items), a "world keeper".
- Items: cards, consumables (including cosmetics), relics. Relics are a high priority, details TBD.

## 3. Combat rules

### Decided
- Strict alternating turns. **Selecting a card is untimed.** Players can think as long as they want.
- Resources for now: **mana and HP only.** Card costs are in mana.
- Time enters combat only through **card execution timing events** (section 4).

### Explicitly dropped
- Turn timers and per-card selection timers.
- The original "card timing by rarity" idea (Common 20s down to Mythical 1s).
- Cast-speed as a real-time countdown. Cast speed survives only as a stat that widens timing windows.

### Open / deferred
Hand size and draw rules, per-class hand differences, party mana pool vs per-class mana, luck stat, status effects (poison, bleeding: bleeding was described as 1 damage per stack, gone after 1 round), gear, relic rules, enemy behavior. These were intentionally postponed.

## 4. Timing events (Decided concept, Prototype values)

### Turn flow
1. Player picks a card (untimed).
2. Mana is paid. The card is committed.
3. If the card has a timing event, it plays (about 1 to 2 seconds).
4. The result sets an outcome tier.
5. The card's effect resolves, modified by the tier.

### Rules that should hold
- **A miss still does the card's base effect.** A miss is never worse than the card would be with no event.
- Only some cards have events. Suggested range: about a quarter to a third of a deck, so a turn doesn't become a string of minigames.
- Include an **assist option** from the start (wider windows or auto-success at baseline). Cheaper to design in now than to retrofit.
- Include a **calibration setting** for input latency.
- Balance around the average outcome, not the perfect one.
- Tune by the **millisecond window** (how long the ring is inside a zone), not by pixels. Pixels are a display detail.

### Event types (only the ring is prototyped)
Build a small set of reusable types, driven by data:
- **Ring / stop the marker:** a ring shrinks onto a target circle; press when they line up. (Prototyped.)
- Hold and release: hold to charge, release inside a window.
- Sequence: tap 2 to 4 prompts in rhythm.
- Mash: rapid taps fill a meter.
- Reactive: timing on the enemy's turn (block, parry, dodge).

Idea, not decided: classes lean on different event types (Weapon Master sequences, Mage hold-and-release, Shield Bearer parries).

### Ring event spec (Prototype values)
Zones are concentric around a target circle. From outside in:

| Zone | Color | Tier |
|---|---|---|
| Outside the outer zone | none | Miss |
| Outer | green | Good |
| Middle | yellow | Great |
| Center | red | Critical |

- Ring shrinks **linearly** from start radius to end radius over the card's duration.
- On the press, compute `d = abs(ringRadius - targetRadius)`. Tier = Critical if `d <= critHalf`, else Great if `d <= greatHalf`, else Good if `d <= goodHalf`, else Miss.
- If the player never presses, the event resolves when the ring hits its minimum radius (effectively a miss).
- Damage = `round(baseDamage * tierMultiplier[tier])`.

Prototype geometry constants (prototype pixel units, arbitrary):
```
ringStartRadius = 115
targetRadius    = 40
ringEndRadius   = 6
speed_px_per_ms = (ringStartRadius - ringEndRadius) / durationMs
window_ms       = 2 * halfWidthPx / speed_px_per_ms
```

Zone half-widths (px) for a card with window scale `s`, crit base `cb`, player stats `castSpeed` (0 to 100) and `critChancePct` (0 to 50):
```
add   = 0.05 * castSpeed
crit  = clamp(cb + 0.5 * add + 0.2 * critChancePct, 1.5, 22)
great = min(32, max(crit + 4, 12 * s + add))
good  = min(40, max(great + 4, 22 * s + add))
```
Design intent behind the formula:
- Each zone has a floor and a cap so stacked modifiers can't produce impossible or trivial windows.
- Crit chance widens **only** the crit zone. It replaces a random crit roll (don't have both, or crit gets double benefit).
- Cast speed widens all zones a little, and the crit zone at half strength.
- Modifiers are additive, not multiplicative, to stay readable.
- Show the final window to the player (card tooltip) before they play.

### Prototype cards
The design principle: **heavy cards are forgiving to hit but have the hardest crit and the biggest crit payoff. Light cards are hard to hit at all, but have a slightly larger crit zone and a small crit payoff.**

| Card | Type | Mana | Base dmg | Zone scale `s` | Crit base `cb` | Ring time | Tier multipliers (Miss/Good/Great/Crit) |
|---|---|---|---|---|---|---|---|
| Crushing blow | Heavy | 3 | 14 | 1.5 | 1.5 | 1800 ms | 1 / 1.15 / 1.3 / 3.6 |
| Fireball | Standard | 2 | 8 | 1.0 | 2.5 | 1400 ms | 1 / 1.25 / 1.5 / 2 |
| Dagger throw | Light | 1 | 4 | 0.7 | 4.0 | 1100 ms | 1 / 1.5 / 2 / 3 |

Resulting windows at 0 crit chance, 0 cast speed (approximate):

| Card | Good window | Crit window | Crit damage |
|---|---|---|---|
| Crushing blow | ~1090 ms | ~50 ms | 50 |
| Fireball | ~565 ms | ~64 ms | 16 |
| Dagger throw | ~310 ms | ~81 ms | 12 |

Balance notes from testing:
- Crushing blow crit (50 dmg) one-shots the 50 HP test dummy. That is the intended fantasy.
- Damage per mana at all-miss vs all-crit: heavy about 4.7 to 16.8, standard 4 to 8, dagger 4 to 12. Heavy has the highest ceiling, so watch that it doesn't become the best pick for everything. Levers: mana cost, ring time, crit multiplier.
- A crit window near 50 ms is close to the edge of reliably humanly hittable. Consider a higher floor, and always keep the assist option.
- Crit chance adds a flat pixel amount to every card, which helps small crit zones more in relative terms. Decide later whether to make it proportional.

### Other modifiers explored (not in final prototype)
Rarity: rarer cards get a faster ring, narrower zones, and more base damage (explored: window scale 1.3, 1.15, 1.0, 0.85, 0.7 for Common to Mythical; ring 1.8 s down to 1.0 s). Rarity should come with a visibly bigger payoff or rare cards feel like a penalty.
Class: only a small flat bonus (0 to 2 px) was tested, and it was barely perceptible. Recommendation: make classes differ by event type rather than window modifiers.
Card type: type mainly picks the event type and base window, as in the table above.

## 5. Data-driven design (Recommended)

Cards should be data. Adding a card should be a data change, not new code:
```json
{
  "id": "dagger_throw",
  "name": "Dagger throw",
  "type": "light",
  "manaCost": 1,
  "baseDamage": 4,
  "event": {
    "kind": "ring",
    "durationMs": 1100,
    "zoneScale": 0.7,
    "critBase": 4.0,
    "tierMultipliers": [1, 1.5, 2, 3]
  }
}
```
Keep the event system generic (event kind + parameters) so new event types plug in later.

## 6. Dungeon wager (Decided concept, details Open)

- **Decided:** the risk is chosen by the player. Before entering a dungeon they stake specific cards. Unstaked cards are safe.
- Proposed shape: win returns the stake plus a reward that scales with what was staked (higher-tier card, upgrade, relic). Lose costs the staked cards.
- Proposed: staking more, or better cards, raises reward and can unlock harder modifiers.
- Open: are lost cards gone forever or dropped at the dungeon entrance and recoverable? Is there a minimum stake? Does the earlier idea of also losing XP levels and max HP on death stay or go? (Recommendation: drop it, since card loss alone is easier to tune and avoids death spirals.)
- Also part of the original notes: rare events and boss sightings drop the best gear.

## 7. Known problems and deferred decisions

Raised in review and intentionally postponed:
- Levels vs deckbuilding: XP-driven stat growth weakens the point of deckbuilding. Decide how much power comes from levels vs cards and relics.
- Luck is undefined.
- Status effect rules (stacking, duration, cleansing).
- Solo vs multiplayer. "Party" and "world keeper" hint at online play. This is a huge scope fork and needs an answer early.
- Support classes (Cleric, Shield Bearer, Augmenter) need roles that make sense in solo play.
- Hand size varying by class is a balance risk.
- Number keys cap out around 9 to 10 cards, so a growing hand needs another input method.
- How enemies appear in the open world (visible enemies, random encounters, arenas).
- Setting and lore are mostly empty.

## 8. Suggested build order

Each step should end with something playable. Fun test for each: *would I replay this for 10 minutes with nothing else in the game?* If not, don't move on.

1. One fight: 1 enemy, ~15 cards, mana and HP. No timing events.
2. Timing events on 2 to 3 cards (ring type), three to four tiers, assist option, calibration.
3. A dungeon: a sequence of fights ending in a reward.
4. Deck editing between fights, plus the wager mechanic.
5. A hub: menu or small map with a shop and a quest NPC.
6. A second class.
7. Only then, the walkable open world. Fake it with a menu map until combat is fun.

Keep a parking lot for everything deferred (open world, classes 2 to 5, crit/luck stats, status effects, cosmetics, multi-world).

Optional: prototype the rules outside the engine first (spreadsheet, paper cards, or a text-based script) to find out whether mana and HP alone make interesting decisions.

## 9. First tasks for Claude Code

1. Ask which engine and language to use, and whether the game is single-player only.
2. Set up a minimal project with a card data format (section 5) and a combat state machine: draw, choose card, pay mana, resolve event, apply effect, enemy turn.
3. Implement the ring event as a standalone, testable module. Inputs: event parameters and player stats. Output: tier. Unit-test the zone formula and tier resolution with the values in section 4.
4. Add the three prototype cards and a training dummy (50 HP).
5. Add an assist mode toggle and an input calibration setting.

## 10. Weapon Master card pool (Draft, not balanced, not implemented)

Flavor: daggers, hammers, bows -- any medieval weapon. Weapon Master starts
with the 5 shared common cards (section 2); the cards below are class-specific
on top of that, rarity-tiered (Common / Uncommon / Rare).

Numbers below are first-draft and explicitly not balanced yet -- don't treat
them as final when implementing.

### Common
- **Slash** -- 3-5 damage + bleed (amount TBD)
- **Backstab** -- 2 bleed to all enemies
- **Swipe** -- 2-4 damage to all enemies
- **Multishot** -- 5 arrows at one enemy, 1 damage per landing arrow
- **Parry** -- chance to negate an incoming common attack; applies 1 bleed
- **Dodge** -- avoid an incoming attack entirely
- **Jagged Edge** -- 2 damage + 4 bleed

### Uncommon
- **Quickdraw** -- mash as many arrows as possible in a 2s window, 1 damage each, capped at 10
- **Split Shot** -- 6 base damage, 50% chance to split into 12 damage
- **Gavel** -- 10 damage, 50% chance to stun the enemy for 1 turn
- **Dagger Storm** -- hits each enemy for 5 damage, 50% crit chance per hit
- **Strike** -- 4 damage per strike, up to 3 strikes within a 2s window (slider input)

### Rare
- **Double Down** -- deals damage equal to the enemy's current bleed stacks

### New systems these imply (none exist yet)
Flagging so implementation doesn't get started on cards whose prerequisites
aren't decided:
- **Bleed** and **stun** status effects -- section 3 & 7 already deferred status
  effects generally; these cards need magnitude/duration/stacking rules decided
  before "Double Down" or "Gavel" can be built.
- **Multi-enemy targeting / AoE** ("hits all enemies") -- CombatState currently
  assumes exactly one enemy (the training dummy).
- **RNG chance effects** (50% split/crit/stun) -- a mechanic distinct from the
  ring's timing-based crit tier; needs its own resolution step.
- **Two new event kinds**: Mash (Quickdraw) and a strike/slider input (Strike)
  -- only "ring" is implemented today (section 4 lists these as future event
  types but only prototyped ring).
- **Reactive event type** (Parry, Dodge: timed on the *enemy's* turn) -- combat
  is currently strict alternating turns where only the active player acts;
  reactive cards need a way to interrupt the opponent's turn.
