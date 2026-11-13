# Realm of Talos

2D roguelite party builder (Godot 4.7, GDScript). Currently: a playable battle prototype, 3 companions against 2 enemies, with weapon proficiency and combat arts that carry over from one battle to the next.

## Run

Open the folder in Godot 4.7 and press Play, or from a shell:

```
godot --path .
```

Play:

- The party is the row along the bottom; the rightmost companion stands nearest the enemies and is aimed at most. Click a READY companion to choose who acts.
- Pick an action on the left, or press its number: Attack, the companion's equipped combat arts (up to 3), Guard, Focus. Hover an action to see what it does; an art you cannot afford is greyed out and says why.
- For Attack and single-target arts, point at an enemy to see hit %, damage and crit %, then click it to strike. Arts that strike every enemy light up every enemy at once; click any of them to confirm. Right-click or Esc backs out.
- Under each enemy: its HP, an hourglass with the ticks left until it acts, and the kind of action coming. Every action you take, art or not, is one tick.
- When nobody is ready, Wait (1 or Space) lets a tick pass. L opens the battle log. Clicking during playback speeds it up.
- Hover a companion or enemy for its stats.

Proficiency and arts:

- Each companion has a grade in every weapon type: E, E+, D, D+, C, C+, B, B+, A, A+, S. Attacking gives 1 point in the type of the weapon held, a combat art 2; Guard, Focus and Wait give none. One companion can gain at most 8 points per battle. The grade and progress for the weapon held show under the companion's name on the left.
- Every grade reached teaches one random art of that weapon type the companion does not know yet (higher grades roll higher tiers), equipped straight away if a slot is free. A banner announces it.
- After a battle: **Fight again** keeps grades and arts and restores HP, stamina and anyone who fell; **Arts** shows every companion's grades and known arts and lets you choose which 3 are equipped; **Start over** resets the party. **Restart** in the top bar replays the current battle and drops what it had gained.

## Tests

```
godot --headless --path . --import          # first time / after adding scripts: builds the class cache
godot --headless --path . -s res://tests/run_tests.gd
```

Exit code 0 means every test passed. The run also prints a random-policy win rate and how fast grades rise over several battles in a row.

## Layout

- `scripts/battle/` battle rules: plain classes, no nodes or UI, seeded `RandomNumberGenerator` injected. `battle_config.gd` holds every tuning number (grade thresholds, points per action, the per-battle cap, the tier odds per grade). `proficiency.gd` is the grade rules (including whether a companion may equip a weapon), `art_learning.gd` picks the art learned on a grade-up.
- `scripts/run/companion_progress.gd` what a companion carries between battles: proficiency points per weapon type, known arts, equipped arts. The seed of the run state; `Battle` reads and updates it.
- `scripts/data/` `Resource` classes for companions, enemies, weapons, combat arts, the art library, enemy actions and effects.
- `data/` the `.tres` data: companions (stats, weapon, starting grades, signature art), enemies (with their action lists), weapons, `arts/<weapon type>/` combat arts, `arts/art_library.tres` (every art that can be learned; signature arts are not in it), and `battles/prototype_battle.tres` (who fights).
- `scripts/ui/`, `scenes/battle/` the battle screen and the arts screen. They only read `Battle` and `CompanionProgress` state, call their commands, and play back `Battle.events`. `ui_theme.gd` holds the colours and fonts. The layout is designed at 1920x1080 and scales with the window.
- `tests/run_tests.gd` headless rule tests.
- `assets/` character and enemy art.

## Combat arts

An art belongs to one weapon type, can only be used with a weapon of that type in hand, and costs stamina and a recovery like any action (always one tick). Tier 1: 4-6 STA, sits out 1 action; tier 2: 8-10 STA, 2 actions; tier 3: 13-15 STA, 3 actions. Effects are limited to bonus Mt/Hit/Crit, striking every enemy, striking twice, ignoring part of DEF, a debuff on each enemy hit and a buff on the user. `WeaponData.unique_art` is reserved for rare weapons that grant an art of their own; nothing uses it yet, nor `CombatArtData.durability_cost`.
