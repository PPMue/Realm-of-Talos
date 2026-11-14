class_name BattleConfig
extends RefCounted
## Every tuning number used by the battle rules lives here.
## Per-unit numbers (stats, weapon Mt/Hit/WT, enemy action CD/Mt/Hit) live in the .tres data under res://data.

# --- Damage, accuracy, crit ---
const MIN_DAMAGE := 1
const ACCURACY_DEX_SPD_FACTOR := 7      # Hit% = weapon Hit + 7 x (attacker DEX - target SPD) - target LCK
const ACCURACY_MIN := 20
const ACCURACY_MAX := 100
const CRIT_CRT_FACTOR := 3              # Crit% = 3 x attacker CRT - target LCK
const CRIT_MIN := 0
const CRIT_MAX := 100
const CRIT_DAMAGE_MULT := 2

# --- Effectiveness ---
# A weapon, art or spell effective against one of the target's traits (a bow against a flying enemy,
# a spear against a large one) deals this much more damage, in percent of the damage left after DEF or
# RES, rounded down. Added before a critical doubles the damage. Never stacks.
const EFFECTIVE_DAMAGE_BONUS_PERCENT := 50

# --- Equipment weight ---
const WEIGHT_PENALTY_PER_POINT := 1     # DEX and SPD lost per point of total WT above BLD

# --- Recovery: how many following player actions a companion sits out ---
const RECOVERY_ATTACK := 2
const RECOVERY_GUARD := 2
const RECOVERY_FOCUS := 2
# Combat arts and spells carry their own recovery in their data (tier 1: 2, tier 2: 3, tier 3: 4).
# Recovery an enemy adds comes on top. When nobody is ready the party waits (Battle.wait), a companion
# standing alone included.

# --- Guard (lasts until the end of the tick it was used in) ---
const GUARD_DAMAGE_TAKEN_MULT := 0.5
const GUARD_DURATION_TICKS := 1

# --- Stamina in battle ---
const FOCUS_RESTORE_PERCENT := 50      # Focus: this share of max stamina, rounded up
const BREATH_PER_TURN := 1             # regained at the end of every turn a standing companion did not act in

# --- The account before a battle (BattleAccount.before) ---
# The scouts' word, from the turns the enemies need to bring the line down over the turns the line needs
# to bring them down. Set with tools/battle_probe.gd so the words are true of the automated player:
# it wins a "sure" fight nine times in ten or more, a "grim" one fewer than four in ten.
const ACCOUNT_SURE_RATIO := 0.8
const ACCOUNT_GRIM_RATIO := 0.4

# --- Enemy single-target selection ---
const TARGET_WEIGHT_BASE := 1.0         # leftmost companion
const TARGET_WEIGHT_GROWTH := 2.0       # multiplier per slot to the right

# --- Enemy countdowns ---
const MIN_ACTION_COUNTDOWN := 1

