# Realm of Talos

2D roguelite party builder (Godot 4.7, GDScript). You command the last city and defend it from monsters for 30 days. Currently: a playable run (a calendar of battle, free, event and boss days) with countdown battles, weapon proficiency and combat arts that carry through the run.

## Run

Open the folder in Godot 4.7 and press Play, or from a shell:

```
godot --path .
```

### A run

- The city screen is the hub. At the top: the day, city health (100; at 0 the run is lost), gold, iron ore and timber. Below: today and the next 7 days by type. In the middle: today's activity. At the bottom: the party at a glance, and **Manage party** (P).
- 30 days. A boss on days 10, 20 and 30; the day before each boss is always free; day 1 is always a battle. Each block of ten has 5-6 battles, 2 free days and 1-2 events.
- You start with 2 random companions of the five. Up to 5 are fielded, left to right (rightmost = nearest the enemies); the rest wait in reserve. On the party screen you choose who is fielded and their order, hand out weapons from the armory (a weapon not allowed says why: the grade it needs) and open the combat arts screen. All of this is free on any day until you commit to the day's activity.
- Levels: every companion starts at level 1. A won battle grants an XP pool (by danger, growing with the day; shown on each front) split evenly among the fielded companions still in the run at its end, injured ones included; reserve companions and lost battles give none. On each level-up every stat but BLD rolls its own growth rate (each companion's own, about 40% on average) to rise by 1, and at least 2 stats always rise. Max HP gained raises current HP too. Tavern hires join at the roster's average level, rounded down. A companion fielded in every battle in a party of four ends the run around level 13.
- HP carries over between days. At the end of every day each companion heals 20% of max HP. Stamina is full at the start of every battle. A companion injured in battle comes back at 1 HP, won or lost; one removed in battle is gone for the rest of the run (their weapon returns to the armory).
- **Battle day**: 2 or 3 fronts (keys 1-3), each with its enemies, a danger of 1-3, the reward and the city health lost if the battle is lost (15/20/25). Fronts you do not pick have no consequence. Enemies get stronger as the days pass.
- **Boss day**: one front. Losing ends the run; beating the day 30 boss wins it.
- **Free day**: 2 actions, each once a day: Rest (everyone to full HP), Shop (weapons; any number of purchases is one action), Tavern (hire 1 of 1-2 companions offered), Repair (materials for city health). End day (E) when done; unused actions are lost.
- **Event day**: a short story and 2-3 choices (keys 1-3) that trade gold, materials, city health, companions' HP or a free weapon.
- The run is lost when the city reaches 0, a boss wins, or no companions are left.

### Battles

- The party is the row along the bottom; the rightmost companion stands nearest the enemies and is aimed at most. Click a READY companion to choose who acts.
- Pick an action on the left, or press its number: Attack, the companion's equipped combat arts (up to 3), Guard, Focus. Hover an action to see what it does; an art you cannot afford is greyed out and says why.
- For Attack and single-target arts, point at an enemy to see hit %, damage and crit %, then click it to strike. Arts that strike every enemy light up every enemy at once; click any of them to confirm. Right-click or Esc backs out.
- Under each enemy: its HP, an hourglass with the ticks left until it acts, and the kind of action coming. Every action you take, art or not, is one tick.
- When nobody is ready, Wait (1 or Space) lets a tick pass. L opens the battle log. Clicking during playback speeds it up.
- Hover a companion or enemy for its stats.

Proficiency and arts:

- Each companion has a grade in every weapon type: E, E+, D, D+, C, C+, B, B+, A, A+, S. Attacking gives 1 point in the type of the weapon held, a combat art 2; Guard, Focus and Wait give none. One companion can gain at most 8 points per battle. The grade and progress for the weapon held show under the companion's name on the left.
- Every grade reached teaches one random art of that weapon type the companion does not know yet (higher grades roll higher tiers), equipped straight away if a slot is free. A banner announces it.
- Weapons need a grade to be held: iron any grade, steel C, silver B (silver is sold from day 11).
- After a battle the result screen shows the reward or the city damage, XP gained, each level-up and the stats that rose, who was injured or removed, and each companion's grade progress, then goes back to the city.

## Tests

```
godot --headless --path . --import          # first time / after adding scripts: builds the class cache
godot --headless --path . -s res://tests/run_tests.gd
```

Exit code 0 means every test passed. `TEST_ONLY=playthrough` runs only tests whose name contains that text; `TEST_VERBOSE=1` prints each test's name. Besides the battle rules (`run_tests.gd`) and the run rules (`run_rule_tests.gd`), the run prints a random-policy battle win rate, how fast grades rise, and an automated playthrough: a simple policy (`run_policy.gd`) plays 200 whole runs through the rule classes and reports how often it wins and on which day runs end.

## Layout

- `scripts/battle/` battle rules: plain classes, no nodes or UI, seeded `RandomNumberGenerator` injected. `battle_config.gd` holds every tuning number (grade thresholds, points per action, the per-battle cap, the tier odds per grade). `proficiency.gd` is the grade rules (including whether a companion may equip a weapon), `art_learning.gd` picks the art learned on a grade-up.
- `scripts/run/` the run rules: plain classes, no nodes or UI, every random choice from an injected seeded generator. `Run` (the day flow, city, gold and materials, roster and line, today's pending choice, the outcome; commands return false or a reason when not allowed), `RunCalendar`, `RunCompanion` (data, progress, HP between days), `Levels` (XP per level and the growth rolls), `RunInventory`/`OwnedWeapon` (the armory: each weapon held by at most one companion), `Front`, `BattleReport`, and `run_config.gd` with every run tuning number (day counts, rewards, city damage, prices, enemy scaling). `CompanionProgress` is what a companion carries between battles: level, XP and stat gains, proficiency, known and equipped arts, and the weapon in hand; `Battle` reads and updates it.
- `scripts/data/` `Resource` classes for companions, enemies, weapons, combat arts, the art library, enemy actions and effects.
- `data/` the `.tres` data: companions (stats, growth rates, weapon, starting grades, signature art), enemies (with their action lists; bosses in `enemies/bosses/`), weapons (iron, steel, silver of each type), `arts/<weapon type>/` combat arts, `arts/art_library.tres` (every art that can be learned; signature arts are not in it), `battles/prototype_battle.tres` (used by the battle tests), and `run/`: `run_content.tres` lists everything a run is built from: the companions, front `sites/`, enemy `groups/` (danger and the days they appear), `bosses/` (one per boss day), `events/` and `shop/` stock. A new event, group or shop item is a new `.tres` added to that list; no code.
- `scripts/ui/`, `scenes/city/city.tscn` (the main scene). `city_screen.gd` is the hub and opens the party (`party_screen.gd`, which opens `arts_screen.gd`), shop and tavern (`store_screen.gd`), battle (`battle_screen.gd`) and run-end screens over itself. The battle screen plays a battle the run prepared (`Run.start_battle`), emits `finished`, and shows the `BattleReport` the run hands back. Screens only read run and battle state and call their commands. `ui_theme.gd` holds the colours and fonts; every screen is built from `SlantPanel`, `SlantBar`, `ActionButton` and the run widgets (`FrontCard`, `ActivityCard`, `CompanionChip`, `RowButton`, `DayStrip`, `CityBackdrop`). The layout is designed at 1920x1080 and scales with the window.
- `tests/` headless tests: `run_tests.gd` (battle rules, and the runner), `run_rule_tests.gd` (run rules and the playthrough), `run_policy.gd` (the automated player).
- `assets/` character and enemy art.

## Combat arts

An art belongs to one weapon type, can only be used with a weapon of that type in hand, and costs stamina and a recovery like any action (always one tick). Tier 1: 4-6 STA, sits out 1 action; tier 2: 8-10 STA, 2 actions; tier 3: 13-15 STA, 3 actions. Effects are limited to bonus Mt/Hit/Crit, striking every enemy, striking twice, ignoring part of DEF, a debuff on each enemy hit and a buff on the user. `WeaponData.unique_art` is reserved for rare weapons that grant an art of their own; nothing uses it yet, nor `CombatArtData.durability_cost`.

## Not built yet

Room is left for, but nothing exists of: weapon durability (`WeaponData.max_uses`, `CombatArtData.durability_cost`), wooden weapons, magic (MAG/RES stats are unused), crafting and the smithy (iron ore is only traded and used for repairs so far), city buildings, jobs for companions in reserve, skill books, and anything carried between runs.
