class_name BattleResult
extends Control
## After a battle, over the field, in five beats:
##   1. won or lost and what it gave or cost, with the company in a row and their XP bars filling,
##      each by their own share (a skull for every enemy they felled, gold marks for whoever did most);
##   2. how it went: a page of the chronicle, at most five lines the rules wrote (BattleReport.account):
##      who fell and to what, what the enemy had left, the misses, who dealt and took the most;
##   3. one LevelUpPanel for every level gained, the stats coming up one at a time;
##   4. one LearnedPanel for every combat art or spell learned (they are learned now, not during the
##      fight), written out in full; an art that found no free place can be swapped in there;
##   5. the company again, and the way back.
## A click, Space or Enter moves it on (advance()), except past an art that waits for a decision:
## that panel has its own way on. It only reads the report; the run has already
## been changed by the time this opens.

signal leave_pressed

enum Stage { SPOILS, ACCOUNT, LEVELS, LEARNED, DONE }

const FILL_SECONDS := 0.7
const CARD_GAP := 18.0
const TITLE_Y := 26.0
const REWARDS_Y := 178.0
const CARDS_Y := 316.0
const PANEL_Y := 296.0
const FOOT_Y := 946.0
## The page of the chronicle ("How it went").
const PAGE_W := 1180.0
const PAGE_PAD := 56.0
const PAGE_HEAD := 96.0
const PAGE_LINE_GAP := 14.0

