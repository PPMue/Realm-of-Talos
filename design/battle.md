# Battles: the enemy's hand shown, the whole line fighting (design; all of it built)

Written 2026-11-14 after the user's play reports ("not engaging; sometimes I don't know why I win or
lose"). The user accepted the answers proposed under "Yours to decide" and asked for step 1, then
step 2, then had the recovery cap of step 2 taken out and asked for step 3, then asked that a
companion standing alone wait like any other and for "The account". All of it is built. Numbers
marked "first guess" were tuned with the probe where a note says so.

## What is wrong, measured

`tools/battle_probe.gd` has the automated player play 30 runs (456 battles) and replays every battle
20 times from the same start, with fresh dice, by three players: the automated player as it is (the
first ready companion acts), the same but with whoever hits hardest acting, and one that makes a plain
Attack with a random ready companion on a random enemy.

| | Automated player | ...the strongest acts | Random Attacks |
|---|---|---|---|
| Battles won | 72% | 76% | 53% |
| Week 1 / week 2 / week 6 | 90 / 87 / 34% | 93 / 91 / 37% | 77 / 67 / 27% |
| Actions taken by the busiest two | 94% | 90% | 82% |
| Fielded who never act, a battle | 0.8 | 0.6 | 0.1 |
| Enemy blows that land, a battle | 4.5 | 4.0 | 5.7 |
| ...taking half of max Health or more | 49% | 46% | 50% |
| ...felling the companion | 27% | 25% | 34% |
| Injured, a battle | 1.3 | 1.1 | 2.0 |
| Guard / Focus, share of actions | 3% / 0% | 6% / 0% | none |

A battle lasts about 15 turns, 3.2 are fielded on average. Of the 456 battles, the automated player
wins 58% nine times in ten or more and loses 17% nine times in ten or more; a quarter are in between.

What that says:

1. **Most battles are settled before the first order.** Three in four come out the same way whatever
   the dice do. The player cannot see what settles them (the enemies' growth with the day is nowhere
   on screen), so a win feels unearned and a loss unexplained.
2. **Orders are worth little.** Never using an art, a spell or Guard and striking at random still wins
   53% of all battles and 77% in week 1. Choosing who acts is worth 4 points.
3. **Two companions do the fighting.** An Attack has Recovery 1, so two can alternate for ever; the
   third and fourth are there to be hit. In a game about building a party, most of the party does not
   play.
4. **A battle turns on four or five blows nobody could see coming.** Half of the enemy blows that land
   take half a companion's Health, one in four fells them, and who they land on is a hidden roll. Even
   while winning 72% of battles the automated player has 1.3 companions injured in each.
5. **Two of the five orders are dead.** Guard is 3% of actions and Focus none: guarding is a guess
   while the target is hidden, and a turn is worth more than 5 stamina.

These are an automated player's battles, not a person's. A person plays better; the shape is the rules'.

## The aim

A battle is a row of threats the player can read (who is struck, how hard, in how many turns) and a
few actions to answer each with, and everyone in the line has something only they can do about it.
A loss can be traced to a blow that was on the table and went unanswered.

Kept as they are: one action is one turn and every enemy's countdown drops by it; stamina, arts,
spells and their data; proficiency and learning; the enemies' data and mechanics; the look.

## Step 1: the enemy's hand is shown

The smallest change in the rules and the largest in what the player understands. First to build.

- **The aim is fixed when the action is chosen.** When an enemy picks its next action and it strikes
  one companion, it draws its target then, with the weights as they stand then (mirrored for one that
  aims from the left), and keeps it (`EnemyUnit.pending_target`). Today the target is drawn when the
  blow lands. The place in the line still decides how often someone is chosen.
- **Everything about the coming action is shown**: its name, its kind, the turns left, and for a blow
  the companion it is aimed at with the damage and the chance to hit, worked out as things stand now
  (so it changes at once when the target guards, is warded or the enemy is weakened). A blow on the
  whole line shows on everyone. `Battle.enemy_forecast` already gives the numbers.
- **What moves an aim once fixed**, and nothing else:
  - the target is injured: every blow aimed at them is drawn again at once among those standing;
  - someone draws the eye (Beacon, and the arts Challenge and Phalanx): every single blow already
    aimed moves to them; while the effect lasts, new aims are drawn with its weight as today;
  - someone is hidden (Veil, the art Fade): blows aimed at them are drawn again among the others;
  - Guard on a neighbour (step 2).
