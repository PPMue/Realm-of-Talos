class_name CallingPanel
extends Control
## The moment a companion takes their calling (design/callings.md), over whatever is behind it, on the
## same band of shadow as a level gained. Three faces, one companion at a time:
##
## 1. The choice: the companion stands at the left beside the callings drawn for them, each a card
##    (CallingCard). One is clicked and "Become a ..." pressed. A calling someone else holds is shown
##    dimmed with their name and cannot be picked.
## 2. For a calling of magic, the spell: the two tier I spells drawn for them written out side by side
##    (a Sage first picks the school from two plates over them); one is clicked and learned.
## 3. What it gave: the stats come up one at a time as for a level (LevelUpPanel.show_gains).
##
## The same panel puts the mastery at RunConfig.MASTERY_LEVEL (design/callings.md, step 2): the holder
## beside their calling's rule and its two masteries, each a card with a name and one line; one is
## clicked and taken. Callings come first, then masteries, so a hire who joins above both chooses both.
##
## It cannot be put off: nothing but the choice moves it on, and it only closes (`finished`) when
## everyone due has chosen. The run is changed through Run.take_calling and Run.take_mastery alone.

signal finished

enum Stage { CHOOSE, SPELL, GAINS, MASTERY }

const SIZE := LevelUpPanel.SIZE
## Where the cards begin, right of the figure.
const X := 540.0
const CARD_Y := 104.0
const CARD_GAP := 16.0
const CARD_W := (SIZE.x - X - CARD_GAP * 2.0) / 3.0
const CARD_H := 430.0
const FOOT_Y := SIZE.y - 70.0
const SPELL_Y := 170.0
const SPELL_W := (SIZE.x - X - CARD_GAP) / 2.0
const SPELL_H := FOOT_Y - SPELL_Y - 14.0
## The two mastery cards, under the calling's own rule.
const MASTERY_Y := 196.0
const MASTERY_H := 300.0

var run: Run
var _queue: Array[RunCompanion] = []
var _who: RunCompanion
var _stage := Stage.CHOOSE
## The cards shown (the open ones first), the one picked, and for a calling of magic the school and spell.
var _shown: Array[CallingData] = []
var _picked: CallingData
var _school := -1
var _spell: SpellData
var _spells: Array[SpellData] = []
## The mastery picked (Stage.MASTERY).
var _mastery: MasteryData

