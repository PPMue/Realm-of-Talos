class_name LearnedPanel
extends Control
## Something learned, shown on its own after a battle or a drill, on a band of shadow (as for a
## level gained). It has two faces.
##
## Alone: a spell, or a combat art that found a free place among the three carried into battle (the
## rules put it there). The companion stands at the left and only the new thing is set out beside
## them, to be read at a glance: its name, what it costs in large figures (stamina or uses, and
## recovery: how many of their next actions they sit out), and what it does, one thing to a line.
##
## Compared: a combat art learned when all three places were taken. It has been left behind, and
## the commander decides: the new art's card stands beside the cards of the three carried, each
## written out the same way so they can be read against one another. Clicking a carried art leaves
## that one behind and carries the new one in its place; clicking it again (or the new art) puts
## things back. Nothing else moves the panel on until "Go on" is pressed.
## Changes go straight into the companion's CompanionProgress through equip() and unequip().

## The way on was pressed (only shown when there is something to decide).
signal finished

const SIZE := LevelUpPanel.SIZE
const X := 700.0
const W := 640.0
## The figures under the name (see ArtFacts).
const FACTS_Y := 146.0
## The foot of the panel: a line saying where the new thing went, or the way on.
const FOOT_Y := SIZE.y - 74.0
## Compared: the four cards.
const CARD_Y := 96.0
const CARD_W := 326.0
const CARD_H := FOOT_Y - CARD_Y - 18.0
const CARD_GAP := 22.0
## The new art's card stands a little apart from the three it is weighed against.
const CARD_APART := 30.0

var _progress: CompanionProgress
var _name := ""
var _art: CombatArtData
var _spell: SpellData
## The arts carried when the panel opened, and which of those places the new art has taken (-1: none).
var _carried: Array[CombatArtData] = []
var _taken := -1
var _choice := false

var _note: Label
## Compared: card 0 is the new art, cards 1 to 3 the places carried.
var _cards: Array[Control] = []
var _go := Button.new()


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in BattleConfig.MAX_EQUIPPED_ARTS + 1:
		var card := _make_card(i)
		card.position = Vector2(i * (CARD_W + CARD_GAP) + (CARD_APART if i > 0 else 0.0), CARD_Y)
		add_child(card)
		_cards.append(card)
	_note = UiTheme.label("", 19, UiTheme.MUTED, false, 4)
	_note.add_theme_font_override("font", UiTheme.italic_font())
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_note)
	_go.text = "Go on"
	_go.focus_mode = Control.FOCUS_NONE
	_go.add_theme_font_size_override("font_size", 26)
	_go.position = Vector2(SIZE.x - 170.0, FOOT_Y + 8.0)
	_go.size = Vector2(170, 48)
	_go.pressed.connect(func() -> void: finished.emit())
	add_child(_go)


## Shows a combat art `progress` has just learned. `equipped`: it found a free place.
func show_art(progress: CompanionProgress, display_name: String, art: CombatArtData, equipped: bool) -> void:
	_progress = progress
	_name = display_name
	_art = art
	_spell = null
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
	for card in _cards:
		card.visible = _choice
		card.queue_redraw()
	_go.visible = _choice
	if _choice:
		_note.position = Vector2(0.0, FOOT_Y)
		_note.size = Vector2(SIZE.x - 200.0, 64.0)
		if _taken < 0:
			_note.text = "All three places are taken, so %s is left behind. Click a carried art to leave that one behind instead." % _art.display_name
		else:
			_note.text = "%s takes the place of %s. Click it again to put things back." % [_art.display_name, _carried[_taken].display_name]
	else:
		_note.position = Vector2(X + 26.0, FOOT_Y)
		_note.size = Vector2(W - 26.0, 64.0)
		if _spell != null:
			_note.text = "Every known spell can be cast. Uses come back with a rest at the inn."
		elif _progress != null and _progress.is_equipped(_art):
			_note.text = "Carried into battle: place %d of %d." % [_progress.equipped_arts.find(_art) + 1, BattleConfig.MAX_EQUIPPED_ARTS]
		else:
			_note.text = "Known, and left behind for now."
	queue_redraw()


## One of the four cards of the comparison. `index` 0: the new art; 1 to 3: the places carried.
func _make_card(index: int) -> Control:
	var card := Control.new()
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := {"hover": false}
	card.mouse_entered.connect(func() -> void:
		state.hover = true
		card.queue_redraw())
	card.mouse_exited.connect(func() -> void:
		state.hover = false
		card.queue_redraw())
	card.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _choice:
			card.accept_event()
			if index == 0:
				# The new art itself: back to leaving it behind.
				if _taken >= 0:
					take_place(_taken)
			elif index - 1 < _carried.size():
				take_place(index - 1))
	card.draw.connect(func() -> void: _draw_card(card, index, state.hover))
	return card


