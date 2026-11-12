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

# --- Equipment weight ---
const WEIGHT_PENALTY_PER_POINT := 1     # DEX and SPD lost per point of total WT above BLD

# --- Recovery: how many following player actions a companion sits out ---
const RECOVERY_ATTACK := 1
const RECOVERY_GUARD := 1
const RECOVERY_FOCUS := 1
const RECOVERY_SKILL := 2

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

# --- Battle end ---
const VICTORY_INJURED_HP := 1
