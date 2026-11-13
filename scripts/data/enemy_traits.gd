class_name EnemyTraits
extends RefCounted
## Enemy traits: plain names listed on EnemyData.traits. Weapons, combat arts and spells list the traits
## they are effective against; an effective strike deals half as much damage again
## (BattleConfig.EFFECTIVE_DAMAGE_BONUS_PERCENT).

const FLYING := "Flying"
const LARGE := "Large"

const DESCRIPTIONS := {
	FLYING: "Flying: it takes to the air. Bows, and any art or spell made for it, are effective: they deal half as much damage again.",
	LARGE: "Large: a hulking brute. Spears, and any art or spell made for it, are effective: they deal half as much damage again.",
}


static func describe(t: String) -> String:
	return DESCRIPTIONS.get(t, t)
