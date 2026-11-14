class_name MasonScreen
extends Control
## The Mason's Yard, from inside: everything the city builds. Down the left are the walls (how they
## stand, and the order to mend them, which is the day's one thing) and the trade of one material for
## the other. The rest is the master mason's plan of the city's works on one sheet: the nine
## facilities, each with its two levels written out. What is built is marked; the next level of each
## shows its price in timber or iron ore and is built with a click, at once and without taking the
## day's action; a second level waits for the first. Only reads the run and calls Run.repair,
## Run.swap and Run.upgrade. Can be entered on any day, to look.

signal closed

const LEFT_X := 60.0
const LEFT_W := 560.0
const WALLS_Y := 156.0
const TRADE_Y := 520.0
const PAGE := Rect2(700, 110, 1180, 946)
const PAD := 36.0
const ROWS_Y := 84.0
const ROW_H := 84.0
const NAME_W := 214.0
const CELL_GAP := 14.0

var run: Run
var _note: Label
var _left := Control.new()
var _page := Control.new()
var _cells := Control.new()
var _purse := Control.new()
var _mend := ActionButton.new()
var _mend_why: Label
var _to_ore := ActionButton.new()
var _to_timber := ActionButton.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run) -> void:
	run = p_run
	_note.text = ""
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	refresh()


func close() -> void:
	visible = false
	closed.emit()


## Sets the masons to the walls: the day's one thing.
func mend() -> void:
	var before := run.city_health
	if run.repair():
		_note.text = "The masons go up on the scaffolds. The walls are stronger by %d." % (run.city_health - before)
		refresh()


## Trades RunConfig.SWAP_GIVE of one material for RunConfig.SWAP_GET of the other.
func swap(from_id: String, to_id: String) -> void:
	if run.swap(from_id, to_id):
		_note.text = "%d %s for %d %s." % [RunConfig.SWAP_GIVE, String(RunConfig.MATERIAL_NAMES[from_id]).to_lower(), RunConfig.SWAP_GET,
			String(RunConfig.MATERIAL_NAMES[to_id]).to_lower()]
		refresh()


## Builds the next level of `f`.
func build(f: Run.Facility) -> void:
	if run.upgrade(f):
		_note.text = "The %s is built up: %s." % [Run.facility_name(f), Run.facility_lines(f, run.facility_level(f)).left(1).to_lower()
			+ Run.facility_lines(f, run.facility_level(f)).substr(1)]
		refresh()


func refresh() -> void:
	_left.queue_redraw()
	_page.queue_redraw()
	_purse.queue_redraw()
	for child in _cells.get_children():
		_cells.remove_child(child)
		child.queue_free()
	if run == null:
		return
	var inner := PAGE.size.x - PAD * 2.0
	var cell_w := (inner - NAME_W - CELL_GAP) * 0.5
	for f: int in Run.Facility.values():
		for level in [1, 2]:
			var cell := _cell(f, level, Vector2(cell_w, ROW_H - 14.0))
			cell.position = Vector2(PAD + NAME_W + (level - 1) * (cell_w + CELL_GAP), ROWS_Y + f * ROW_H + 6.0)
			_cells.add_child(cell)
	# The walls.
	var why := run.free_action_block_reason(Run.FreeAction.REPAIR)
	_mend.disabled = why != ""
	_mend.detail = Run.cost_text(run.repair_cost()).to_lower()
	_mend.tooltip_text = (why + "\n" if why != "" else "") + "The walls gain %d. It is the one thing done today." % run.repair_amount()
	_mend_why.text = why
	_mend.queue_redraw()
	# The trade.
	for pair: Array in [[_to_ore, RunConfig.TIMBER, RunConfig.IRON_ORE], [_to_timber, RunConfig.IRON_ORE, RunConfig.TIMBER]]:
		var b: ActionButton = pair[0]
		var swap_why := run.swap_block_reason(pair[1], pair[2])
		b.disabled = swap_why != ""
		b.tooltip_text = (swap_why + "\n" if swap_why != "" else "") + "%d %s for %d %s. It takes no time from the day." % [RunConfig.SWAP_GIVE,
			String(RunConfig.MATERIAL_NAMES[pair[1]]).to_lower(), RunConfig.SWAP_GET, String(RunConfig.MATERIAL_NAMES[pair[2]]).to_lower()]
		b.queue_redraw()


