class_name JewelerScreen
extends Control
## The jeweler's workshop. On the left, a velvet tray with the company's stones, weakest to strongest:
## pick one and have it set (the day's work, and gold). The jeweler turns the stone to the light, then
## lays down what it can become: one design, or two to choose from once the workshop has its second
## level. The piece made is handed to someone at once ("Who wears it?") or put in the case. On the
## right, the case: everything the company owns and who wears it (handed round at the barracks).
## Only reads the run and calls Run.craft, take_craft and wear.

signal closed

const TRAY := Rect2(90, 196, 1040, 318)
const STONE := 124.0
const CASE := Rect2(1190, 110, 690, 946)
const CASE_PAD := 34.0
const CARD := Vector2(460, 470)
const CARD_GAP := 56.0
const CARD_Y := 300.0
const WEARER := Vector2(196, 250)
## How long the jeweler turns the stone before the designs are laid down.
const CUT_TIME := 1.4
const SEAL_AT := Vector2(TRAY.position.x + 40.0, TRAY.end.y + 34.0)

var run: Run
var _backdrop := InteriorBackdrop.new()
var _hint: Label
var _purse := Control.new()
var _tray := Control.new()
var _seal := ActionButton.new()
var _why: Label
var _case := Control.new()
## The company along the foot of the room, each with what they wear.
var _crew := Control.new()
var _list := VBoxContainer.new()
## Over the whole room while a design is being chosen or a piece handed over.
var _bench := Control.new()
## Over everything while the stone is being turned: a click finishes it.
var _hush := Control.new()
var _anim: Tween
## The stone picked on the tray (its rank); 0 for none.
var _picked := 0
## How far the turning of the stone has got (0..1); 1 when nothing is playing.
var _cut := 1.0:
	set(v):
		_cut = v
		_bench.queue_redraw()
## The piece just made, waiting to be handed to someone.
var _made: Accessory


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(p_run: Run) -> void:
	run = p_run
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_hush.visible = false
	_anim = null
	_cut = 1.0
	_made = null
	_picked = 0
	for rank in range(Gem.max_rank(), 0, -1):
		if run.gem_count(rank) > 0 and run.craft_block_reason(rank) == "":
			_picked = rank
			break
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	refresh()


## Leaving waits until the design is chosen; a piece not yet handed over goes into the case.
func close() -> void:
	_skip()
	if run != null and run.craft_offer != null:
		return
	_made = null
	visible = false
	closed.emit()


func pick(rank: int) -> void:
	if run.gem_count(rank) <= 0 or run.craft_offer != null or _made != null:
		return
	_picked = rank
	refresh()