var _dim := ColorRect.new()
var _head := Control.new()
var _cards := Control.new()
var _panel := LevelUpPanel.new()
var _learn := LearnedPanel.new()
## The page of the chronicle and what is written on it.
var _page := Control.new()
var _account: Array[String] = []
## True once the first beat's bars have filled.
var _spoils_shown := false
var _page_h := 0.0
var _hint: Label
var _button := Button.new()
var _stage := Stage.DONE
## Levels still to show: {data, name, level, before, gains}.
var _queue: Array[Dictionary] = []
var _next := 0
## Arts and spells still to show: {progress, name, art, equipped} or {progress, name, spell}.
var _learned: Array[Dictionary] = []
var _next_learned := 0
var _generation := 0
var _won := true
## The company fell back before the battle was decided (a lost battle all the same).
var _retreated := false
## What the battle gave or cost, drawn as pictures with numbers: {icon, text, color}.
var _rewards: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.color = Color(UiTheme.INK, 0.9)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_head.set_anchors_preset(Control.PRESET_FULL_RECT)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.draw.connect(_draw_head)
	add_child(_head)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)
	_panel.visible = false
	_panel.finished.connect(_on_level_shown)
	add_child(_panel)
	_learn.visible = false
	_learn.finished.connect(_after_learned)
	add_child(_learn)
	_page.visible = false
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.draw.connect(_draw_page)
	add_child(_page)
	_hint = UiTheme.label("Click to go on", 22, UiTheme.MUTED, false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(600, 32)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_button.focus_mode = Control.FOCUS_NONE
	_button.size = Vector2(460, 68)
	_button.add_theme_font_size_override("font_size", 34)
	_button.pressed.connect(func() -> void: leave_pressed.emit())
	add_child(_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Shows what `report` says about a battle fought by `roster`. `battle`, when given, is asked who
## felled how many.
func open(report: BattleReport, roster: Array[CompanionUnit], battle: Battle = null) -> void:
	_generation += 1
	_won = report.won
	_retreated = report.retreated
	_rewards.clear()
	if report.won:
		_rewards.append({"icon": "coin", "text": "+%d" % report.gold, "color": UiTheme.GOLD})
		for m: String in RunConfig.MATERIAL_ORDER:
			if int(report.materials.get(m, 0)) > 0:
				_rewards.append({"icon": "timber" if m.contains("timber") or m.contains("wood") else "ore",
					"text": "+%d %s" % [int(report.materials[m]), String(RunConfig.MATERIAL_NAMES[m]).to_lower()], "color": UiTheme.TEXT})
		if report.weapon_found != null:
			_rewards.append({"icon": "swords", "text": "found: %s" % report.weapon_found.display_name, "color": UiTheme.GOLD})
		if report.gem > 0:
			_rewards.append({"icon": "gem", "rank": report.gem, "text": Gem.name_of(report.gem), "color": UiIcons.gem_color(report.gem)})
		if report.xp_total() > 0:
			_rewards.append({"icon": "diamond", "text": "+%d XP" % report.xp_total(), "color": UiTheme.TEXT})
	elif report.front != null and report.front.is_boss:
		_rewards.append({"icon": "rampart", "text": "%s breaks through. The city falls." % report.front.group.display_name,
			"color": UiTheme.INJURED})
	else:
		_rewards.append({"icon": "rampart", "text": "The walls lose %d" % report.city_damage, "color": UiTheme.INJURED})

	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_queue.clear()
	_next = 0
	_learned.clear()
	_next_learned = 0
	_write_page(report.account)
	for g: Dictionary in report.grade_ups:
		var actor: CompanionUnit = g.actor
		if g.get("art") != null:
			_learned.append({"progress": actor.progress, "name": actor.display_name, "art": g.art, "equipped": bool(g.get("equipped", false))})
		if g.get("spell") != null:
			_learned.append({"progress": actor.progress, "name": actor.display_name, "spell": g.spell})
	# Whoever did the most, when one companion stands out.
	var best := 0
	var shared := false
	for c in roster:
		var p := report.points_of(c.display_name)
		shared = p == best if p >= best else shared
		best = maxi(best, p)
	for c in roster:
		var foremost := report.won and best > 0 and not shared and report.points_of(c.display_name) == best
		_cards.add_child(_card_for(c, report, battle.kills_of(c) if battle != null else 0, foremost))
	_button.text = "Continue" if report.run_over else "Back to the city"
	_button.visible = false
	_hint.visible = false
	_panel.visible = false
	_learn.visible = false
	_page.visible = false
	_cards.visible = true
	_spoils_shown = false
	_stage = Stage.SPOILS
	_layout()
	_head.queue_redraw()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)

	if report.xp_total() > 0:
		for card: SpoilsCard in _cards.get_children():
			card.play(FILL_SECONDS)
		var generation := _generation
		get_tree().create_timer(FILL_SECONDS + (0.35 if not _queue.is_empty() else 0.1)).timeout.connect(func() -> void:
			if generation == _generation and _stage == Stage.SPOILS and not _spoils_shown:
				_show_spoils())
	else:
		_show_spoils()


## True once everything has been shown and only the way back is left.
func is_done() -> bool:
	return _stage == Stage.DONE


## Moves on: ends whatever is still animating, or goes to the next level gained.
func advance() -> void:
	match _stage:
		Stage.SPOILS:
			if _spoils_shown:
				_after_spoils()
			else:
				_show_spoils()
		Stage.ACCOUNT:
			_after_account()
		Stage.LEVELS:
			if not _panel.is_done():
				_panel.skip()
			elif _next < _queue.size():
				_show_next_level()
			else:
				_after_levels()
		Stage.LEARNED:
			# An art that waits for a decision has its own way on.
			if not _learn.needs_choice():
				_after_learned()


## The first beat has been shown in full. With a page of the chronicle to follow it waits here for a
## click, so the cards can be read; without one it goes straight on, as it always did.
func _show_spoils() -> void:
	_spoils_shown = true
	for card: SpoilsCard in _cards.get_children():
		card.finish()
	if _account.is_empty():
		_after_spoils()
	else:
		_hint.visible = true


func _after_spoils() -> void:
	for card: SpoilsCard in _cards.get_children():
		card.finish()
	if _account.is_empty():
		_after_account()
		return
	# How it went: the page is laid over the field, the cards put aside.
	_stage = Stage.ACCOUNT
	_cards.visible = false
	_page.visible = true
	_page.modulate.a = 0.0
	create_tween().tween_property(_page, "modulate:a", 1.0, 0.18)
	_hint.visible = true


func _after_account() -> void:
	_page.visible = false
	_hint.visible = false
	_cards.visible = true
	if _queue.is_empty():
		_after_levels()
	else:
		_stage = Stage.LEVELS
		_show_next_level()


func _after_levels() -> void:
	_panel.visible = false
	_after_learned()


## Shows the next art or spell learned, or the way back when there is none left.
func _after_learned() -> void:
	if _next_learned >= _learned.size():
		_finish()
		return
	var l := _learned[_next_learned]
	_next_learned += 1
	_stage = Stage.LEARNED
	_cards.visible = false
	_learn.visible = true
	_learn.modulate.a = 0.0
	create_tween().tween_property(_learn, "modulate:a", 1.0, 0.12)
	if l.has("art"):
		_learn.show_art(l.progress, l.name, l.art, l.equipped)
	else:
		_learn.show_spell(l.progress, l.name, l.spell)
	_hint.visible = not _learn.needs_choice()


func _show_next_level() -> void:
	var q := _queue[_next]
	_next += 1
	_cards.visible = false
	_hint.visible = false
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.1)
	_panel.show_level(q.data, q.name, q.level, q.before, q.gains)


func _on_level_shown() -> void:
	if _stage == Stage.LEVELS:
		_hint.visible = true


