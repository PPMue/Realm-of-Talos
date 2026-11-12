# Realm of Talos

2D roguelite party builder (Godot 4.7, GDScript). Currently: a playable battle prototype, 3 companions against 2 enemies.

## Run

Open the folder in Godot 4.7 and press Play, or from a shell:

```
godot --path .
```

Play: click a READY companion, pick Attack / skill / Guard / Focus, click an enemy to see hit %, crit % and damage, then Confirm (or click the same enemy again). Restart is in the top right.

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
- `scripts/ui/`, `scenes/battle/` the battle screen. It only reads `Battle` state and calls its commands.
- `tests/run_tests.gd` headless rule tests.
- `assets/` character and enemy art.