## Pays for the picked stone to be set: the jeweler turns it to the light, then shows the designs.
func set_stone() -> void:
	_skip()
	if _picked <= 0 or run.craft_block_reason(_picked) != "":
		return
	if run.craft(_picked) == null:
		return
	refresh()
	_cut = 0.0
	_hush.visible = true
	_anim = create_tween()
	_anim.tween_property(self, "_cut", 1.0, CUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var i := 0
	for child in _bench.get_children():
		child.modulate.a = 0.0
		var home: Vector2 = child.position
		child.position = home + Vector2(0, 34.0)
		_anim.tween_property(child, "modulate:a", 1.0, 0.26).set_delay(0.0 if i == 0 else 0.06)
		_anim.parallel().tween_property(child, "position", home, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		i += 1
	_anim.tween_callback(_end)


## Makes design `index` of the offer; it then waits for a wearer.
func take(index: int) -> void:
	_skip()
	if run.craft_offer == null:
		return
	_made = run.take_craft(index)
	_picked = 0
	refresh()


func wear(c: RunCompanion) -> void:
	if _made == null or run.wear_block_reason(c, _made) != "":
		return
	run.wear(c, _made)
	_made = null
	refresh()


func put_away() -> void:
	_made = null
	refresh()


func _end() -> void:
	_hush.visible = false
	_anim = null


func _skip() -> void:
	if _anim != null and _anim.is_valid() and _anim.is_running():
		_anim.custom_step(600.0)
	if _anim != null and (not _anim.is_valid() or not _anim.is_running()):
		_end()


func refresh() -> void:
	_purse.queue_redraw()
	_tray.queue_redraw()
	_case.queue_redraw()
	# A stone is always picked while the company holds one, so the seal says what setting it takes.
	if _picked <= 0 or run.gem_count(_picked) <= 0:
		_picked = 0
		for rank in range(Gem.max_rank(), 0, -1):
			if run.gem_count(rank) > 0:
				_picked = rank
				break
	var level := run.facility_level(Run.Facility.JEWELER)
	_hint.text = "\"A stone is only a stone until it is set, Commander. What it becomes is for the stone to say%s.\"" % (
		"; I can show you two ways it might go" if level >= 2 else "")
	# The seal under the tray: what setting the picked stone costs, or why it cannot be done.
	var why := run.craft_block_reason(_picked) if _picked > 0 else "No stone is picked."
	if run.gem_total() <= 0:
		why = "The company holds no stones."
	_seal.title = "Set the %s" % Gem.name_of(_picked) if _picked > 0 else "Set a stone"
	_seal.detail = "%d gold  ·  the day" % _gold(_picked) if _picked > 0 else ""
	_seal.disabled = why != ""
	_seal.tooltip_text = why if why != "" else "The jeweler sets the %s into something to wear. It takes the rest of the day and %d gold; what it becomes is not yours to choose%s." % [
		Gem.name_of(_picked), _gold(_picked), ", beyond the two designs shown" if level >= 2 else ""]
	_why.text = why if why != "" and _picked > 0 else ""
	for child in _tray.get_children():
		child.queue_redraw()
	_refresh_case()
	_refresh_crew()
	_refresh_bench()


## Gold the jeweler asks to set a stone of `rank`.
func _gold(rank: int) -> int:
	return int(run.craft_cost(rank).get("gold", 0))


# ---------------------------------------------------------------- the tray

func _draw_tray() -> void:
	var r := Rect2(Vector2.ZERO, TRAY.size)
	_tray.draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(0, 0, 0, 0.4))
	# A wooden tray lined with dark velvet.
	_tray.draw_rect(r, Color("3a2819"))
	UiTheme.draw_grain(_tray, r, 0.2)
	var cloth := r.grow(-16.0)
	_tray.draw_rect(cloth, Color("2a1830"))
	_tray.draw_rect(cloth, Color(0, 0, 0, 0.35), false, 3.0)
	for k in 8:
		_tray.draw_rect(cloth.grow(-k * 14.0), Color(1.0, 0.8, 1.0, 0.012))
	UiTheme.draw_text(_tray, UiTheme.display_font(), Vector2(40, 30), "THE COMPANY'S STONES", 17, Color(UiTheme.MUTED, 0.9), 4)


## One place on the tray: the stone of `rank`, large when the company holds one, a hollow when not.
func _stone_place(rank: int) -> Control:
	var place := Control.new()
	var step := (TRAY.size.x - 80.0) / Gem.max_rank()
	place.position = Vector2(40.0 + (rank - 1) * step, 62.0)
	place.size = Vector2(step, TRAY.size.y - 84.0)
	place.mouse_filter = Control.MOUSE_FILTER_STOP
	place.draw.connect(func() -> void:
		if run == null:
			return
		var n := run.gem_count(rank)
		var c := Vector2(place.size.x * 0.5, 92.0)
		var display := UiTheme.display_font()
		var lit := rank == _picked and n > 0
		if lit:
			for k in 9:
				place.draw_circle(c, 46.0 + k * 9.0, Color(UiIcons.gem_color(rank), 0.035))
		if n > 0:
			place.draw_circle(c + Vector2(4, STONE * 0.42), STONE * 0.3, Color(0, 0, 0, 0.35))
			UiIcons.gem(place, c + (Vector2(0, -8) if lit else Vector2.ZERO), STONE, rank)
		else:
			# Nothing here yet: the hollow the stone would lie in.
			UiIcons.gem(place, c, STONE * 0.8, rank, 0.12)
		var ink := UiIcons.gem_color(rank).lerp(UiTheme.TEXT, 0.35) if n > 0 else Color(UiTheme.MUTED, 0.55)
		UiTheme.draw_text(place, display, Vector2(0, 168.0), Gem.name_of(rank).to_upper(), 20, ink, 4, place.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if n > 0:
			UiTheme.draw_text(place, display, Vector2(0, 194.0), str(n), 30, UiTheme.TEXT, 5, place.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if lit:
			UiIcons.diamond(place, Vector2(place.size.x * 0.5, 240.0), 6.0, UiTheme.GOLD))
	place.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			place.accept_event()
			pick(rank))
	return place


# ---------------------------------------------------------------- the case

func _refresh_case() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var w := CASE.size.x - CASE_PAD * 2.0
	if run.accessories.is_empty():
		var none := UiTheme.label("Nothing has been made yet.", 18, UiTheme.PARCHMENT_MUTED)
		none.add_theme_font_override("font", UiTheme.italic_font())
		_list.add_child(none)
	for a: Accessory in run.accessories:
		_list.add_child(piece_row(run, a, w))


## One owned piece, as a line on parchment: its stone, its name, what it does, and who wears it.
static func piece_row(r: Run, a: Accessory, w: float) -> Control:
	var row := Control.new()
	var lines := a.lines()
	var h := 40.0 + lines.size() * 21.0 + 10.0
	row.custom_minimum_size = Vector2(w, h)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := r.wearer_of(a)
	row.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		UiIcons.gem(row, Vector2(18.0, 22.0), 30.0, a.rank)
		UiTheme.draw_text(row, display, Vector2(44.0, 4.0), a.title(), 24, UiTheme.PARCHMENT_INK)
		var where := "worn by %s" % who.display_name() if who != null else "in the case"
		UiTheme.draw_text(row, italic, Vector2(0, 10.0), where, 16, UiTheme.PARCHMENT_MUTED, 0, w, HORIZONTAL_ALIGNMENT_RIGHT)
		for i in lines.size():
			var takes := a.is_two_edged() and i == lines.size() - 1
			UiTheme.draw_text(row, italic, Vector2(44.0, 36.0 + i * 21.0), lines[i], 17,
				UiTheme.WAX.darkened(0.15) if takes else UiTheme.PARCHMENT_INK.lerp(UiTheme.PARCHMENT_MUTED, 0.4))
		row.draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(UiTheme.PARCHMENT_INK, 0.2), 1.0))
	return row


