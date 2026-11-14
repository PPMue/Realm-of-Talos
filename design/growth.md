# Growth: fewer points, and each one stays (design; nothing built)

Written 2026-11-14. The user: "I want the overall growth rate (and maybe starting stats?) to be lower
/ slower, so it's more satisfying when the player sees a number go up (kind of like Fire Emblem).
Might need to balance weapons as well." To be settled before the callings (`design/callings.md`).
Every proposed number is a first guess, to be tuned with the 200-run playthrough when it is built.

## What a level-up is worth today

**1. A level raises many stats.** Ten stats roll, at 43% on average: 4.3 rise a level, 5 or more on
more than four levels in ten. Over the eleven level-ups of a run that is 47 points. A "+1" is not an
event.

**2. The enemy takes it back.** Besides tougher kinds arriving, every enemy grows by the day: +7
Strength and Magic, +4 Defence, +3 Speed and Dexterity and more than twice the Health by day 42. The
suite's own table, for a sword user against the average enemy of the day with the same wooden sword:

| | Level 1, day 1 | Level 6, day 14 | Level 12, day 36 |
|---|---|---|---|
| Damage of a plain Attack | 6.6 | 8.1 | 6.5 |

Eleven levels of Strength, and the Attack deals what it dealt on day 1.

**3. The weapon is the growth.** Each metal is +2 Mt, five steps, +10 in all, and the Smithy sells
the next one every week or two. Against one kind of enemy (an Orc, Defence 5), a sword user from day
1 to day 36:

| | Levels | The weapon | The day's growth of the Orc | Damage |
|---|---|---|---|---|
| Today | +5.8 | +6 (steel) | -3 | 4, then 12.8 |

Half of what a companion gains is bought, and a quarter of the total is taken back. This is the
"then I can just keep buying a higher tier weapon" of the first play report.

## The aim

1. A level-up raises few stats, so each is noticed.
2. A point gained is kept: the same Orc is the same Orc on day 30.
3. Levels are the largest part of what a companion gains in a run; the weapon is a smaller part.

Kept as they are: starting stats and Health, levels and XP, spells, arts, traits, accessories,
enchantments, the battle rules.

## A. Growth rates down by about a third

Every growth rate x0.7, rounded to the nearest 5; the lesser of Strength and Magic is then set 10
under the other, as now.

| | Stats raised a level | Strength | Magic | Health | Defence |
|---|---|---|---|---|---|
| Elena today | 4.5 | 65% | 55% | 75% | 55% |
| Elena proposed | 3.1 | 45% | 35% | 55% | 40% |
| Freya today | 4.5 | 65% | 75% | 40% | 15% |
| Freya proposed | 3.2 | 45% | 55% | 30% | 10% |

- On average 3.0 stats a level where it was 4.3; a level of five or more becomes one in seven.
- Over a run: 33 points where it was 47. Elena gains about 5 Strength and 6 Health where she gained 7
  and 8.
- "At least 2 stats rise" stays (`MIN_STAT_GAINS`), so no level is empty. About one level in seven is
  lifted to 2 by it.
- What a point does is unchanged, and is on screen: Strength or Magic +1 damage, Defence or
  Resistance -1 taken, Dexterity +5 Hit, Speed -5 to the enemy's Hit, Critical +2 Crit, Luck -1 to
  the enemy's Hit and Crit.

## B. The enemy stops taking it back

| By day 42 | Today | Proposed |
|---|---|---|
| Strength and Magic | +7 (every 5.5 days) | +3 (every 12) |
| Defence | +4 (every 9) | +2 (every 20) |
| Speed and Dexterity | +3 (every 11) | +2 (every 20) |
| Health | x2.23 (3.0% a day) | x1.74 (1.8% a day) |

- The rise in danger is carried by what already carries half of it: the tougher kinds and larger
  groups of the later weeks. An enemy met in week 1 is nearly the same enemy in week 5, and falls
  faster each time.
- Health comes down with the rest because the line's damage will grow less (see C). The first guess
  keeps the blows needed to fell an Orc on day 36 where they are (9 plain Attacks from a sword user).
- The bosses do not grow by the day; their Health and Defence are set by hand, and are set again in
  the same pass, since the company reaching them will hit less hard than today.

## C. The weapon ladder at half its height

- **+1 Mt a metal, not +2**: wooden 0, bronze 1, iron 2, steel 3, silver 4, platinum 5. Spears keep
  their +1. Bows and daggers lose their -1 (with steps of 1 it would make a bronze bow no better than
  a wooden one); the axe keeps +1 at silver and platinum only. To be checked against the
  damage-by-type table the suite prints.
- **Prices fall with it**: 20 / 40 / 70 / 110 / 160 / 220 gold where they were 20 / 50 / 110 / 200 /
  320 / 480. A better metal is then +1 damage, one more point of enchantment (as now) and room for
  the two-proficiency weapon of that metal.
- **The others keep their place on the new ladder**: a two-proficiency weapon is its main type's
  next metal (+1); each rare weapon is pegged to the same metals as before (a magic weapon above
  bronze and at most iron); Oathkeeper follows the ladder.
- The gold that no longer goes to metal goes to hires, cures, drills, enchanting and stones. Whether
  that makes runs too easy is one of the things the playthrough is for.

The same sword user against the same Orc, with all three:

| | Levels | The weapon | The day's growth of the Orc | Damage |
|---|---|---|---|---|
| Today | +5.8 | +6 (steel) | -3 | 4, then 12.8 |
| Proposed | +3.9 | +3 (steel) | -1 | 4, then 9.9 |

- **What this gives**: each point is rarer, levels are the larger part of the gain, and one point in
  seven is taken back where it was one in four.
- **What it does not give**: a larger total. A companion ends a run less far from where they began
  than today. If the wish is also to watch someone become several times as strong, that is a
  different lever (more levels in a run, or lower starting stats: see below), and it pulls against
  "fewer points".

## Not proposed: lower starting stats

Lower starting stats would make each point a larger share of the whole. It is left out for now:

- Damage is attack less defence, so stats cannot be lowered on one side only. Companions' Strength,
  Health and Defence, every enemy's and boss's, every spell's and art's Mt and the healing spells
  would all be set again.
- The numbers that are not stats would not shrink with them: the traits ("+2 damage"), the 54
  accessories (a Ring is +1 to +5 Strength), enchantments (1 to 6 points), poison and bleeding. All
  of them would have to be weighed again.
- Small numbers are coarse: Koharu's Attack is 7 against Defence 2 today; halved, half the line deals
  1 or 2.
- A, B and C can be played first. If the numbers still feel large after that, lowering them is a
  step that can follow, on its own.

## What to watch when it is built

- **Stones and enchantments weigh more.** A Ring of +3 Strength is worth five levels of Strength
  today and seven after. They are drawn and rare, which is why they are left alone; if they decide
  runs, their numbers come down.
- **Mages.** Spells have no ladder, so the weapon's loss costs fighters and not casters. The
  playthrough has to say whether casters pull ahead.
- **The targets**: runs won by the automated player held near today's 14%, battles near today's
  length (19 turns), the first boss beaten about as often as today (70 to 80%).

## Yours to decide

1. **How deep the cut.** x0.7, about 3 stats a level (proposed); or x0.6, about 2.6.
2. **The floor.** At least 2 stats a level, as now (proposed); or at least 1, so a poor level exists
   as it does in Fire Emblem.
3. **Starting stats.** Left alone for now (proposed), or lowered in the same pass.
4. **The weapons.** +1 Mt a metal with lower prices (proposed), or the ladder left as it is.
5. **Order.** A, B and C together, since they only balance together, then the callings (proposed).
