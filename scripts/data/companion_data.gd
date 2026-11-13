class_name CompanionData
extends Resource
## A companion's definition: base stats, equipment, starting weapon grades and signature art.
## What changes during a run (proficiency, known and equipped arts) lives in CompanionProgress.

@export var display_name: String = ""
@export var portrait: Texture2D
@export var color: Color = Color.GRAY
## Where the face is in the portrait art (0-1 on each axis); the UI crops around it.
@export var portrait_focus: Vector2 = Vector2(0.5, 0.2)

@export_group("Stats")
@export var max_hp: int = 20
@export var max_sta: int = 30
@export var strength: int = 5
@export var magic: int = 0
@export var crit: int = 0
@export var dexterity: int = 5
@export var speed: int = 5
@export var defense: int = 3
@export var resistance: int = 1
@export var luck: int = 3
@export var build: int = 5

@export_group("Equipment")
@export var weapon: WeaponData
@export var armor: EquipmentData
@export var accessory: EquipmentData

@export_group("Proficiency")
## Grade in each weapon type at the start of a run.
@export var start_grade_sword: Proficiency.Grade = Proficiency.Grade.E
@export var start_grade_axe: Proficiency.Grade = Proficiency.Grade.E
@export var start_grade_spear: Proficiency.Grade = Proficiency.Grade.E
@export var start_grade_bow: Proficiency.Grade = Proficiency.Grade.E
@export var start_grade_dagger: Proficiency.Grade = Proficiency.Grade.E
## Known and equipped from the start of a run.
@export var signature_art: CombatArtData

@export_group("Progression")
## Not used: every companion starts a run at level 1 (tavern hires at the roster's average level).
@export var level: int = 1
## Stat key -> growth percent: the chance that stat rises by 1 on each level-up. BLD never grows.
## See Levels.
@export var growths: Dictionary = {}


func base_stats() -> Dictionary:
	return {
		Stat.HP: max_hp, Stat.STA: max_sta, Stat.STR: strength, Stat.MAG: magic,
		Stat.CRT: crit, Stat.DEX: dexterity, Stat.SPD: speed, Stat.DEF: defense,
		Stat.RES: resistance, Stat.LCK: luck, Stat.BLD: build,
	}


func equipment() -> Array[EquipmentData]:
	var items: Array[EquipmentData] = []
	for item: EquipmentData in [weapon, armor, accessory]:
		if item != null:
			items.append(item)
	return items


func starting_grade(t: WeaponData.WeaponType) -> int:
	match t:
		WeaponData.WeaponType.SWORD:
			return start_grade_sword
		WeaponData.WeaponType.AXE:
			return start_grade_axe
		WeaponData.WeaponType.SPEAR:
			return start_grade_spear
		WeaponData.WeaponType.BOW:
			return start_grade_bow
		WeaponData.WeaponType.DAGGER:
			return start_grade_dagger
	return Proficiency.Grade.E
