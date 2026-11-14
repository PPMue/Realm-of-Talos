class_name CityBuilding
extends Control
## One building of the city, drawn in code. In the hub it is also a button: it brightens under the
## pointer, carries a name board at its foot, and emits `pressed`. A building can be shut (dark,
## shuttered) and can call for attention (its board glows and always shows its status line).

signal pressed

enum Kind { TAVERN, SMITHY, INN, MASON, BARRACKS, WATCHTOWER, GATE, YARD, INFIRMARY, JEWELER }

const NAMES := {
	Kind.TAVERN: "The Tavern", Kind.SMITHY: "The Smithy", Kind.INN: "The Inn", Kind.MASON: "Mason's Yard",
	Kind.BARRACKS: "The Barracks", Kind.WATCHTOWER: "The Watchtower", Kind.GATE: "The Gate",
	Kind.YARD: "The Drill Yard", Kind.INFIRMARY: "The Infirmary", Kind.JEWELER: "The Jeweler",
}
## Where each building stands in the 1920x1080 scene.
const RECTS := {
	Kind.WATCHTOWER: Rect2(250, 106, 150, 370),
	Kind.GATE: Rect2(820, 226, 280, 250),
	Kind.BARRACKS: Rect2(450, 452, 330, 235),
	Kind.INN: Rect2(1165, 424, 250, 270),
	Kind.MASON: Rect2(1490, 388, 320, 200),
	Kind.TAVERN: Rect2(70, 548, 400, 350),
	Kind.SMITHY: Rect2(1440, 580, 410, 320),
	Kind.YARD: Rect2(505, 752, 290, 168),
	Kind.INFIRMARY: Rect2(1150, 742, 270, 178),
	Kind.JEWELER: Rect2(18, 392, 190, 152),
}

var kind: Kind = Kind.TAVERN
## Ambient colour, lamp glow (0-1) and the clock, set by the backdrop.
var ambient := Color.WHITE
var glow := 0.0
var time := 0.0
## One line under the name when the pointer is over the building.
var status := "":
	set(v):
		status = v
		queue_redraw()
## False: shuttered and dark.
var open := true:
	set(v):
		open = v
		queue_redraw()
## The place to go today.
var attention := false:
	set(v):
		attention = v
		queue_redraw()
var interactive := false:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
		queue_redraw()

var _hover := false
var _lift := 0.0
var _tween: Tween


func _init(p_kind: Kind = Kind.TAVERN) -> void:
	kind = p_kind
	var r: Rect2 = RECTS[kind]
	position = r.position
	size = r.size
	pivot_offset = Vector2(r.size.x * 0.5, r.size.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func display_name() -> String:
	return NAMES[kind]


## True while the building has to be redrawn every frame.
func is_lively() -> bool:
	return attention or _hover


## Chimney tops, in the scene's coordinates.
func smoke_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not open:
		return out
	match kind:
		Kind.TAVERN:
			out.append(position + Vector2(315, 12))
		Kind.SMITHY:
			out.append(position + Vector2(314, 0))
		Kind.INN:
			out.append(position + Vector2(57, 2))
		Kind.INFIRMARY:
			out.append(position + Vector2(204, 18))
	return out


## Torches and braziers, in the scene's coordinates.
func fire_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	match kind:
		Kind.GATE:
			out.append(position + Vector2(92, 186))
			out.append(position + Vector2(188, 186))
		Kind.WATCHTOWER:
			out.append(position + Vector2(75, 60))
		Kind.SMITHY:
			if open:
				out.append(position + Vector2(180, 300))
	return out


func _set_hover(v: bool) -> void:
	if not interactive:
		return
	_hover = v
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_lift, _lift, 1.0 if v else 0.0, 0.14)


func _set_lift(v: float) -> void:
	_lift = v
	scale = Vector2.ONE * (1.0 + 0.025 * v)
	self_modulate = Color(1.0 + 0.16 * v, 1.0 + 0.13 * v, 1.0 + 0.06 * v)
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) or _board_rect().grow(4.0).has_point(point)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and interactive:
		accept_event()
		pressed.emit()


func _draw() -> void:
	match kind:
		Kind.TAVERN:
			_tavern()
		Kind.SMITHY:
			_smithy()
		Kind.INN:
			_inn()
		Kind.MASON:
			_mason()
		Kind.BARRACKS:
			_barracks()
		Kind.WATCHTOWER:
			_watchtower()
		Kind.GATE:
			_gate()
		Kind.YARD:
			_yard()
		Kind.INFIRMARY:
			_infirmary()
		Kind.JEWELER:
			_jeweler()
	if interactive:
		_board()


# ---------------------------------------------------------------- the name board

