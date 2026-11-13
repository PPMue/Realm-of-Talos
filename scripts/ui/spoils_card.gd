class_name SpoilsCard
extends Control
## One companion after a battle: their face, their level with the XP bar filling by what the battle
## gave (the level number turns over each time the bar fills), and how far their weapon and magic
## grades came. XP is shared by what each did, so the card also shows it: a skull on the face for every
## enemy they felled, and gold marks beside the name of whoever did the most. Injured is written
## across the face of whoever goes to the infirmary. The details are in the tooltip.

const W := 244.0
const H := 392.0
const PORTRAIT_H := 176.0
const PAD := 8.0

var _portrait := SlantPanel.new()
var _marks := Control.new()
var _name := ""
var _level_before := 1
var _level_after := 1
var _xp_before := 0
var _xp_after := 0
var _xp_gained := 0
## [{text, gained, frac, rose}] one per weapon or magic grade worth showing.
var _lines: Array = []
var _learned: Array[String] = []
var _status := ""
var _kills := 0
var _foremost := false
## XP of this battle counted in so far.
var _shown := 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait.position = Vector2(PAD, PAD)
	_portrait.size = Vector2(W - PAD * 2.0, PORTRAIT_H)
	_portrait.shade = 0.5
	_portrait.border_width = 0.0
	_portrait.backing = true
	add_child(_portrait)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.position = _portrait.position
	_marks.size = _portrait.size
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


## `status`: "" or "INJURED" (they go to the infirmary).
func setup(data: CompanionData, display_name: String, level_before: int, level_after: int, xp_before: int, xp_after: int, xp_gained: int,
		lines: Array, learned: Array[String], status: String, kills: int = 0, foremost: bool = false) -> void:
	_kills = kills
	_foremost = foremost
	_name = display_name
	_level_before = level_before
	_level_after = level_after
	_xp_before = xp_before
	_xp_after = xp_after
	_xp_gained = xp_gained
	_lines = lines
	_learned = learned
	_status = status
	_portrait.texture = data.portrait
	_portrait.focus = data.portrait_focus + Vector2(0.0, 0.05)
	_portrait.zoom = 1.7 * data.figure_scale
	_portrait.tint = Color(0.8, 0.5, 0.48) if status == "INJURED" else Color.WHITE
	_shown = 0.0
	queue_redraw()
	_marks.queue_redraw()


## Fills the XP bar by what the battle gave, over `seconds`.
func play(seconds: float) -> void:
	finish()
	if _xp_gained <= 0:
		return
	_shown = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_shown, 0.0, float(_xp_gained), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func finish() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_set_shown(float(_xp_gained))


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


func _set_shown(v: float) -> void:
	_shown = v
	queue_redraw()
	_marks.queue_redraw()


## Level, XP into it and XP it needs, with `_shown` of the battle's XP counted in.
func _standing() -> Vector3i:
	if _shown >= float(_xp_gained):
		return Vector3i(_level_after, _xp_after, Levels.xp_to_next(_level_after))
	var level := _level_before
	var xp := _xp_before + int(floor(_shown))
	while level < _level_after and xp >= Levels.xp_to_next(level):
		xp -= Levels.xp_to_next(level)
		level += 1
	return Vector3i(level, xp, Levels.xp_to_next(level))


