# Realm of Talos

2D roguelite party builder (Godot 4.7, GDScript). Currently: a playable battle prototype, 3 companions against 2 enemies.

## Run

Open the folder in Godot 4.7 and press Play, or from a shell:

```
godot --path .
```

Play:

- The party is the row along the bottom; the rightmost companion stands nearest the enemies and is aimed at most. Click a READY companion to choose who acts.
- Pick an action on the left (or press 1-4). For Attack and the weapon skill, point at an enemy to see hit %, damage and crit %, then click it to strike. Right-click or Esc backs out.
- Under each enemy: its HP, an hourglass with the ticks left until it acts, and the kind of action coming. Every action you take is one tick.
- When nobody is ready, Wait (1 or Space) lets a tick pass. L opens the battle log. Clicking during the enemies' turn speeds it up.
- Hover a companion or enemy for its stats.

## Tests

```
godot --headless --path . --import          # first time / after adding scripts: builds the class cache
godot --headless --path . -s res://tests/run_tests.gd
```

Exit code 0 means every test passed.

## Layout

- `scripts/battle/` battle rules: plain classes, no nodes or UI, seeded `RandomNumberGenerator` injected. `battle_config.gd` holds every tuning number.
- `scripts/data/` `Resource` classes for companions, enemies, weapons, skills, enemy actions and effects.
- `data/` the `.tres` data: companions, enemies (with their action lists), weapons, skills, and `battles/prototype_battle.tres` (who fights).
- `scripts/ui/`, `scenes/battle/` the battle screen. It only reads `Battle` state, calls its commands, and plays back `Battle.events`. `ui_theme.gd` holds the colours and fonts. The layout is designed at 1920x1080 and scales with the window.
- `tests/run_tests.gd` headless rule tests.
- `assets/` character and enemy art.
