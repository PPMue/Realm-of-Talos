class_name PartyMedallion
extends Control
## A companion in the city's square: a round portrait in a brass ring, their name under it, and their
## health as an arc around the ring. Reserve companions are drawn smaller and dimmer. Hovering gives
## the full account; clicking emits `pressed`.

signal pressed

const R := 40.0
const RESERVE_R := 28.0
const H := 112.0

var companion: RunCompanion
var _fielded := true
var _hover := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func setup(c: RunCompanion, fielded: bool, where: String) -> void:
	companion = c
	_fielded = fielded
	var r := R if fielded else RESERVE_R
	custom_minimum_size = Vector2(r * 2.0 + 28.0, H)
	size = custom_minimum_size
	tooltip_text = "%s\n%s" % [where, describe(c)]
	queue_redraw()


## A companion's state in a few lines, for tooltips.
static func describe(c: RunCompanion) -> String:
	var w := c.weapon()
	var t := w.weapon_type
	var arts: Array[String] = []
	for a in c.progress.equipped_arts:
		arts.append(a.display_name)
	var text := "%s  ·  level %d  ·  HP %d / %d\n%s (Mt %d, Hit %d, weight %d)\n%s grade %s\nArts: %s" % [
		c.display_name(), c.level(), c.hp, c.max_hp(), w.display_name, w.might, w.hit, w.weight,
		WeaponData.type_name(t), Proficiency.grade_name(c.progress.grade(t)), ", ".join(arts) if not arts.is_empty() else "none"]
	if not c.progress.known_spells.is_empty():
		var spells: Array[String] = []
		for sp in c.progress.known_spells:
			spells.append("%s %d/%d" % [sp.display_name, c.progress.uses_left(sp), sp.uses])
		for s in c.progress.spell_schools():
			text += "\n%s grade %s" % [SpellData.school_name(s), Proficiency.grade_name(c.progress.magic_grade(s))]
		text += "\nSpells: " + ", ".join(spells)
	return text


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	if companion == null:
		return
	var r := (R if _fielded else RESERVE_R) + (2.0 if _hover else 0.0)
	var c := Vector2(size.x * 0.5, R + 8.0)
	var dim := Color.WHITE if _fielded else Color(0.62, 0.6, 0.58)
	draw_circle(c + Vector2(0, 3), r + 5.0, Color(0, 0, 0, 0.5))
	draw_circle(c, r + 4.0, UiTheme.INK)
	UiIcons.portrait(self, c, r, companion.data.portrait, companion.data.portrait_focus + Vector2(0.0, 0.02),
		0.3 / companion.data.figure_scale, dim)
	# Health: an arc clockwise from the top, over a dark ring.
	var frac := clampf(float(companion.hp) / maxf(1.0, companion.max_hp()), 0.0, 1.0)
	draw_arc(c, r + 2.0, 0.0, TAU, 48, UiTheme.GOLD if _hover else UiTheme.GOLD_DEEP, 2.0, true)
	if frac < 0.999:
		var hp := UiTheme.HP if frac * 3.0 >= 1.0 else UiTheme.INJURED
		draw_arc(c, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU, 48, Color(0, 0, 0, 0.6), 4.0, true)
		draw_arc(c, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, hp, 4.0, true)
	var font := UiTheme.display_font()
	var ink := ActionButton.LIT_INK if _hover else (UiTheme.TEXT if _fielded else UiTheme.MUTED)
	UiTheme.draw_text(self, font, Vector2(-30.0, R * 2.0 + 18.0), companion.display_name(), 17 if _fielded else 15, ink, 4,
		size.x + 60.0, HORIZONTAL_ALIGNMENT_CENTER)