func _draw_case() -> void:
	UiTheme.draw_parchment(_case, Rect2(Vector2.ZERO, _case.size))
	var w := _case.size.x - CASE_PAD * 2.0
	UiTheme.draw_text(_case, UiTheme.display_font(), Vector2(CASE_PAD, 34.0), "IN THE CASE  ·  %d" % (run.accessories.size() if run != null else 0), 18,
		UiTheme.PARCHMENT_MUTED)
	UiTheme.draw_text(_case, UiTheme.italic_font(), Vector2(CASE_PAD, 36.0), "two each, never two of a kind", 16, UiTheme.PARCHMENT_MUTED, 0, w,
		HORIZONTAL_ALIGNMENT_RIGHT)
	_case.draw_line(Vector2(CASE_PAD, 70.0), Vector2(CASE_PAD + w, 70.0), Color(UiTheme.PARCHMENT_INK, 0.45), 1.0)


# ---------------------------------------------------------------- the bench: the designs, and who wears the piece

func _refresh_bench() -> void:
	for child in _bench.get_children():
		_bench.remove_child(child)
		child.queue_free()
	var offer: CraftOffer = run.craft_offer
	_bench.visible = offer != null or _made != null
	_bench.queue_redraw()
	if offer != null:
		var n := offer.designs.size()
		var total := n * CARD.x + (n - 1) * CARD_GAP
		for i in n:
			_bench.add_child(_design_card(offer, i, Vector2(960.0 - total * 0.5 + i * (CARD.x + CARD_GAP), CARD_Y)))
	elif _made != null:
		var crew := run.roster
		var total := crew.size() * WEARER.x
		for i in crew.size():
			_bench.add_child(_wearer(crew[i], Vector2(960.0 - total * 0.5 + i * WEARER.x, 520.0)))
		var away := Button.new()
		away.text = "Into the case"
		away.tooltip_text = "Nobody puts it on now. It waits in the case and can be handed out at the barracks."
		away.focus_mode = Control.FOCUS_NONE
		away.add_theme_font_size_override("font_size", 22)
		away.position = Vector2(960.0 - 130.0, 830.0)
		away.size = Vector2(260, 50)
		away.pressed.connect(put_away)
		_bench.add_child(away)


