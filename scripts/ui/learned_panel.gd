class_name LearnedPanel
extends Control
## Something learned, shown on its own after a battle or a drill: the companion stands at the left
## of a band of shadow (as for a level gained) and what they learned is set out beside them to be
## read at a glance: its name, what it costs in large figures (stamina or uses, and recovery: how many
## of their next actions they sit out), and what it does, one thing to a line.
## A combat art also shows the three they carry into battle. If there was room the new one is among
## them. If all three places were taken it has been left behind, and the commander can click a
## carried art to leave that one behind instead (and change their mind until they go on); pointing
## at a carried art writes that one out, to compare. A spell needs no place: every known spell can
## be cast.
## Changes go straight into the companion's CompanionProgress through equip() and unequip().

## The way on was pressed (only shown when there is something to decide).
signal finished

const SIZE := LevelUpPanel.SIZE
const X := 700.0
const W := 640.0
const SLOT_Y := 408.0
const SLOT_H := 46.0
## The figures under the name (see ArtFacts), and the room the lines under them have above the
## carried arts.
const FACTS_Y := 146.0
const LINES_ROOM := 126.0

var _progress: CompanionProgress
var _name := ""
var _art: CombatArtData
var _spell: SpellData
## The arts carried when the panel opened, and which of those places the new art has taken (-1: none).
var _carried: Array[CombatArtData] = []
var _taken := -1
var _choice := false
## The carried art under the pointer, written out in place of the new one.
var _pointed: CombatArtData

var _note: Label
var _slots: Array[Control] = []
var _go := Button.new()


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in BattleConfig.MAX_EQUIPPED_ARTS:
		var slot := _make_slot(i)
		slot.position = Vector2(X - 16.0, SLOT_Y + i * SLOT_H)
		add_child(slot)
		_slots.append(slot)
	_note = UiTheme.label("", 19, UiTheme.MUTED, false, 4)
	_note.add_theme_font_override("font", UiTheme.italic_font())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.position = Vector2(X, SLOT_Y + BattleConfig.MAX_EQUIPPED_ARTS * SLOT_H + 10.0)
	_note.size = Vector2(W - 190.0, 56.0)
	add_child(_note)
	_go.text = "Go on"
	_go.focus_mode = Control.FOCUS_NONE
	_go.add_theme_font_size_override("font_size", 26)
	_go.position = Vector2(X + W - 170.0, SLOT_Y + BattleConfig.MAX_EQUIPPED_ARTS * SLOT_H + 8.0)
	_go.size = Vector2(170, 48)
	_go.pressed.connect(func() -> void: finished.emit())
	add_child(_go)


## Shows a combat art `progress` has just learned. `equipped`: it found a free place.
func show_art(progress: CompanionProgress, display_name: String, art: CombatArtData, equipped: bool) -> void:
	_progress = progress
	_name = display_name
	_art = art
	_spell = null
	_pointed = null
	_carried = progress.equipped_arts.duplicate()
	_choice = not equipped and not progress.is_equipped(art) and not progress.has_free_slot()
	_taken = -1
	_refresh()


## Shows a spell `progress` has just learned.
func show_spell(progress: CompanionProgress, display_name: String, spell: SpellData) -> void:
	_progress = progress
	_name = display_name
	_art = null
	_spell = spell
	_pointed = null
	_carried.clear()
	_choice = false
	_taken = -1
	_refresh()


## True while the panel has its own way on (something can be decided here), so a click elsewhere
## should not move past it.
func needs_choice() -> bool:
	return _choice


## Leaves the carried art in place `index` behind and carries the new one there; the same place
## again (or -1) puts everything back as it was.
func take_place(index: int) -> void:
	if not _choice:
		return
	_taken = -1 if index == _taken else index
	# Put down everything, then pick up what is wanted, in the old order.
	for a: CombatArtData in _progress.equipped_arts.duplicate():
		_progress.unequip(a)
	for i in _carried.size():
		_progress.equip(_art if i == _taken else _carried[i])
	_refresh()