## One level of one facility on the plan: built, to be built next (a button), or waiting for the first.
func _cell(f: int, level: int, cell_size: Vector2) -> Control:
	var cell := Control.new()
	cell.size = cell_size
	var have := run.facility_level(f)
	var built := level <= have
	var next := level == have + 1
	var why := run.upgrade_block_reason(f) if next else ""
	var can := next and why == ""
	var cost := run.upgrade_cost(f) if next else {RunConfig.FACILITY_MATERIAL[f]: RunConfig.UPGRADE_COST[level - 1]}
	var line := Run.facility_lines(f, level)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can else Control.CURSOR_ARROW
	cell.tooltip_text = "Built." if built else (("Build it: %s. It works at once and takes no time from the day." % Run.cost_text(cost).to_lower()) if can
		else (why if next else "The first level comes first."))
	var state := {"hover": false}
	cell.mouse_entered.connect(func() -> void:
		state.hover = true
		cell.queue_redraw())
	cell.mouse_exited.connect(func() -> void:
		state.hover = false
		cell.queue_redraw())
	cell.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and can:
			cell.accept_event()
			build.call_deferred(f))
	cell.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var body := UiTheme.body_font()
		var italic := UiTheme.italic_font()
		var ink := UiTheme.PARCHMENT_INK
		var muted := UiTheme.PARCHMENT_MUTED
		var r := Rect2(Vector2.ZERO, cell_size)
		var lit: bool = state.hover and can
		if built:
			cell.draw_rect(r, Color(UiTheme.WAX, 0.09))
		elif next:
			cell.draw_rect(r, Color(ink, 0.1 if lit else 0.04))
			cell.draw_rect(r.grow(-1.0), UiTheme.WAX if lit else Color(ink, 0.55 if can else 0.3), false, 2.5 if lit else 1.5)
		var text_ink := ink if (built or can) else Color(muted, 0.85 if next else 0.6)
		UiTheme.draw_text(cell, display, Vector2(12.0, 8.0), CombatArtData.tier_numeral(level), 16, Color(muted, 1.0 if (built or next) else 0.6))
		# What it does, on up to two lines.
		var room := cell_size.x - 44.0 - 96.0
		var rows := ArtFacts._wrap(body, line, 17, room)
		var y := (cell_size.y - rows.size() * 22.0) * 0.5 - 1.0
		for row in rows:
			UiTheme.draw_text(cell, body, Vector2(44.0, y), row, 17, text_ink)
			y += 22.0
		# At the right: built, the price, or that it waits.
		var right := cell_size.x - 12.0
		var mid := cell_size.y * 0.5
		if built:
			cell.draw_circle(Vector2(right - 62.0, mid + 1.0), 6.0, UiTheme.WAX)
			UiTheme.draw_text(cell, italic, Vector2(right - 50.0, mid - 11.0), "built", 18, UiTheme.WAX.darkened(0.15))
		elif next:
			var m: String = cost.keys()[0]
			var short := run.material(m) < int(cost[m])
			var price := str(int(cost[m]))
			var price_ink := UiTheme.WAX if short else (UiTheme.WAX.darkened(0.2) if lit else ink)
			var pw := display.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			UiTheme.draw_text(cell, display, Vector2(right - 34.0 - pw, mid - 19.0), price, 28, Color(price_ink, 1.0 if can or short else 0.6))
			_material_icon(cell, m, Vector2(right - 14.0, mid), 26.0, 1.0 if can else 0.6)
		else:
			UiTheme.draw_text(cell, italic, Vector2(right - 90.0, mid - 10.0), "after I", 16, Color(muted, 0.7), 0, 90.0, HORIZONTAL_ALIGNMENT_RIGHT))
	return cell


static func _material_icon(ci: CanvasItem, m: String, c: Vector2, size: float, alpha: float = 1.0) -> void:
	if m == RunConfig.TIMBER:
		UiIcons.timber(ci, c, size, Color(Color("7a5630"), alpha))
	else:
		UiIcons.ore(ci, c, size, Color(Color("5d666f"), alpha))