func _draw_bench() -> void:
	var w := maxf(size.x, 1920.0)
	var h := maxf(size.y, 1080.0)
	_bench.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.03, 0.88))
	var display := UiTheme.display_font()
	var italic := UiTheme.italic_font()
	if run == null:
		return
	var offer: CraftOffer = run.craft_offer
	if offer != null:
		var done := _cut >= 1.0
		var said := "The jeweler turns the stone to the light." if not done else (
			"\"It could be either of these. Choose.\"" if offer.designs.size() > 1 else "\"This is what it wants to be.\"")
		UiTheme.draw_text(_bench, display, Vector2(0, 150.0), "THE %s" % Gem.name_of(offer.rank).to_upper(), 46, UiIcons.gem_color(offer.rank), 8, w,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_text(_bench, italic, Vector2(0, 214.0), said, 22, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3), 4, w, HORIZONTAL_ALIGNMENT_CENTER)
		if not done:
			_draw_cut(offer.rank, _cut)
	elif _made != null:
		UiIcons.gem(_bench, Vector2(960.0, 210.0), 96.0, _made.rank)
		UiTheme.draw_text(_bench, display, Vector2(0, 280.0), _made.title().to_upper(), 46, UiTheme.TEXT, 8, w, HORIZONTAL_ALIGNMENT_CENTER)
		var lines := _made.lines()
		for i in lines.size():
			var takes := _made.is_two_edged() and i == lines.size() - 1
			UiTheme.draw_text(_bench, italic, Vector2(0, 346.0 + i * 30.0), lines[i], 24, UiTheme.INJURED.lightened(0.15) if takes else UiTheme.GOLD, 4, w,
				HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_text(_bench, display, Vector2(0, 460.0), "WHO WEARS IT?", 20, UiTheme.MUTED, 4, w, HORIZONTAL_ALIGNMENT_CENTER)


## The stone held up and turned (`f` 0..1): it swells, rays of its colour turn about it, and it flashes
## white as the cut is found.
func _draw_cut(rank: int, f: float) -> void:
	var c := Vector2(960.0, 560.0)
	var color := UiIcons.gem_color(rank)
	var swell := 0.6 + 0.4 * smoothstep(0.0, 0.5, f)
	for k in 10:
		_bench.draw_circle(c, 70.0 + k * 26.0, Color(color, 0.03 * swell))
	# Rays turning about the stone.
	for i in 12:
		var a := TAU * i / 12.0 + f * 2.6
		var long := 150.0 + 110.0 * (0.5 + 0.5 * sin(f * 14.0 + i * 1.9))
		var dir := Vector2.from_angle(a)
		_bench.draw_polygon(PackedVector2Array([c + dir.orthogonal() * 5.0, c + dir * long * swell, c - dir.orthogonal() * 5.0]),
			PackedColorArray([Color(color, 0.0), Color(color.lightened(0.5), 0.5 * swell), Color(color, 0.0)]))
	UiIcons.gem(_bench, c, 190.0 * swell, rank)
	# Glints running over the facets, and the flash at the end.
	for i in 5:
		var p := fposmod(f * 2.2 + i * 0.21, 1.0)
		var at := c + Vector2(lerpf(-70.0, 70.0, p), lerpf(-50.0, 30.0, fposmod(i * 0.37, 1.0))) * swell
		_bench.draw_circle(at, 5.0 * sin(p * PI), Color(1, 1, 1, 0.8 * sin(p * PI)))
	# The cut is found: a soft bloom and a ring running outward.
	var flash := smoothstep(0.8, 1.0, f)
	if flash > 0.0:
		var fade := 1.0 - flash
		for k in 9:
			_bench.draw_circle(c, (60.0 + 420.0 * flash) * (1.0 - k / 9.0), Color(1.0, 0.98, 0.92, 0.07 * fade + 0.02))
		_bench.draw_arc(c, 90.0 + 560.0 * flash, 0.0, TAU, 64, Color(1, 1, 1, 0.5 * fade), 3.0, true)


## One design of the offer, as a card: the stone in its setting, the name, what it gives in large
## figures, what it takes in red, and the seal that has it made.
func _design_card(offer: CraftOffer, index: int, at: Vector2) -> Control:
	var type: AccessoryTypeData = offer.designs[index]
	var card := Control.new()
	card.position = at
	card.size = CARD
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner := CARD.x - 60.0
	card.draw.connect(func() -> void:
		card.draw_rect(Rect2(Vector2(8, 10), CARD), Color(0, 0, 0, 0.45))
		UiTheme.draw_parchment(card, Rect2(Vector2.ZERO, CARD), 0.5)
		var display := UiTheme.display_font()
		var c := Vector2(CARD.x * 0.5, 84.0)
		# The setting: a ring of gold about the stone.
		card.draw_arc(c, 52.0, 0.0, TAU, 48, UiTheme.GOLD_DEEP.darkened(0.2), 7.0, true)
		card.draw_arc(c, 52.0, PI * 1.1, PI * 1.7, 16, UiTheme.GOLD.lightened(0.2), 3.0, true)
		UiIcons.gem(card, c + Vector2(0, 2), 66.0, offer.rank)
		UiTheme.draw_text(card, display, Vector2(0, 150.0), "%s %s" % [Gem.name_of(offer.rank), type.display_name], 36, UiTheme.PARCHMENT_INK, 0, CARD.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.draw_text(card, display, Vector2(0, 196.0), type.family_name().to_upper(), 14, UiTheme.PARCHMENT_MUTED, 0, CARD.x, HORIZONTAL_ALIGNMENT_CENTER)
		card.draw_line(Vector2(30, 224.0), Vector2(30 + inner, 224.0), Color(UiTheme.PARCHMENT_INK, 0.4), 1.0))
	var gives_text := type.gives_line(offer.rank)
	var gives := UiTheme.label(gives_text, 32 if gives_text.length() <= 24 else 24, UiTheme.PARCHMENT_INK, true)
	gives.position = Vector2(30, 236)
	gives.size = Vector2(inner, 96)
	gives.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gives.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gives.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(gives)
	if type.is_two_edged():
		var takes := UiTheme.label(type.takes_line(), 22, UiTheme.WAX.darkened(0.15), true)
		takes.position = Vector2(30, 334)
		takes.size = Vector2(inner, 54)
		takes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		takes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(takes)
	var seal := ActionButton.new()
	seal.paper = true
	seal.h = 50.0
	seal.title = "Make this one" if offer.designs.size() > 1 else "Take it"
	seal.position = Vector2((CARD.x - ActionButton.W) * 0.5, CARD.y - 70.0)
	seal.tooltip_text = "The stone is set as this. It cannot be re-made."
	seal.pressed.connect(take.bind(index))
	card.add_child(seal)
	return card


## The company along the foot of the room, each with what they wear.
func _refresh_crew() -> void:
	for child in _crew.get_children():
		_crew.remove_child(child)
		child.queue_free()
	var crew := run.roster
	var step := minf(WEARER.x + 10.0, _crew.size.x / maxi(1, crew.size()))
	for i in crew.size():
		var c := crew[i]
		var who := Control.new()
		who.position = Vector2(i * step, 34.0)
		who.size = Vector2(step, 300.0)
		who.mouse_filter = Control.MOUSE_FILTER_STOP
		var worn := run.accessories_of(c)
		var tips: Array[String] = []
		for a: Accessory in worn:
			tips.append("%s: %s" % [a.title(), "; ".join(a.lines())])
		who.tooltip_text = "%s wears nothing yet." % c.display_name() if worn.is_empty() else "%s wears
%s" % [c.display_name(), "
".join(tips)]
		who.draw.connect(func() -> void:
			var display := UiTheme.display_font()
			var italic := UiTheme.italic_font()
			var head := Vector2(step * 0.5, 54.0)
			who.draw_circle(head + Vector2(0, 3), 49.0, Color(0, 0, 0, 0.4))
			who.draw_circle(head, 48.0, UiTheme.INK)
			UiIcons.portrait(who, head, 45.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale)
			who.draw_arc(head, 46.5, 0.0, TAU, 48, UiTheme.GOLD_DEEP, 2.0, true)
			UiTheme.draw_text(who, display, Vector2(0, 108.0), c.display_name(), 22, UiTheme.TEXT, 5, step, HORIZONTAL_ALIGNMENT_CENTER)
			for k in RunConfig.MAX_ACCESSORIES:
				var y := 146.0 + k * 30.0
				if k < worn.size():
					var name := worn[k].title()
					var px := 17
					while px > 12 and italic.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > step - 44.0:
						px -= 1
					var tw := italic.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
					var x := (step - tw - 24.0) * 0.5
					UiIcons.gem(who, Vector2(x + 8.0, y + 11.0), 18.0, worn[k].rank)
					UiTheme.draw_text(who, italic, Vector2(x + 24.0, y), name, px, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.2), 4)
				else:
					who.draw_arc(Vector2(step * 0.5, y + 11.0), 7.0, 0.0, TAU, 20, Color(UiTheme.MUTED, 0.6), 1.5, true))
		_crew.add_child(who)


## One of the company, to hand the new piece to: their face, their name, what they already wear, and
## why not when they cannot take it.
func _wearer(c: RunCompanion, at: Vector2) -> Control:
	var who := Control.new()
	who.position = at
	who.size = WEARER
	who.mouse_filter = Control.MOUSE_FILTER_STOP
	var why := run.wear_block_reason(c, _made)
	var worn := run.accessories_of(c)
	who.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if why == "" else Control.CURSOR_ARROW
	var lit := [false]
	var names: Array[String] = []
	for a: Accessory in worn:
		names.append(a.title())
	who.tooltip_text = why if why != "" else "%s puts it on.%s" % [c.display_name(), "\nWears: " + ", ".join(names) if not names.is_empty() else ""]
	who.draw.connect(func() -> void:
		var display := UiTheme.display_font()
		var italic := UiTheme.italic_font()
		var head := Vector2(WEARER.x * 0.5, 70.0)
		var can := why == ""
		if lit[0] and can:
			for k in 6:
				who.draw_circle(head, 66.0 + k * 7.0, Color(UiTheme.GOLD, 0.05))
		who.draw_circle(head + Vector2(0, 3), 63.0, Color(0, 0, 0, 0.4))
		who.draw_circle(head, 62.0, UiTheme.INK)
		UiIcons.portrait(who, head, 58.0, c.data.portrait, c.data.portrait_focus + Vector2(0.0, 0.02), 0.3 / c.data.figure_scale,
			Color.WHITE if can else Color(0.45, 0.42, 0.4))
		who.draw_arc(head, 60.0, 0.0, TAU, 48, UiTheme.GOLD if lit[0] and can else UiTheme.GOLD_DEEP, 3.0 if lit[0] and can else 2.0, true)
		UiTheme.draw_text(who, display, Vector2(0, 140.0), c.display_name(), 24, UiTheme.TEXT if can else UiTheme.MUTED, 5, WEARER.x,
			HORIZONTAL_ALIGNMENT_CENTER)
		# The two places: a small stone for each piece worn, a hollow ring for each free one.
		for i in RunConfig.MAX_ACCESSORIES:
			var p := Vector2(WEARER.x * 0.5 + (i - (RunConfig.MAX_ACCESSORIES - 1) * 0.5) * 34.0, 190.0)
			if i < worn.size():
				UiIcons.gem(who, p, 22.0, worn[i].rank)
			else:
				who.draw_arc(p, 8.0, 0.0, TAU, 20, Color(UiTheme.MUTED, 0.7), 1.5, true)
		if not can:
			UiTheme.draw_text(who, italic, Vector2(0, 212.0), _short(why), 15, UiTheme.INJURED.lightened(0.1), 4, WEARER.x, HORIZONTAL_ALIGNMENT_CENTER))
	who.mouse_entered.connect(func() -> void:
		lit[0] = true
		who.queue_redraw())
	who.mouse_exited.connect(func() -> void:
		lit[0] = false
		who.queue_redraw())
	who.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			who.accept_event()
			wear(c))
	return who