func _board_rect() -> Rect2:
	var w := UiTheme.display_font().get_string_size(display_name().to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 40.0
	return Rect2(size.x * 0.5 - w * 0.5, size.y + 8.0, w, 30.0)


func _board() -> void:
	var r := _board_rect()
	var font := UiTheme.display_font()
	var pulse := 0.5 + 0.5 * sin(time * 3.2)
	var trim := UiTheme.EDGE
	var ink := UiTheme.MUTED
	if open:
		trim = UiTheme.GOLD_DEEP.lerp(UiTheme.GOLD, _lift)
		ink = UiTheme.TEXT.lerp(ActionButton.LIT_INK, _lift)
	if attention:
		trim = UiTheme.GOLD.lerp(Color("fff0c0"), pulse * 0.6)
		ink = UiTheme.GOLD.lerp(Color("fff0c0"), pulse * 0.5)
		draw_rect(r.grow(5.0 + 3.0 * pulse), Color(UiTheme.GOLD, 0.10 + 0.12 * pulse))
	UiTheme.draw_frame(self, r, Color(UiTheme.INK, 0.9), trim, 2.0, false)
	UiTheme.draw_text(self, font, Vector2(r.position.x, r.position.y + (r.size.y - font.get_height(17)) * 0.5),
		display_name().to_upper(), 17, ink, 0, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if status == "" or not (attention or _lift > 0.05):
		return
	var body := UiTheme.italic_font()
	var a := 1.0 if attention else _lift
	var w := body.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 28.0
	var s := Rect2(size.x * 0.5 - w * 0.5, r.end.y + 4.0, w, 28.0)
	draw_rect(s, Color(UiTheme.INK, 0.82 * a))
	UiTheme.draw_text(self, body, Vector2(s.position.x, s.position.y + (s.size.y - body.get_height(17)) * 0.5), status, 17,
		Color(UiTheme.TEXT, a), 0, s.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------- the buildings

func _t(c: Color) -> Color:
	return CityArt.tint(c, ambient)


func _tavern() -> void:
	var a := ambient
	CityArt.chimney(self, Rect2(300, 18, 30, 80), CityArt.STONE_DARK, a)
	# Stone ground floor, then a plastered upper floor that juts out over it.
	CityArt.wall(self, Rect2(40, 225, 320, 125), CityArt.STONE, a, 14.0)
	CityArt.stones(self, Rect2(40, 240, 320, 100), CityArt.STONE, a, 1)
	CityArt.wall(self, Rect2(28, 120, 344, 108), CityArt.PLASTER, a, 0.0)
	CityArt.gable(self, 28, 372, 122, 100, CityArt.PLASTER, CityArt.ROOF_RED, a)
	var beam := _t(CityArt.TIMBER)
	for x: float in [28.0, 113.0, 197.0, 281.0, 366.0]:
		draw_rect(Rect2(x, 120, 7, 108), beam)
	draw_rect(Rect2(28, 118, 344, 7), beam)
	draw_rect(Rect2(24, 222, 352, 9), beam)
	draw_line(Vector2(120, 122), Vector2(200, 52), beam, 5.0)
	draw_line(Vector2(281, 122), Vector2(200, 52), beam, 5.0)
	CityArt.window(self, Rect2(186, 74, 28, 30), glow, a, open, true)
	for x: float in [56.0, 140.0, 225.0, 308.0]:
		CityArt.window(self, Rect2(x, 150, 32, 44), glow, a, open)
	CityArt.window(self, Rect2(66, 258, 70, 52), maxf(glow, 0.25), a, open)
	CityArt.window(self, Rect2(266, 258, 70, 52), maxf(glow, 0.25), a, open)
	CityArt.door(self, Rect2(176, 266, 50, 84), CityArt.WOOD, a)
	draw_rect(Rect2(164, 345, 74, 6), _t(CityArt.STONE.lightened(0.1)))
	# Lantern by the door.
	draw_line(Vector2(240, 262), Vector2(252, 262), _t(Color("2b2622")), 2.0)
	if open:
		draw_circle(Vector2(252, 274), 22.0, Color(CityArt.LAMP, 0.10 + 0.14 * glow))
	draw_rect(Rect2(247, 264, 10, 16), CityArt.LAMP if open else _t(Color("3a3a3a")))
	# The sign: a mug.
	var c := CityArt.sign_board(self, Vector2(28, 150), a, -1.0)
	var mug := _t(Color("e6d3a0"))
	draw_rect(Rect2(c.x - 9, c.y - 8, 15, 18), mug)
	draw_arc(Vector2(c.x + 7, c.y + 1), 6.0, -PI * 0.5, PI * 0.5, 8, mug, 2.5)
	draw_rect(Rect2(c.x - 10, c.y - 11, 17, 5), _t(Color.WHITE))
	# Barrels outside.
	for bx: float in [340.0, 372.0]:
		draw_rect(Rect2(bx, 314, 28, 36), _t(CityArt.WOOD))
		draw_rect(Rect2(bx, 322, 28, 3), _t(Color("2b2622")))
		draw_rect(Rect2(bx, 340, 28, 3), _t(Color("2b2622")))


func _smithy() -> void:
	var a := ambient
	CityArt.chimney(self, Rect2(292, 6, 44, 130), CityArt.STONE_DARK, a)
	CityArt.roof(self, 20, 390, 130, 76, 48, CityArt.ROOF_SLATE, a)
	var stone := CityArt.STONE_DARK.lightened(0.14)
	CityArt.wall(self, Rect2(20, 130, 370, 190), stone, a, 14.0)
	CityArt.stones(self, Rect2(240, 150, 150, 160), stone, a, 3)
	# The open front of the forge.
	var mouth := Rect2(52, 190, 176, 130)
	draw_rect(mouth, Color(0.05, 0.04, 0.04))
	if open:
		draw_polygon(PackedVector2Array([Vector2(mouth.position.x, mouth.end.y), Vector2(mouth.end.x, mouth.end.y),
			Vector2(mouth.end.x, mouth.position.y), Vector2(mouth.position.x, mouth.position.y)]),
			PackedColorArray([Color(CityArt.FIRE, 0.25), Color(CityArt.FIRE, 0.75), Color(CityArt.FIRE, 0.3), Color(CityArt.FIRE, 0.0)]))
		# The hearth and the anvil in front of it.
		draw_rect(Rect2(150, 286, 62, 34), Color(0.1, 0.08, 0.08))
		draw_colored_polygon(PackedVector2Array([Vector2(78, 284), Vector2(128, 284), Vector2(120, 294), Vector2(112, 296),
			Vector2(114, 312), Vector2(122, 320), Vector2(84, 320), Vector2(92, 312), Vector2(94, 296), Vector2(70, 290)]),
			Color(0.03, 0.03, 0.03))
	else:
		draw_rect(mouth, _t(CityArt.WOOD.darkened(0.3)))
		for i in range(1, 6):
			var x := mouth.position.x + mouth.size.x * i / 6.0
			draw_line(Vector2(x, mouth.position.y), Vector2(x, mouth.end.y), _t(CityArt.TIMBER.darkened(0.2)), 2.0)
		draw_rect(Rect2(mouth.position.x, mouth.position.y + 50, mouth.size.x, 8), _t(Color("2b2622")))
	draw_rect(Rect2(42, 178, 196, 14), _t(CityArt.TIMBER))
	draw_rect(Rect2(42, 178, 12, 142), _t(CityArt.TIMBER))
	draw_rect(Rect2(226, 178, 12, 142), _t(CityArt.TIMBER.darkened(0.15)))
	CityArt.window(self, Rect2(272, 204, 44, 50), glow, a, open)
	# The sign: a hammer.
	var c := CityArt.sign_board(self, Vector2(390, 160), a, 1.0)
	var iron := _t(Color("d9d2c4"))
	draw_line(c + Vector2(-9, 11), c + Vector2(5, -5), _t(CityArt.WOOD.lightened(0.3)), 3.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -9), c + Vector2(6, -14), c + Vector2(14, -4), c + Vector2(5, 1)]), iron)
	# A rack of blades and a shield against the wall.
	draw_rect(Rect2(326, 270, 56, 4), _t(CityArt.TIMBER))
	for sx: float in [334.0, 346.0, 358.0]:
		draw_line(Vector2(sx, 262), Vector2(sx, 318), _t(Color("b8bcc4")), 3.0)
		draw_line(Vector2(sx - 5, 274), Vector2(sx + 5, 274), _t(Color("7a6a3a")), 3.0)
	draw_circle(Vector2(374, 300), 13.0, _t(Color("7a3028")))
	draw_arc(Vector2(374, 300), 13.0, 0.0, TAU, 16, _t(Color("c9a85a")), 2.0)
	# Quenching trough.
	draw_rect(Rect2(246, 296, 60, 24), _t(CityArt.WOOD.darkened(0.1)))
	draw_rect(Rect2(250, 298, 52, 6), _t(Color("3a5560")))