var _dim := ColorRect.new()
var _band := Control.new()
var _cards: Array[Control] = []
var _spell_cards: Array[Control] = []
var _tabs: Array[Control] = []
var _mastery_cards: Array[Control] = []
var _gains := LevelUpPanel.new()
var _take := Button.new()
var _back := Button.new()
var _hint: Label
var _hover := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_dim.color = Color(UiTheme.INK, 0.86)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_band.size = SIZE
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.draw.connect(_draw_band)
	add_child(_band)
	for i in 3:
		var card := _plate(Vector2(X + i * (CARD_W + CARD_GAP), CARD_Y), Vector2(CARD_W, CARD_H), "card%d" % i,
			pick_card.bind(i), _draw_card.bind(i))
		_cards.append(card)
	for i in 2:
		var tab := _plate(Vector2(X + i * (SPELL_W + CARD_GAP), CARD_Y), Vector2(SPELL_W, 52.0), "tab%d" % i,
			pick_school.bind(i), _draw_tab.bind(i))
		_tabs.append(tab)
		var card := _plate(Vector2(X + i * (SPELL_W + CARD_GAP), SPELL_Y), Vector2(SPELL_W, SPELL_H), "spell%d" % i,
			pick_spell.bind(i), _draw_spell.bind(i))
		_spell_cards.append(card)
		var mastery_card := _plate(Vector2(X + i * (SPELL_W + CARD_GAP), MASTERY_Y), Vector2(SPELL_W, MASTERY_H), "mastery%d" % i,
			pick_mastery.bind(i), _draw_mastery.bind(i))
		_mastery_cards.append(mastery_card)
	_gains.visible = false
	_gains.finished.connect(func() -> void: _hint.visible = true)
	add_child(_gains)
	for b: Button in [_take, _back]:
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		_band.add_child(b)
	_take.size = Vector2(360, 50)
	_take.position = Vector2(SIZE.x - 360.0, FOOT_Y + 8.0)
	_take.pressed.connect(confirm)
	_back.text = "Another calling"
	_back.size = Vector2(240, 50)
	_back.position = Vector2(X, FOOT_Y + 8.0)
	_back.pressed.connect(back)
	_hint = UiTheme.label("Click to go on", 22, UiTheme.MUTED, false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(600, 32)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var at := Vector2((size.x - SIZE.x) * 0.5, (size.y - SIZE.y) * 0.5)
	_band.position = at
	_gains.position = at
	_hint.position = Vector2((size.x - 600.0) * 0.5, at.y + SIZE.y + 84.0)


func is_open() -> bool:
	return visible


## Opens on everyone in `p_run` whose calling or mastery is due (Run.callings_due, masteries_due), one
## after another. Returns false, and stays shut, when nobody's is.
func open(p_run: Run) -> bool:
	run = p_run
	if run.callings_due().is_empty() and run.masteries_due().is_empty():
		return false
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_layout()
	_next()
	return true


## The companion choosing now, the stage, and what is picked (for the screen checks).
func who() -> RunCompanion:
	return _who


func stage() -> int:
	return _stage


# ---------------------------------------------------------------- the steps

func _next() -> void:
	# Someone's choice may have closed a calling another was waiting on: ask the run again each time.
	_queue = run.callings_due()
	_mastery = null
	if _queue.is_empty():
		_queue = run.masteries_due()
		if _queue.is_empty():
			visible = false
			finished.emit()
			return
		_who = _queue[0]
		_picked = _who.progress.calling
		_shown.clear()
		_show(Stage.MASTERY)
		return
	_who = _queue[0]
	_picked = null
	_school = -1
	_spell = null
	_shown.clear()
	var open_ones := run.open_callings(_who)
	_shown.append_array(open_ones.slice(0, 3))
	for calling in _who.progress.calling_offers:
		if _shown.size() < 3 and not _shown.has(calling):
			_shown.append(calling)
	_show(Stage.CHOOSE)


func _show(s: Stage) -> void:
	_stage = s
	_gains.visible = s == Stage.GAINS
	_band.visible = s != Stage.GAINS
	_hint.visible = false
	for i in _cards.size():
		_cards[i].visible = s == Stage.CHOOSE and i < _shown.size()
	var either := _picked != null and _picked.either_school
	for i in 2:
		_tabs[i].visible = s == Stage.SPELL and either
		_spell_cards[i].visible = s == Stage.SPELL and i < _spells.size()
		_mastery_cards[i].visible = s == Stage.MASTERY and _picked != null and i < _picked.masteries.size()
	_back.visible = s == Stage.SPELL
	_take.visible = s != Stage.GAINS
	_refresh()


func _refresh() -> void:
	match _stage:
		Stage.CHOOSE:
			_take.text = "Become a %s" % _picked.display_name if _picked != null else "Choose one"
			_take.disabled = _picked == null
		Stage.SPELL:
			_take.text = "Learn %s" % _spell.display_name if _spell != null else ("Choose a spell" if not _spells.is_empty() else "Go on")
			_take.disabled = _spell == null and not _spells.is_empty()
		Stage.MASTERY:
			_take.text = "Take %s" % _mastery.display_name if _mastery != null else "Choose one"
			_take.disabled = _mastery == null
	_band.queue_redraw()
	for c: Control in _cards + _spell_cards + _tabs + _mastery_cards:
		c.queue_redraw()


## Picks the calling on card `index` (an open one only).
func pick_card(index: int) -> void:
	if _stage != Stage.CHOOSE or index >= _shown.size() or not run.is_calling_open(_shown[index]):
		return
	_picked = _shown[index]
	_refresh()


## A Sage's school: 0 Black Magic, 1 White Magic.
func pick_school(index: int) -> void:
	if _stage != Stage.SPELL or _picked == null or not _picked.either_school:
		return
	_school = _picked.schools()[index]
	_spell = null
	_spells = run.calling_spell_choices(_who, _picked, _school)
	_show(Stage.SPELL)


func pick_spell(index: int) -> void:
	if _stage != Stage.SPELL or index >= _spells.size():
		return
	_spell = _spells[index]
	_refresh()


## Picks the mastery on card `index` (0 or 1).
func pick_mastery(index: int) -> void:
	if _stage != Stage.MASTERY or _picked == null or index >= _picked.masteries.size():
		return
	_mastery = _picked.masteries[index]
	_refresh()


## Back from the spell to the three callings.
func back() -> void:
	if _stage == Stage.SPELL:
		_spell = null
		_show(Stage.CHOOSE)


## The way on: from the calling picked to its spell (a calling of magic), or to taking it.
func confirm() -> void:
	if _stage == Stage.MASTERY:
		if _mastery != null and run.take_mastery(_who, _mastery):
			_next()
		return
	if _picked == null:
		return
	if _stage == Stage.CHOOSE and _picked.is_magic():
		var p := _who.progress
		_school = _picked.school
		if _picked.either_school:
			_school = SpellData.School.WHITE if p.magic_points_in(SpellData.School.WHITE) > p.magic_points_in(SpellData.School.BLACK) \
				else SpellData.School.BLACK
		_spell = null
		_spells = run.calling_spell_choices(_who, _picked, _school)
		if _spells.is_empty() and not _picked.either_school:
			_commit()   # nothing to choose: every tier I spell of it is known
		else:
			_show(Stage.SPELL)
		return
	if _stage == Stage.SPELL and _spell == null and not _spells.is_empty():
		return
	_commit()


func _commit() -> void:
	var got := run.take_calling(_who, _picked, _school, _spell)
	if got.is_empty():
		return
	var parts: Array[String] = [_picked.display_name.to_upper()]
	if int(got.school) >= 0:
		var grade := Proficiency.grade_name(int(got.grade_to))
		parts.append("%s %s" % [SpellData.school_name(int(got.school)), grade])
		if got.spell != null:
			parts.append((got.spell as SpellData).display_name)
	elif int(got.weapon_type) >= 0 and int(got.grade_to) > int(got.grade_from):
		parts.append("%s %s" % [WeaponData.type_name(int(got.weapon_type)), Proficiency.grade_name(int(got.grade_to))])
	_show(Stage.GAINS)
	_gains.modulate.a = 0.0
	create_tween().tween_property(_gains, "modulate:a", 1.0, 0.12)
	_gains.show_gains(_who.data, _who.display_name(), "A CALLING", "  ·  ".join(parts), got.before, got.gains)


## A click, Space or Enter: past the gains once they are shown (first ending the reveal), and on the
## choice the same as the button.
func advance() -> void:
	match _stage:
		Stage.GAINS:
			if not _gains.is_done():
				_gains.skip()
			else:
				_next()
		_:
			if not _take.disabled:
				confirm()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _stage == Stage.GAINS:
			advance()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()   # nothing behind it hears a key while a calling waits
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			advance()
		KEY_1, KEY_2, KEY_3:
			var i := key.keycode - KEY_1
			if _stage == Stage.CHOOSE:
				pick_card(i)
			elif _stage == Stage.SPELL and i < 2:
				pick_spell(i)
			elif _stage == Stage.MASTERY and i < 2:
				pick_mastery(i)
		KEY_ESCAPE, KEY_BACKSPACE:
			back()


# ---------------------------------------------------------------- drawing

## A clickable plate on the band: `on_click` when pressed, `on_draw` to draw it; its hover is kept in
## `_hover` under `key`.
func _plate(at: Vector2, plate_size: Vector2, key: String, on_click: Callable, on_draw: Callable) -> Control:
	var c := Control.new()
	c.position = at
	c.size = plate_size
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.mouse_entered.connect(func() -> void:
		_hover[key] = true
		c.queue_redraw())
	c.mouse_exited.connect(func() -> void:
		_hover[key] = false
		c.queue_redraw())
	c.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			c.accept_event()
			on_click.call())
	c.draw.connect(func() -> void: on_draw.call(c))
	_band.add_child(c)
	return c