## A card: whether it is carried, the art's name and kind, its figures, and what it does.
func _draw_card(card: Control, index: int, hover: bool) -> void:
	if _progress == null or _art == null:
		return
	var is_new := index == 0
	var art: CombatArtData = _art if is_new else (_carried[index - 1] if index - 1 < _carried.size() else null)
	if art == null:
		return
	# Whether this art goes into battle as things stand.
	var carried := (_taken >= 0) if is_new else (index - 1 != _taken)
	# Clicking does something on a carried art, and on the new one once it has taken a place.
	var lit := hover and (not is_new or _taken >= 0)
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var w := card.size.x
	var h := card.size.y
	var tone := UiTheme.GOLD if is_new else Color(0.86, 0.82, 0.74)
	var a := 1.0 if carried or is_new else 0.42
	card.draw_rect(Rect2(Vector2.ZERO, card.size), Color(tone, (0.11 if is_new else 0.05) + (0.05 if lit else 0.0)))
	card.draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0),
		Color(tone, minf(1.0, (0.75 if is_new else 0.28) * (1.0 if carried or is_new else 0.6) + (0.3 if lit else 0.0))), false,
		2.0 if is_new or lit else 1.0)
	var pad := 18.0
	var inner := w - pad * 2.0
	# The head of the card: what it is, and where it stands.
	var head := "NEW" if is_new else "CARRIED  ·  PLACE %d" % index
	UiTheme.draw_text(card, display, Vector2(pad, 12.0), head, 16, Color(tone if is_new else UiTheme.MUTED, a), 4)
	var name_size := 34
	while name_size > 22 and display.get_string_size(art.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > inner:
		name_size -= 1
	UiTheme.draw_text(card, display, Vector2(pad, 36.0), art.display_name, name_size, Color(UiTheme.TEXT, a), 6)
	ArtFacts.draw_tag(card, Vector2(pad, 79.0), art.weapon_type, -1, art.tier, 15, Color(UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), a), 4)
	var held := _progress.weapon.weapon_type if _progress.weapon != null else -1
	ArtFacts.draw(card, Vector2(pad, 106.0), inner, ArtFacts.art_figures(art, _progress.art_cost(art)), ArtFacts.art_lines(art, held),
		Color(tone if is_new else UiTheme.GOLD, a), Color(UiTheme.TEXT, a), Color(UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), a), 0.6,
		h - 106.0 - 110.0, 4, "", Color.WHITE, 20)
	# The foot: what happens to it, or what a click would do.
	var foot := "carried"
	var foot_ink := UiTheme.MUTED
	if is_new:
		foot = "left behind" if _taken < 0 else "carried in place %d" % (_taken + 1)
		foot_ink = UiTheme.MUTED if _taken < 0 else UiTheme.GOLD
		if lit:
			foot = "click to leave it behind after all"
	elif not carried:
		foot = "left behind" if not lit else "click to carry it again"
		foot_ink = UiTheme.INJURED.lightened(0.2)
	elif lit:
		foot = "click to leave this one behind"
		foot_ink = UiTheme.GOLD
	card.draw_line(Vector2(pad, h - 44.0), Vector2(w - pad, h - 44.0), Color(tone, 0.22), 1.0)
	UiTheme.draw_text(card, italic, Vector2(pad, h - 36.0), foot, 18, foot_ink, 4, inner, HORIZONTAL_ALIGNMENT_CENTER)


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
	var display := UiTheme.display_font()
	var p := _progress

	if _choice:
		# Compared: who it is and what is asked, over the four cards.
		var data := p.data
		var c := Vector2(34.0, 50.0)
		draw_circle(c + Vector2(0, 2), 36.0, Color(0, 0, 0, 0.5))
		draw_circle(c, 34.0, UiTheme.INK)
		UiIcons.portrait(self, c, 31.0, data.portrait, data.portrait_focus + Vector2(0.0, 0.02), 0.3 / data.figure_scale)
		draw_arc(c, 32.5, 0.0, TAU, 40, UiTheme.GOLD, 2.0, true)
		UiTheme.draw_text(self, display, Vector2(84.0, 16.0), "%s LEARNS A COMBAT ART" % _name.to_upper(), 24, UiTheme.GOLD, 4)
		UiTheme.draw_text(self, display, Vector2(84.0, 48.0), "Three are carried into battle. Which three?", 26, UiTheme.TEXT, 5)
		# A line between the new art and the three it is weighed against.
		var mx := CARD_W + (CARD_GAP + CARD_APART) * 0.5
		draw_line(Vector2(mx, CARD_Y + 10.0), Vector2(mx, CARD_Y + CARD_H - 10.0), Color(UiTheme.GOLD, 0.3), 1.0)
		return

	# Alone: the companion, and the one new thing written out.
	_draw_figure()
	var title := ""
	var kicker := ""
	var figures: Array = []
	var lines: Array[String] = []
	if _art != null:
		kicker = "%s LEARNS A COMBAT ART" % _name.to_upper()
		title = _art.display_name
		figures = ArtFacts.art_figures(_art, p.art_cost(_art))
		lines = ArtFacts.art_lines(_art, p.weapon.weapon_type if p.weapon != null else -1)
	else:
		kicker = "%s LEARNS A SPELL" % _name.to_upper()
		title = _spell.display_name
		figures = ArtFacts.spell_figures(_spell, -1, p.max_uses(_spell))
		lines = ArtFacts.spell_lines(_spell)
	UiTheme.draw_text(self, display, Vector2(X, 30.0), kicker, 24, school_ink, 4)
	if _art != null:
		ArtFacts.draw_tag(self, Vector2(X, 32.0), _art.weapon_type, -1, _art.tier, 19, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), 4, X + W)
	else:
		ArtFacts.draw_tag(self, Vector2(X, 32.0), -1, _spell.school, _spell.tier, 19, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), 4, X + W)
	var title_size := 68
	while title_size > 40 and display.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > W:
		title_size -= 2
	UiTheme.draw_text(self, display, Vector2(X - 3.0, 58.0 + (68 - title_size) * 0.5), title.to_upper(), title_size, UiTheme.TEXT, 8)
	ArtFacts.draw(self, Vector2(X, FACTS_Y), W, figures, lines, school_ink, UiTheme.TEXT, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), 1.0,
		FOOT_Y - FACTS_Y - 130.0)
	# The foot: where it went.
	draw_line(Vector2(X, FOOT_Y - 6.0), Vector2(X + W, FOOT_Y - 6.0), Color(school_ink, 0.22), 1.0)
	UiIcons.diamond(self, Vector2(X + 9.0, FOOT_Y + 32.0), 6.0, school_ink)


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
