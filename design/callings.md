# Callings: a companion becomes something, and not the same thing every run (design; nothing built)

Written 2026-11-14 after the user's play reports: "When I get a companion, I can just keep using it
and it will grow stronger... and I can do the same like this in every run. There is nothing that
forces the player out of this comfort zone", and "I want to be able to take the same companion to a
different path in a different run". Every number here is a first guess.

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

- **Twelve callings.** A calling is one rule that changes what its holder does in a battle. It is not
  a number added to a stat.
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
- **Led by the higher of the two, both ways.** For a holder of Mender, Hexer, Sage or Spellblade,
  spells are cast with whichever is higher, Strength or Magic. For a holder of any of the other
  eight, the callings of arms, weapon strikes are led by whichever is higher (in the weapon's own
  formula, Magic standing where Strength does), and the grade of the weapon in their hand is raised to
  D if it is lower. A Spellblade has both. This is the rule that takes the wall between arms and magic
  down, and it has to come down from both sides: with only the first half a fighter could take up
  magic and keep the weapon, while a mage could never take up a weapon, and the mages would simply be
  the worse companions.
  - A fighter with a calling of magic: at their starting stats Elena the Mender heals 15 with Mend
    (Strength 11 + 4) where Aveline heals 12, and still swings her axe.
  - A mage with a calling of arms: Freya the Skirmisher strikes with a dagger at 9 ((Magic 10 +
    Speed 8) / 2), the same as Yuzu, and still casts.
  - Whoever stays on their own side (Elena the Champion, Freya the Sage) has one craft, not two, and
    is ahead in it: a companion fielded from day 1 is about a week and a half of grades, arts or
    spells ahead of someone who opens the craft at level 4.
  - What is left between them is the body, as between any two companions today: Elena has 36 Health
    and 7 Defence, Freya 7 Resistance against Elena's 2 and more Speed and Dexterity. The mages'
    bodies are those of the light fighters (Freya 27 Health, Yuzu 27, Koharu 26).
  - The stat table still says Magic 1 for Elena: the forecasts show the truth.
- **Written so that most of them work for anyone.** "Strike or spell" wherever it can be, so a mage is
  served by Executioner, Harrier, Hunter and Captain as a fighter is. Two are poor for anyone frail,
  mage or not (Warden, Champion); at most two of the three drawn can be those.
- **Two rules that are broken on purpose.** Mender undoes an injury in battle, which nothing does
  today: the one raised fights on and does not go to the Infirmary. Captain moves who is ready, on
  top of the recovery rules just built: it costs the Captain's own turn and recovery, so the line acts
  no more often than before; the same action is given to someone else.

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

## Yours to decide

1. **How the three are offered.** Drawn and known from the first day, with a day at the Drill Yard to
   change one (proposed). Or the whole list open to everyone, which lets you choose any path but ends
   in the same choice every run. Or drawn with no way to change them.
2. **One holder each** (proposed), or any number of the same calling in a company.
3. **Arms and magic.** Led by the higher of Strength and Magic, both ways: spells for the four
   callings of magic, weapon strikes for the eight of arms (proposed; whoever crosses over has both
   crafts, late). Or Strength and Magic change places for good when someone crosses over, which gives
   one craft only and leaves the other useless. Or the stats are left alone and whoever crosses over
   stays weak at it.
4. **The Mender's raising**, which reverses "nothing in battle undoes an injury": keep it (proposed),
   or give the Mender another rule.
5. **When.** Levels 4 and 8 for each companion on their own (proposed), or everyone at once after the
   first and second boss.
6. **What to build first.** Step 1 alone with all twelve, then play (proposed); or steps 1 and 2
   together; step 3 in either case after.