func _draw() -> void:
	var st := _standing()
	var rose := st.x > _level_before
	var rect := Rect2(Vector2.ZERO, size)
	UiTheme.draw_frame(self, rect, Color(UiTheme.PANEL, 0.96), UiTheme.GOLD if rose else UiTheme.EDGE, 2.5 if rose else 2.0, false)
	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var italic := UiTheme.italic_font()
	var y := PAD + PORTRAIT_H + 8.0
	var name_ink := UiTheme.GOLD if _foremost else UiTheme.TEXT
	UiTheme.draw_text(self, display, Vector2(0, y), _name, 27, name_ink, 4, W, HORIZONTAL_ALIGNMENT_CENTER)
	if _foremost:
		var half := display.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 27).x * 0.5 + 16.0
		for side: float in [-1.0, 1.0]:
			UiIcons.diamond(self, Vector2(W * 0.5 + side * half, y + 19.0), 5.0, UiTheme.GOLD)
	y += 36.0
	UiTheme.draw_text(self, italic, Vector2(0, y), "Level %d" % st.x, 20, UiTheme.GOLD if rose else UiTheme.MUTED, 0, W,
		HORIZONTAL_ALIGNMENT_CENTER)
	y += 32.0
	# The XP bar.
	var bar := Rect2(20.0, y, W - 40.0, 12.0)
	draw_rect(bar, Color(0.03, 0.025, 0.02, 0.9))
	if st.z > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(st.y) / st.z, 0.0, 1.0), bar.size.y)), UiTheme.GOLD)
	else:
		draw_rect(bar, UiTheme.GOLD_DEEP)
	draw_rect(bar, Color(UiTheme.EDGE, 0.9), false, 1.0)
	y += 15.0
	if _xp_gained > 0:
		UiTheme.draw_text(self, display, Vector2(20.0, y), "+%d XP" % int(floor(_shown)), 21, UiTheme.GOLD, 3)
	UiTheme.draw_text(self, body, Vector2(20.0, y + 5.0), "top level" if st.z == 0 else "%d / %d" % [st.y, st.z], 15, UiTheme.MUTED, 0, W - 40.0,
		HORIZONTAL_ALIGNMENT_RIGHT)
	y += 33.0
	# Grades: the name, what the battle added, and a thin line of the way to the next grade.
	for line: Dictionary in _lines:
		var ink := UiTheme.GOLD if line.rose else UiTheme.TEXT.lerp(UiTheme.MUTED, 0.3)
		UiTheme.draw_text(self, body, Vector2(20.0, y), String(line.text), 17, ink)
		if int(line.gained) > 0:
			UiTheme.draw_text(self, body, Vector2(20.0, y), "+%d" % int(line.gained), 17, UiTheme.GOLD, 0, W - 40.0, HORIZONTAL_ALIGNMENT_RIGHT)
		var track := Rect2(20.0, y + 23.0, W - 40.0, 3.0)
		draw_rect(track, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(line.frac), 0.0, 1.0), 3.0)), Color(ink, 0.9))
		y += 32.0
	if not _learned.is_empty():
		var text := "learned " + ", ".join(_learned)
		var font_size := 16
		while font_size > 12 and italic.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > W - 24.0:
			font_size -= 1
		UiTheme.draw_text(self, italic, Vector2(0, y), text, font_size, UiTheme.GOLD, 0, W, HORIZONTAL_ALIGNMENT_CENTER)


## Across the face: a level gained, or what the battle cost them.
func _draw_marks() -> void:
	var display := UiTheme.display_font()
	var w := _marks.size.x
	if _standing().x > _level_before:
		var band := Rect2(0, 0, w, 30.0)
		_marks.draw_rect(band, Color(UiTheme.INK, 0.86))
		_marks.draw_rect(Rect2(0, 29.0, w, 1.5), UiTheme.GOLD)
		UiTheme.draw_text(_marks, display, Vector2(0, 3.0), "LEVEL UP", 19, UiTheme.GOLD, 0, w, HORIZONTAL_ALIGNMENT_CENTER)
	# A skull for every enemy they felled, along the foot of the face.
	var foot := _marks.size.y - (32.0 if _status != "" else 0.0)
	for i in _kills:
		var at := Vector2(18.0 + i * 28.0, foot - 18.0)
		_marks.draw_circle(at, 13.0, Color(UiTheme.INK, 0.82))
		UiIcons.skull(_marks, at, 17.0, UiTheme.TEXT)
	if _status != "":
		var color := UiTheme.INJURED
		var band := Rect2(0, _marks.size.y - 32.0, w, 32.0)
		_marks.draw_rect(band, Color(UiTheme.INK, 0.88))
		UiTheme.draw_text(_marks, display, Vector2(0, band.position.y + 4.0), _status, 19, color, 0, w, HORIZONTAL_ALIGNMENT_CENTER)
