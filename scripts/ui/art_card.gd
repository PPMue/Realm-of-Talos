class_name ArtCard
extends Control
## One known combat art on the arts screen: tier, name, cost, what it does, and whether it is equipped.
## Clicking it asks to equip or unequip; the arts screen decides.

signal pressed

const W := 1240.0
const H := 104.0
const TAG_W := 196.0

var art: CombatArtData
## 0 = not equipped, else its place among the equipped arts (1-3), which is its place in the action list.
var equipped_slot := 0
var signature := false
## False when every slot is taken (and this art is not one of them).
var can_equip := true
## Set when the companion's weapon is of another type: the art could be equipped but not used.
var wrong_weapon := false

var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = custom_minimum_size
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if equipped_slot > 0 or can_equip:
			pressed.emit()


func _draw() -> void:
	if art == null:
		return
	var equipped := equipped_slot > 0
	var toggles := equipped or can_equip
	var lit := _hover and toggles
	var rect := Rect2(Vector2.ZERO, Vector2(W, H))
	var fill := Color(UiTheme.PANEL_HI, 0.97) if equipped else Color(UiTheme.PANEL, 0.94)
	var edge := UiTheme.GOLD if equipped else UiTheme.EDGE
	if lit:
		edge = UiTheme.TEXT if equipped else Color(UiTheme.GOLD, 0.8)
	UiTheme.fill_para(self, rect, fill)
	UiTheme.stroke_para(self, rect, edge, 3.0 if equipped or lit else 2.0)

	var display := UiTheme.display_font()
	var body := UiTheme.body_font()
	var s := UiTheme.slant_for(H)

	# Tier badge.
	var badge := Rect2(s * 0.5 + 16.0, 16.0, 78.0, H - 32.0)
	var badge_fill: Color = [UiTheme.EDGE, UiTheme.GOLD_DEEP, UiTheme.GOLD][clampi(art.tier - 1, 0, 2)]
	UiTheme.fill_para(self, badge, badge_fill)
	UiTheme.draw_text(self, display, Vector2(badge.position.x, badge.position.y + (badge.size.y - display.get_height(36)) * 0.5),
		CombatArtData.tier_numeral(art.tier), 36, UiTheme.INK if art.tier > 1 else UiTheme.TEXT, 0, badge.size.x, HORIZONTAL_ALIGNMENT_CENTER)

	# Name and costs.
	var x := badge.end.x + 22.0
	UiTheme.draw_text(self, display, Vector2(x, 12.0), art.display_name.to_upper(), 34, UiTheme.TEXT, 6)
	var meta := "%s ART  ·  TIER %d  ·  %d STA  ·  RECOVERY %d" % [art.type_name().to_upper(), art.tier, art.stamina_cost, art.recovery]
	UiTheme.draw_text(self, body, Vector2(x, 60.0), meta, 15, UiTheme.MUTED)

	# What it does.
	var text_x := 520.0
	var text_w := W - TAG_W - 60.0 - text_x
	draw_multiline_string(body, Vector2(text_x, 14.0 + body.get_ascent(17)), art.description, HORIZONTAL_ALIGNMENT_LEFT,
		text_w, 17, 1, UiTheme.TEXT)
	draw_multiline_string(body, Vector2(text_x, 44.0 + body.get_ascent(16)), art.effect_summary(), HORIZONTAL_ALIGNMENT_LEFT,
		text_w, 16, 2, UiTheme.GOLD)

	# Equip tag on the right.
	var tag := Rect2(W - TAG_W - s * 0.5 - 20.0, 22.0, TAG_W, H - 44.0)
	var tag_text := "EQUIPPED  %d" % equipped_slot if equipped else ("EQUIP" if can_equip else "SLOTS FULL")
	var tag_fill := UiTheme.GOLD if equipped else (Color(UiTheme.INK, 0.9) if can_equip else Color(UiTheme.INK, 0.6))
	var tag_ink := UiTheme.INK if equipped else (UiTheme.GOLD if can_equip else Color(UiTheme.MUTED, 0.6))
	UiTheme.fill_para(self, tag, tag_fill)
	UiTheme.stroke_para(self, tag, UiTheme.GOLD if can_equip or equipped else Color(UiTheme.EDGE, 0.6), 2.0)
	UiTheme.draw_text(self, display, Vector2(tag.position.x, tag.position.y + (tag.size.y - display.get_height(24)) * 0.5),
		tag_text, 24, tag_ink, 0, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var notes: Array[String] = []
	if signature:
		notes.append("SIGNATURE")
	if wrong_weapon:
		notes.append("NEEDS A %s" % art.type_name().to_upper())
	if not notes.is_empty():
		UiTheme.draw_text(self, body, Vector2(tag.position.x - 10.0, H - 21.0), "  ·  ".join(notes), 13,
			UiTheme.RECOVERING if wrong_weapon else UiTheme.MUTED, 0, tag.size.x, HORIZONTAL_ALIGNMENT_CENTER)