## A reason short enough to stand under a face.
static func _short(why: String) -> String:
	var s := why.trim_suffix(".")
	return s if s.length() <= 26 else s.substr(0, 24) + "…"


func _draw_purse() -> void:
	if run == null:
		return
	var display := UiTheme.display_font()
	var text := str(run.gold)
	var tw := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var right := _purse.size.x
	UiTheme.draw_text(_purse, display, Vector2(right - tw, (_purse.size.y - display.get_height(36)) * 0.5), text, 36, UiTheme.GOLD, 6)
	UiIcons.coin(_purse, Vector2(right - tw - 30.0, _purse.size.y * 0.5 + 2.0), 30.0, UiTheme.GOLD)


func _build() -> void:
	_backdrop.kind = InteriorBackdrop.Kind.JEWELER
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var title := UiTheme.label("THE JEWELER", 44, UiTheme.GOLD, true, 8)
	title.position = Vector2(60, 20)
	add_child(title)
	_hint = UiTheme.label("", 20, UiTheme.TEXT.lerp(UiTheme.MUTED, 0.5), false, 4)
	_hint.add_theme_font_override("font", UiTheme.italic_font())
	_hint.position = Vector2(64, 78)
	add_child(_hint)

	_tray.position = TRAY.position
	_tray.size = TRAY.size
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.draw.connect(_draw_tray)
	add_child(_tray)
	for rank in range(1, Gem.max_rank() + 1):
		_tray.add_child(_stone_place(rank))

	# The slip the jeweler's price is written on, with its seal.
	var slip := Control.new()
	slip.position = SEAL_AT - Vector2(14.0, 8.0)
	slip.size = Vector2(ActionButton.W + 44.0, 66.0)
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip.draw.connect(func() -> void:
		slip.draw_rect(Rect2(Vector2(5, 6), slip.size), Color(0, 0, 0, 0.35))
		UiTheme.draw_parchment(slip, Rect2(Vector2.ZERO, slip.size), 0.4))
	add_child(slip)
	_seal.paper = true
	_seal.h = 50.0
	_seal.position = SEAL_AT
	_seal.pressed.connect(set_stone)
	add_child(_seal)
	_why = UiTheme.label("", 19, UiTheme.INJURED.lightened(0.2), false, 4)
	_why.add_theme_font_override("font", UiTheme.italic_font())
	_why.position = SEAL_AT + Vector2(ActionButton.W + 60.0, 12.0)
	add_child(_why)

	_crew.position = Vector2(TRAY.position.x, 650.0)
	_crew.size = Vector2(TRAY.size.x, 340.0)
	_crew.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crew.draw.connect(func() -> void:
		UiTheme.draw_text(_crew, UiTheme.display_font(), Vector2(4, 0), "WORN BY THE COMPANY", 17, Color(UiTheme.MUTED, 0.9), 4)
		_crew.draw_line(Vector2(0, 26), Vector2(_crew.size.x, 26), Color(UiTheme.GOLD_DEEP, 0.6), 1.0))
	add_child(_crew)

	_case.position = CASE.position
	_case.size = CASE.size
	_case.mouse_filter = Control.MOUSE_FILTER_STOP
	_case.draw.connect(_draw_case)
	add_child(_case)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(CASE_PAD, 82.0)
	scroll.size = Vector2(CASE.size.x - CASE_PAD * 2.0, CASE.size.y - 82.0 - 30.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_case.add_child(scroll)
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)

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

	_bench.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bench.mouse_filter = Control.MOUSE_FILTER_STOP
	_bench.visible = false
	_bench.draw.connect(_draw_bench)
	add_child(_bench)

	_hush.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hush.mouse_filter = Control.MOUSE_FILTER_STOP
	_hush.visible = false
	_hush.gui_input.connect(func(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_hush.accept_event()
			_skip())
	add_child(_hush)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
