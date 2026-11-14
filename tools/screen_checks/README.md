# Screen checks

Scripts that open the real game in a window, set up a run, click through one screen and save screenshots, so UI work can be checked by eye. They are not tests: nothing asserts, nothing runs them automatically, and the headless suite in `tests/` never loads `scripts/ui/`.

```
godot --path . -s res://tools/screen_checks/jeweler_room.gd -- <folder for the screenshots>
```

The folder must exist. Each script prints what it did and quits; look for `SCRIPT ERROR` in the output, then at the pictures.

| Script | What it shows |
|---|---|
| `day_strip.gd` | The day strip around a boss day |
| `restock_notice.gd` | When the Smithy and the Tavern restock: the strip's wagon and the notice in both rooms |
| `hire_paper.gd` | A hire's paper in week 1 and after weeks of practice outside the company |
| `battle_day_stores.gd` | The Smithy and the Tavern on a battle day |
| `smithy_enchanting.gd` | The smith's work, the enchanting choice and a hire, frame by frame |
| `elite_day.gd` | An elite day on the strip, in the city and at the war table; the stones in hand |
| `jeweler_building.gd` | The Jeweler's shop in the city, shut and open, by day and by night |
| `jeweler_room.gd` | The Jeweler's room: the tray, setting a stone, the designs, who wears it, the case |
| `barracks_accessories.gd` | Accessories in the Barracks (worn, the case, putting on, taking off) and on the battle sheet |
| `mason_plan.gd` | The Mason's plan with all ten facilities |
| `battle_aims.gd` | A battle with the enemy's hand shown: each enemy's coming action, target and figures, what is aimed at each portrait, the threads, the sheets, and three turns played (a day to fight on may follow the folder; default 16) |
| `battle_line.gd` | A battle where the whole line fights: Guard asking whom to shield, what the guard would take and the thread swinging to them, the blow caught, then the retreat asked for, sounded and its result (a day may follow the folder; default 16) |
| `battle_wait.gd` | A line of two, as a run begins: both act, both are recovering, the orders offer only Wait; the wait and the turn after |
| `battle_account.gd` | The account: the war table with a line of two, on an elite day, before a boss and late in a run (each report's WORST and SCOUTS lines), then a battle lost and the result's first beat, the HOW IT WENT page, and the last beat |
| `calling_moment.gd` | A calling taken: the three cards, one picked, the gains; another's card closed; a Sage's schools and spells |
| `calling_sheets.gd` | Callings on the Barracks sheet (the three drawn, one read, the one taken, another's closed) and on the Tavern's wall |
| `calling_yard.gd` | A day to look elsewhere at the Drill Yard: the callings at the chosen companion's feet, one picked, the one drawn in its place |
| `calling_battle.gd` | Callings in a battle: the calling over the name, Rouse asking whom, an Executioner's FELLS, a Mender's heal raising someone injured |
| `battle_breath.gd` | A staggering art aimed (STAGGERS +1) and landed (the action DELAYED), the same art aimed again (ALREADY DELAYED); stamina coming back over the turns, then Focus (a day may follow the folder; default 16) |

How they are written, for the next one:

- `extends SceneTree`; load the main scene, add it to `root`, `game.start_run(seed, false)`, wait about 2.4 seconds, close the opening letter.
- Set the run up directly (`run.gold`, `run.day`, `run.calendar[...]`, `run.add_gem(...)`), then `city.refresh(false)`.
- Click with `root.push_input` (a button-down and a button-up `InputEventMouseButton`). Positions are in the 1920x1080 canvas, so use a control's `global_position` as it is; do not scale by the window size.
- Save with `root.get_texture().get_image().save_png(...)` after two `process_frame`s.

They reach into the screens' private fields (`city._store_screen`, `store._papers`), so a script can break when its screen changes; fix it when it is next needed.
