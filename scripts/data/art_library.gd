class_name ArtLibrary
extends Resource
## Every combat art that can be learned by raising a weapon grade.
## Twelve for each weapon type. A companion's signature art (CompanionData.signature_art) is one of
## them: they start a run knowing it, and the other user of that weapon can learn it like any other.

const DEFAULT_PATH := "res://data/arts/art_library.tres"

@export var arts: Array[CombatArtData] = []


static func load_default() -> ArtLibrary:
	return load(DEFAULT_PATH) as ArtLibrary


func of_type(t: WeaponData.WeaponType) -> Array[CombatArtData]:
	var out: Array[CombatArtData] = []
	for a in arts:
		if a.weapon_type == t:
			out.append(a)
	return out