func _refresh() -> void:
	var arts := _art != null
	for slot in _slots:
		slot.visible = arts
		slot.queue_redraw()
	_go.visible = _choice
	if not arts:
		_note.text = "Every known spell can be cast. Uses come back with a rest at the inn."
		_note.position.y = SLOT_Y + 40.0
	else:
		_note.position.y = SLOT_Y + BattleConfig.MAX_EQUIPPED_ARTS * SLOT_H + 6.0
		if not _choice:
			_note.text = "There was room: it is carried into battle."
		elif _taken < 0:
			_note.text = "No free place: it is left behind. Click an art to leave that one behind instead."
		else:
			_note.text = "%s is left behind. Click again to put it back." % _carried[_taken].display_name
	queue_redraw()


## One of the three places: what is carried there.
func _make_slot(index: int) -> Control:
	var slot := Control.new()
	slot.size = Vector2(W + 16.0, SLOT_H - 4.0)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var state := {"hover": false}
	slot.mouse_entered.connect(func() -> void:
		state.hover = true
		var a := _art_in(index)
		_pointed = a if a != _art else null
		_refresh())
	slot.mouse_exited.connect(func() -> void:
		state.hover = false
		_pointed = null
		_refresh())
	slot.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _choice and index < _carried.size():
			slot.accept_event()
			take_place(index))
	slot.draw.connect(func() -> void:
		var a := _art_in(index)
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		var h := slot.size.y
		var is_new := a != null and a == _art
		var lit: bool = state.hover and (_choice or a != null)
		if is_new or lit:
			var tone := UiTheme.GOLD if is_new else Color(1, 1, 1)
			var clear := Color(tone, 0.0)
			slot.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(slot.size.x, 0), Vector2(slot.size.x, h), Vector2(0, h)]),
				PackedColorArray([Color(tone, 0.2 if is_new else 0.1), clear, clear, Color(tone, 0.2 if is_new else 0.1)]))
			slot.draw_rect(Rect2(0, 0, 3, h), Color(tone, 0.9 if is_new else 0.5))
		slot.draw_line(Vector2(0, h + 1.0), Vector2(slot.size.x, h + 1.0), Color(UiTheme.GOLD, 0.14), 1.0)
		var c := Vector2(26.0, h * 0.5)
		var ink := UiTheme.GOLD if is_new else (ActionButton.LIT_INK if lit else UiTheme.TEXT)
		if a == null:
			UiIcons.diamond(slot, c, 6.0, Color(UiTheme.MUTED, 0.5))
			UiTheme.draw_text(slot, italic, Vector2(48.0, h * 0.5 - 13.0), "an empty place", 20, Color(UiTheme.MUTED, 0.7), 4)
			return
		UiIcons.diamond(slot, c, 7.0, ink)
		UiTheme.draw_text(slot, display, Vector2(48.0, h * 0.5 - 16.0), a.display_name, 25, ink, 4)
		var right := ""
		if is_new:
			right = "new"
		elif _choice and state.hover:
			right = "leave this one behind"
		else:
			right = "tier %s  ·  %d stamina" % [CombatArtData.tier_numeral(a.tier), a.stamina_cost]
		UiTheme.draw_text(slot, italic, Vector2(0, h * 0.5 - 12.0), right, 18, UiTheme.GOLD if is_new or (_choice and state.hover) else UiTheme.MUTED,
			4, slot.size.x - 12.0, HORIZONTAL_ALIGNMENT_RIGHT))
	return slot


## The art carried in place `index` as things stand now, or null.
func _art_in(index: int) -> CombatArtData:
	if _progress == null or _art == null:
		return null
	if _choice:
		if index >= _carried.size():
			return null
		return _art if index == _taken else _carried[index]
	return _progress.equipped_arts[index] if index < _progress.equipped_arts.size() else null


