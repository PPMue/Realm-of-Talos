class_name SpellLibrary
extends Resource
## Every spell that can be learned by raising a magic school's grade.
## Signature spells are not listed here: each belongs to one companion (CompanionData.signature_spell).

const DEFAULT_PATH := "res://data/spells/spell_library.tres"

@export var spells: Array[SpellData] = []


static func load_default() -> SpellLibrary:
	return load(DEFAULT_PATH) as SpellLibrary


func of_school(s: SpellData.School) -> Array[SpellData]:
	var out: Array[SpellData] = []
	for sp in spells:
		if sp.school == s:
			out.append(sp)
	return out
