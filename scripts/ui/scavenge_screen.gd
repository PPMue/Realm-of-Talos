class_name ScavengeScreen
extends Control
## The map table for a party sent beyond the walls. The company is listed down the left; on the table
## lie the scouts' two reports for the day, one per place: how many must go and as what (each place in
## the party asks for one stat), what a success would bring, what it costs when it goes badly, and
## the chance, which moves as the party is filled. Choose a report, click a place in it and then
## whoever should fill it, and send them out: that is the day's one thing. How it went is then written
## up in place of the reports (Success, Passable or Failure, the odds and the roll, what
## came home, and what happened to each of them), and every level gained is shown stat by stat like
## after a battle. Only reads the run and calls Run.scavenge.

signal closed

enum Stage { CHOOSE, RESULT, LEVELS, DONE }

const LIST_X := 60.0
const LIST_Y := 156.0
const LIST_W := 380.0
const ROW_H := 84.0
const PAPER := Vector2(680, 800)
const PAPER_Y := 124.0
const PAPER_X: Array[float] = [470.0, 1180.0]
const PAD := 34.0
const SLOT_Y := 100.0
const SLOT_STEP := 104.0
const HAUL_Y := 424.0
const RISK_Y := 566.0
const CHANCE_Y := 676.0
const FOOT_Y := 944.0
const REPORT := Rect2(470, 124, 1390, 800)
const STAMPS: Array[String] = ["SUCCESS", "PASSABLE", "FAILURE"]
const STAMP_LINES: Array[String] = [
	"\"More than we could carry, Commander. Almost.\"",
	"\"We took what we could and ran.\"",
	"\"Nothing. Someone had been there before us.\"",
]

var run: Run
var _stage := Stage.CHOOSE
var _site: ScavengeSite
## The place in the chosen report that the next click on the company fills.
var _slot := 0
## ScavengeSite -> Array of RunCompanion or null, one per place.
var _parties: Dictionary = {}
var _result: ScavengeResult
var _stamp := 0.0
var _shown := 0.0
var _tween: Tween
## Levels gained, still to show: [member, level-up].
var _levels: Array = []
var _next_level := 0
var _time := 0.0

var _row_box := Control.new()
var _papers := Control.new()
var _report := Control.new()
var _slip := Control.new()
var _send := ActionButton.new()
var _why: Label
var _words: Label
var _hint: Label
var _dim := ColorRect.new()
var _panel := LevelUpPanel.new()
var _back := Button.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run) -> void:
	run = p_run
	_stage = Stage.CHOOSE
	_result = null
	_parties.clear()
	var sites := run.scavenge_sites()
	for s in sites:
		var party: Array = []
		party.resize(s.slots.size())
		_parties[s] = party
	_site = null
	# The first report the company can fill is the one laid on top.
	for s in sites:
		if s.size <= run.available().size():
			_site = s
			break
	if _site == null and not sites.is_empty():
		_site = sites[0]
	_slot = 0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	_refresh()


func close() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false
	closed.emit()


func choose_site(s: ScavengeSite) -> void:
	if _stage != Stage.CHOOSE or s == _site:
		return
	_site = s
	_slot = _first_empty()
	_refresh()


## Clicks a place in a report: it becomes the one to fill; someone already in it steps out.
func pick_slot(s: ScavengeSite, index: int) -> void:
	if _stage != Stage.CHOOSE:
		return
	_site = s
	var party: Array = _parties[s]
	if party[index] != null:
		party[index] = null
	_slot = index
	_refresh()


## Clicks one of the company: they take the place being filled, or step out if they were going.
func toggle(c: RunCompanion) -> void:
	if _stage != Stage.CHOOSE or _site == null:
		return
	var party: Array = _parties[_site]
	var at := party.find(c)
	if at >= 0:
		party[at] = null
		_slot = at
	else:
		party[clampi(_slot, 0, party.size() - 1)] = c
		_slot = _first_empty()
	_refresh()


func party() -> Array:
	return _parties.get(_site, []) if _site != null else []


