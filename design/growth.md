# Growth: small numbers, few points, and each one stays (design; nothing built)

Written 2026-11-14. The user: "I want the overall growth rate (and maybe starting stats?) to be lower
/ slower, so it's more satisfying when the player sees a number go up (kind of like Fire Emblem).
Might need to balance weapons as well." Then, on the first draft: "Lower starting stats as well. I
want to see a companion become stronger at the end of a run (or weak if built wrong)", and that the
callings should nudge growth as a class does (that part is in `design/callings.md`).
To be built before the callings. Every proposed number is a first guess, to be tuned with the
200-run playthrough when it is built.

## What a level-up is worth today

**1. A level raises many stats.** Ten stats roll, at 43% on average: 4.3 rise a level, 5 or more on
more than four levels in ten. Over the eleven level-ups of a run that is 47 points. A "+1" is not an
event.

**2. The numbers are large beside a point.** Elena starts with Strength 11 and 36 Health. One more
Strength is about a tenth more damage.

**3. The enemy takes it back.** Besides tougher kinds arriving, every enemy grows by the day: +7
Strength and Magic, +4 Defence, +3 Speed and Dexterity and more than twice the Health by day 42. The
suite's own table, for a sword user against the average enemy of the day with the same wooden sword:

| | Level 1, day 1 | Level 6, day 14 | Level 12, day 36 |
|---|---|---|---|
| Damage of a plain Attack | 6.6 | 8.1 | 6.5 |

Eleven levels of Strength, and the Attack deals what it dealt on day 1.

**4. The weapon is half the growth.** Each metal is +2 Mt, +10 over the ladder. Against one kind of
enemy (an Orc), a sword user from day 1 to day 36 gains 5.8 from levels and 6 from the weapon, and
the Orc's own growth takes 3 back.

## The aim

1. Numbers are small, so one point shows.
2. A level-up raises few stats, so each is noticed.
3. A point gained is kept: the same Orc is the same Orc on day 30.
4. By the end of a run a companion is plainly stronger than they began, by how they were built: what
   their levels brought and what their calling added. One built against their calling is plainly
   weaker than they could have been.

Kept as they are: levels and XP, Stamina and what arts cost, the battle rules, how arts and spells
are learned, what traits and accessories do (only their numbers move).

## A. The whole game at two thirds

Lowering the companions alone would break every matchup, since damage is attack less defence. So
everything that is a stat, or is added to one, comes down together, and a battle on day 1 plays as it
does today, in smaller numbers.

- **Every stat but Stamina, on both sides, x2/3** (rounded, at least 1): Health, Strength, Magic,
  Defence, Resistance, Dexterity, Speed, Luck, Critical, Build, for the fourteen companions, the 23
  enemies and the nine bosses.

| | Health | Strength | Magic | Defence | Speed |
|---|---|---|---|---|---|
| Elena | 36, now 24 | 11, now 7 | 9, now 6 | 7, now 5 | 5, now 3 |
| Kaito | 29, now 19 | 10, now 7 | 8, now 6 | 3, now 2 | 9, now 6 |
| Freya | 27, now 18 | 8, now 6 | 10, now 7 | 2, now 1 | 8, now 5 |
| An Orc on day 1 | 57, now 38 | 11, now 7 | | 5, now 3 | 4, now 3 |

- **Strength and Magic stand 1 apart**, which is the 2 of today at the new size; their growth rates
  stay 10 apart.
- **What is added to a stat, x2/3 as well**: every weapon's Mt and weight, an art's bonus Mt, a
  spell's Mt and a heal's power, an enemy action's Mt, poison and bleeding, the traits that are a
  number of damage or of a stat ("+3 damage" becomes +2, "+2 Strength" +1, "+4 Health" +3), an
  enchantment's points (1 to 6 by metal becomes 1, 1, 2, 3, 3, 4), the stat stones (a Ring's +1 to +5
  Strength becomes 1, 1, 2, 2, 3).
- **What is a percentage keeps its chance**: a point of Dexterity over the target's Speed is worth 7
  Hit where it was 5, a point of Critical 3 Crit where it was 2 (`ACCURACY_DEX_SPD_FACTOR`,
  `CRIT_CRT_FACTOR`). Traits and accessories written in percent or in Hit and Crit are untouched.
- **The weapon ladder is +1 Mt a metal**: wooden 0, bronze 1, iron 2, steel 3, silver 4, platinum 5,
  which is today's +2 at the new size, rounded down. Spears keep +1. Bows and daggers lose their -1
  (it would make a bronze bow no better than a wooden one). Prices stay.

