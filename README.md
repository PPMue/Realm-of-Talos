# Realm of Talos

2D roguelite party builder (Godot 4.7, GDScript). You command the last city and defend it from monsters for 30 days. Currently: a playable run (a calendar of battle, free, event and boss days) with countdown battles, weapon proficiency, combat arts and magic that carry through the run.

## Run

Open the folder in Godot 4.7 and press Play, or from a shell:

```
godot --path .
```

### A run

- The city screen is the hub. At the top: the day, city health (100; at 0 the run is lost), gold, iron ore and timber. Below: today and the next 7 days by type. In the middle: today's activity. At the bottom: the party at a glance, and **Manage party** (P).
- 30 days. A boss on days 10, 20 and 30; the day before each boss is always free; day 1 is always a battle. Each block of ten has 5-6 battles, 2 free days and 1-2 events.
- You start with 2 random companions of the seven (five fighters and two mages; at least one of the two is never a mage). Up to 5 are fielded, left to right (rightmost = nearest the enemies); the rest wait in reserve. On the party screen you choose who is fielded and their order, hand out weapons from the armory (a weapon not allowed says why: the grade it needs) and open the combat arts screen. All of this is free on any day until you commit to the day's activity.
- Levels: every companion starts at level 1. A won battle grants an XP pool (by danger, growing with the day; shown on each front) split evenly among the fielded companions still in the run at its end, injured ones included; reserve companions and lost battles give none. On each level-up every stat but BLD rolls its own growth rate (each companion's own, about 40% on average) to rise by 1, and at least 2 stats always rise. Max HP gained raises current HP too. Tavern hires join at the roster's average level, rounded down. A companion fielded in every battle in a party of four ends the run around level 13.
- HP carries over between days. At the end of every day each companion heals 20% of max HP. Stamina is full at the start of every battle. A companion injured in battle comes back at 1 HP, won or lost; one removed in battle is gone for the rest of the run (their weapon returns to the armory).
- **Battle day**: 2 or 3 fronts (keys 1-3), each with its enemies, a danger of 1-3, the reward and the city health lost if the battle is lost (15/20/25). Fronts you do not pick have no consequence. Enemies get stronger as the days pass.
- **Boss day**: one front. Losing ends the run; beating the day 30 boss wins it.
- **Free day**: 2 actions, each once a day: Rest (everyone to full HP and every spell back to full uses; nothing else restores spell uses), Shop (weapons; any number of purchases is one action; rare magic weapons turn up now and then from day 8), Tavern (hire 1 of 1-2 companions offered, mages included), Repair (materials for city health). End day (E) when done; unused actions are lost.
- **Event day**: a short story and 2-3 choices (keys 1-3) that trade gold, materials, city health, companions' HP or a free weapon.
- The run is lost when the city reaches 0, a boss wins, or no companions are left.

### Battles

- The party is the row along the bottom; the rightmost companion stands nearest the enemies and is aimed at most. Click a READY companion to choose who acts.
- Pick an action on the left, or press its number: Attack, the companion's equipped combat arts (up to 3), Magic (for anyone who knows a spell), Guard, Focus. Hover an action to see what it does; an art you cannot afford is greyed out and says why.
- Magic opens the companion's spells in the same place, each with its school, tier and uses left (number keys; Back, Esc or right-click returns; more than six spells page with More). A spell with no uses left is greyed out and says why.
- For Attack and single-target arts, point at an enemy to see hit %, damage and crit %, then click it to strike. Arts that strike every enemy light up every enemy at once; click any of them to confirm. Right-click or Esc backs out.
- A spell aimed at a companion is cast by clicking their panel below; each panel shows what it would do (for a heal, HP before and after). A spell for every ally or every enemy lights them all up; one click confirms.
- Under each enemy: its HP, an hourglass with the ticks left until it acts, and the kind of action coming. Every action you take, art, spell or not, is one tick. A pending action already pushed back by a spell shows its countdown in pale blue with a DELAYED tag.
- Traits such as FLYING show as a tag above an enemy's name (hover it). The forecast says EFFECTIVE when the strike doubles Mt, and MAGIC when it is MAG against RES.
- When nobody is ready, Wait (1 or Space) lets a tick pass. L opens the battle log. Clicking during playback speeds it up.
- Hover a companion or enemy for its stats.

Proficiency and arts:

- Each companion has a grade in every weapon type: E, E+, D, D+, C, C+, B, B+, A, A+, S. Attacking gives 1 point in the type of the weapon held, a combat art 2; Guard, Focus and Wait give none. One companion can gain at most 8 points per battle. The grade and progress for the weapon held show under the companion's name on the left.
- Every grade reached teaches one random art of that weapon type the companion does not know yet (higher grades roll higher tiers), equipped straight away if a slot is free. A banner announces it.
- Weapons need a grade to be held: iron any grade, steel C, silver B (silver is sold from day 11).
- After a battle the result screen shows the reward or the city damage, XP gained, each level-up and the stats that rose, who was injured or removed, and each companion's grade progress, then goes back to the city.

### Magic

- Two schools: **Black Magic** (offence) and **White Magic** (support). Every companion has a grade in each, with the same grades and thresholds as weapons. Casting gives 4 points in the spell's school, up to 12 magic points per battle (separate from the weapon cap). Every school grade reached teaches a random spell of that school not yet known, with the same tier odds, no-duplicate rule and fall-through as combat arts. All known spells can be cast; there are no slots.
- A spell costs one tick and no stamina, then a recovery of its tier (1-3). Each spell has a number of uses per companion (6 / 4 / 2 by tier, set per spell); uses last between battles and days and only Rest restores them.
- Black spells: damage = caster MAG + spell Mt - target RES (at least 1), with the normal accuracy and crit formulas using the spell's own Hit. They may strike every enemy, ignore part of RES, debuff the target, and delay the target's pending action: a pending action can be delayed only once; the next one it picks can be delayed again. Combat arts never touch countdowns.
- White spells always succeed: heals (caster MAG + the spell's power, on anyone still in the line; lifting an injured companion above 0 HP clears the injury; companions removed from the run cannot be healed), buffs, less damage taken, a veil (enemies aim elsewhere) or a beacon (enemies aim here), and removing debuffs, on one ally or all. Healing spells can also be cast on the party screen between battles, spending uses.
- Enemy actions are physical (STR against DEF) or magic (MAG against RES); Guard halves both. The Goblin Wizard, the Frostfang Warden's frost and the Oathbreaker's Black Tide are magic. Enemy MAG grows with the day like STR.
- **Magic weapons** are rare variants of the normal types: Attack and arts with them use MAG against RES with the weapon's own Mt.
- **Effectiveness**: enemies carry traits (so far Flying). Weapons, arts and spells list the traits they are effective against; every bow is effective against Flying. An effective strike doubles Mt (the weapon's, or the spell's) before DEF or RES is subtracted; effective through both weapon and art still doubles once. The multiplier is `BattleConfig.EFFECTIVE_MIGHT_MULT`.
- The arts screen (Arts and Magic) shows both magic grades and every known spell with uses left; the party screen shows spell uses and casts heals; the battle result lists magic grades gained and spells learned.

## Tests

```
godot --headless --path . --import          # first time / after adding scripts: builds the class cache
godot --headless --path . -s res://tests/run_tests.gd
```

Exit code 0 means every test passed. `TEST_ONLY=playthrough` runs only tests whose name contains that text, `TEST_SKIP=playthrough` skips them; `TEST_VERBOSE=1` prints each test's name. Besides the battle rules (`run_tests.gd`), the run rules (`run_rule_tests.gd`) and magic and effectiveness (`magic_tests.gd`), the run prints a random-policy battle win rate, how fast grades rise, and an automated playthrough: a simple policy (`run_policy.gd`) plays 200 whole runs through the rule classes and reports how often it wins and on which day runs end.

## Layout

- `scripts/battle/` battle rules: plain classes, no nodes or UI, seeded `RandomNumberGenerator` injected. `battle_config.gd` holds every tuning number (grade thresholds, points per action, the per-battle cap, the tier odds per grade). `proficiency.gd` is the grade rules (including whether a companion may equip a weapon), `art_learning.gd` picks the art learned on a grade-up.
- `scripts/run/` the run rules: plain classes, no nodes or UI, every random choice from an injected seeded generator. `Run` (the day flow, city, gold and materials, roster and line, today's pending choice, the outcome; commands return false or a reason when not allowed), `RunCalendar`, `RunCompanion` (data, progress, HP between days), `Levels` (XP per level and the growth rolls), `RunInventory`/`OwnedWeapon` (the armory: each weapon held by at most one companion), `Front`, `BattleReport`, and `run_config.gd` with every run tuning number (day counts, rewards, city damage, prices, enemy scaling). `CompanionProgress` is what a companion carries between battles: level, XP and stat gains, proficiency, known and equipped arts, and the weapon in hand; `Battle` reads and updates it.
- `scripts/data/` `Resource` classes for companions, enemies, weapons, combat arts, the art library, spells (`SpellData`) and the spell library, enemy traits (`EnemyTraits`), enemy actions and effects. `scripts/battle/spell_learning.gd` picks the spell learned on a school grade-up; `CombatMath.DamageType` is physical or magic.
- `data/` the `.tres` data: companions (stats, growth rates, weapon, starting grades, signature art), enemies (with their action lists; bosses in `enemies/bosses/`), weapons (iron, steel, silver of each type), `arts/<weapon type>/` combat arts, `arts/art_library.tres` (every art that can be learned; signature arts are not in it), `spells/black/` and `spells/white/` spells with `spells/spell_library.tres` (every spell that can be learned; the mages' signature spells are not in it), `battles/prototype_battle.tres` (used by the battle tests), and `run/`: `run_content.tres` lists everything a run is built from: the companions, front `sites/`, enemy `groups/` (danger and the days they appear), `bosses/` (one per boss day), `events/` and `shop/` stock. A new event, group or shop item is a new `.tres` added to that list; no code.
- `scripts/ui/`, `scenes/city/city.tscn` (the main scene). `city_screen.gd` is the hub and opens the party (`party_screen.gd`, which opens `arts_screen.gd`), shop and tavern (`store_screen.gd`), battle (`battle_screen.gd`) and run-end screens over itself. The battle screen plays a battle the run prepared (`Run.start_battle`), emits `finished`, and shows the `BattleReport` the run hands back. Screens only read run and battle state and call their commands. `ui_theme.gd` holds the colours and fonts; every screen is built from `SlantPanel`, `SlantBar`, `ActionButton` and the run widgets (`FrontCard`, `ActivityCard`, `CompanionChip`, `RowButton`, `DayStrip`, `CityBackdrop`). The layout is designed at 1920x1080 and scales with the window.
- `tests/` headless tests: `run_tests.gd` (battle rules, and the runner), `run_rule_tests.gd` (run rules and the playthrough), `run_policy.gd` (the automated player).
- `assets/` character and enemy art.

## Combat arts

An art belongs to one weapon type, can only be used with a weapon of that type in hand, and costs stamina and a recovery like any action (always one tick). Tier 1: 4-6 STA, sits out 1 action; tier 2: 8-10 STA, 2 actions; tier 3: 13-15 STA, 3 actions. Effects are limited to bonus Mt/Hit/Crit, striking every enemy, striking twice, ignoring part of DEF, a debuff on each enemy hit and a buff on the user. `WeaponData.unique_art` is reserved for rare weapons that grant an art of their own; nothing uses it yet, nor `CombatArtData.durability_cost`.

## Not built yet

Room is left for, but nothing exists of: weapon durability (`WeaponData.max_uses`, `CombatArtData.durability_cost`), wooden weapons, damage over time, spell or skill books, crafting and the smithy (iron ore is only traded and used for repairs so far), city buildings, jobs for companions in reserve, skill books, and anything carried between runs.