func _inn() -> void:
	var a := ambient
	CityArt.chimney(self, Rect2(48, 8, 18, 60), CityArt.STONE_DARK, a)
	CityArt.roof(self, 20, 230, 86, 62, 46, CityArt.ROOF_SLATE, a)
	CityArt.gable(self, 100, 150, 64, 26, CityArt.PLASTER, CityArt.ROOF_SLATE, a, 6.0)
	CityArt.window(self, Rect2(117, 46, 16, 16), glow, a, open)
	CityArt.wall(self, Rect2(20, 86, 210, 184), CityArt.PLASTER, a, 12.0)
	var beam := _t(CityArt.TIMBER)
	draw_rect(Rect2(20, 146, 210, 6), beam)
	draw_rect(Rect2(20, 208, 210, 6), beam)
	draw_rect(Rect2(20, 86, 6, 184), beam)
	draw_rect(Rect2(224, 86, 6, 184), beam)
	for row: float in [100.0, 160.0]:
		for x: float in [44.0, 110.0, 176.0]:
			CityArt.window(self, Rect2(x, row, 30, 34), glow, a, open)
			# Window boxes.
			draw_rect(Rect2(x - 4, row + 38, 38, 5), _t(Color("4f7a3a")))
			draw_circle(Vector2(x + 4, row + 38), 2.5, _t(Color("c94f4a")))
			draw_circle(Vector2(x + 22, row + 38), 2.5, _t(Color("e0c050")))
	CityArt.window(self, Rect2(40, 224, 36, 34), maxf(glow, 0.2), a, open)
	CityArt.window(self, Rect2(174, 224, 36, 34), maxf(glow, 0.2), a, open)
	CityArt.door(self, Rect2(105, 226, 40, 44), Color("5a3a2a"), a)
	# Awning over the door.
	draw_colored_polygon(PackedVector2Array([Vector2(92, 200), Vector2(158, 200), Vector2(166, 216), Vector2(84, 216)]),
		_t(Color("8f3b34")))
	draw_line(Vector2(84, 216), Vector2(166, 216), _t(Color("e2c477")), 2.0)
	# The sign: a crescent moon.
	var c := CityArt.sign_board(self, Vector2(230, 150), a, 1.0, Vector2(40, 36))
	draw_circle(c, 11.0, _t(Color("f0e2a8")))
	draw_circle(c + Vector2(5, -3), 9.5, _t(CityArt.WOOD.darkened(0.15)))


