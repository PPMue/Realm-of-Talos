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
## Full names, as the screens write them.
const NAMES := {HP: "Health", STA: "Stamina", STR: "Strength", MAG: "Magic", CRT: "Critical", DEX: "Dexterity",
	SPD: "Speed", DEF: "Defence", RES: "Resistance", LCK: "Luck", BLD: "Build"}


static func name_of(key: String) -> String:
	return NAMES.get(key, key)
const ENEMY_KEYS: Array[String] = [HP, STR, MAG, CRT, DEX, SPD, DEF, RES, LCK]