# ---------------------------------------------------------------- drawing

## The left column: the walls and the trade, in light on the yard.
func _draw_left() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	UiTheme.draw_text(_left, display, Vector2(0, WALLS_Y), "THE WALLS", 20, UiTheme.MUTED, 5)
	_left.draw_line(Vector2(0, WALLS_Y + 30.0), Vector2(LEFT_W, WALLS_Y + 30.0), Color(UiTheme.GOLD_DEEP, 0.7), 1.0)
	var most := run.max_city_health()
	var figure := str(run.city_health)
	var hurt := run.city_health * 3 <= most
	UiTheme.draw_text(_left, display, Vector2(0, WALLS_Y + 38.0), figure, 96, UiTheme.INJURED if hurt else UiTheme.TEXT, 8)
	var fw := display.get_string_size(figure, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
	UiTheme.draw_text(_left, display, Vector2(fw + 12.0, WALLS_Y + 96.0), "of %d" % most, 28, UiTheme.MUTED, 5)
	var track := Rect2(0, WALLS_Y + 156.0, LEFT_W, 14.0)
	_left.draw_rect(track.grow(2.0), Color(0, 0, 0, 0.6))
	_left.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(run.city_health) / maxf(1.0, most), 0.0, 1.0), track.size.y)),
		UiTheme.INJURED if hurt else UiTheme.HP)
	# What one mending would add, drawn paler on the same line.
	if run.city_health < most:
		var after := minf(most, run.city_health + run.repair_amount())
		_left.draw_rect(Rect2(Vector2(track.position.x + track.size.x * run.city_health / float(most), track.position.y),
			Vector2(track.size.x * (after - run.city_health) / float(most), track.size.y)), Color(UiTheme.HEAL, 0.45))
	UiTheme.draw_text(_left, italic, Vector2(0, WALLS_Y + 180.0), "One mending adds %d." % run.repair_amount(), 18, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.4), 4)

	UiTheme.draw_text(_left, display, Vector2(0, TRADE_Y), "TRADE", 20, UiTheme.MUTED, 5)
	_left.draw_line(Vector2(0, TRADE_Y + 30.0), Vector2(LEFT_W, TRADE_Y + 30.0), Color(UiTheme.GOLD_DEEP, 0.7), 1.0)
	UiTheme.draw_text(_left, italic, Vector2(0, TRADE_Y + 40.0), "Timber builds the city. Iron ore is for the smith.", 18, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.4), 4)


## The plan: the heading, each facility's name and how far it is built.
func _draw_page() -> void:
	UiTheme.draw_parchment(_page, Rect2(Vector2.ZERO, _page.size))
	if run == null:
		return
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	var ink := UiTheme.PARCHMENT_INK
	var muted := UiTheme.PARCHMENT_MUTED
	var inner := PAGE.size.x - PAD * 2.0
	UiTheme.draw_text(_page, display, Vector2(PAD, 32.0), "THE CITY'S WORKS", 18, muted)
	UiTheme.draw_text(_page, italic, Vector2(PAD, 34.0), "built at once  ·  never the day's one thing", 15, muted, 0, inner, HORIZONTAL_ALIGNMENT_RIGHT)
	_page.draw_line(Vector2(PAD, 68.0), Vector2(PAD + inner, 68.0), Color(ink, 0.45), 1.0)
	for f: int in Run.Facility.values():
		var y := ROWS_Y + f * ROW_H
		var level := run.facility_level(f)
		UiTheme.draw_text(_page, display, Vector2(PAD, y + 20.0), Run.facility_name(f), 25, ink)
		# Two marks under the name: how far it is built.
		for k in Run.facility_max_level():
			var c := Vector2(PAD + 9.0 + k * 22.0, y + 66.0)
			if k < level:
				UiIcons.diamond(_page, c, 7.0, UiTheme.WAX)
			else:
				UiIcons.diamond(_page, c, 7.0, Color(ink, 0.18))
		if f > 0:
			_page.draw_line(Vector2(PAD, y), Vector2(PAD + inner, y), Color(ink, 0.14), 1.0)