func _mason() -> void:
	var a := ambient
	# The crane: post, jib, stay, and a block of stone on the rope.
	var wood := _t(CityArt.WOOD)
	draw_line(Vector2(238, 18), Vector2(238, 200), wood, 8.0)
	draw_line(Vector2(238, 24), Vector2(310, 54), wood, 6.0)
	draw_line(Vector2(238, 24), Vector2(178, 70), _t(CityArt.WOOD.darkened(0.2)), 4.0)
	draw_line(Vector2(222, 200), Vector2(238, 150), wood, 5.0)
	draw_line(Vector2(254, 200), Vector2(238, 150), wood, 5.0)
	var swing := sin(time * 0.9) * 3.0 if open else 0.0
	draw_line(Vector2(306, 54), Vector2(306 + swing, 118), _t(Color("3a3028")), 2.0)
	draw_rect(Rect2(291 + swing, 118, 30, 22), _t(CityArt.STONE.lightened(0.12)))
	draw_rect(Rect2(291 + swing, 118, 30, 22), _t(CityArt.STONE_DARK), false, 1.5)
	# The shed.
	CityArt.wall(self, Rect2(18, 112, 164, 88), CityArt.WOOD.lightened(0.05), a, 8.0)
	for i in range(1, 8):
		draw_line(Vector2(18 + i * 20.5, 112), Vector2(18 + i * 20.5, 200), _t(CityArt.TIMBER), 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(6, 104), Vector2(194, 84), Vector2(194, 100), Vector2(6, 120)]),
		_t(CityArt.ROOF_THATCH))
	draw_line(Vector2(6, 120), Vector2(194, 100), _t(CityArt.ROOF_THATCH.darkened(0.4)), 3.0)
	CityArt.door(self, Rect2(110, 140, 40, 60), CityArt.TIMBER.lightened(0.1), a, false)
	CityArt.window(self, Rect2(40, 142, 34, 30), glow, a, open)
	# Dressed stone, stacked and waiting.
	var block := _t(CityArt.STONE.lightened(0.15))
	var edge := _t(CityArt.STONE_DARK)
	for r: Rect2 in [Rect2(196, 172, 42, 28), Rect2(262, 172, 42, 28), Rect2(270, 146, 40, 26), Rect2(20, 178, 0, 0)]:
		if r.size.x > 0.0:
			draw_rect(r, block)
			draw_rect(r, edge, false, 1.5)
	# A ladder against the shed.
	draw_line(Vector2(160, 200), Vector2(176, 96), wood, 3.0)
	draw_line(Vector2(174, 200), Vector2(190, 96), wood, 3.0)
	for i in 5:
		var t := (i + 0.5) / 5.0
		draw_line(Vector2(160, 200).lerp(Vector2(176, 96), t), Vector2(174, 200).lerp(Vector2(190, 96), t), wood, 2.0)


