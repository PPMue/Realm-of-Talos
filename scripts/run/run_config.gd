class_name RunConfig
extends RefCounted
## Every tuning number used by the run rules lives here.
## Content (enemy groups, front sites, events, shop stock) lives in the .tres data under res://data/run.

# --- Calendar ---
# See RunCalendar for the shape of a week: battle and free days alternate, the boss every second week.
const DAYS := 42
const WEEK_DAYS := 7                    # the tavern and the smithy restock on the first day of each week
const BOSS_EVERY_DAYS := 14             # a boss ends every second week: days 14, 28, 42
const EVENTS_PER_WEEK := 1              # free days that begin with an event, in every week
const DAYS_SHOWN_AHEAD := 7             # the player always sees the type of the next 7 days

# --- City ---
const CITY_MAX_HEALTH := 100
## City health lost when a battle on a front of danger 1, 2, 3 is lost.
const CITY_DAMAGE_BY_DANGER: Array[int] = [15, 20, 25]

# --- Party ---
const STARTING_COMPANIONS := 2
const MAX_FIELDED := 4
## At the end of every day each surviving companion heals this share of max HP (rounded up).
const DAILY_HEAL_FRACTION := 0.2
## HP an injured companion comes back with after a battle, won or lost.
const INJURED_RETURN_HP := 1

# --- Fronts ---
## Chance a battle day offers three fronts (danger 1, 2 and 3) instead of two.
const THREE_FRONTS_CHANCE := 0.5
## Gold for winning, by danger, on day 1. Grows by REWARD_GROWTH_PER_DAY each day after.
const REWARD_GOLD_BY_DANGER: Array[int] = [40, 70, 110]
const REWARD_GOLD_SPREAD := 0.15        # +/- this share, rolled per front
const REWARD_GROWTH_PER_DAY := 0.021  # day 42 pays x1.86
## Chance the reward also includes materials, and how many, by danger.
const REWARD_MATERIAL_CHANCE: Array[float] = [0.3, 0.6, 1.0]
const REWARD_MATERIAL_AMOUNT: Array[int] = [1, 2, 3]
## Boss rewards, by boss (day 14, 28, 42). The last one ends the run, so it only shows.
const BOSS_REWARD_GOLD: Array[int] = [150, 250, 0]
const BOSS_REWARD_MATERIALS := 3

# --- Bestiary bands ---
# Every normal enemy belongs to a band (EnemyData.band): 1 early, 2 middle, 3 late. A band's enemies
# appear from its first day on; groups never field an enemy before its band begins.
const BAND_FIRST_DAY: Array[int] = [1, 15, 29]   # weeks 1-2, 3-4, 5-6
## How likely a group is to be picked for a front, by how many bands older than the day's band it is:
## the day's own band, one band older, two bands older. Older groups still turn up, scaled to the day.
const BAND_AGE_WEIGHT: Array[float] = [1.0, 0.3, 0.12]

# --- Enemy scaling with the day (normal fronts only; bosses are built for their day) ---
# Assumes companions level at the pace below (about level 13 by day 42, roughly +4 to +6 in each
# main stat), plus better weapons and grades.
const ENEMY_HP_GROWTH_PER_DAY := 0.035  # max HP x (1 + 0.035 x (day - 1)): day 42 is x2.44
const ENEMY_STR_EVERY_DAYS := 5.5       # +1 STR and MAG on days 7, 12, 18, 23, 29, 34, 40 (+7)
const ENEMY_DEF_EVERY_DAYS := 9         # +1 DEF on days 10, 19, 28, 37 (+4)
const ENEMY_SPD_EVERY_DAYS := 11        # +1 SPD and DEX on days 12, 23, 34 (+3)

# --- Levels and XP ---
# A won battle grants an XP pool, split evenly (rounded down) among the fielded companions still in
# the run at its end. Pace target: fielded in every battle in a party of about four, a companion ends
# the run around level 12-15. Measured by the level pace test.
const XP_POOL_BY_DANGER: Array[int] = [57, 86, 119]
const XP_POOL_GROWTH_PER_DAY := 0.028   # pool x (1 + 0.028 x (day - 1)): day 42 is x2.15
const BOSS_XP_POOL: Array[int] = [220, 320, 420]
## XP to go from level L to L + 1: BASE + STEP x (L - 1).
const XP_PER_LEVEL_BASE := 30
const XP_PER_LEVEL_STEP := 5
const MAX_LEVEL := 20
## At least this many stats rise on every level-up.
const MIN_STAT_GAINS := 2

# --- Materials ---
const IRON_ORE := "iron_ore"
const TIMBER := "timber"
const MATERIAL_NAMES := {IRON_ORE: "Iron Ore", TIMBER: "Timber"}
const MATERIAL_ORDER: Array[String] = [IRON_ORE, TIMBER]

# --- Free days ---
const FREE_DAY_ACTIONS := 1
const HIRE_COST := 100
## How many companions the tavern offers (at most; fewer if fewer are left to hire).
const TAVERN_OFFERS_MIN := 1
const TAVERN_OFFERS_MAX := 2
const REPAIR_COST := {TIMBER: 2, IRON_ORE: 1}
const REPAIR_AMOUNT := 20

# --- Starting resources ---
const STARTING_GOLD := 60
const STARTING_MATERIALS := {IRON_ORE: 0, TIMBER: 1}