func _draw_card(card: Control, index: int) -> void:
	if _who == null or index >= _shown.size():
		return
	var calling := _shown[index]
	var holder := run.calling_holder(calling)
	var state := CallingCard.State.OPEN
	if holder != null:
		state = CallingCard.State.CLOSED
	elif calling == _picked:
		state = CallingCard.State.PICKED
	CallingCard.draw(card, Rect2(Vector2.ZERO, card.size), calling, _who.progress, state, bool(_hover.get("card%d" % index, false)),
		holder.display_name() if holder != null else "")


func _draw_tab(tab: Control, index: int) -> void:
	if _picked == null or not _picked.either_school:
		return
	var school: int = _picked.schools()[index]
	var on := school == _school
	var hover := bool(_hover.get("tab%d" % index, false))
	var tone := UiTheme.school_color(school)
	tab.draw_rect(Rect2(Vector2.ZERO, tab.size), Color(tone, 0.2 if on else (0.1 if hover else 0.04)))
	tab.draw_rect(Rect2(0.5, 0.5, tab.size.x - 1.0, tab.size.y - 1.0), Color(tone, 0.95 if on else 0.35), false, 2.0 if on else 1.0)
	var display := UiTheme.display_font()
	var w := UiIcons.proficiency(tab, Vector2(18.0, 12.0), -1, school, "", 22, tone, tone, 4)
	UiTheme.draw_text(tab, display, Vector2(26.0 + w, 11.0), SpellData.school_name(school).to_upper(), 24,
		UiTheme.TEXT if on else UiTheme.MUTED, 4)