## Sends the party out and shows how it went.
func send() -> void:
	if _stage != Stage.CHOOSE or _site == null or run.scavenge_block_reason(_site, party()) != "":
		return
	_result = run.scavenge(_site, party())
	if _result == null:
		_refresh()
		return
	_stage = Stage.RESULT
	_stamp = 0.0
	_shown = 0.0
	_levels.clear()
	_next_level = 0
	for m in _result.members:
		for up: Dictionary in m.level_ups:
			_levels.append([m, up])
	_refresh()
	_tween = create_tween()
	_tween.tween_interval(0.45)
	_tween.tween_method(_set_stamp, 0.0, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.3)
	_tween.tween_method(_set_shown, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(0.2)
	_tween.tween_callback(_counted)


## A click, Space or Enter: ends what is still counting, or goes on to the next thing to show.
func advance() -> void:
	match _stage:
		Stage.RESULT:
			if _tween != null and _tween.is_running():
				_tween.kill()
				_set_stamp(1.0)
				_set_shown(1.0)
				_counted()
			else:
				_next_beat()
		Stage.LEVELS:
			if not _panel.is_done():
				_panel.skip()
			else:
				_next_beat()


func is_done() -> bool:
	return _stage == Stage.DONE


# ---------------------------------------------------------------- what the rules say

func _company() -> Array[RunCompanion]:
	var out: Array[RunCompanion] = []
	out.append_array(run.lineup)
	out.append_array(run.reserve())
	return out


func _first_empty() -> int:
	var p := party()
	for i in p.size():
		if p[i] == null:
			return i
	return maxi(0, p.size() - 1)


static func _stat_of(c: RunCompanion, key: String) -> int:
	return int(c.progress.stats().get(key, 0))


## What it costs when it goes badly, one thing to a line.
static func risk_lines(s: ScavengeSite) -> Array[String]:
	var share := "%d%% of their health" % roundi(RunConfig.SCAVENGE_HP_LOSS_FRACTION * 100.0)
	match s.risk:
		ScavengeSite.Risk.MEDIUM:
			return ["Failure: everyone loses %s" % share]
		ScavengeSite.Risk.HIGH:
			return ["Passable: everyone loses %s" % share, "Failure: one is injured, the rest lose %s" % share]
	return ["A failure costs nothing but the day"]


static func _risk_ink(s: ScavengeSite) -> Color:
	match s.risk:
		ScavengeSite.Risk.MEDIUM:
			return UiTheme.WAX.lerp(UiTheme.PARCHMENT_INK, 0.55)
		ScavengeSite.Risk.HIGH:
			return UiTheme.WAX
	return UiTheme.PARCHMENT_INK


static func _materials_text(materials: Dictionary) -> String:
	var parts: Array[String] = []
	for m in RunConfig.MATERIAL_ORDER:
		var n := int(materials.get(m, 0))
		if n > 0:
			parts.append("%d %s" % [n, String(RunConfig.MATERIAL_NAMES[m]).to_lower()])
	return ", ".join(parts)


# ---------------------------------------------------------------- the result

func _set_stamp(v: float) -> void:
	_stamp = v
	_report.queue_redraw()


func _set_shown(v: float) -> void:
	_shown = v
	_report.queue_redraw()


func _counted() -> void:
	_tween = null
	if _levels.is_empty():
		_finish()
	else:
		_hint.visible = true


func _next_beat() -> void:
	if _next_level < _levels.size():
		var m: ScavengeResult.Member = _levels[_next_level][0]
		var up: Dictionary = _levels[_next_level][1]
		_next_level += 1
		_stage = Stage.LEVELS
		_hint.visible = false
		_dim.visible = true
		_panel.visible = true
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, 0.1)
		var before: Dictionary = up.before
		var gains: Dictionary = up.gains
		_panel.show_level(m.companion.data, m.companion.display_name(), int(up.level_from), before, gains)
	else:
		_finish()


func _on_level_shown() -> void:
	if _stage == Stage.LEVELS:
		_hint.visible = true


