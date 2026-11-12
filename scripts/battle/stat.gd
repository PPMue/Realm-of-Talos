class_name Stat
extends RefCounted
## Stat keys used in stat dictionaries and status-effect modifiers.

const HP := "HP"
const STA := "STA"
const STR := "STR"
const MAG := "MAG"
const CRT := "CRT"
const DEX := "DEX"
const SPD := "SPD"
const DEF := "DEF"
const RES := "RES"
const LCK := "LCK"
const BLD := "BLD"

const COMPANION_KEYS: Array[String] = [HP, STA, STR, MAG, CRT, DEX, SPD, DEF, RES, LCK, BLD]
const ENEMY_KEYS: Array[String] = [HP, STR, MAG, CRT, DEX, SPD, DEF, RES, LCK]