## Writes `lines` on the page of the chronicle: one Label a line, wrapped to the page.
func _write_page(lines: Array[String]) -> void:
	_account = lines.duplicate()
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	var y := PAGE_HEAD
	var room := PAGE_W - PAGE_PAD * 2.0 - 34.0
	for text in _account:
		var l := UiTheme.label(text, 27, UiTheme.PARCHMENT_INK)
		l.add_theme_font_override("font", UiTheme.body_font())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(PAGE_PAD + 34.0, y)
		l.size = Vector2(room, 0.0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page.add_child(l)
		var rows := maxi(1, ceili(UiTheme.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x / room))
		y += rows * UiTheme.body_font().get_height(27) + PAGE_LINE_GAP
	_page_h = y + PAGE_PAD - PAGE_LINE_GAP
	_page.size = Vector2(PAGE_W, _page_h)
	_page.queue_redraw()


func _draw_page() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(PAGE_W, _page_h))
	UiTheme.draw_parchment(_page, rect)
	var display := UiTheme.display_font()
	UiTheme.draw_text(_page, display, Vector2(0, 30.0), "HOW IT WENT", 34, UiTheme.PARCHMENT_INK, 0, PAGE_W, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.draw_rule(_page, Vector2(PAGE_W * 0.5, 80.0), 420.0, Color(UiTheme.PARCHMENT_MUTED, 0.8))
	# A mark before each line: red for a fall, plain for the rest.
	for child in _page.get_children():
		var l := child as Label
		if l == null:
			continue
		var fell := l.text.contains(" fell on turn ") or l.text.begins_with("Then ")
		UiIcons.diamond(_page, Vector2(PAGE_PAD + 10.0, l.position.y + 19.0), 6.0, UiTheme.WAX if fell else UiTheme.PARCHMENT_MUTED)


func _finish() -> void:
	_stage = Stage.DONE
	_panel.visible = false
	_learn.visible = false
	_page.visible = false
	_hint.visible = false
	_cards.visible = true
	_button.visible = true


## The card of one companion, and their level-ups added to the queue.
func _card_for(c: CompanionUnit, report: BattleReport, kills: int, foremost: bool) -> SpoilsCard:
	var who := c.display_name
	var ups: Array[Dictionary] = []
	for up in report.level_ups:
		if up.name == who:
			ups.append(up)
	var level_after := c.progress.level
	var level_before := level_after - ups.size()
	var gained := report.xp_of(who)
	var total := c.progress.xp
	for l in range(level_before, level_after):
		total += Levels.xp_to_next(l)
	var xp_before := maxi(0, total - gained)

	# Stats as they were before the battle, then one queue entry per level.
	var stats := c.progress.stats()
	for up in ups:
		for key: String in up.gains:
			stats[key] = int(stats.get(key, 0)) - int(up.gains[key])
	var level := level_before
	for up in ups:
		_queue.append({"data": c.data, "name": who, "level": level, "before": stats.duplicate(), "gains": up.gains})
		for key: String in up.gains:
			stats[key] = int(stats.get(key, 0)) + int(up.gains[key])
		level += 1

	var status := ""
	if report.injured.has(who):
		status = "INJURED"
	var lines: Array = []
	var tips: Array[String] = []
	if c.weapon() != null:
		var t := c.weapon().weapon_type
		# The weapon is left out for a caster who did not fight with it.
		if c.spells().is_empty() or c.proficiency_gained > 0 or c.magic_gained == 0:
			var rose := false
			for g in report.grade_ups:
				rose = rose or (g.actor == c and not g.get("magic", false) and g.get("weapon_type") == t)
			var line := _line(WeaponData.type_name(t), c.progress.grade(t), c.proficiency_gained, c.progress.progress_to_next(t), rose, tips)
			line["weapon"] = t
			lines.append(line)
		for s in c.progress.spell_schools():
			var rose := false
			for g in report.grade_ups:
				rose = rose or (g.actor == c and g.get("magic", false) and g.get("school") == s)
			var line := _line(SpellData.school_name(s), c.progress.magic_grade(s), c.magic_gained, c.progress.magic_progress_to_next(s),
				rose, tips)
			line["school"] = s
			lines.append(line)
	var learned: Array[String] = []
	for g in report.grade_ups:
		if g.actor == c:
			if g.get("art") != null:
				learned.append((g.art as CombatArtData).display_name)
			if g.get("spell") != null:
				learned.append((g.spell as SpellData).display_name)

	var card := SpoilsCard.new()
	card.setup(c.data, who, level_before, level_after, xp_before, c.progress.xp, gained, lines, learned, status, kills, foremost)
	var tip := "%s, level %d" % [who, level_after]
	if gained > 0:
		tip += "
+%d XP of the %d shared out: a quarter evenly, the rest by what each did." % [gained, report.xp_total()]
	if kills > 0:
		tip += "
Felled %d." % kills
	if foremost:
		tip += "
Did the most in this fight."
	if not ups.is_empty():
		var all := {}
		for up in ups:
			for key: String in up.gains:
				all[key] = int(all.get(key, 0)) + int(up.gains[key])
		tip += "\nLevel up from %d: %s" % [level_before, Levels.gains_text(all)]
	# What their traits brought in ("Looter: +10 gold").
	for brought in report.trait_lines:
		if brought.begins_with("%s, " % who):
			tip += "\n" + brought.trim_prefix("%s, " % who)
	var purse := int(report.kill_gold_by.get(who, 0))
	if purse > 0 and c.weapon() != null:
		tip += "\n%s brought in %d gold, counted in the gold above." % [c.weapon().display_name, purse]
	if status == "INJURED":
		tip += "\nInjured: bound for the infirmary."
	for line in tips:
		tip += "\n" + line
	if not learned.is_empty():
		tip += "\nLearned " + ", ".join(learned) + "."
	card.tooltip_text = tip
	return card


## One grade on a card, and its full wording for the tooltip.
static func _line(kind: String, grade: int, gained: int, step: Vector2i, rose: bool, tips: Array[String]) -> Dictionary:
	tips.append("%s %s: +%d this battle, %s." % [kind, Proficiency.grade_name(grade), gained,
		"top grade" if step.y == 0 else "%d of %d to %s" % [step.x, step.y, Proficiency.grade_name(grade + 1)]])
	return {"text": "%s %s" % [kind, Proficiency.grade_name(grade)], "grade": Proficiency.grade_name(grade), "gained": gained,
		"frac": 1.0 if step.y == 0 else float(step.x) / step.y, "rose": rose}


func _layout() -> void:
	var n := _cards.get_child_count()
	var row := n * SpoilsCard.W + maxi(0, n - 1) * CARD_GAP
	_cards.position = Vector2((size.x - row) * 0.5, CARDS_Y)
	_cards.size = Vector2(row, SpoilsCard.H)
	for i in n:
		(_cards.get_child(i) as Control).position = Vector2(i * (SpoilsCard.W + CARD_GAP), 0)
	_panel.position = Vector2((size.x - LevelUpPanel.SIZE.x) * 0.5, PANEL_Y)
	_page.position = Vector2((size.x - PAGE_W) * 0.5, PANEL_Y + 20.0)
	_learn.position = _panel.position
	_hint.position = Vector2((size.x - _hint.size.x) * 0.5, FOOT_Y + 14.0)
	_button.position = Vector2((size.x - _button.size.x) * 0.5, FOOT_Y)


func _draw_head() -> void:
	# The battle's own controls lie under the foot of the screen: put them out.
	var dark := Color(UiTheme.INK, 0.94)
	var clear := Color(UiTheme.INK, 0.0)
	var w := _head.size.x
	var h := _head.size.y
	_head.draw_polygon(PackedVector2Array([Vector2(0, h - 420.0), Vector2(w, h - 420.0), Vector2(w, h - 300.0), Vector2(0, h - 300.0)]),
		PackedColorArray([clear, clear, dark, dark]))
	_head.draw_rect(Rect2(0, h - 300.0, w, 300.0), dark)
	var display := UiTheme.display_font()
	var cx := _head.size.x * 0.5
	UiTheme.draw_text(_head, display, Vector2(0, TITLE_Y), "VICTORY" if _won else ("RETREAT" if _retreated else "DEFEAT"), 100, UiTheme.GOLD if _won else UiTheme.INJURED, 10,
		_head.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.draw_rule(_head, Vector2(cx, REWARDS_Y - 22.0), 760.0, Color(UiTheme.GOLD if _won else UiTheme.INJURED, 0.5))
	# What it gave or cost: a picture and a number each, in a row.
	var font_size := 32
	var gap := 54.0
	var icon_w := 44.0
	var total := -gap
	for r in _rewards:
		total += icon_w + display.get_string_size(String(r.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap
	var x := cx - total * 0.5
	var mid := REWARDS_Y + 22.0
	for r in _rewards:
		var color: Color = r.color
		var c := Vector2(x + 16.0, mid)
		match String(r.icon):
			"coin":
				UiIcons.coin(_head, c, 30.0, UiTheme.GOLD)
			"ore":
				UiIcons.ore(_head, c, 30.0, color)
			"timber":
				UiIcons.timber(_head, c, 30.0, color)
			"rampart":
				UiIcons.rampart(_head, c, 30.0, color)
			"swords":
				UiIcons.swords(_head, c, 30.0, color)
			"gem":
				UiIcons.gem(_head, c, 34.0, int(r.rank))
			_:
				UiIcons.diamond(_head, c, 9.0, UiTheme.GOLD)
		UiTheme.draw_text(_head, display, Vector2(x + icon_w, mid - display.get_height(font_size) * 0.5), String(r.text), font_size, color, 6)
		x += icon_w + display.get_string_size(String(r.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap
