class_name BattleSetup
extends Resource
## Who fights in a battle. Companions are listed left to right; the last one stands nearest the enemies.

@export var companions: Array[CompanionData] = []
@export var enemies: Array[EnemyData] = []
## 0 = random seed each battle.
@export var rng_seed: int = 0