func _barracks() -> void:
	var a := ambient
	var sway := sin(time * 1.6)
	CityArt.banner(self, Vector2(112, 34), 64, 36, 44, CityArt.BANNER, a, sway)
	CityArt.banner(self, Vector2(284, 34), 64, 36, 44, CityArt.BANNER, a, sin(time * 1.6 + 1.2))
	# A squat tower and the long hall.
	CityArt.crenels(self, 4, 82, 44, 13, 12, CityArt.STONE, a)
	CityArt.wall(self, Rect2(6, 44, 74, 191), CityArt.STONE, a, 0.0)
	CityArt.stones(self, Rect2(6, 60, 74, 170), CityArt.STONE, a, 5)
	CityArt.crenels(self, 80, 322, 98, 14, 12, CityArt.STONE.darkened(0.06), a)
	CityArt.wall(self, Rect2(80, 98, 242, 137), CityArt.STONE.darkened(0.06), a, 0.0)
	CityArt.stones(self, Rect2(80, 110, 242, 120), CityArt.STONE, a, 2)
	var dark := Color(0.05, 0.05, 0.07)
	draw_rect(Rect2(38, 84, 9, 30), dark)
	draw_rect(Rect2(38, 150, 9, 30), dark)
	CityArt.window(self, Rect2(112, 150, 26, 34), glow, a, open, true)
	CityArt.window(self, Rect2(264, 150, 26, 34), glow, a, open, true)
	CityArt.door(self, Rect2(170, 164, 62, 71), CityArt.WOOD.darkened(0.2), a)
	# The city's shield over the door.
	var c := Vector2(201, 118)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-13, -12), c + Vector2(13, -12), c + Vector2(13, 3), c + Vector2(0, 15),
		c + Vector2(-13, 3)]), _t(CityArt.BANNER))
	UiTheme.stroke_points(self, PackedVector2Array([c + Vector2(-13, -12), c + Vector2(13, -12), c + Vector2(13, 3), c + Vector2(0, 15),
		c + Vector2(-13, 3)]), _t(Color("e2c477")), 2.0)
	# A training dummy in the yard.
	draw_line(Vector2(306, 235), Vector2(306, 176), _t(CityArt.WOOD), 5.0)
	draw_line(Vector2(288, 192), Vector2(324, 192), _t(CityArt.WOOD), 4.0)
	draw_circle(Vector2(306, 172), 9.0, _t(Color("c8b078")))
	# Spears stacked by the tower.
	for sx: float in [56.0, 64.0, 72.0]:
		draw_line(Vector2(sx, 235), Vector2(sx + 6, 168), _t(CityArt.WOOD.lightened(0.2)), 2.5)
		draw_colored_polygon(PackedVector2Array([Vector2(sx + 3, 168), Vector2(sx + 7, 156), Vector2(sx + 10, 169)]), _t(Color("c8ccd4")))


func _watchtower() -> void:
	var a := ambient
	CityArt.wall(self, Rect2(48, 96, 54, 274), CityArt.STONE, a, 0.0)
	CityArt.stones(self, Rect2(48, 110, 54, 250), CityArt.STONE, a, 4)
	draw_colored_polygon(PackedVector2Array([Vector2(36, 94), Vector2(114, 94), Vector2(102, 114), Vector2(48, 114)]),
		_t(CityArt.STONE.darkened(0.25)))
	CityArt.crenels(self, 34, 116, 66, 11, 10, CityArt.STONE.lightened(0.04), a)
	CityArt.wall(self, Rect2(34, 66, 82, 30), CityArt.STONE.lightened(0.04), a, 0.0)
	# A roof on posts over the beacon.
	draw_line(Vector2(44, 66), Vector2(44, 34), _t(CityArt.TIMBER), 4.0)
	draw_line(Vector2(106, 66), Vector2(106, 34), _t(CityArt.TIMBER), 4.0)
	CityArt.cone(self, 75, 36, 54, 36, CityArt.ROOF_RED, a)
	draw_colored_polygon(PackedVector2Array([Vector2(62, 60), Vector2(88, 60), Vector2(83, 68), Vector2(67, 68)]), _t(Color("2b2622")))
	var dark := Color(0.05, 0.05, 0.07)
	for y: float in [150.0, 226.0, 300.0]:
		draw_rect(Rect2(71, y, 8, 24), dark)
	CityArt.door(self, Rect2(63, 334, 24, 36), CityArt.WOOD.darkened(0.2), a)


