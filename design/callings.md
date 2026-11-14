# Callings: a companion becomes something, and not the same thing every run (design; step 1 built)

Written 2026-11-14 after the user's play reports: "When I get a companion, I can just keep using it
and it will grow stronger... and I can do the same like this in every run. There is nothing that
forces the player out of this comfort zone", and "I want to be able to take the same companion to a
different path in a different run". Then: "design the callings to also help nudge growth, similar
to a class in Fire Emblem". Step 1 is built (2026-11-15: the twelve callings, how they are offered and taken, growth by calling, the screens); "Step 1 as built" below says where it differs from what is written here, and what the playthrough said. Steps 2 and 3 are not built. Every number here is a first guess. `design/growth.md` is built (2026-11-14): the stats
in "What a calling does to growth" are at the size the game now has; the stats named elsewhere in
this note (Elena's Strength 11, 36 Health, a Mend of 15) were written before it and are half as
large again as they are now.

## What is wrong, from the rules and the data

**1. A companion's growth holds no decision.** Everything a companion gains in a run is handed out:
1 to 3 traits (drawn), about twelve level-ups (rolled), about six arts or spells (drawn), an
enchantment and an accessory design (drawn). What the player decides is which three arts are carried,
which weapon is held and who is drilled. Nothing arrives that changes what the companion does on
their turn, so nothing is waited for.

**2. The role is fixed before the run begins.** Attack power by what is held, from the companions'
data (level 1, then level 9 at their own growth rates):

| | Own weapon | Sword or spear | Axe | Bow | Dagger | Magic |
|---|---|---|---|---|---|---|
| Elena (axe) | 15, then 20 | 11, 16 | 15, 20 | 8, 12 | 8, 11 | 1, 1 |
| Kaito (sword) | 10, then 15 | 10, 15 | 13, 18 | 9, 14 | 9, 14 | 1, 1 |
| Erik (bow) | 9, then 13 | 7, 10 | 9, 12 | 9, 13 | 7, 11 | 3, 5 |
| Freya (black magic) | 10, then 16 | 3, 4 | 5, 6 | 6, 8 | 5, 8 | 10, 16 |

- Between weapon types the gap is a few points. The wall there is the grade: everyone starts at D or
  better in their own weapon and at E in nearly everything else, and E holds only a wooden weapon
  (Mt 0) while the Smithy sells steel (Mt 6) by week 3. Reaching iron's grade from E by drills takes
  five of the 21 free days.
- Between arms and magic the wall is the stat itself: the ten fighters have Magic 1 to 3 and grow it
  5 to 20% a level; the four mages have Strength 2 to 4. No rule in the game moves either.
- A companion's starting grade, signature art and four in five of their weapon-tied traits point at
  the weapon they start with.

So every other path is strictly worse, in every run, and the player is right not to take it.

**3. Nothing differs between two runs with the same companion** except the traits, which are small
numbers. (The traits were made purely random on purpose, "so some runs push a companion to retrain":
the push is there, but nothing answers it.)

## The aim

1. Every companion reaches two moments in a run where the player chooses what they become. Both are
   known from the first day, so they are looked forward to and prepared for.
2. What is on offer differs from run to run, so the obvious path is often not on the table, and a
   company is a set of different roles.
3. Whatever is taken is worth taking: no calling leaves a companion weaker than the obvious one would.

Kept as they are: levels and their rolls, grades, the arts and spells and how they are learned, the
traits, accessories, enchanting, the weapons, everything in the battle that is not named below.

## Step 1: the calling

- **Twelve callings.** A calling is one rule that changes what its holder does in a battle, and a
  lean in how they grow from then on (see "What a calling does to growth").
- **Three are offered to each companion, drawn when they first appear in a run** (with their traits,
  with the run's generator, each of the twelve as likely as another). They are shown from then on: on
  a hire's paper in the Tavern before the hire, and on the Barracks sheet. Elena may be offered
  Champion, Captain and Mender in one run and Hunter, Sage and Warden in the next.
- **Taken at level 4** (about the second week for those fielded from day 1; `CALLING_LEVEL`). The
  choice is made when the level is shown, after a battle, a drill or a scavenging trip, and cannot be
  put off or undone. A hire who joins at level 4 or more chooses on joining.
- **One holder each.** A calling someone in the company has taken is closed to everyone else that run.
  When two are offered the same one, who takes it is a decision about the company. If that leaves
  someone with fewer than two open when their moment comes, more are drawn until two are.
- **A day to look elsewhere.** Before the calling is taken, a free day's action and 30 gold at the
  Drill Yard puts one of a companion's three aside and draws another in its place. This is the only
  way to steer what is offered; it costs a day, and the days are few.

### The twelve

Each is written as it would stand on a screen: one line.

| Calling | Its rule |
|---|---|
| **Warden** | Guard has no recovery. |
| **Champion** | An enemy they strike turns its coming blow on them. |
| **Executioner** | A strike or spell that leaves an enemy at a fifth of its Health or less fells it (a boss: a tenth). |
| **Skirmisher** | Their plain Attack has Recovery 1. |
| **Captain** | A new order, Rouse: a companion who is recovering is ready at once. |
| **Harrier** | Every strike or spell of theirs that lands staggers: the action comes 1 turn later (once per action, as now). |
| **Hunter** | Whatever they land on an enemy with 1 turn left is critical. |
| **Berserker** | Their arts cost Health, half as much, in place of stamina. |
| **Mender** | Once a battle, their healing spell can raise an injured companion, at a quarter of their Health. |
| **Hexer** | When an enemy carrying their poison, bleeding or curse falls, it passes to another enemy. |
| **Sage** | Their first spell of each battle costs no use. |
| **Spellblade** | Their weapon strikes are against the lower of the target's Defence and Resistance. |

- **The four of magic open their school.** Mender opens White Magic, Hexer and Spellblade Black, Sage
  either (the player picks): the grade is raised to D if it is lower, and one tier I spell of the
  school is learned, chosen from two drawn.
- **Strength and Magic stand close together** (the user's rule, in place of any rule about which
  stat leads a strike or a spell). In the companions' data, whichever of the two is lower is raised
  to 2 under the other, and its growth rate to 10 under the other's: Elena Strength 11 and Magic 9
  (65% and 55% a level), Freya Magic 10 and Strength 8 (75% and 65%). Nothing else about anyone
  changes and no rule is added: Strength leads weapons, Magic leads spells, and the stat table says
  what will happen.
  - Either craft is open to anyone in any run, about 2 points behind at level 1 and 3 by the end.
  - Which is the better one this run is moved by things the game already hands out, most of them
    worth nothing to a fighter today: the Bright trait and Growing: Magic, Magic on an enchanted axe,
    a magic weapon or a Runeblade found, a school as second hand (step 3), and the level-ups
    themselves. By the rolls alone the lesser stat has caught up or passed by level 13 in about one
    run in eight (worked out from the growth rates, not measured).
  - The grades are still a wall, and the callings take it down from both sides: a calling of magic
    opens its school as above, and a calling of arms raises the grade of the weapon in the holder's
    hand to D if it is lower.
  - What it costs: the four mages are no longer the only ones who cast well. What sets them apart is
    a school and a spell from day 1, and the body they have (Freya 7 Resistance against Elena's 2,
    more Speed and Dexterity; Elena 36 Health and 7 Defence).
  - Someone who uses both crafts has more to choose from each turn than anyone has today. Whether
    that makes the company too strong is for the playthrough to say.
- **Written so that most of them work for anyone.** "Strike or spell" wherever it can be, so a mage is
  served by Executioner, Harrier, Hunter and Captain as a fighter is. Two are poor for anyone frail,
  mage or not (Warden, Champion); at most two of the three drawn can be those.
- **Two rules that are broken on purpose.** Mender undoes an injury in battle, which nothing does
  today: the one raised fights on and does not go to the Infirmary. Captain moves who is ready, on
  top of the recovery rules just built: it costs the Captain's own turn and recovery, so the line acts
  no more often than before; the same action is given to someone else.

### What a calling does to growth

As a class does in Fire Emblem: the calling is felt the moment it is taken and in every level after.

- **On taking**: +2 to its first stat and +1 to its second, shown stat by stat as a level-up is.
  Health counts three for one (+6, or +3).
- **From then on**: the first stat's growth rate is 20 points higher, the second's 10 higher, and one
  stat's 10 lower.
- "Lead" is whichever of Strength and Magic is higher when the calling is taken; "the other" is the
  lower one.

| Calling | On taking | Grows faster | Grows slower |
|---|---|---|---|
| Warden | Defence +2, Health +3 | Defence, Health | Speed |
| Champion | Health +6, Defence +1 | Health, Defence | Dexterity |
| Executioner | Lead +2, Critical +1 | Lead, Critical | Defence |
| Skirmisher | Speed +2, Dexterity +1 | Speed, Dexterity | Health |
| Captain | Resistance +2, Defence +1 | Resistance, Defence | Critical |
| Harrier | Dexterity +2, Lead +1 | Dexterity, Lead | Resistance |
| Hunter | Lead +2, Dexterity +1 | Lead, Dexterity | Health |
| Berserker | Lead +2, Health +3 | Lead, Health | Dexterity |
| Mender | Magic +2, Resistance +1 | Magic, Resistance | Strength |
| Hexer | Magic +2, Dexterity +1 | Magic, Dexterity | Strength |
| Sage | Magic +2, Critical +1 | Magic, Critical | Defence |
| Spellblade | The other +2, Lead +1 | The other, Lead | Health |

- **What it comes to.** Taken at level 4 with about eight levels to go, a calling adds about 3.5
  points to its first stat by the end of a run and about 2 to its second, and takes about 1 from the
  third. The first stat began at 5 to 7 and gains about 4 or 5 from levels, so the calling is nearly
  half of how far it goes.
- **It settles arms or magic.** Strength and Magic start 1 apart. A calling of magic gives Magic +2
  at once and the faster growth after, and slows Strength: Elena the Mender has about Magic 9
  against Strength 8 the day she takes it and is a caster from then on. An Executioner or a Hunter makes the
  stat that already leads lead further.
- **Built well, built wrong.** Elena the Executioner ends near Strength 16 where her levels alone
  would leave her at 12. A Mender kept swinging her axe has spent the calling on the stat she is not
  using and grows slower in the one she is; a Hunter stood at the front has less Health than anyone
  there should; a Warden left at the rear has Defence nobody tests. Nothing stops any of it, and the
  company is weaker for it.
- **Known beforehand.** Each of the three cards offered shows its stats from day one (two rising, one
  falling), and the Barracks' growth lines count the calling as they count traits.
- The mastery at level 8 stays a choice of rule and adds no stats.

### What it does to the two complaints

**Three Elenas.** Champion: the obvious one, at the front with 36 Health, pulling onto herself the
blow aimed at Freya by striking whoever aims it. Captain: second in the line, rousing Kaito for the
killing blow and using her axe when nobody needs rousing. Mender: a healer who can stand at the
front, where no mage can. Each plays differently every turn, and which of them is possible is
decided by the draw, not by habit.

**Something to wait for, and things that fall into place.** The rules are written to meet the things
already in the game, so a find can complete a companion:

- Skirmisher with the Twinfang Sabre (a plain Attack strikes twice), or with the Relentless trait.
- Berserker with Bloodletter (heals half the damage dealt), or beside a Mender.
- Hexer with Viper's Kiss (every hit poisons) or any art that poisons or bleeds: it never leaves the
  field.
- Hunter beside a Warden: the Hunter waits for an enemy's last turn, the Warden takes what waiting
  costs.
- Captain beside the Executioner: the finisher is ready when the enemy is low.
- Spellblade with a Runeblade, which asks for the sword and black magic together and so is held by
  almost nobody today.

## Step 1 as built (2026-11-15)

Built with the proposed answers to "Yours to decide": three drawn and known from the first day with
a day at the Drill Yard to change one; one holder each; the Mender's raising kept; level 4, each
companion on their own; step 1 alone; +2 and +1 on the day and three growth rates. Where the build
differs from the text above, or settles something it left open:

- **What is drawn.** Three from the callings nobody holds (not from all twelve): a calling already
  taken would be a dead card on a new hire's sheet.
- **More are drawn at once**, when a calling is taken or someone joins, for whoever is left with
  fewer than two open; not when their own moment comes. The sheets are then always true.
- **The callings have their own dice**, seeded from the run's seed: a run's battles, fronts and
  shops fall as they would without callings.
- **Lead** is read from who they are (base stats, levels, traits), not from what they hold or wear,
  so a ring cannot be put on for the day to turn it. A tie goes to the faster growth, then Strength.
- **A calling of arms teaches nothing**; it only raises the grade of the weapon in hand to D. A
  calling of magic teaches one tier I spell of two drawn; a Mender who knows no heal is always
  offered one (the rule works through a heal).
- **Champion**: a strike or spell that lands turns the enemy's pending single blow; a miss turns
  nothing, and a blow on the whole line has no aim to turn.
- **Harrier**: the push comes after whatever the action itself pushes, so an art that staggers by 2
  still staggers by 2 and the Harrier's 1 adds nothing to it.
- **Hexer**: the effect goes to the living enemy with the most Health, with the turns it has left,
  and not onto one already carrying it for as long.
- **Sage**: the first spell of a battle can be cast even with no use left.
- **Mender**: the heal must be one aimed at one ally (Mend, Grace). The one raised is ready at once.
- **Berserker**: the cost is half the stamina cost rounded up, and can never be their last Health.
- **When the choice is put**: after a battle, once the result is left and before the day turns;
  after a drill, a scavenging trip or a hire, when that room is left. Nothing else answers until it
  is made.
- **The Barracks** has no room for three cards: the callings are plates at the head of the third
  column, and pointing at one reads it where an art is read. The cards are at the moment itself.

### What the playthrough said, and the retune

200 automated runs each (`run_policy.gd`; the same runs with and without, since the callings have
their own dice).

**Each calling by itself** (only that one is ever taken, by whoever is offered it first; about two
runs in three have it), runs won against 20% with no callings at all:

| Calling | Runs won | | Calling | Runs won |
|---|---|---|---|---|
| Harrier | 32% | | Sage | 26% |
| Skirmisher | 28% | | Spellblade | 26% |
| Hexer | 28% | | Executioner | 23% |
| Hunter | 27% | | Warden | 22% |
| Mender | 26% | | Berserker | 21% |
| | | | Champion | 20% |
| | | | Captain | 19% |

About 7 points either way is the dice. None is broken alone; the Harrier is the strongest, and the
Captain and the Champion are worth nothing to the automated player, which rouses by one plain rule
and never moves its line to suit a Champion. The four that open a school are worth as much for the
spell as for the rule: any fighter given a black spell hits harder with it than with a wooden axe.

**All together** (everyone takes one at level 4): 59% of runs won, bosses beaten 84% / 94% / 77%.
Four callings in a line add up, and a company that lives longer also levels further (level 13.0
at the end against 10.2).

**The retune.** The note said the bosses would be retuned after, and they were, with the later
kinds. Twenty-four settings were tried over four rounds. Two things were learned:

- Health moves a big fight far more than Strength does, because a boss is lost by running out
  (stamina, spell uses, heals), not by one blow. But Health alone made the day-28 bosses last 58
  turns (44 before the callings, 30 before the big fights were set in order). Bosses now have somewhat more Health and
  clearly harder blows instead, which keeps a boss fight at 33 to 43 turns for the automated player.
- The fight-length figure was added to the playthrough's report for this ("turns a fight takes").

| | Now (on top of what `design/growth.md` records) |
|---|---|
| Middle and late kinds | Health x1.1, +1 Strength and Magic |
| Elites (`ELITE_HP_MULT`, `ELITE_STR_BONUS`) | Health x0.9 on day 6, x1.6 and +1 Strength and Magic on day 20, x1.25 on day 34 |
| Day-14 bosses | Health x1.3, +2 Strength |
| Day-28 bosses | Health x1.3, +4 Strength and Magic |
| Day-42 bosses | Health x1.5, +4 Strength and Magic |

| Won by the automated player | Before callings | Callings, enemies as they were | Callings, retuned |
|---|---|---|---|
| Elite, day 6 | 76% | 76% | 76% |
| Boss, day 14 | 71% | 84% | 70% |
| Elite, day 20 | 65% | 82% | 71% |
| Boss, day 28 | 59% | 94% | 59% |
| Elite, day 34 | 47% | 68% | 52% |
| Boss, day 42 | 48% | 77% | 46% |
| Runs | 20% | 59% | 19% |
| Turns a boss fight takes when won (days 14, 28, 42) | 35 / 44 / 27 (60 runs) | | 36 / 43 / 33 |

("Before callings" is with the automated player's heal fixed: it used to aim a single heal at
whoever was injured, which did nothing, so healers stopped healing once anyone had fallen. That
alone took runs won from 16% to 20%, which is also about what the dice can do.)

**Against the targets** (set under "How it is built"):

| | Target | Measured |
|---|---|---|
| Each calling, how often taken when offered | None under 15% or over 60% | Warden 12%, Spellblade 16%, Captain 17% at the low end; Executioner 78%, Harrier 58% at the high end. This is the automated player's score, which ranks the Executioner first for everyone; it says little about what a person would take |
| Battles won with a given calling in the line | No calling more than 10 points from the average | 78% (Berserker) to 83% (Warden); the average is 83% |
| One companion over 200 runs | Their most-taken calling under half of the runs | The highest is Elena: a Skirmisher in 29% of the runs where Elena took a calling |

**The battle probe after it** (`tools/battle_probe.gd`, 20 runs, 329 battles replayed 10 times):
18.2 turns a battle (18.6 before the callings); the scouts' words still hold (a fight called sure is
won 98% of the time, close 78%, grim 22%). The harder blows show: an enemy blow that lands takes
half of someone's Health or more 20% of the time, where it was 13%, and fells them 12% of the time.

Not measured: any of it played by a person. The screens were checked by screenshot
(`tools/screen_checks/calling_*.gd`).

## Step 2: mastery

At level 8 (about the day of the second boss; `MASTERY_LEVEL`) the holder chooses one of their
calling's two masteries. Both are always offered: the draw was the calling, the mastery is the
player's.

| Calling | One | Or the other |
|---|---|---|
| Warden | Can shield anyone in the line, not only a neighbour | A blow caught for another is answered with their plain Attack |
| Champion | Takes a quarter less from a blow they turned | When the battle begins, every blow already aimed is aimed at them |
| Executioner | A quarter of its Health (a boss: an eighth) | Felling an enemy, they are ready at once |
| Skirmisher | Tier I arts have Recovery 1 too | Their first action of a battle has no recovery |
| Captain | The one roused cannot miss with their next action | Rouse has Recovery 1 |
| Harrier | Can push back an action already pushed back, once more | A staggered enemy takes a quarter more damage until it acts |
| Hunter | With 2 turns left or fewer | Such a blow cannot miss |
| Berserker | Below half Health: a quarter more damage | Felling an enemy heals a fifth of their Health |
| Mender | Their heals reach the target's neighbours, at half | Twice a battle |
| Hexer | Their effects last 2 turns longer | Enemies under their effects have 20 less Hit |
| Sage | That first spell has no recovery either | Every spell of theirs has 1 less recovery |
| Spellblade | After a spell, their next weapon strike has no recovery | A weapon strike that fells an enemy gives one spell use back |

## Step 3: two smaller forks (either can be left out)

- **A second hand.** When a companion first appears in a run, one weapon type or school other than
  their best is drawn, and their grade in it starts at D (a school teaches one tier I spell). It is
  on the hire's paper and the Barracks sheet with their other grades; nothing new is drawn on screen.
  One run Elena can pick up a bronze spear on day 1, another run a bow. It also brings the 24
  two-proficiency weapons within reach, which today ask for a second grade that only drills raise.
- **A choice at every grade.** Each grade reached offers two arts (or spells) of the tier rolled
  instead of handing over one; the player keeps one and the other may come up again. About six such
  choices for a companion in a run, each a chance to build toward their calling. Those outside the
  company go on learning at random.

## On the screens (mine to build with each step)

- **Tavern**: under a hire's traits, the three callings by name. **Barracks**: a heading CALLING on
  the sheet with the three as cards (name, the one line), the level it comes at as marks to fill;
  once taken, the one card and under it the two masteries.
- **The moment**: a beat of its own after the level is shown. The companion stands beside three
  cards; one is clicked, and it moves on only by its own "Go on", as the choice of arts does now.
- **In battle**: the calling's name under the companion's name. Rouse is an order in the list and
  asks whom, as Guard does. The forecast says what the rule will do before the order is given: FELLS
  for an Executioner's finishing blow, TURNS ON ELENA for a Champion's strike, STAGGERS +1, CRITICAL,
  the Health an art will cost in place of stamina.

## How it is built

A calling is data read where traits are read (`CompanionProgress.all_traits()`), as an accessory is,
with a new kind of modifier for each new rule; `Run` draws, offers, closes and hands them over. The
automated player has to choose callings and use them (a rough score by stats for the choice; Rouse,
the Mender's raising and the Hunter's timing in `run_policy.gd`), or the 200-run check says nothing
about them.

The stats are data, and are built: the fourteen `data/companions/*.tres` files, a test that holds
every companion to the rule (`weapon_tests.gd` `test_strength_and_magic_stand_close`), and the
scavenging targets, which are set from the companions' averages (`SCAVENGE_STAT_BASE`,
`SCAVENGE_STAT_GROWTH`: a Seer's place asks for Magic 7 on day 1 where it asked for 4).

**What to check after step 1**, in the playthrough:

| | Target |
|---|---|
| Runs won by the automated player | Up from 10%; the bosses are retuned after, not before |
| Each calling, how often taken when offered | None under 15% or over 60% |
| Battles won with a given calling in the line | No calling more than 10 points from the average |
| One companion over 200 runs | Their most-taken calling under half of the runs |

The user's own play outranks all four.

## What this does not touch

- The weapon ladder is still "+2 Mt a tier, buy the next one". It needs its own answer later.
- Days that differ (the first complaint) is the next design after this one.

## Yours to decide (step 1 was built with the proposed answers, 2026-11-15)

1. **How the three are offered.** Drawn and known from the first day, with a day at the Drill Yard to
   change one (proposed). Or the whole list open to everyone, which lets you choose any path but ends
   in the same choice every run. Or drawn with no way to change them.
2. **One holder each** (proposed), or any number of the same calling in a company.
3. **Arms and magic.** Settled by the user and built (2026-11-14): Strength and Magic stand close
   together in every companion's data, 2 points and 10% of growth apart, with no rule about which
   leads. (3 and 15% was the other choice: by the rolls alone the lesser stat would catch up in about
   one run in thirty, not one in eight.)
4. **The Mender's raising**, which reverses "nothing in battle undoes an injury": keep it (proposed),
   or give the Mender another rule.
5. **When.** Levels 4 and 8 for each companion on their own (proposed), or everyone at once after the
   first and second boss.
6. **What to build first.** Step 1 alone with all twelve, then play (proposed); or steps 1 and 2
   together; step 3 in either case after.
7. **Growth by calling.** +2 and +1 on taking, and three growth rates shifted (proposed). Or the
   growth rates alone, with nothing on the day it is taken. Or larger: +3 and +2.
