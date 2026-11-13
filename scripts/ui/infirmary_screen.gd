class_name InfirmaryScreen
extends Control
## The infirmary: a bed for everyone injured in battle. Each bed shows who lies in it, the days of
## their stay (RunConfig.INFIRMARY_DAYS) as marks (those behind them filled in), the day they will be up again, and a slip
## for paying the healer to have them on their feet today: the price falls with every day already
## served and rises with their level; it costs gold only, never the day's action. Rest at the inn does nothing for
## them. Can be entered on any day, to look. Only reads the run and calls Run.cure.

signal closed

const COLS := 2
const BED := Vector2(860, 196)
const BED_X := 80.0
const BED_Y := 176.0
const BED_GAP := Vector2(40, 64)
const FRAME_W := 400.0

var run: Run
var _beds := Control.new()
var _empty: Label
var _purse := Control.new()
var _hint: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run) -> void:
	run = p_run
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	refresh()


func close() -> void:
	visible = false
	closed.emit()


## Pays the healer for `c`: they are up at once, at full health, on the bench.
func cure(c: RunCompanion) -> void:
	if run.cure(c):
		refresh()


func refresh() -> void:
	_purse.queue_redraw()
	for child in _beds.get_children():
		_beds.remove_child(child)
		child.queue_free()
	var patients := run.infirmary()
	_empty.visible = patients.is_empty()
	# A full ward packs its beds closer.
	var rows := ceili(patients.size() / float(COLS))
	var step := minf(BED.y + BED_GAP.y, 860.0 / maxi(1, rows))
	for i in patients.size():
		var bed := _bed(patients[i], step - BED_GAP.y)
		bed.position = Vector2((i % COLS) * (BED.x + BED_GAP.x), floorf(i / float(COLS)) * step)
		_beds.add_child(bed)