func _gate() -> void:
	var a := ambient
	for x0: float in [0.0, 200.0]:
		CityArt.wall(self, Rect2(x0, 62, 80, 188), CityArt.STONE, a, 0.0)
		CityArt.stones(self, Rect2(x0, 80, 80, 160), CityArt.STONE, a, int(x0))
		CityArt.cone(self, x0 + 40.0, 64, 50, 62, CityArt.ROOF_SLATE, a)
		draw_rect(Rect2(x0 + 36.0, 112, 8, 28), Color(0.05, 0.05, 0.07))
	CityArt.crenels(self, 80, 200, 98, 13, 12, CityArt.STONE.darkened(0.08), a)
	CityArt.wall(self, Rect2(80, 98, 120, 152), CityArt.STONE.darkened(0.08), a, 0.0)
	# The arch.
	var frame := _t(CityArt.STONE_DARK.darkened(0.15))
	draw_circle(Vector2(140, 166), 44.0, frame)
	draw_rect(Rect2(96, 166, 88, 84), frame)
	var through := Color(0.05, 0.05, 0.07)
	draw_circle(Vector2(140, 166), 36.0, through)
	draw_rect(Rect2(104, 166, 72, 84), through)
	var iron := _t(Color("3a3632"))
	if attention:
		# Raised: the road outside shows through, and only the teeth of the portcullis hang down.
		draw_polygon(PackedVector2Array([Vector2(104, 250), Vector2(176, 250), Vector2(176, 170), Vector2(104, 170)]),
			PackedColorArray([Color(1.0, 0.8, 0.55, 0.75), Color(1.0, 0.8, 0.55, 0.75), Color(1.0, 0.7, 0.4, 0.0), Color(1.0, 0.7, 0.4, 0.0)]))
		for i in 7:
			var x := 110.0 + i * 10.0
			draw_line(Vector2(x, 134), Vector2(x, 158), iron, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 158), Vector2(x + 3, 158), Vector2(x, 166)]), iron)
	else:
		for i in 7:
			var x := 110.0 + i * 10.0
			draw_line(Vector2(x, 134), Vector2(x, 250), iron, 3.0)
		for y: float in [176.0, 204.0, 232.0]:
			draw_line(Vector2(104, y), Vector2(176, y), iron, 3.0)
	# The city's colours over the arch.
	draw_rect(Rect2(126, 102, 28, 22), _t(CityArt.BANNER))
	draw_colored_polygon(PackedVector2Array([Vector2(126, 124), Vector2(154, 124), Vector2(140, 136)]), _t(CityArt.BANNER))
	draw_colored_polygon(PackedVector2Array([Vector2(140, 105), Vector2(147, 114), Vector2(140, 123), Vector2(133, 114)]), _t(Color("e2c477")))
	# Torch brackets.
	for x: float in [92.0, 188.0]:
		draw_line(Vector2(x, 186), Vector2(x, 204), iron, 3.0)


## The drill yard: a ring of sand in the square, fenced, with straw men, a butt for the archers and a
## rack of wooden weapons.
func _yard() -> void:
	var a := ambient
	var wood := _t(CityArt.WOOD)
	var dark := _t(CityArt.TIMBER)
	var straw := _t(Color("c8b078"))
	var c := Vector2(145, 118)
	var r := Vector2(140, 46)
	# The sand, trodden darker in the middle.
	var ring := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 40:
		var d := Vector2.from_angle(TAU * k / 40.0)
		ring.append(c + d * r)
		inner.append(c + Vector2(0, 4) + d * r * 0.62)
	draw_colored_polygon(ring, _t(Color("b9a172")))
	draw_colored_polygon(inner, _t(Color("a48c60")))
	# The far side of the fence.
	_yard_fence(c, r, PI, TAU, wood, dark)
	# The city's colours on a pole at the back.
	CityArt.banner(self, Vector2(236, 8), 78, 32, 40, CityArt.BANNER, a, sin(time * 1.6 + 0.6))
	# The rack: wooden swords and a spear.
	draw_line(Vector2(22, 112), Vector2(22, 80), dark, 4.0)
	draw_line(Vector2(66, 108), Vector2(66, 76), dark, 4.0)
	draw_line(Vector2(18, 86), Vector2(70, 82), dark, 4.0)
	for x: float in [30.0, 40.0, 50.0]:
		draw_line(Vector2(x, 110), Vector2(x + 3, 64), _t(CityArt.WOOD.lightened(0.25)), 3.0)
		draw_line(Vector2(x - 3, 96), Vector2(x + 7, 95), _t(CityArt.WOOD.lightened(0.25)), 2.5)
	draw_line(Vector2(58, 110), Vector2(62, 44), _t(CityArt.WOOD.lightened(0.2)), 2.5)
	draw_colored_polygon(PackedVector2Array([Vector2(59, 46), Vector2(63, 32), Vector2(66, 46)]), _t(Color("c8ccd4")))
	# Two straw men; the nearer one still rocks from the last blow.
	_straw_man(Vector2(112, 124), 1.0, 0.0, wood, straw)
	_straw_man(Vector2(160, 134), 1.15, sin(time * 2.2) * 0.05 if open else 0.0, wood, straw)
	# The butt on its three legs.
	var b := Vector2(224, 96)
	draw_line(b, Vector2(206, 134), dark, 3.0)
	draw_line(b, Vector2(242, 134), dark, 3.0)
	draw_line(b, Vector2(226, 128), dark, 3.0)
	draw_circle(b, 21.0, straw)
	draw_circle(b, 15.0, _t(Color("e8e0cc")))
	draw_circle(b, 9.5, _t(Color("a8322c")))
	draw_circle(b, 4.0, _t(Color("e2c477")))
	draw_line(b + Vector2(3, -2), b + Vector2(22, -12), _t(Color("3a3028")), 1.5)
	# The near side of the fence, open at the front.
	_yard_fence(c, r, 0.0, PI * 0.36, wood, dark)
	_yard_fence(c, r, PI * 0.64, PI, wood, dark)


