class_name RunInventory
extends RefCounted
## Every weapon owned during a run. A weapon is held by at most one companion; every companion in
## the roster holds exactly one.

var weapons: Array[OwnedWeapon] = []


func add(data: WeaponData, holder: RunCompanion = null) -> OwnedWeapon:
	var w := OwnedWeapon.new(data)
	weapons.append(w)
	if holder != null:
		_hand_to(w, holder)
	return w


func held_by(c: RunCompanion) -> OwnedWeapon:
	for w in weapons:
		if w.holder == c:
			return w
	return null


func unheld() -> Array[OwnedWeapon]:
	var out: Array[OwnedWeapon] = []
	for w in weapons:
		if w.holder == null:
			out.append(w)
	return out


## Why `c` cannot take `w` in hand, or "" if they can.
func equip_block_reason(c: RunCompanion, w: OwnedWeapon) -> String:
	if c == null or w == null or not weapons.has(w):
		return "That weapon is not in the armory."
	if w.holder == c:
		return "%s already holds it." % c.display_name()
	if w.holder != null:
		return "%s is holding it." % w.holder.display_name()
	return c.progress.weapon_block_reason(w.data)


## Puts `w` in `c`'s hand; the weapon they held goes back to the armory.
func equip(c: RunCompanion, w: OwnedWeapon) -> bool:
	if equip_block_reason(c, w) != "":
		return false
	var old := held_by(c)
	if old != null:
		old.holder = null
	_hand_to(w, c)
	return true


## A companion left the run: their weapon goes back to the armory.
func release(c: RunCompanion) -> void:
	var w := held_by(c)
	if w != null:
		w.holder = null


func _hand_to(w: OwnedWeapon, c: RunCompanion) -> void:
	w.holder = c
	c.progress.weapon = w.data
