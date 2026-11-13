class_name EnemyTraits
extends RefCounted
## Enemy traits: plain names listed on EnemyData.traits. Weapons, combat arts and spells list the traits
## they are effective against; an effective strike doubles Mt (BattleConfig.EFFECTIVE_MIGHT_MULT).

const FLYING := "Flying"

const DESCRIPTIONS := {
	FLYING: "Flying: it takes to the air. Bows, and any art or spell made for it, are effective: their Mt is doubled.",
}


static func describe(t: String) -> String:
	return DESCRIPTIONS.get(t, t)
