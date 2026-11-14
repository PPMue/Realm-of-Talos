class_name MasteryData
extends Resource
## A calling's mastery (design/callings.md, step 2): one of the two its holder chooses between at
## RunConfig.MASTERY_LEVEL. One more line of rule on top of the calling's own (`modifiers`, read by
## TraitRules with the calling's: CallingData.effect_for). Each lives inside its calling's .tres
## (CallingData.masteries); tools/generate_callings.gd wrote them.

## "warden_wide_shield".
@export var id: String = ""
## "Wide Shield".
@export var display_name: String = ""
## Its rule as it stands on a screen: one line.
@export var rule: String = ""
@export var modifiers: Array[TraitModifier] = []