func _finish() -> void:
	_stage = Stage.DONE
	_dim.visible = false
	_panel.visible = false
	_hint.visible = false
	_back.text = "Back to the city"
	_refresh()


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	queue_redraw()
	var choosing := _stage == Stage.CHOOSE
	_papers.visible = choosing
	_report.visible = not choosing
	_report.queue_redraw()
	_slip.visible = choosing
	_why.visible = choosing
	_dim.visible = _stage == Stage.LEVELS
	_panel.visible = _stage == Stage.LEVELS
	if _stage == Stage.CHOOSE or _stage == Stage.DONE:
		_hint.visible = false
	if choosing:
		_back.text = "Leave"
	_back.visible = choosing or _stage == Stage.DONE
	for box: Control in [_row_box, _papers]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	if run == null:
		return
	var company := _company()
	var step := minf(ROW_H, 880.0 / maxi(1, company.size()))
	for i in company.size():
		var row := _make_row(company[i], step - 8.0)
		row.position = Vector2(0, i * step)
		_row_box.add_child(row)
	if not choosing:
		return
	var sites := run.scavenge_sites()
	for i in sites.size():
		_papers.add_child(_paper(sites[i], i))
	_words.text = "\"Two places within a day's walk, Commander. One party can go and be back by dusk.\"" if sites.size() > 1 \
		else "\"One place within a day's walk, Commander.\""
	var why := "Nowhere to go today." if _site == null else run.scavenge_block_reason(_site, party())
	_send.disabled = why != ""
	_send.title = "Send them out"
	_send.detail = "" if _site == null else _site.display_name.trim_prefix("The ")
	_send.tooltip_text = why if why != "" else "The party goes to %s and is back by dusk. It is the one thing done today." % _site.display_name
	_send.queue_redraw()
	_why.text = "" if why == Run.FILL_EVERY_PLACE else why


## One of the company in the list on the left: who they are and what they have of each stat the
## chosen report asks for (the one being filled now is underlined).
func _make_row(c: RunCompanion, h: float) -> Control:
	var row := Control.new()
	row.size = Vector2(LIST_W, h)
	var choosing := _stage == Stage.CHOOSE
	var state := {"hover": false}
	if choosing:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.mouse_entered.connect(func() -> void:
			state.hover = true
			row.queue_redraw())
		row.mouse_exited.connect(func() -> void:
			state.hover = false
			row.queue_redraw())
		row.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				row.accept_event()
				toggle.call_deferred(c))
	else:
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var going := party().find(c) if choosing else (_result.party.find(c) if _result != null else -1)
	row.draw.connect(func() -> void:
		var chosen := going >= 0
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var r := minf(30.0, h * 0.5 - 4.0)
		var center := Vector2(r + 10.0, h * 0.5)
		if chosen:
			var clear := Color(UiTheme.GOLD, 0.0)
			row.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(LIST_W, 0), Vector2(LIST_W, h), Vector2(0, h)]),
				PackedColorArray([Color(UiTheme.GOLD, 0.2), clear, clear, Color(UiTheme.GOLD, 0.2)]))
			row.draw_rect(Rect2(0, 0, 3, h), UiTheme.GOLD)
		var lit: bool = chosen or state.hover
		row.draw_circle(center + Vector2(0, 2), r + 4.0, Color(0, 0, 0, 0.5))
		row.draw_circle(center, r + 3.0, UiTheme.INK)
		UiIcons.portrait(row, center, r, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color.WHITE if lit else Color(0.78, 0.76, 0.74))
		row.draw_arc(center, r + 1.5, 0.0, TAU, 40, UiTheme.GOLD if lit else UiTheme.GOLD_DEEP, 2.0, true)
		var x := center.x + r + 16.0
		UiTheme.draw_text(row, display, Vector2(x, h * 0.5 - 28.0), c.display_name(), 24, ActionButton.LIT_INK if lit else UiTheme.TEXT, 4)
		var tag := "bench" if not run.is_fielded(c) else ""
		if chosen and _site != null and choosing:
			tag = "goes as %s" % _site.slots[going].role.to_lower()
		if tag != "":
			UiTheme.draw_text(row, UiTheme.italic_font(), Vector2(x, h * 0.5 - 22.0), tag, 16, UiTheme.GOLD if chosen else UiTheme.MUTED, 4,
				LIST_W - x - 8.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if _site == null or not choosing:
			UiTheme.draw_text(row, body, Vector2(x, h * 0.5 + 4.0), "level %d" % c.progress.level, 17, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.25), 4)
			return
		# What they have of each stat the report asks for.
		var sx := x
		for i in _site.slots.size():
			var slot := _site.slots[i]
			var have := _stat_of(c, slot.stat)
			var meets := have >= slot.target
			var number := str(have)
			var word := String(StatTable.NAMES[slot.stat])
			var ink := UiTheme.READY if meets else UiTheme.RECOVERING.lerp(UiTheme.MUTED, 0.35)
			UiTheme.draw_text(row, display, Vector2(sx, h * 0.5 + 1.0), number, 21, ink, 4)
			var nw := display.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
			UiTheme.draw_text(row, body, Vector2(sx + nw + 5.0, h * 0.5 + 6.0), word, 15, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45), 4)
			var ww := body.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			if i == _slot:
				row.draw_line(Vector2(sx, h * 0.5 + 29.0), Vector2(sx + nw + 5.0 + ww, h * 0.5 + 29.0), UiTheme.GOLD, 2.0)
			sx += nw + ww + 20.0)
	return row