func _draw_spell(card: Control, index: int) -> void:
	if _who == null or index >= _spells.size():
		return
	var sp := _spells[index]
	var on := sp == _spell
	var hover := bool(_hover.get("spell%d" % index, false))
	var tone := UiTheme.school_color(sp.school)
	var display := UiTheme.display_font()
	card.draw_rect(Rect2(Vector2.ZERO, card.size), Color(tone, 0.16 if on else (0.09 if hover else 0.05)))
	card.draw_rect(Rect2(0.5, 0.5, card.size.x - 1.0, card.size.y - 1.0), Color(tone, 0.95 if on else (0.6 if hover else 0.3)), false,
		2.0 if on or hover else 1.0)
	var pad := 20.0
	var inner := card.size.x - pad * 2.0
	UiTheme.draw_text(card, display, Vector2(pad, 12.0), "CHOSEN" if on else "A SPELL", 16, tone if on else UiTheme.MUTED, 4)
	ArtFacts.draw_tag(card, Vector2(pad, 12.0), -1, sp.school, sp.tier, 15, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), 4, card.size.x - pad)
	var name_size := 36
	while name_size > 22 and display.get_string_size(sp.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > inner:
		name_size -= 1
	UiTheme.draw_text(card, display, Vector2(pad, 36.0), sp.display_name.to_upper(), name_size, UiTheme.TEXT, 6)
	ArtFacts.draw(card, Vector2(pad, 88.0), inner, ArtFacts.spell_figures(sp, -1, _who.progress.max_uses(sp)), ArtFacts.spell_lines(sp),
		tone, UiTheme.TEXT, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), 0.7, card.size.y - 88.0 - 80.0, 4, "", Color.WHITE, 21)