## One bed and what is written beside it.
func _bed(c: RunCompanion, h: float) -> Control:
	var bed := Control.new()
	bed.size = Vector2(BED.x, h)
	bed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := c.days_left(run.day)
	# A trait can lengthen or shorten the stay.
	var stay := maxi(run.infirmary_days(c), left)
	var served := clampi(stay - left, 0, stay)
	bed.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		var floor_y := h - 8.0
		# The bed, seen from the side: head board on the left, linen, a blanket drawn up.
		var wood := Color("5a4430")
		var dark := Color("2e2117")
		bed.draw_rect(Rect2(6, floor_y - 4.0, FRAME_W, 10.0), Color(0, 0, 0, 0.3))
		bed.draw_rect(Rect2(0, floor_y - 122.0, 14.0, 122.0), wood)
		bed.draw_rect(Rect2(0, floor_y - 122.0, 4.0, 122.0), wood.lightened(0.15))
		bed.draw_rect(Rect2(FRAME_W - 12.0, floor_y - 70.0, 12.0, 70.0), dark)
		bed.draw_rect(Rect2(10, floor_y - 34.0, FRAME_W - 20.0, 12.0), dark)
		bed.draw_rect(Rect2(14, floor_y - 62.0, FRAME_W - 26.0, 30.0), Color("e6dfd0"))
		bed.draw_rect(Rect2(14, floor_y - 62.0, FRAME_W - 26.0, 5.0), Color(1, 1, 1, 0.25))
		# The pillow, and who lies on it.
		var head := Vector2(74.0, floor_y - 92.0)
		bed.draw_rect(Rect2(20, floor_y - 84.0, 112.0, 26.0), Color("f2ecdf"))
		bed.draw_circle(head + Vector2(0, 3), 47.0, Color(0, 0, 0, 0.35))
		bed.draw_circle(head, 46.0, UiTheme.INK)
		UiIcons.portrait(bed, head, 43.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color(0.9, 0.84, 0.8))
		bed.draw_arc(head, 44.5, 0.0, TAU, 48, UiTheme.GOLD_DEEP, 2.0, true)
		# The blanket.
		var wool := Color("5d6f62")
		bed.draw_colored_polygon(PackedVector2Array([Vector2(128, floor_y - 78.0), Vector2(FRAME_W - 14.0, floor_y - 70.0),
			Vector2(FRAME_W - 14.0, floor_y - 34.0), Vector2(120, floor_y - 34.0)]), wool)
		bed.draw_line(Vector2(128, floor_y - 78.0), Vector2(FRAME_W - 14.0, floor_y - 70.0), wool.lightened(0.2), 2.0)
		bed.draw_line(Vector2(150, floor_y - 62.0), Vector2(FRAME_W - 20.0, floor_y - 56.0), wool.darkened(0.2), 1.5)

		# Beside the bed: who, and how long.
		var x := FRAME_W + 36.0
		UiTheme.draw_text(bed, display, Vector2(x, 2.0), c.display_name(), 38, UiTheme.TEXT, 6)
		var nw := display.get_string_size(c.display_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		UiTheme.draw_text(bed, italic, Vector2(x + nw + 16.0, 20.0), "level %d" % c.level(), 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45), 4)
		# The days of the stay: the ones served filled in.
		for d in stay:
			var at := Vector2(x + 12.0 + d * 30.0, 70.0)
			if d < served:
				UiIcons.diamond(bed, at, 9.0, UiTheme.GOLD)
			else:
				bed.draw_arc(at, 7.0, 0.0, TAU, 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), 1.5, true)
		var word := "Up tomorrow" if left <= 1 else "%d days to go" % left
		UiTheme.draw_text(bed, display, Vector2(x + stay * 30.0 + 16.0, 56.0), word, 24, UiTheme.TEXT, 4)
		UiTheme.draw_text(bed, italic, Vector2(x, 90.0), "on their feet on day %d" % (run.day + left), 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.45), 4)
		# The slip under the healer's price.
		bed.draw_rect(Rect2(x + 4.0, h - 62.0 + 4.0, ActionButton.W + 26.0, 56.0), Color(0, 0, 0, 0.3))
		UiTheme.draw_parchment(bed, Rect2(x, h - 62.0, ActionButton.W + 26.0, 56.0), 0.4))
	var pay := ActionButton.new()
	pay.paper = true
	pay.h = 44.0
	pay.title = "Pay the healer"
	pay.position = Vector2(FRAME_W + 36.0 + 10.0, h - 56.0)
	var why := run.cure_block_reason(c)
	var cost := run.cure_cost(c)
	pay.disabled = why != ""
	pay.detail = "%d gold" % cost
	pay.tooltip_text = ("%s\n" % why if why != "" else "") + "%s is up today at full health and waits on the bench. It costs %d gold and takes no time from the day. The price falls by %d for every day they have lain here." % [
		c.display_name(), cost, cost / maxi(1, left)]
	pay.pressed.connect(cure.bind(c))
	bed.add_child(pay)
	if why != "":
		var note := UiTheme.label(why, 17, UiTheme.MUTED, false, 4)
		note.add_theme_font_override("font", UiTheme.italic_font())
		note.position = Vector2(FRAME_W + 36.0 + ActionButton.W + 40.0, h - 46.0)
		note.size = Vector2(BED.x - FRAME_W - 36.0 - ActionButton.W - 40.0, 40.0)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bed.add_child(note)
	return bed


func _draw_purse() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var text := "%d" % run.gold
	var tw := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var right := _purse.size.x
	UiTheme.draw_text(_purse, display, Vector2(right - tw, (_purse.size.y - display.get_height(36)) * 0.5), text, 36, UiTheme.GOLD, 6)
	UiIcons.coin(_purse, Vector2(right - tw - 30.0, _purse.size.y * 0.5 + 2.0), 30.0, UiTheme.GOLD)


func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.INFIRMARY
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := UiTheme.label("THE INFIRMARY", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	_hint = UiTheme.label("\"A few days in bed mend most things, Commander. Sleep at the inn will not. Coin can hurry me, if you must have them today.\"",
		20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.position = Vector2(64, 78)
	add_child(_hint)

	_beds.position = Vector2(BED_X, BED_Y)
	_beds.size = Vector2(1760, 880)
	_beds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beds)
	_empty = UiTheme.label("The beds are empty.", 34, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.4), true, 6)
	_empty.position = Vector2(0, 480)
	_empty.size = Vector2(1920, 50)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)

	_purse.position = Vector2(1250, 28)
	_purse.size = Vector2(300, 58)
	_purse.mouse_filter = Control.MOUSE_FILTER_STOP
	_purse.tooltip_text = "The company's gold."
	_purse.draw.connect(_draw_purse)
	add_child(_purse)

	var back := Button.new()
	back.text = "Leave"
	back.tooltip_text = "Back to the city.\nKey: Esc"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 28)
	back.position = Vector2(1590, 28)
	back.size = Vector2(300, 58)
	back.pressed.connect(close)
	add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