## Posts and two rails along the ring from angle `from` to `to`.
func _yard_fence(c: Vector2, r: Vector2, from: float, to: float, wood: Color, dark: Color) -> void:
	var n := maxi(2, int(round((to - from) / (PI / 7.0))) + 1)
	var last := Vector2.ZERO
	for i in n:
		var at := c + Vector2.from_angle(lerpf(from, to, float(i) / (n - 1))) * r
		if i > 0:
			draw_line(last + Vector2(0, -16), at + Vector2(0, -16), wood, 3.0)
			draw_line(last + Vector2(0, -7), at + Vector2(0, -7), wood, 3.0)
		last = at
	for i in n:
		var at := c + Vector2.from_angle(lerpf(from, to, float(i) / (n - 1))) * r
		draw_line(at, at + Vector2(0, -22), dark, 4.0)


## A straw man on a post at `foot`, leaning by `lean` radians.
func _straw_man(foot: Vector2, k: float, lean: float, wood: Color, straw: Color) -> void:
	var up := Vector2.UP.rotated(lean)
	var side := up.orthogonal()
	draw_line(foot, foot + up * 46.0 * k, wood, 4.0 * k)
	var chest := foot + up * 34.0 * k
	draw_line(chest - side * 17.0 * k, chest + side * 17.0 * k, wood, 3.5 * k)
	draw_colored_polygon(PackedVector2Array([chest - side * 9.0 * k + up * 8.0 * k, chest + side * 9.0 * k + up * 8.0 * k,
		chest + side * 7.0 * k - up * 16.0 * k, chest - side * 7.0 * k - up * 16.0 * k]), straw)
	draw_line(chest - side * 8.0 * k - up * 2.0 * k, chest + side * 8.0 * k - up * 2.0 * k, straw.darkened(0.3), 1.5)
	draw_circle(foot + up * 51.0 * k, 7.5 * k, straw)


## The infirmary: a low whitewashed house with a slate roof, a white board with a red cross for a
## sign, a lamp that burns all night, and linen drying on a line beside it.
func _infirmary() -> void:
	var a := ambient
	CityArt.chimney(self, Rect2(196, 22, 16, 44), CityArt.STONE_DARK, a)
	CityArt.roof(self, 26, 232, 82, 44, 34, CityArt.ROOF_SLATE, a)
	CityArt.wall(self, Rect2(26, 82, 206, 96), Color("e4dccb"), a, 10.0)
	var beam := _t(CityArt.TIMBER)
	draw_rect(Rect2(26, 82, 6, 96), beam)
	draw_rect(Rect2(226, 82, 6, 96), beam)
	draw_rect(Rect2(26, 170, 206, 8), _t(CityArt.STONE))
	# The sick room keeps a light: its windows glow a little even by day.
	CityArt.window(self, Rect2(46, 106, 32, 38), maxf(glow, 0.35), a, true)
	CityArt.window(self, Rect2(182, 106, 32, 38), maxf(glow, 0.35), a, true)
	CityArt.door(self, Rect2(108, 104, 44, 74), Color("6a7a6a"), a)
	# A lamp over the door.
	draw_line(Vector2(130, 88), Vector2(130, 96), _t(Color("2b2622")), 2.0)
	draw_circle(Vector2(130, 100), 14.0, Color(CityArt.LAMP, 0.10 + 0.16 * glow))
	draw_rect(Rect2(126, 95, 8, 10), CityArt.LAMP)
	# The sign: a red cross on a white board.
	var c := CityArt.sign_board(self, Vector2(26, 92), a, -1.0, Vector2(38, 36))
	draw_rect(Rect2(c - Vector2(15, 14), Vector2(30, 28)), _t(Color("efe8da")))
	draw_rect(Rect2(c.x - 4, c.y - 11, 8, 22), _t(Color("a8322c")))
	draw_rect(Rect2(c.x - 11, c.y - 4, 22, 8), _t(Color("a8322c")))
	# Linen on a line to the right, lifting in the wind.
	var post := _t(CityArt.WOOD)
	draw_line(Vector2(232, 112), Vector2(266, 108), _t(Color("3a3028")), 1.5)
	draw_line(Vector2(266, 178), Vector2(266, 104), post, 4.0)
	var lift := sin(time * 1.4) * 3.0
	for i in 2:
		var x := 238.0 + i * 13.0
		var top := 111.5 - i * 1.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 10, top - 1), Vector2(x + 10 + lift, top + 30),
			Vector2(x + lift, top + 32)]), _t(Color("efe8da") if i == 0 else Color("d8d0c0")))
	# A bench and a water butt by the door.
	draw_rect(Rect2(160, 156, 18, 22), _t(CityArt.WOOD.darkened(0.1)))
	draw_rect(Rect2(160, 162, 18, 2), _t(Color("2b2622")))
	draw_rect(Rect2(60, 160, 36, 5), _t(CityArt.WOOD))
	draw_rect(Rect2(63, 165, 4, 13), _t(CityArt.WOOD.darkened(0.2)))
	draw_rect(Rect2(89, 165, 4, 13), _t(CityArt.WOOD.darkened(0.2)))