# --- The weapon ladder ---
# Six tiers: wooden, bronze, iron, steel, silver, platinum (WeaponData.Tier). Every weapon type exists
# in every tier. Mt = the tier's base + the type's offset in that tier, never below 0: 1 a tier. The axe
# has no edge in Mt early: its heft comes from BLD (see CombatMath.attack_power) and it pulls ahead late.
# Hit and weight are in each weapon's data (README, Weapons, has the table).
const WEAPON_TIER_BASE_MIGHT: Array[int] = [0, 1, 2, 3, 4, 5]
# By WeaponData.WeaponType (sword, axe, spear, bow, dagger), then by tier.
const WEAPON_TYPE_MIGHT_OFFSET := [
	[0, 0, 0, 0, 0, 0],      # sword
	[0, 0, 0, 0, 1, 1],      # axe
	[1, 1, 1, 1, 1, 1],      # spear
	[0, 0, 0, 0, 0, 0],      # bow
	[0, 0, 0, 0, 0, 0],      # dagger
]
# Grade (Proficiency.Grade) needed to hold each tier: E, D, C, B, A, S.
const WEAPON_TIER_GRADE: Array[int] = [0, 2, 4, 6, 8, 10]
# Two-proficiency weapons (bronze to silver): Mt of their main type's ladder weapon this many tiers up,
# weight this much above it at the same tier (by family: HYBRID_WEIGHT_BONUS_BY_FAMILY, else
# HYBRID_WEIGHT_BONUS; see WeaponData.hybrid_weight_bonus), Hit as it; the second type needs a grade this many steps
# lower than the tier's (2 steps = one letter), but never below HYBRID_SECOND_GRADE_MIN: everyone has E
# in everything, so E would be no requirement. Bronze D + E+, iron C + D, steel B + C, silver A + B.
const HYBRID_MIGHT_TIERS_UP := 1
const HYBRID_WEIGHT_BONUS := 1
## Twinblades were ahead of the sword with no cost: they carry more weight.
const HYBRID_WEIGHT_BONUS_BY_FAMILY := {"Twinblades": 3}
const HYBRID_SECOND_GRADE_STEPS_BELOW := 2
const HYBRID_SECOND_GRADE_MIN := 1   # Proficiency.Grade.E_PLUS

# --- Weapon proficiency ---
# Grades in order: E, E+, D, D+, C, C+, B, B+, A, A+, S (see Proficiency.Grade).
# Total points needed to reach each grade. Steps: 5, 6, 6, 8, 10, 12, 15, 18, 22, 28.
# Companions start at D in the weapon they wield, so D+ comes after about one prototype
# battle and C after about two; each later grade takes longer.
const PROFICIENCY_GRADE_POINTS: Array[int] = [0, 5, 11, 17, 25, 35, 47, 62, 80, 102, 130]
const PROFICIENCY_POINTS_ATTACK := 1
const PROFICIENCY_POINTS_ART := 2      # Guard, Focus and Wait give none
# Most points one companion can gain in a single battle, so stalling a safe fight is no way to train.
const PROFICIENCY_CAP_PER_BATTLE := 8

# --- Combat arts ---
const MAX_EQUIPPED_ARTS := 3
# Chance (percent) of learning a tier 1 / tier 2 / tier 3 art on reaching each grade, by grade.
# E is never reached by a grade-up; it is listed so the table lines up with the grades.
const ART_TIER_ODDS := [
	[100, 0, 0],   # E
	[100, 0, 0],   # E+
	[100, 0, 0],   # D
	[100, 0, 0],   # D+
	[75, 25, 0],   # C
	[75, 25, 0],   # C+
	[50, 40, 10],  # B
	[50, 40, 10],  # B+
	[25, 50, 25],  # A
	[25, 50, 25],  # A+
	[0, 50, 50],   # S
]

# --- Magic ---
# Two schools, Black (offence) and White (support), graded like weapons with the same thresholds.
const MAGIC_POINTS_PER_CAST := 4
# Separate from the weapon cap: the most magic points one companion can gain in a single battle.
const MAGIC_CAP_PER_BATTLE := 12
# Spells learned on a school grade-up use ART_TIER_ODDS, like combat arts.

# --- Contribution ---
# Points each companion earns in a battle; a won battle's XP is mostly shared out by them (see Run).
# Focus and Wait earn nothing.
const POINTS_ATTACK_HIT := 2
const POINTS_ATTACK_MISS := 1
const POINTS_ART := 3                 # per art used, however many enemies it strikes
const POINTS_SPELL := 3               # per spell cast, of any kind
const POINTS_BLOW_TAKEN := 1          # per enemy blow that lands on the companion
const POINTS_BLOW_TAKEN_GUARDING := 2
# Landing the killing blow on an enemy, per enemy. Damage over time counts for whoever applied it, a
# reflecting stance for whoever carries it.
const POINTS_KILL := 4