- **Guard no longer makes the enemy aim at the guard** (x4 today). With aims fixed and shown it would
  only attract blows that land after the guard is down.
- **Enemies do not strike critically** unless an action says so, and then it is shown. Today it is
  2 x CRT - LCK, unseen: nothing for most, but about one blow in ten from a Stalker or a Blackwing
  and one in five from Shadowed Wings does double damage. The purest "why did I lose".
- Still unknown: whether a blow lands (its chance is shown), and what an enemy will choose next.

On screen (mine to build): each enemy's plate carries the action's name and figures; a thread runs
from it to the portrait it is aimed at; each portrait lists what is coming at it in the order it
lands (whose blow, how much, in how many turns) and is marked in red with the turn when those blows,
all landing, would fell them. Shift on an enemy lists everything it can do. The "targeted N%" roundel
stays, as the chance of being chosen next.

Rules: `pending_target`, drawing it in `pick_next_action`, the re-aims above, `Battle.incoming(c)`
(what is aimed at a companion, in order, with forecasts) and `Battle.falls_on_turn(c)` for the screen
and the automated player, whose `should_guard` reads the aim in place of guessing it.

**Built** (2026-11-14). `EnemyUnit.pending_target` is drawn in `Battle.pick_next_action` for every
single-target action (one that deals no damage too) and the blow lands there; the "intent" event
carries it. It moves only by the three re-aims above, each an "aim" event (`enemy`, `target`, `from`,
`why`: "injured", "drawn", "hidden") and a log line; a passive weight (the place, Sentinel's Pike, a
trait) only counts when an aim is drawn. Guard no longer draws the aim (`BattleConfig.GUARD_TARGET_WEIGHT_MULT`
is now 1 and unused by the rules; it stays only for the action menu's text). Enemy criticals come only
from `EnemyActionData.crit_percent` (none set). `Battle.incoming(c)` and `Battle.falls_on_turn(c)` as
above; the automated player guards a heavy blow due next turn that is aimed at the guard. Decided
along the way: the re-aims follow any effect that lands with an aim multiplier above or below 1, not
only the five named; a "hidden" redraw uses the other companions' weights as they stand; an injury
redraw with nobody left standing clears the aim (the battle is lost); `falls_on_turn` counts the Locket
as well as Clings to Life, and only blows (not damage over time) can be saved from, as in the battle.

## Step 2: the whole line fights

- **Recovery is one longer for everything**: Attack, Guard and Focus 2; arts and spells 2 / 3 / 4 by
  tier. ~~Nobody sits out longer than there are others standing~~ (proposed and built, then taken
  out the same day at the user's word: see "The cap removed" below). Three take turns, and four have
  one to spare each round; two act in turn and then wait one action. A companion standing alone
  ignores recovery, as before. Recovery an enemy adds comes on top.
  To recheck: the Spur (now "3 or more"), Quick Hands, Relentless, grades per battle (the actions
  spread out), and the enemies' Health, since the weaker half of the line now strikes too.
- **Guard a neighbour.** Guard is aimed: at oneself (half damage this turn, as now) or at whoever
  stands beside them. Single blows that land on that neighbour this turn land on the guard instead,
  halved. Whole-line blows are not caught. Knowing the turn a blow lands, the player has to have the
  right companion free on that turn: that is the plan a round is made of, and it gives the sturdy a
  job and the order of the line a second meaning.
- **Sound the retreat.** In a battle or an elite fight (not a boss) the company can fall back at any
  time: the battle is lost and the walls pay for it, but nobody else is injured. Today a lost battle
  puts the whole line in the Infirmary for four days, and the next fight is two days away.

**Built** (2026-11-14). Recovery: Attack, Guard and Focus 2 (`BattleConfig.RECOVERY_*`); every art and
spell file carries tier + 1 (the cards show what happens). `Battle.recovery_cap(c)` is the others
standing; `action_recovery` and `art_recovery` return the capped number, and `_end_player_action` caps
again in case someone fell during the action. Enemy-added recovery comes on top; an injury cuts every
standing companion to the new cap, enemy-added included. `is_lone_companion` stays (a lone companion
still ignores even an enemy's recovery). Wait now happens only through an enemy's added recovery.
Spur: "3 or more", "not below 2" (data/accessories/tempo/spur.tres; the generator line in
tools/generate_accessories.gd still says 2 and wants the same change). Quick Hands and Relentless
keep their rules (a tier 1 art 2 -> 1; a felling action 0). Grades per battle were left alone: points
per companion per battle went from 4.7 to 4.6 and the share of companion-battles at the cap from 16%
to 13%. Guard a neighbour: `Battle.guard(c, ward)`, `guard_wards(c)`, `guard_preview(c, ward)`, the
"cover" event and "ward" on the "guard" event, as proposed; a neighbour is the place either side in
`line()`, standing, never stepped over. `guard_preview`'s "damage" counts the guard's damage over time
too, the Locket or Clings to Life once each, and a caught blow goes to the ward once the guard would
have fallen. Retreat: `allow_retreat`, `can_retreat()`, `retreat()`, `retreated`,
`BattleReport.retreated`; `Run.finish_battle` already sent only the injured to the Infirmary. The
automated player covers a neighbour who would fall this turn when, covering, neither would, and
retreats (not from a boss) once half the line is injured and the enemies keep more than half their
Health. Balance: 16% of 200 runs won after the change (20% before); enemy Health growth with the day
lowered from 3.5% to 3% (`RunConfig.ENEMY_HP_GROWTH_PER_DAY`, day 42 x2.23 in place of x2.44) brought
it to 21%. With four in the line the automated player's actions went 38% / 31% / 24% / 7%, busiest
first: three rotate and the fourth acts only when chosen.

**The cap removed** (2026-11-14, the user's decision after the figures below under "After step 2":
with the cap, every action cost the same recovery once three or fewer stood). `Battle.recovery_cap`
is gone: `action_recovery` and `art_recovery` return what the action carries (and 0 for a companion
standing alone, whose recovery is also cleared the moment the last other falls; that last exception
went too, see "One alone waits too"). An injury no longer
shortens anyone else's recovery. What follows from it: two standing (how a run begins) act in turn
and then both recover, so the party waits one action in three and the enemies get that turn; with
three, a tier 2 or 3 art leaves a Wait behind it unless the line is four; one alone acts every turn,
so two standing act less often than one. The automated player, unchanged (it uses arts without
counting the wait), won 13% of 200 runs (21% with the cap), the day 6 elite 59% (72%), the day 20
elite 50% (59%), the day 34 elite 26% (23%). Nothing was retuned for it: step 3 changes Health on both
sides and the balance is set again there.

## Step 3: more to say each turn

- **Breath comes back.** A standing companion regains 1 stamina at the end of every turn they did
  not act in (first guess). Today stamina is spent in the first few turns and the rest is Attack
  (46% of the automated player's actions). Focus restores half of max stamina in place of 5.
- **Some arts stagger.** One tier 2 art of each weapon type also pushes the target's coming action
  back 1 turn, once per action as spells do. Five arts; spells keep the long delays.
- **Light and heavy blows.** Companions' base Health up by half (first guess: 16-24 becomes 24-36),
  the enemies' Health and growth retuned to hold the win rate. An ordinary blow should be a cost and
  a heavy one (countdown 4 or more) a threat to answer.

**Built** (2026-11-14). Breath: `BattleConfig.BREATH_PER_TURN` (1), given in `Battle._advance` at the
end of every turn to each standing companion who did not act in it (a Wait is a turn nobody acts in;
a companion standing alone acts every turn and gets none). Focus: `FOCUS_RESTORE_PERCENT` (50) of max
stamina, rounded up, plus Steady Breath and Beads. Stagger: `CombatArtData.stagger_ticks` (1) on Sword
Dance, Hamstring, Skewer, Suppressing Volley (every enemy it hits) and Hobble; it goes through
`Battle.delay_action`, so an action is pushed back once, by anything (a spell, an art, an Hourglass),
and only by a strike that lands. Health: every companion's base Health times 1.5, rounded up (24-36).
Enemies: `RunConfig.ENEMY_HP_MULT` 1.35 on every enemy of a normal front and a boss's escorts, before
the day's growth (left at 3% a day), and `BOSS_HP_MULT` 1.4 on the boss itself (`Run.sized_boss`);
their blows were left as they were. Tried on 200 runs: enemies untouched 55% of runs won, both
multipliers 1.3 28%, both 1.5 10%; 1.35 and 1.4 gave 19%. The automated player and the probe's players
push back a blow that would fell someone this turn when the one acting carries a staggering art it can
pay for (`run_policy.gd` `stagger_answer`), after trying to cover and before guarding. On screen: the
art's card says "Staggers: its action comes 1 turn later (once per action)", the enemy pointed at
says STAGGERS +1 or ALREADY DELAYED, and the pushed action carries the DELAYED tag a spell's does.

**One alone waits too** (2026-11-14, the user's decision: "player should do their best to keep party
alive"). The rule that a companion standing alone ignores recovery is gone: after an Attack the last
one standing waits two turns like anyone, and enemy-added recovery holds them too. So the line's pace
only ever falls as it thins: one action a turn with three or more, two in three with two, one in
three alone, and breath comes back on the turns waited. `Battle.is_lone_companion` stays as a
question the automated player asks. For the automated player a battle begun alone went from 52% won
to 24%, and whole runs from 19% to 10% of 200: it loses at the bosses, where there is no falling back
and a line that thins can no longer act (the day 42 bosses are beaten 7-31% of the time). Lowering
the enemies' Health does little for it (both multipliers at 1.3: 11%; at 1.25: 13%), so they were
left at 1.35 and 1.4. The automated player does nothing to keep its line standing beyond covering a
neighbour about to fall; whether 10% is the right hardness for a person is for the user's play to say,
and the knob that would move it is the bosses themselves, not the Health of ordinary enemies.

## The account

- **Before**, on each report at the war table: the hardest blow that front has against the line as it
  stands ("Crushing Blow: 21 to Freya"), and the scouts' word for the fight, from the turns the line
  needs to bring them down against the turns they need to fell the line. Three words, set with the
  probe so they are true: the automated player wins the first nine times in ten, the last fewer than
  four.
- **After**, one more beat in the result, "How it went", at most five lines the rules write
  (`BattleReport.account`): each fall (who, to which blow, how much, what they had left, the turn),
  the blows that missed on both sides, and who dealt and took the most.

**Built** (2026-11-14; `scripts/battle/battle_account.gd`, tests in `tests/account_tests.gd`).
Before: `Run.front_account(front)` looks at a throwaway battle for the line as it stands (the run's
dice are not rolled) and `BattleAccount.before` gives the hardest blow and the two counts of turns.
The hardest blow is the one taking the largest share of some companion's Health as they stand, over
every damaging action of every enemy, second phases included, so it is not always the largest figure.
The line's turns: each companion's Attack or best damaging spell, with its chance to hit, averaged
over the line, at the pace the line can act (1, 2/3 or 1/3 of the turns). The enemies' turns: each
enemy's actions by how often it picks them and how long they take, with their chance to hit, single
blows spread as the line draws them; a second phase counts for the share of the enemy's Health it
covers (half when it begins once the enemy stands alone). Arts, healing, Guard, and enemies falling
one by one are all left out, which is why the ratio that means an even fight is well under 1. On
each report at the war table: WORST ("CRUSHING BLOW  ·  21 TO FREYA", or "FELLS FREYA" in red) and
SCOUTS (A SURE FIGHT, A CLOSE FIGHT, A GRIM FIGHT), written again when the line's order changes.

The words were set with the probe (40 runs, 640 battles, 10 replays each, the automated player):

| Ratio (turns they need / turns we need) | Battles | Won |
|---|---|---|
| under 0.2 | 82 | 4% |
| 0.2 to 0.3 | 53 | 22% |
| 0.3 to 0.4 | 36 | 43% |
| 0.4 to 0.5 | 30 | 60% |
| 0.5 to 0.7 | 90 | 70% |
| 0.7 to 0.8 | 34 | 94% |
| 0.8 to 1.0 | 64 | 91% |
| 1.0 and more | 251 | 99% |

Sure is 0.8 or more (`BattleConfig.ACCOUNT_SURE_RATIO`), grim under 0.4 (`ACCOUNT_GRIM_RATIO`):

| Word | Share of battles | Won | Battles / elites / bosses |
|---|---|---|---|
| Sure | 49% | 97% | 98 / 97 / 94% |
| Close | 24% | 73% | 76 / 78 / 56% |
| Grim | 27% | 18% | 17 / 19 / 15% |

So the first word is right nine times in ten and the last is won fewer than four times in ten, for
every kind of fight, as asked. A close boss fight is harder than a close battle (56% for 76%): boss
mechanics are not in the count. The words describe the automated player; a person who shields and
staggers well should beat them, and the words should be read again with the probe after any change
to the rules of battle.

After: `Battle.account` keeps every fall (the enemy, the blow, the damage, the Health they had, the
turn, whether it was a critical; damage over time names the effect alone), strikes and blows with
their misses, and damage dealt and taken by name (never more than the target had left).
`BattleAccount.lines` writes: the first fall in full, a second in full or the rest together ("Then
Ingrid on turn 6 and Freya on turn 8."), "The enemy had 433 of 468 Health left." after a battle lost,
the misses, and who dealt and took the most. The result shows them as a page of the chronicle, its
second beat; the first beat now waits for a click when the page follows.

## What it reverses

- Hidden targets (decided 2026-11-12).
- "Combat arts never touch countdowns" (2026-11-13), for five arts and one turn.
- Guard drawing the enemy's aim.

## How we will know

The probe gains a fourth player, the reader, who uses what is shown: guards or covers the blow that
would fell someone, strikes first at whatever is about to land a heavy blow, falls back from a lost
fight. Against today's figures:

| | Today | After |
|---|---|---|
| Reader's win share over random Attacks | 19 points (automated player) | 40 or more |
| Actions by the busiest two, four in the line | 94% | 60% or less |
| Fielded who never act | 0.8 a battle | about none |
| Guard, share of the reader's actions | 3% | 10% or more |
| Blows taking half of max Health or more | 49% | about 20%, nearly all heavy |
| Injured a battle, battles won | 1.3 (all battles) | under 0.5 |

And the user's own word after playing each step, which outranks the table.

**After step 1** (2026-11-14; 30 runs, 434 battles, 20 replays each; the reader guards whoever would
fall this turn or fells an enemy about to bring them down):

| | Before | After step 1 |
|---|---|---|
| Battles won: automated player / strongest acts / random Attacks | 72 / 76 / 53% | 78 / 83 / 58% |
| Battles won: reader | none | 82% |
| Reader's (before: automated player's) win share over random Attacks | 19 points | 24 points |
| Actions by the busiest two | 94% | 93% (reader 88%) |
| Guard, share of actions | 3% | 6% (reader 9%) |
| Blows taking half of max Health or more | 49% | 46% (reader 41%) |
| Injured a battle | 1.3 | 1.2 (reader 0.9) |
| Whole runs won by the automated player (200 runs) | 21% | 20% |

Step 1 makes a battle readable and Guard worth using, and it leaves the rest where it was: reading
the enemy's hand wins no more than letting the strongest act, because with only Guard on oneself
there is little to answer a blow with. That is what step 2 is for.

**After step 2** (2026-11-14; 30 runs, 540 battles, 20 replays each; the reader also has a free
neighbour shield whoever would fall, and every player but the random one retreats as the automated
player does, a retreat counting as a battle lost). The enemies' Health growth was lowered with it
(3.5% to 3% a day) to hold the share of runs won, so the win figures are not the rules alone:

| | After step 1 | After step 2 |
|---|---|---|
| Battles won: automated player / strongest acts / random Attacks | 78 / 83 / 58% | 73 / 76 / 54% |
| Battles won: reader | 82% | 76% |
| Reader's win share over random Attacks | 24 points | 22 points |
| Actions by the busiest two | 93% (reader 88%) | 76% (reader 74%) |
| ...with four in the line | not measured | 68% (reader 66%) |
| Fielded who never act, a battle | 0.8 | 0.28 (reader 0.13) |
| Guard, share of actions | 6% (reader 9%) | 8% (reader 11%) |
| ...of them shielding a neighbour | none | about a quarter |
| Blows taking half of max Health or more | 46% (reader 41%) | 37% (reader 35%) |
| Injured a battle | 1.2 (reader 0.9) | 1.0 (reader 0.87) |
| ...in battles won | not measured | 0.50 (reader 0.40) |
| Battles ended by a retreat | none | 18% (reader 16%) |
| Plain Attack, share of actions | 46% (before step 1) | 29% (arts 48%) |
| Whole runs won by the automated player (200 runs) | 20% | 21% |

What it did: the fighting is spread (the third companion now acts as a matter of course, and stamina
is spent across the line, so arts are half of all actions and the plain Attack under a third), fewer
are injured, and Guard has a second use. What it did not do:

- **Reading still wins no more than letting the strongest act** (76% both). The reader loses fewer
  companions, not fewer battles. Shielding answers one blow; what decides a battle is still how the
  two sides' numbers compare. Step 3 (breath back, staggering arts, lighter ordinary blows) is aimed
  at that, and so is the account before a battle.
- **With four in the line, the fourth is a spare.** Recovery 2 lets three rotate; the automated
  player's actions go 38 / 31 / 24 / 7%. A person will use the fourth to shield or to hold a heavy art,
  but nothing makes them.
- **With three or fewer standing every action costs the same**: the cap makes a tier 3 art's recovery
  (4) the same as an Attack's (2) with two others standing, and 1 with one. Stamina is then the only
  price of a heavy art. (Answered the same day: the cap was removed, see "The cap removed".)
- **Retreating is common and cheap**: about one battle in six ends that way for the automated player
  (3.3 a run), and runs lost to the walls fell rather than rose. Whether that is right is for the
  user's play to say; the wall damage of a lost front is the knob.

**After the cap was removed, and after step 3** (2026-11-14; 30 runs each, 504 and 531 battles, 20
replays each). The first column is step 2 without the recovery cap and nothing else changed; the
second adds step 3 with the enemies' Health retuned (so its win figures are not the rules alone):

| | Step 2 with the cap | Cap removed | After step 3 |
|---|---|---|---|
| Battles won: automated player / strongest acts / random Attacks | 73 / 76 / 54% | 72 / 73 / 53% | 74 / 76 / 51% |
| Battles won: reader | 76% | 74% | 77% |
| Reader's win share over random Attacks | 22 points | 21 points | 26 points |
| Turns a battle | 13.8 | 13.9 | 19.0 |
| Waits a battle | 0.1 | 1.2 | 1.4 |
| Actions by the busiest two | 76% | 78% | 75% |
| ...with four in the line | 68% | 68% | 67% |
| Fielded who never act, a battle | 0.28 | 0.24 | 0.22 (reader 0.10) |
| Plain Attack / arts, share of actions | 29 / 48% | 29 / 48% | 18 / 58% |
| Guard, share of actions | 8% (reader 11%) | 8% (reader 10%) | 6% (reader 8%) |
| Blows taking half of max Health or more | 37% | 37% | 17% |
| Blows felling someone at 80% Health or more | 2.4% | 2.5% | 0.2% |
| Injured a battle | 1.00 (reader 0.87) | 0.98 (reader 0.87) | 0.90 (reader 0.79) |
| ...in battles won | 0.50 (reader 0.40) | 0.47 (reader 0.37) | 0.41 (reader 0.33) |
| Battles ended by a retreat | 18% | 18% | 17% |
| Won with two in the line / with four | 86 / 70% | 76 / 71% | 81 / 73% |
| Whole runs won by the automated player (200 runs) | 21% | 13% | 19% |

Removing the cap cost the small line most: a line of two went from 86% to 76% of battles won (it
waits one action in three), week 1 from 91% to 86%. It did not make the fourth companion busier for
the automated player, which does not plan around a heavy art's recovery.

Step 3 did what it was for on two counts. Blows are lighter against the Health they land on: those
taking half of someone's Health fell from 37% to 17% (the target was about 20%), and almost nobody is
felled from near full Health any more. And stamina lasts: arts are 58% of actions and the plain Attack
18%. Battles are longer, 19 turns for 14.

What it did not do: **reading the enemy's hand still wins no more than letting the strongest act**
(77% and 76%). The reader loses fewer companions (0.33 injured in a battle won, for 0.41), and is 26
points ahead of random Attacks where the target was 40. A stagger saved someone only about once in
twenty battles for the reader: the automated players carry whatever arts they learned and seldom have
one to hand on the turn it is needed, so that figure says little about what a person choosing their
three arts can do with it. The late game is still the wall: week 5 battles are won 41% of the time,
the day 34 elite 19%, the day 42 bosses 28-36%.

## Yours to decide

1. Show the target and the damage (proposed), or the target only.
2. Whether any art may stagger at all.
3. Retreat: battles only, or elites too (proposed: both, never a boss).
4. Health up by half, or the enemies' blows cut down one by one.
5. Step 1 alone first, played, before 2 and 3 (proposed), or all three together.

## Considered and left

- Countdowns that drop once a round in place of once an action: the usual way to make a party count,
  but it gives up "every action is a turn" and every countdown in the data would be set again.
- ~~A flat Recovery 2 with no cap~~: left at first because two companions (how a run begins) have to
  Wait every third turn; it is the rule now (see "The cap removed").
- A bonus for striking after a different companion: two alternating already earn it.