**The cost.** It is the largest data pass so far: 14 companions, 32 enemies with their actions, 68
weapons, 60 arts, 24 spells, the two tables the 152 traits and 54 accessories are generated from, and
every test that names a real number. It is done by script and then tuned, because at this size
rounding moves things: Defence 1 against Defence 2 is a large difference.

## B. Growth rates down by about a third

Every growth rate but Health's x0.7, rounded to the nearest 5; the lesser of Strength and Magic is
then set 10 under the other. Health keeps its rates: it is the number everyone watches, and a level
that brings Health is never a wasted one.

| | Stats raised a level | Health | Strength | Magic | Defence |
|---|---|---|---|---|---|
| Elena today | 4.5 | 75% | 65% | 55% | 55% |
| Elena proposed | 3.3 | 75% | 45% | 35% | 40% |
| Freya today | 4.5 | 40% | 65% | 75% | 15% |
| Freya proposed | 3.3 | 40% | 45% | 55% | 10% |

- About 3.1 stats a level where it was 4.3, and each is worth half as much again as a point is today.
- "At least 2 stats rise" stays (`MIN_STAT_GAINS`), so no level is empty.
- What a point does is on screen: Strength or Magic +1 damage, Defence or Resistance -1 taken,
  Dexterity +7 Hit, Speed -7 to the enemy's Hit, Critical +3 Crit, Luck -1 to the enemy's Hit and
  Crit.

## C. The enemy stops taking it back

| By day 42 | Today | Proposed (at the new size) |
|---|---|---|
| Strength and Magic | +7 | +2 (days 19 and 37) |
| Defence | +4 | +1 (day 31) |
| Speed and Dexterity | +3 | +1 (day 31) |
| Health | x2.23 (3.0% a day) | x1.74 (1.8% a day) |

- The rise in danger is carried by what already carries half of it: the tougher kinds and larger
  groups of the later weeks. An enemy met in week 1 is nearly the same enemy in week 5, and falls
  faster each time.
- The bosses do not grow by the day; after the two-thirds pass their Health and Defence are set again
  by hand with the playthrough.

## What a run looks like after

Elena from level 1 to level 12, by her levels alone (her calling comes on top: see
`design/callings.md`):

| | Health | Strength | Defence |
|---|---|---|---|
| Today | 36, then 44 | 11, then 18 | 7, then 13 |
| Proposed | 24, then 32 | 7, then 12 | 5, then 9 |

A sword user against the same Orc, day 1 to day 36:

| | Levels | The weapon | The Orc's growth | Damage |
|---|---|---|---|---|
| Today | +5.8 | +6 (steel) | -3 | 4, then 12.8 |
| Proposed | +3.9 | +3 (steel) | -1 | 3, then 8.9 |

And the Orc's plain blow on Elena: 9 of her 36 Health on day 1 and still 9 of her 44 at level 12
today (the Orc has grown as fast as her Defence); 5 of 24 and then 2 of 32 as proposed.

- **What this gives**: one point is about a quarter of a sword user's first damage, not a seventh; a
  level brings three of them; almost nothing is taken back; levels are the larger part of the gain.
- **What it does not give by itself**: more growth from levels alone. Elena's Strength grows by about
  two thirds of what she began with, today (11 to 18) and as proposed (7 to 12). The larger arc, and the
  difference between a good build and a poor one, come from the callings: a calling adds about 3.5
  points to its first stat by the end of a run, on a stat that began at 5 to 7.

## What to watch when it is built

- **Sameness.** At this size five of the fourteen start with Strength 5. What tells them apart is
  their growth, their other stats and their calling more than their first numbers.
- **Mages.** Spells have no ladder of metals. The playthrough has to say whether casters pull ahead.
- **The targets**: runs won by the automated player held near today's 14%, battles near today's
  length (19 turns), the first boss beaten about as often as today (70 to 80%).

## Decided

- Starting stats are lowered too (the user, 2026-11-14).

## Yours to decide

1. **How small.** Two thirds (proposed: Elena 24 Health and Strength 7). Or a half (18 and 6), which
   is nearer Fire Emblem's first levels but leaves the weakest with Strength 2 or 3 and Defence 1.
2. **How deep the cut in growth.** x0.7 with Health spared, about 3 stats a level (proposed); or x0.6,
   about 2.7.
3. **The floor.** At least 2 stats a level, as now (proposed); or at least 1, so a poor level exists
   as it does in Fire Emblem.
4. **Order.** A, B and C together, since they only balance together, then the callings (proposed).