func _draw() -> void:
	if _progress == null:
		return
	# The same band of shadow as a level gained.
	var x0 := -2400.0
	var x1 := SIZE.x + 2400.0
	var dark := Color(LevelUpPanel.BAND, 0.95)
	var clear := Color(LevelUpPanel.BAND, 0.0)
	var soft := 70.0
	draw_polygon(PackedVector2Array([Vector2(x0, -soft), Vector2(x1, -soft), Vector2(x1, 0), Vector2(x0, 0)]),
		PackedColorArray([clear, clear, dark, dark]))
	draw_rect(Rect2(x0, 0, x1 - x0, SIZE.y), dark)
	draw_polygon(PackedVector2Array([Vector2(x0, SIZE.y), Vector2(x1, SIZE.y), Vector2(x1, SIZE.y + soft), Vector2(x0, SIZE.y + soft)]),
		PackedColorArray([dark, dark, clear, clear]))
	var school_ink := UiTheme.school_color(_spell.school) if _spell != null else UiTheme.GOLD
	UiTheme.draw_rule(self, Vector2(SIZE.x * 0.5, 0.0), SIZE.x + 300.0, Color(school_ink, 0.55))
	UiTheme.draw_rule(self, Vector2(SIZE.x * 0.5, SIZE.y), SIZE.x + 300.0, Color(school_ink, 0.55))
	_draw_figure()

	var display := UiTheme.display_font()
	var p := _progress
	var title := ""
	var kicker := ""
	var tag := ""
	var figures: Array = []
	var lines: Array[String] = []
	if _art != null:
		var a := _pointed if _pointed != null else _art
		kicker = "%s LEARNS A COMBAT ART" % _name.to_upper() if _pointed == null else "CARRIED NOW"
		title = a.display_name
		tag = ArtFacts.art_tag(a)
		figures = ArtFacts.art_figures(a)
		lines = ArtFacts.art_lines(a, p.weapon.weapon_type if p.weapon != null else -1)
		UiTheme.draw_text(self, display, Vector2(X, SLOT_Y - 28.0), "CARRIED INTO BATTLE", 17, UiTheme.MUTED, 4)
	else:
		kicker = "%s LEARNS A SPELL" % _name.to_upper()
		title = _spell.display_name
		tag = ArtFacts.spell_tag(_spell)
		figures = ArtFacts.spell_figures(_spell)
		lines = ArtFacts.spell_lines(_spell)
	UiTheme.draw_text(self, display, Vector2(X, 30.0), kicker, 24, school_ink if _pointed == null else UiTheme.MUTED, 4)
	UiTheme.draw_text(self, display, Vector2(X, 34.0), tag, 19, UiTheme.MUTED, 4, W, HORIZONTAL_ALIGNMENT_RIGHT)
	var title_size := 68
	while title_size > 40 and display.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > W:
		title_size -= 2
	UiTheme.draw_text(self, display, Vector2(X - 3.0, 58.0 + (68 - title_size) * 0.5), title.to_upper(), title_size, UiTheme.TEXT, 8)
	ArtFacts.draw(self, Vector2(X, FACTS_Y), W, figures, lines, school_ink, UiTheme.TEXT, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), 1.0,
		LINES_ROOM if _art != null else 0.0)


## The cut-out, standing at the left with their feet below the band (as on the level-up panel).
func _draw_figure() -> void:
	var data := _progress.data
	var tex := data.portrait
	if tex == null:
		return
	var face := LevelUpPanel.FACE
	for i in 18:
		var f := 1.0 - i / 18.0
		var pts := PackedVector2Array()
		for k in 32:
			pts.append(Vector2(face.x, SIZE.y * 0.55) + Vector2.from_angle(TAU * k / 32.0) * Vector2(330.0, 300.0) * f)
		draw_colored_polygon(pts, Color(UiTheme.GOLD, 0.011))
	var ts := tex.get_size()
	var h := LevelUpPanel.ART * data.figure_scale
	var art := Vector2(h * ts.x / maxf(1.0, ts.y), h)
	var top_left := face - data.portrait_focus * art
	var shown := clampf((SIZE.y - top_left.y) / art.y, 0.0, 1.0)
	draw_texture_rect_region(tex, Rect2(top_left, Vector2(art.x, art.y * shown)), Rect2(0, 0, ts.x, ts.y * shown))
	var dark := Color(LevelUpPanel.BAND, 0.92)
	var clear := Color(LevelUpPanel.BAND, 0.0)
	var x0 := X - 190.0
	var x1 := X - 30.0
	draw_polygon(PackedVector2Array([Vector2(x0, 1), Vector2(x1, 1), Vector2(x1, SIZE.y - 1.0), Vector2(x0, SIZE.y - 1.0)]),
		PackedColorArray([clear, dark, dark, clear]))
	draw_rect(Rect2(x1, 1, top_left.x + art.x - x1, SIZE.y - 2.0), dark)