## The company's stores, as figures.
func _draw_purse() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var x := _purse.size.x
	var mid := _purse.size.y * 0.5
	for entry: Array in [["ore", str(run.material(RunConfig.IRON_ORE))], ["timber", str(run.material(RunConfig.TIMBER))], ["coin", str(run.gold)]]:
		var text: String = entry[1]
		var tw := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
		x -= tw
		UiTheme.draw_text(_purse, display, Vector2(x, mid - display.get_height(36) * 0.5), text, 36, UiTheme.GOLD if entry[0] == "coin" else UiTheme.TEXT, 6)
		x -= 30.0
		match entry[0]:
			"coin":
				UiIcons.coin(_purse, Vector2(x, mid + 2.0), 30.0, UiTheme.GOLD)
			"timber":
				UiIcons.timber(_purse, Vector2(x, mid + 2.0), 32.0, Color("a0794a"))
			_:
				UiIcons.ore(_purse, Vector2(x, mid + 2.0), 30.0, Color("9aa3ad"))
		x -= 46.0


func _slip(at: Vector2, button: ActionButton, title: String, detail: String, action: Callable) -> void:
	var slip := Control.new()
	slip.position = at
	slip.size = Vector2(ActionButton.W + 40.0, 74.0)
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.draw.connect(func() -> void:
		slip.draw_rect(Rect2(4, 6, slip.size.x, slip.size.y), Color(0, 0, 0, 0.3))
		UiTheme.draw_parchment(slip, Rect2(Vector2.ZERO, slip.size), 0.4))
	_left.add_child(slip)
	button.paper = true
	button.h = 50.0
	button.title = title
	button.detail = detail
	button.position = Vector2(14.0, 12.0)
	button.pressed.connect(action)
	slip.add_child(button)


func _build() -> void:
	var backdrop := InteriorBackdrop.new()
	backdrop.kind = InteriorBackdrop.Kind.YARD
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var title := UiTheme.label("MASON'S YARD", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	var hint := UiTheme.label("\"Timber and iron, Commander, and tell us what the city needs most.\"", 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	hint.add_theme_font_override("font", UiTheme.italic_font())
	hint.position = Vector2(64, 78)
	add_child(hint)
	_note = UiTheme.label("", 20, UiTheme.READY, false, 5)
	_note.add_theme_font_override("font", UiTheme.italic_font())
	_note.position = Vector2(64, 106)
	add_child(_note)

	_left.position = Vector2(LEFT_X, 0)
	_left.size = Vector2(LEFT_W, 1080)
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.draw.connect(_draw_left)
	add_child(_left)
	_slip(Vector2(0, WALLS_Y + 222.0), _mend, "Mend the walls", "", mend)
	_mend_why = UiTheme.label("", 18, UiTheme.INJURED, false, 4)
	_mend_why.add_theme_font_override("font", UiTheme.italic_font())
	_mend_why.position = Vector2(4, WALLS_Y + 306.0)
	_mend_why.size = Vector2(LEFT_W, 28)
	_left.add_child(_mend_why)
	_slip(Vector2(0, TRADE_Y + 78.0), _to_ore, "Timber for iron ore", "%d for %d" % [RunConfig.SWAP_GIVE, RunConfig.SWAP_GET],
		swap.bind(RunConfig.TIMBER, RunConfig.IRON_ORE))
	_slip(Vector2(0, TRADE_Y + 166.0), _to_timber, "Iron ore for timber", "%d for %d" % [RunConfig.SWAP_GIVE, RunConfig.SWAP_GET],
		swap.bind(RunConfig.IRON_ORE, RunConfig.TIMBER))

	_page.position = PAGE.position
	_page.size = PAGE.size
	_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_page.draw.connect(_draw_page)
	add_child(_page)
	_cells.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_cells)

	_purse.position = Vector2(1050, 28)
	_purse.size = Vector2(500, 58)
	_purse.mouse_filter = Control.MOUSE_FILTER_STOP
	_purse.tooltip_text = "Iron ore, timber and gold."
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
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
