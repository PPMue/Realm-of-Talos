class_name FrontCard
extends Control
## One front to defend on the city screen: the enemies waiting there, the danger, what winning gives
## and what losing costs, and a button to go. Also used, wider, for the boss.

signal chosen

const W := 520.0
const BOSS_W := 980.0
const H := 520.0
const ART_H := 214.0
const PAD := 8.0
const DANGER_COLORS: Array[Color] = [Color("86e27a"), Color("f2a541"), Color("ff5d5d")]
const DANGER_NAMES: Array[String] = ["LOW", "MEDIUM", "HIGH"]

var front: Front
var _w := W
var _bg := SlantPanel.new()
var _button := ActionButton.new()
var _pips: Control
var _hover := false
var _enabled := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void:
		_hover = true
		_restyle())
	mouse_exited.connect(func() -> void:
		_hover = false
		_restyle())


## `why_not`: when not "", the card cannot be chosen and says why instead.
func setup(p_front: Front, hotkey: String, why_not: String = "") -> void:
	front = p_front
	_w = BOSS_W if front.is_boss else W
	custom_minimum_size = Vector2(_w, H)
	size = custom_minimum_size
	_enabled = why_not == ""

	_bg.size = size
	_bg.fill = Color(UiTheme.PANEL, 0.96)
	add_child(_bg)

	_build_art()

	var y := PAD + ART_H + 14.0
	# Danger pips and word.
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.position = Vector2(_edge_x(y + 30.0) + 26.0, y)
	_pips.size = Vector2(_w * 0.6, 30)
	_pips.draw.connect(_draw_pips)
	add_child(_pips)
	y += 40.0

	var title := UiTheme.label(front.title().to_upper(), 44 if front.is_boss else 40, UiTheme.TEXT, true, 8)
	title.position = Vector2(_edge_x(y + 50.0) + 22.0, y)
	add_child(title)
	y += 54.0
	var who: Array[String] = []
	for e in front.enemies:
		who.append(e.display_name)
	var sub_text := front.group.display_name.to_upper() + "  ·  " + ", ".join(who)
	if front.is_boss:
		who.remove_at(0)
		sub_text = "BOSS" + ("  ·  with " + ", ".join(who) if not who.is_empty() else "  ·  alone")
	var sub := UiTheme.label(sub_text, 18, UiTheme.MUTED)
	sub.position = Vector2(_edge_x(y + 24.0) + 26.0, y)
	add_child(sub)
	y += 40.0

	y = _add_row(y, "REWARD", _reward_text(), UiTheme.GOLD)
	var loss := "THE RUN ENDS" if front.is_boss else "CITY  -%d HEALTH" % front.city_damage
	y = _add_row(y, "IF LOST", loss, UiTheme.INJURED)

	_button.title = "DEFEND" if not front.is_boss else "FACE THE BOSS"
	_button.hotkey = hotkey
	_button.detail = ""
	_button.position = Vector2(_edge_x(H - 18.0) + (_w - UiTheme.SLANT * H - ActionButton.W) * 0.5, H - 18.0 - ActionButton.H)
	_button.disabled = not _enabled
	_button.pressed.connect(func() -> void: chosen.emit())
	_button.tooltip_text = why_not if not _enabled else "Commit to this front. The party fights now; changes to the party are locked until tomorrow."
	add_child(_button)
	_restyle()


func _reward_text() -> String:
	var parts: Array[String] = []
	if front.reward_gold > 0:
		parts.append("%d GOLD" % front.reward_gold)
	for m in RunConfig.MATERIAL_ORDER:
		if int(front.reward_materials.get(m, 0)) > 0:
			parts.append("%d %s" % [int(front.reward_materials[m]), String(RunConfig.MATERIAL_NAMES[m]).to_upper()])
	if parts.is_empty():
		return "THE CITY IS SAVED"
	return "  ·  ".join(parts)


func _add_row(y: float, head: String, text: String, color: Color) -> float:
	var h := UiTheme.label(head, 18, UiTheme.MUTED, true)
	h.position = Vector2(_edge_x(y + 30.0) + 26.0, y + 4.0)
	add_child(h)
	var l := UiTheme.label(text, 24, color, true, 6)
	l.position = Vector2(_edge_x(y + 30.0) + 130.0, y)
	add_child(l)
	return y + 38.0


func _build_art() -> void:
	var count := maxi(1, front.enemies.size())
	var inner := _w - UiTheme.SLANT * H + UiTheme.slant_for(ART_H) - PAD * 2.0
	var lean := UiTheme.slant_for(ART_H)
	# Neighbouring portraits share their leaning edge.
	var slot := (inner - lean) / count
	for i in front.enemies.size():
		var e := front.enemies[i]
		var p := SlantPanel.new()
		p.texture = e.portrait
		p.focus = Vector2(0.5, 0.2 if front.is_boss and i == 0 else 0.28)
		p.zoom = 1.0 if front.is_boss else (1.2 + 0.15 * (count - 1))
		p.shade = 0.7
		p.border = Color(UiTheme.INK, 0.9)
		p.border_width = 2.0
		p.position = Vector2(_edge_x(PAD + ART_H) + PAD + slot * i, PAD)
		p.size = Vector2(slot + lean, ART_H)
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.tooltip_text = enemy_info(e)
		add_child(p)
		var n := UiTheme.label(e.display_name.to_upper(), 20 if count > 2 else 24, UiTheme.TEXT, true, 6)
		n.position = Vector2(lean * 0.2 + 12.0, ART_H - 36.0)
		p.add_child(n)


## Stats and action list of an enemy, for tooltips.
static func enemy_info(e: EnemyData) -> String:
	var lines: Array[String] = [e.display_name,
		"HP %d   STR %d   DEF %d   SPD %d   DEX %d   LCK %d" % [e.max_hp, e.strength, e.defense, e.speed, e.dexterity, e.luck], ""]
	for a in e.actions:
		var what := EnemyActionData.intent_name(a.intent).capitalize()
		if a.targeting == EnemyActionData.Targeting.ALL_COMPANIONS:
			what += ", everyone"
		if a.deals_damage:
			what += ", Mt %d" % a.might
		if a.effect != null:
			what += ", " + a.effect.summary()
		lines.append("%s  (countdown %d): %s" % [a.display_name, a.countdown, what])
	return "\n".join(lines)


func _draw_pips() -> void:
	var c := DANGER_COLORS[front.danger - 1]
	var font := UiTheme.display_font()
	UiTheme.draw_text(_pips, font, Vector2(0, 2), "DANGER", 20, UiTheme.MUTED)
	for i in 3:
		var r := Rect2(96.0 + i * 40.0, 2.0, 34.0, 24.0)
		UiTheme.fill_para(_pips, r, c if i < front.danger else Color(UiTheme.INK, 0.8))
		UiTheme.stroke_para(_pips, r, c if i < front.danger else UiTheme.EDGE, 2.0)
	UiTheme.draw_text(_pips, font, Vector2(226.0, 2), DANGER_NAMES[front.danger - 1], 22, c)


func _restyle() -> void:
	var lit := _hover and _enabled
	_bg.border = UiTheme.GOLD if lit or front.is_boss else UiTheme.EDGE
	_bg.border_width = 4.0 if lit else (3.0 if front.is_boss else 2.0)
	_bg.fill = Color(UiTheme.PANEL_HI, 0.97) if lit else Color(UiTheme.PANEL, 0.96)
	_button.active = lit


func _edge_x(y: float) -> float:
	return UiTheme.SLANT * (H - y)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and _enabled:
		accept_event()
		chosen.emit()