func _draw_mastery(card: Control, index: int) -> void:
	if _who == null or _picked == null or index >= _picked.masteries.size():
		return
	var m := _picked.masteries[index]
	var on := m == _mastery
	var hover := bool(_hover.get("mastery%d" % index, false))
	var tone := UiTheme.GOLD
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	card.draw_rect(Rect2(Vector2.ZERO, card.size), Color(tone, 0.16 if on else (0.11 if hover else 0.06)))
	card.draw_rect(Rect2(0.5, 0.5, card.size.x - 1.0, card.size.y - 1.0), Color(tone, 0.95 if on else (0.6 if hover else 0.3)), false,
		2.0 if on or hover else 1.0)
	var pad := 22.0
	var inner := card.size.x - pad * 2.0
	UiTheme.draw_text(card, display, Vector2(pad, 14.0), "CHOSEN" if on else "A MASTERY", 16, tone if on else UiTheme.MUTED, 4)
	var name_size := 40
	while name_size > 22 and display.get_string_size(m.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > inner:
		name_size -= 1
	UiTheme.draw_text(card, display, Vector2(pad, 40.0), m.display_name.to_upper(), name_size, UiTheme.TEXT, 6)
	var y := 40.0 + display.get_height(name_size) + 14.0
	card.draw_line(Vector2(pad, y), Vector2(pad + inner, y), Color(tone, 0.3), 1.0)
	y += 14.0
	for row in CallingCard.wrap_text(italic, m.rule, 27, inner):
		UiTheme.draw_text(card, italic, Vector2(pad, y), row, 27, UiTheme.TEXT, 4)
		y += italic.get_height(27)


func _draw_band() -> void:
	if _who == null:
		return
	# The same band of shadow as a level gained.
	var x0 := -2400.0
	var x1 := SIZE.x + 2400.0
	var dark := Color(LevelUpPanel.BAND, 0.95)
	var clear := Color(LevelUpPanel.BAND, 0.0)
	var soft := 70.0
	_band.draw_polygon(PackedVector2Array([Vector2(x0, -soft), Vector2(x1, -soft), Vector2(x1, 0), Vector2(x0, 0)]),
		PackedColorArray([clear, clear, dark, dark]))
	_band.draw_rect(Rect2(x0, 0, x1 - x0, SIZE.y), dark)
	_band.draw_polygon(PackedVector2Array([Vector2(x0, SIZE.y), Vector2(x1, SIZE.y), Vector2(x1, SIZE.y + soft), Vector2(x0, SIZE.y + soft)]),
		PackedColorArray([dark, dark, clear, clear]))
	UiTheme.draw_rule(_band, Vector2(SIZE.x * 0.5, 0.0), SIZE.x + 300.0, Color(UiTheme.GOLD, 0.55))
	UiTheme.draw_rule(_band, Vector2(SIZE.x * 0.5, SIZE.y), SIZE.x + 300.0, Color(UiTheme.GOLD, 0.55))
	LevelUpPanel.draw_figure(_band, _who.data, X)
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var who_name := _who.display_name().to_upper()
	if _stage == Stage.CHOOSE:
		UiTheme.draw_text(_band, display, Vector2(X, 18.0), "LEVEL %d" % _who.level(), 22, UiTheme.GOLD, 4)
		UiTheme.draw_text(_band, display, Vector2(X - 2.0, 42.0), "%s TAKES A CALLING" % who_name, 46, UiTheme.TEXT, 8)
		if _picked == null:
			UiTheme.draw_text(_band, italic, Vector2(X, FOOT_Y + 18.0), "For the rest of the run. Nobody else can take the same one.", 21,
				UiTheme.MUTED, 4)
	elif _stage == Stage.SPELL and _picked != null:
		UiTheme.draw_text(_band, display, Vector2(X, 18.0), "%s, %s" % [who_name, _picked.display_name.to_upper()], 22, UiTheme.GOLD, 4)
		var ask := "WHICH SCHOOL, AND WHICH SPELL?" if _picked.either_school else "WHICH SPELL TO BEGIN WITH?"
		if _spells.is_empty():
			ask = "WHICH SCHOOL?"
		UiTheme.draw_text(_band, display, Vector2(X - 2.0, 42.0), ask, 46, UiTheme.TEXT, 8)
		if not _picked.either_school:
			var tone := UiTheme.school_color(_school)
			var w := UiIcons.proficiency(_band, Vector2(X, CARD_Y + 14.0), -1, _school, "", 22, tone, tone, 4)
			UiTheme.draw_text(_band, display, Vector2(X + w + 10.0, CARD_Y + 13.0),
				"%s OPENS AT %s" % [SpellData.school_name(_school).to_upper(), Proficiency.grade_name(RunConfig.CALLING_OPEN_GRADE)], 24,
				UiTheme.TEXT, 4)
		if _spells.is_empty():
			UiTheme.draw_text(_band, italic, Vector2(X, SPELL_Y + 20.0), "Every first spell of this school is already known.", 24, UiTheme.MUTED, 4)
	elif _stage == Stage.MASTERY and _picked != null:
		UiTheme.draw_text(_band, display, Vector2(X, 18.0), "LEVEL %d  ·  %s, %s" % [_who.level(), who_name, _picked.display_name.to_upper()], 22,
			UiTheme.GOLD, 4)
		UiTheme.draw_text(_band, display, Vector2(X - 2.0, 42.0), "WHICH MASTERY?", 46, UiTheme.TEXT, 8)
		# The calling's own rule stands over the two: each mastery is one more line on it.
		var y := CARD_Y + 8.0
		for row in CallingCard.wrap_text(italic, _picked.rule, 25, SIZE.x - X):
			UiTheme.draw_text(_band, italic, Vector2(X, y), row, 25, Color(UiTheme.TEXT, 0.85), 4)
			y += italic.get_height(25)
		if _mastery == null:
			UiTheme.draw_text(_band, italic, Vector2(X, FOOT_Y + 18.0), "For the rest of the run. The other is closed for good.", 21, UiTheme.MUTED, 4)
