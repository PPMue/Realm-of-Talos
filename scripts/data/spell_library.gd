class_name SpellLibrary
extends Resource
## Every spell that can be learned by raising a magic school's grade.
## Twelve for each school, 5 / 4 / 3 by tier. A mage's signature spell (CompanionData.signature_spell)
## is one of them: they start a run knowing it, and the other mage of that school can learn it.

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
