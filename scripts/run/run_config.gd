class_name RunConfig
extends RefCounted
## Every tuning number used by the run rules lives here.
## Content (enemy groups, front sites, events, shop stock) lives in the .tres data under res://data/run.

# --- Calendar ---
const DAYS := 30
const BLOCK_DAYS := 10                  # a boss closes every block: days 10, 20, 30
const BATTLES_PER_BLOCK_MIN := 5        # battle days in a block besides the boss
const BATTLES_PER_BLOCK_MAX := 6
const FREE_DAYS_PER_BLOCK := 2          # one of them is always the day before the boss
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
const REWARD_GROWTH_PER_DAY := 0.03
## Chance the reward also includes materials, and how many, by danger.
const REWARD_MATERIAL_CHANCE: Array[float] = [0.3, 0.6, 1.0]
const REWARD_MATERIAL_AMOUNT: Array[int] = [1, 2, 3]
## Boss rewards, by boss (day 10, 20, 30). The last one ends the run, so it only shows.
const BOSS_REWARD_GOLD: Array[int] = [150, 250, 0]
const BOSS_REWARD_MATERIALS := 3

# --- Bestiary bands ---
# Every normal enemy belongs to a band (EnemyData.band): 1 early, 2 middle, 3 late. A band's enemies
# appear from its first day on; groups never field an enemy before its band begins.
const BAND_FIRST_DAY: Array[int] = [1, 11, 21]
## How likely a group is to be picked for a front, by how many bands older than the day's band it is:
## the day's own band, one band older, two bands older. Older groups still turn up, scaled to the day.
const BAND_AGE_WEIGHT: Array[float] = [1.0, 0.3, 0.12]

# --- Enemy scaling with the day (normal fronts only; bosses are built for their day) ---
# Assumes companions level at the pace below (about level 13 by day 30, roughly +4 to +6 in each
# main stat), plus better weapons and grades.
const ENEMY_HP_GROWTH_PER_DAY := 0.05   # max HP x (1 + 0.05 x (day - 1)): day 30 is x2.45
const ENEMY_STR_EVERY_DAYS := 4         # +1 STR and MAG on days 5, 9, 13, ... 29 (+7)
const ENEMY_DEF_EVERY_DAYS := 6         # +1 DEF on days 7, 13, 19, 25 (+4)
const ENEMY_SPD_EVERY_DAYS := 8         # +1 SPD and DEX on days 9, 17, 25

# --- Levels and XP ---
# A won battle grants an XP pool, split evenly (rounded down) among the fielded companions still in
# the run at its end. Pace target: fielded in every battle in a party of about four, a companion ends
# the run around level 12-15. Measured by the level pace test.
const XP_POOL_BY_DANGER: Array[int] = [60, 90, 125]
const XP_POOL_GROWTH_PER_DAY := 0.04    # pool x (1 + 0.04 x (day - 1))
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
const FREE_DAY_ACTIONS := 2
const HIRE_COST := 100
## How many companions the tavern offers (at most; fewer if fewer are left to hire).
const TAVERN_OFFERS_MIN := 1
const TAVERN_OFFERS_MAX := 2
const REPAIR_COST := {TIMBER: 2, IRON_ORE: 1}
const REPAIR_AMOUNT := 20

# --- Starting resources ---
const STARTING_GOLD := 60
const STARTING_MATERIALS := {IRON_ORE: 0, TIMBER: 1}
