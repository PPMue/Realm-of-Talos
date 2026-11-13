class_name BattleConfig
extends RefCounted
## Every tuning number used by the battle rules lives here.
## Per-unit numbers (stats, weapon Mt/Hit/WT, enemy action CD/Mt/Hit) live in the .tres data under res://data.

# --- Damage, accuracy, crit ---
const MIN_DAMAGE := 1
const ACCURACY_DEX_SPD_FACTOR := 5      # Hit% = weapon Hit + 5 x (attacker DEX - target SPD) - target LCK
const ACCURACY_MIN := 20
const ACCURACY_MAX := 100
const CRIT_CRT_FACTOR := 2              # Crit% = 2 x attacker CRT - target LCK
const CRIT_MIN := 0
const CRIT_MAX := 100
const CRIT_DAMAGE_MULT := 2

# --- Effectiveness ---
# A weapon, art or spell effective against one of the target's traits (e.g. a bow against a flying
# enemy) multiplies its Mt by this before the target's DEF or RES is subtracted. Never stacks.
const EFFECTIVE_MIGHT_MULT := 2

# --- Equipment weight ---
const WEIGHT_PENALTY_PER_POINT := 1     # DEX and SPD lost per point of total WT above BLD

# --- Recovery: how many following player actions a companion sits out ---
const RECOVERY_ATTACK := 1
const RECOVERY_GUARD := 1
const RECOVERY_FOCUS := 1
# Combat arts carry their own recovery in their data (tier 1: 1, tier 2: 2, tier 3: 3).

# --- Guard (lasts until the end of the tick it was used in) ---
const GUARD_DAMAGE_TAKEN_MULT := 0.5
const GUARD_TARGET_WEIGHT_MULT := 4.0
const GUARD_DURATION_TICKS := 1

# --- Focus ---
const FOCUS_RESTORE_FRACTION := 0.1     # of max stamina, rounded, at least 1

# --- Enemy single-target selection ---
const TARGET_WEIGHT_BASE := 1.0         # leftmost companion
const TARGET_WEIGHT_GROWTH := 2.0       # multiplier per slot to the right
const INJURED_TARGET_WEIGHT_MULT := 0.25

# --- Enemy countdowns ---
const MIN_ACTION_COUNTDOWN := 1

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

# --- Battle end ---
const VICTORY_INJURED_HP := 1