## The jeweler's: a narrow shop under a steep slate roof by the wall, the day's stones laid out behind
## the glass of its bay window, a striped awning over it and a cut stone for a sign. Shut (not built
## yet), the window is boarded up and nothing is lit.
func _jeweler() -> void:
	var a := ambient
	var plaster := CityArt.PLASTER.lightened(0.05)
	CityArt.chimney(self, Rect2(136, 14, 14, 44), CityArt.STONE_DARK, a)
	CityArt.wall(self, Rect2(24, 66, 142, 86), plaster, a, 10.0)
	CityArt.gable(self, 24, 166, 68, 60, plaster, CityArt.ROOF_SLATE, a)
	var beam := _t(CityArt.TIMBER)
	draw_rect(Rect2(24, 66, 5, 86), beam)
	draw_rect(Rect2(161, 66, 5, 86), beam)
	draw_rect(Rect2(24, 100, 142, 5), beam)
	CityArt.window(self, Rect2(85, 32, 20, 24), glow, a, open, true)
	CityArt.window(self, Rect2(44, 74, 22, 20), glow, a, open)
	CityArt.window(self, Rect2(124, 74, 22, 20), glow, a, open)
	# The shop window: lit all day, with the stones on a dark cloth along its foot.
	var bay := Rect2(36, 114, 72, 32)
	draw_rect(bay.grow(3.0), beam)
	if open:
		draw_rect(bay, _t(Color("3a2c22")).lerp(CityArt.LAMP, 0.35 + 0.3 * glow))
		draw_circle(bay.get_center(), 44.0, Color(CityArt.LAMP, 0.06 + 0.10 * glow))
		draw_rect(Rect2(bay.position.x, bay.end.y - 11.0, bay.size.x, 11.0), Color(0.12, 0.08, 0.14))
		for i in 5:
			var at := Vector2(bay.position.x + 10.0 + i * 13.0, bay.end.y - 7.0)
			UiIcons.gem(self, at, 10.0, i + 1)
			var twinkle := 0.5 + 0.5 * sin(time * 2.4 + i * 1.7)
			draw_circle(at + Vector2(-1.5, -3.0), 1.2 + 0.8 * twinkle, Color(1, 1, 1, 0.35 + 0.5 * twinkle))
		draw_line(Vector2(bay.get_center().x, bay.position.y), Vector2(bay.get_center().x, bay.end.y), beam, 2.0)
	else:
		draw_rect(bay, _t(CityArt.WOOD.darkened(0.3)))
		for i in range(1, 5):
			var x := bay.position.x + bay.size.x * i / 5.0
			draw_line(Vector2(x, bay.position.y), Vector2(x, bay.end.y), _t(CityArt.TIMBER.darkened(0.2)), 2.0)
		draw_line(bay.position + Vector2(0, 6), bay.end - Vector2(0, 6), _t(Color("2b2622")), 3.0)
	# A striped awning over the window.
	var stripe_a := _t(Color("2f6b62"))
	var stripe_b := _t(Color("e6dcc0"))
	for i in 6:
		var x0 := 30.0 + i * 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 4.0, 103), Vector2(x0 + 16.0, 103), Vector2(x0 + 14.0, 114), Vector2(x0, 114)]),
			stripe_a if i % 2 == 0 else stripe_b)
	draw_line(Vector2(30, 114), Vector2(114, 114), _t(Color("e2c477")), 2.0)
	CityArt.door(self, Rect2(122, 110, 30, 42), Color("34485a"), a)
	draw_rect(Rect2(116, 148, 42, 4), _t(CityArt.STONE.lightened(0.1)))
	# The sign: a cut stone.
	var c := CityArt.sign_board(self, Vector2(24, 78), a, -1.0, Vector2(34, 32))
	UiIcons.gem(self, c + Vector2(0, 1), 22.0, 5 if open else 2, 1.0 if open else 0.55)