## A scouts' report laid on the table.
func _paper(s: ScavengeSite, index: int) -> Control:
	var paper := Control.new()
	paper.position = Vector2(PAPER_X[index % PAPER_X.size()], PAPER_Y)
	paper.size = PAPER
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state := {"hover": false}
	paper.mouse_entered.connect(func() -> void:
		state.hover = true
		paper.queue_redraw())
	paper.mouse_exited.connect(func() -> void:
		state.hover = false
		paper.queue_redraw())
	paper.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			choose_site.call_deferred(s))
	var group: Array = _parties[s]
	var inner := PAPER.x - PAD * 2.0
	paper.draw.connect(func() -> void:
		var chosen := s == _site
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var italic := UiTheme.italic_font()
		var ink := UiTheme.PARCHMENT_INK
		var muted := UiTheme.PARCHMENT_MUTED
		paper.draw_rect(Rect2(6, 8, PAPER.x, PAPER.y), Color(0, 0, 0, 0.35))
		UiTheme.draw_parchment(paper, Rect2(Vector2.ZERO, PAPER), 0.45)
		if chosen:
			paper.draw_rect(Rect2(Vector2.ZERO, PAPER).grow(-3.0), UiTheme.WAX, false, 3.0)
		elif state.hover:
			paper.draw_rect(Rect2(Vector2.ZERO, PAPER), Color(ink, 0.05))
		else:
			paper.draw_rect(Rect2(Vector2.ZERO, PAPER), Color(0, 0, 0, 0.1))
		# Where, how many, how dangerous.
		UiTheme.draw_text(paper, display, Vector2(PAD, 20.0), s.display_name, 36, ink, 0, inner - 190.0)
		UiTheme.draw_text(paper, display, Vector2(PAD, 22.0), "%s PARTY" % s.size_name().to_upper(), 15, muted, 0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
		UiTheme.draw_text(paper, display, Vector2(PAD, 42.0), "%s RISK" % s.risk_name().to_upper(), 22, _risk_ink(s), 0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
		paper.draw_line(Vector2(PAD, 80.0), Vector2(PAD + inner, 80.0), Color(ink, 0.45), 1.5, true)

		# The places in the party.
		for i in s.slots.size():
			var slot := s.slots[i]
			var y := SLOT_Y + i * SLOT_STEP
			var who: RunCompanion = group[i]
			var filling := chosen and i == _slot
			if filling:
				paper.draw_rect(Rect2(PAD - 10.0, y + 2.0, inner + 20.0, SLOT_STEP - 8.0), Color(UiTheme.WAX, 0.08))
				paper.draw_rect(Rect2(PAD - 10.0, y + 2.0, 4.0, SLOT_STEP - 8.0), UiTheme.WAX)
			var center := Vector2(PAD + 44.0, y + SLOT_STEP * 0.5 - 2.0)
			if who != null:
				paper.draw_circle(center, 41.0, Color(ink, 0.9))
				UiIcons.portrait(paper, center, 38.0, who.data.portrait, who.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / who.data.figure_scale)
			else:
				paper.draw_circle(center, 40.0, Color(ink, 0.07))
				paper.draw_arc(center, 40.0, 0.0, TAU, 48, Color(UiTheme.WAX if filling else ink, 0.75 if filling else 0.35), 2.0, true)
				UiTheme.draw_text(paper, display, center + Vector2(-40.0, -22.0), "?", 36, Color(ink, 0.3), 0, 80.0, HORIZONTAL_ALIGNMENT_CENTER)
			var x := PAD + 104.0
			UiTheme.draw_text(paper, display, Vector2(x, y + 10.0), slot.role.to_upper(), 15, muted)
			var number := str(slot.target)
			UiTheme.draw_text(paper, display, Vector2(x, y + 28.0), number, 44, ink)
			var nw := display.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
			UiTheme.draw_text(paper, display, Vector2(x + nw + 10.0, y + 52.0), String(StatTable.NAMES[slot.stat]).to_upper(), 17, muted)
			var score := run.scavenge_slot_score(s, i, who)
			var wx := PAD + 330.0
			if who != null:
				UiTheme.draw_text(paper, display, Vector2(wx, y + 18.0), who.display_name(), 25, ink)
				UiTheme.draw_text(paper, body, Vector2(wx, y + 52.0), "has %d" % _stat_of(who, slot.stat), 18, muted)
			else:
				UiTheme.draw_text(paper, italic, Vector2(wx, y + 36.0), "who goes?" if filling else "nobody yet", 19, Color(muted, 1.0 if filling else 0.75))
			UiTheme.draw_text(paper, display, Vector2(PAD, y + 26.0), "%+d" % score, 38, (UiTheme.WAX if score < 0 else ink) if who != null else Color(muted, 0.6),
				0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
			paper.draw_line(Vector2(PAD, y + SLOT_STEP - 4.0), Vector2(PAD + inner, y + SLOT_STEP - 4.0), Color(ink, 0.2), 1.5, true)

		# What a full haul brings.
		StatTable.head(paper, Vector2(PAD, HAUL_Y), inner, "ON SUCCESS")
		var lines: Array[String] = []
		if s.material_count() > 0:
			lines.append(_materials_text(s.materials))
		if s.weapon_chance > 0:
			lines.append("%d in 100: a weapon" % s.weapon_chance)
		ArtFacts.draw(paper, Vector2(PAD, HAUL_Y + StatTable.HEAD_H - 4.0), inner, [[str(s.gold), "GOLD"], [str(s.xp_each), "XP EACH"]], lines,
			ink, ink, muted, 0.62, 0.0, 0, "", Color.WHITE, 19)
		# What it costs when it goes badly.
		StatTable.head(paper, Vector2(PAD, RISK_Y), inner, "IF IT GOES BADLY")
		var ry := RISK_Y + StatTable.HEAD_H
		for line in risk_lines(s):
			UiIcons.diamond(paper, Vector2(PAD + 7.0, ry + 13.0), 4.0, _risk_ink(s))
			UiTheme.draw_text(paper, body, Vector2(PAD + 22.0, ry), line, 19, ink, 0, inner - 22.0)
			ry += 26.0
		# The chance.
		paper.draw_line(Vector2(PAD, CHANCE_Y), Vector2(PAD + inner, CHANCE_Y), Color(ink, 0.45), 1.0)
		var chance := run.scavenge_chance(s, group)
		var figure := "%d" % chance
		var chance_ink := UiTheme.WAX if chance < 45 else ink
		UiTheme.draw_text(paper, display, Vector2(PAD, CHANCE_Y + 4.0), figure, 92, chance_ink)
		var fw := display.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		UiTheme.draw_text(paper, display, Vector2(PAD + fw + 6.0, CHANCE_Y + 22.0), "%", 44, chance_ink)
		UiTheme.draw_text(paper, display, Vector2(PAD + fw + 62.0, CHANCE_Y + 30.0), "CHANCE", 22, muted)
		UiTheme.draw_text(paper, italic, Vector2(PAD + fw + 62.0, CHANCE_Y + 60.0), "of success", 18, muted)
		var track := Rect2(PAD + 330.0, CHANCE_Y + 52.0, inner - 330.0, 12.0)
		paper.draw_rect(track, Color(ink, 0.14))
		paper.draw_rect(Rect2(track.position, Vector2(track.size.x * chance / 100.0, track.size.y)), chance_ink)
		paper.draw_rect(track, Color(ink, 0.5), false, 1.0))
	# The places are buttons of their own.
	for i in s.slots.size():
		var slot := s.slots[i]
		var spot := Control.new()
		spot.position = Vector2(PAD - 10.0, SLOT_Y + i * SLOT_STEP + 2.0)
		spot.size = Vector2(inner + 20.0, SLOT_STEP - 8.0)
		spot.mouse_filter = Control.MOUSE_FILTER_STOP
		spot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		spot.tooltip_text = "%s: %d %s or more adds to the chance (+%d, and +%d for each point above, to +%d). Each point short takes %d away. An empty place counts %d." % [
			slot.role, slot.target, String(StatTable.NAMES[slot.stat]), RunConfig.SCAVENGE_MEET, RunConfig.SCAVENGE_PER_POINT_ABOVE,
			RunConfig.SCAVENGE_SLOT_MAX, RunConfig.SCAVENGE_PER_POINT_SHORT, RunConfig.SCAVENGE_EMPTY]
		spot.gui_input.connect(func(event: InputEvent) -> void:
			var mb := event as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				spot.accept_event()
				pick_slot.call_deferred(s, i))
		paper.add_child(spot)
	return paper


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## The table top under the reports: dark boards, an old map's lines, a candle.
func _draw() -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	draw_rect(Rect2(0, 0, w, h), Color("1b130d"))
	UiTheme.draw_grain(self, Rect2(0, 0, w, h), 0.16)
	for i in range(1, 6):
		draw_line(Vector2(0, h * i / 6.0), Vector2(w, h * i / 6.0), Color(0, 0, 0, 0.35), 2.0)
	for k in 3:
		var pts := PackedVector2Array()
		for i in 40:
			var t := i / 39.0
			pts.append(Vector2(w * t, h * (0.3 + 0.24 * k) + 40.0 * sin(t * 5.0 + k * 1.7) + 16.0 * sin(t * 15.0 + k)))
		draw_polyline(pts, Color(UiTheme.GOLD_DEEP, 0.12), 1.5, true)
	var c := Vector2(w - 70.0, h - 70.0)
	var flick := 0.9 + 0.1 * sin(_time * 9.0)
	for i in 6:
		draw_circle(c + Vector2(0, -40), 70.0 + 80.0 * i, Color(1.0, 0.72, 0.36, 0.03 * flick))
	draw_rect(Rect2(c.x - 9, c.y - 34, 18, 64), Color("d9c9a0"))
	draw_rect(Rect2(c.x + 2, c.y - 34, 7, 64), Color("b3a27a"))
	draw_set_transform(c + Vector2(0, 30), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color("7d6032"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	CityArt.flame(self, c + Vector2(0, -36), 8.0, _time)


## How it went, written up in place of the reports.
func _draw_report() -> void:
	if _result == null:
		return
	var size_ := REPORT.size
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	var ink := UiTheme.PARCHMENT_INK
	var muted := UiTheme.PARCHMENT_MUTED
	_report.draw_rect(Rect2(6, 8, size_.x, size_.y), Color(0, 0, 0, 0.35))
	UiTheme.draw_parchment(_report, Rect2(Vector2.ZERO, size_), 0.45)
	var pad := 60.0
	var inner := size_.x - pad * 2.0
	var s := _result.site
	var o := int(_result.outcome)
	UiTheme.draw_text(_report, display, Vector2(pad, 30.0), s.display_name, 34, ink)
	UiTheme.draw_text(_report, display, Vector2(pad, 40.0), "%s PARTY  ·  %s RISK" % [s.size_name().to_upper(), s.risk_name().to_upper()], 18, muted,
		0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
	_report.draw_line(Vector2(pad, 84.0), Vector2(pad + inner, 84.0), Color(ink, 0.45), 1.0)

	# The verdict, stamped.
	var a := clampf(_stamp, 0.0, 1.0)
	var stamp_ink := [UiTheme.WAX, ink, muted][o] as Color
	if _stamp > 0.02:
		var font_size := int(round(lerpf(104.0, 72.0, a)))
		UiTheme.draw_text(_report, display, Vector2(pad, 112.0 - (font_size - 72) * 0.5), STAMPS[o], font_size, Color(stamp_ink, a), 0, inner,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_rule(_report, Vector2(size_.x * 0.5, 210.0), 460.0, Color(stamp_ink, 0.6 * a))
		UiTheme.draw_text(_report, italic, Vector2(pad, 226.0), STAMP_LINES[o], 22, Color(muted, a), 0, inner, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_text(_report, italic, Vector2(pad, 258.0), "The chance was %d in 100. The day rolled %d." % [_result.chance, _result.roll], 17,
			Color(muted, 0.9 * a), 0, inner, HORIZONTAL_ALIGNMENT_CENTER)
	var f := clampf(_shown, 0.0, 1.0)
	if f <= 0.0:
		return

	# What came home.
	StatTable.head(_report, Vector2(pad, 310.0), inner, "BROUGHT HOME")
	var lines: Array[String] = []
	if not _result.materials.is_empty() and _materials_text(_result.materials) != "":
		lines.append(_materials_text(_result.materials))
	if _result.weapon_found != null:
		lines.append("Found: %s. It waits in the armory." % _result.weapon_found.display_name)
	if _result.gold <= 0 and lines.is_empty():
		UiTheme.draw_text(_report, italic, Vector2(pad, 350.0), "Nothing.", 24, Color(muted, f))
	else:
		ArtFacts.draw(_report, Vector2(pad, 336.0), inner, [[str(roundi(_result.gold * f)), "GOLD"]], lines, Color(ink, f), Color(ink, f), Color(muted, f),
			0.7, 0.0, 0, "", Color.WHITE, 21)

	# What happened to each of them.
	StatTable.head(_report, Vector2(pad, 500.0), inner, "THE PARTY")
	var n := _result.members.size()
	var cw := inner / 3.0
	for i in n:
		var m := _result.members[i]
		var c := m.companion
		var x := pad + i * cw
		var hurt := c == _result.injured
		var center := Vector2(x + 62.0, 610.0)
		_report.draw_circle(center, 59.0, Color(ink, 0.9 * f))
		UiIcons.portrait(_report, center, 56.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color(0.55, 0.5, 0.5, f) if hurt else Color(1, 1, 1, f))
		var tx := x + 138.0
		UiTheme.draw_text(_report, display, Vector2(tx, 546.0), c.display_name(), 28, Color(ink, f))
		UiTheme.draw_text(_report, display, Vector2(tx, 580.0), s.slots[m.slot].role.to_upper(), 14, Color(muted, f))
		var y := 604.0
		if m.xp_gained > 0:
			var rose := not m.level_ups.is_empty()
			UiTheme.draw_text(_report, display, Vector2(tx, y), "+%d XP%s" % [roundi(m.xp_gained * f), "  ·  LEVEL %d" % c.progress.level if rose and f >= 1.0 else ""],
				22, Color(UiTheme.WAX.darkened(0.1) if rose else ink, f))
			y += 30.0
		if hurt:
			UiTheme.draw_text(_report, display, Vector2(tx, y), "INJURED", 24, Color(UiTheme.WAX, f))
			UiTheme.draw_text(_report, italic, Vector2(tx, y + 30.0), "in the Infirmary until day %d" % c.back_on_day, 17, Color(muted, f))
		elif m.hp_lost > 0:
			UiTheme.draw_text(_report, display, Vector2(tx, y), "-%d health" % m.hp_lost, 22, Color(UiTheme.WAX, f))
			UiTheme.draw_text(_report, body, Vector2(tx, y + 28.0), "%d of %d left" % [c.hp, c.max_hp()], 16, Color(muted, f))
		elif m.xp_gained <= 0:
			UiTheme.draw_text(_report, italic, Vector2(tx, y), "back unharmed", 19, Color(muted, f))
	UiTheme.draw_text(_report, italic, Vector2(pad, size_.y - 50.0), "The party is back by dusk. The day is spent.", 17, Color(muted, f), 0, inner,
		HORIZONTAL_ALIGNMENT_CENTER)


func _build() -> void:
	var title := UiTheme.label("BEYOND THE WALLS", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	_words = UiTheme.label("", 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	_words.add_theme_font_override("font", UiTheme.italic_font())
	_words.position = Vector2(64, 78)
	add_child(_words)

	_row_box.position = Vector2(LIST_X, LIST_Y)
	_row_box.size = Vector2(LIST_W, 880)
	_row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row_box)
	_papers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_papers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_papers)
	_report.position = REPORT.position
	_report.size = REPORT.size
	_report.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.draw.connect(_draw_report)
	add_child(_report)

	# The order, on a slip of its own under the reports.
	_slip.position = Vector2(PAPER_X[0], FOOT_Y)
	_slip.size = Vector2(ActionButton.W + 40.0, 74.0)
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.draw.connect(func() -> void:
		_slip.draw_rect(Rect2(4, 6, _slip.size.x, _slip.size.y), Color(0, 0, 0, 0.3))
		UiTheme.draw_parchment(_slip, Rect2(Vector2.ZERO, _slip.size), 0.4))
	add_child(_slip)
	_send.paper = true
	_send.h = 50.0
	_send.position = Vector2(14.0, 12.0)
	_send.pressed.connect(send)
	_slip.add_child(_send)
	_why = UiTheme.label("", 19, UiTheme.INJURED, false, 4)
	_why.add_theme_font_override("font", UiTheme.italic_font())
	_why.position = Vector2(PAPER_X[0] + ActionButton.W + 64.0, FOOT_Y + 22.0)
	_why.size = Vector2(900, 60)
	add_child(_why)

	_back.text = "Leave"
	_back.tooltip_text = "Back to the city.\nKey: Esc"
	_back.focus_mode = Control.FOCUS_NONE
	_back.add_theme_font_size_override("font_size", 28)
	_back.position = Vector2(1590, 28)
	_back.size = Vector2(300, 58)
	_back.pressed.connect(close)
	add_child(_back)

	# A level gained on the way is shown over everything, as after a battle.
	_dim.color = Color(UiTheme.INK, 0.88)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_panel.position = Vector2((1920.0 - LevelUpPanel.SIZE.x) * 0.5, 230.0)
	_panel.visible = false
	_panel.finished.connect(_on_level_shown)
	add_child(_panel)
	_hint = UiTheme.label("Click to go on", 22, UiTheme.MUTED, false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(REPORT.position.x, FOOT_Y + 20.0)
	_hint.size = Vector2(REPORT.size.x, 32)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)


## While the result is being shown, a click anywhere moves it on.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if is_visible_in_tree() and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT \
			and (_stage == Stage.RESULT or _stage == Stage.LEVELS):
		get_viewport().set_input_as_handled()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _stage == Stage.RESULT or _stage == Stage.LEVELS:
				advance()
			else:
				close()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if _stage == Stage.RESULT or _stage == Stage.LEVELS:
				advance()
			elif _stage == Stage.CHOOSE:
				send()
		KEY_1, KEY_2:
			var sites := run.scavenge_sites()
			var i := key.keycode - KEY_1
			if _stage == Stage.CHOOSE and i < sites.size():
				get_viewport().set_input_as_handled()
				choose_site(sites[i])
