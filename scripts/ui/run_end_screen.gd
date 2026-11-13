class_name RunEndScreen
extends Control
## The end of a run: victory or defeat, why, the day reached, a few numbers, and a new run.

signal new_run_pressed

var _ribbon := SlantPanel.new()
var _title: Label
var _reason: Label
var _stats: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open(run: Run) -> void:
	var won := run.outcome == Run.Outcome.VICTORY
	_title.text = "VICTORY" if won else "DEFEAT"
	_title.add_theme_color_override("font_color", UiTheme.GOLD if won else UiTheme.INJURED)
	_ribbon.border = UiTheme.GOLD if won else UiTheme.INJURED
	_reason.text = run.end_reason
	var survivors: Array[String] = []
	for c in run.roster:
		survivors.append(c.display_name())
	var lost: Array[String] = []
	for d in run.gone:
		lost.append(d.display_name)
	_stats.text = "DAY REACHED   %d / %d\nBATTLES   %d won, %d lost\nCITY HEALTH   %d / %d\nGOLD   %d\nSTILL STANDING   %s\nLOST   %s" % [
		run.day, RunConfig.DAYS, run.battles_won, run.battles_lost, run.city_health, RunConfig.CITY_MAX_HEALTH, run.gold,
		", ".join(survivors) if not survivors.is_empty() else "nobody", ", ".join(lost) if not lost.is_empty() else "nobody"]
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func _build() -> void:
	var backdrop := CityBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_ribbon.fill = Color(UiTheme.INK, 0.96)
	_ribbon.border_width = 5.0
	_ribbon.position = Vector2(960 - 560, 150)
	_ribbon.size = Vector2(1120, 220)
	add_child(_ribbon)
	_title = UiTheme.label("", 150, UiTheme.GOLD, true)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ribbon.add_child(_title)

	_reason = UiTheme.label("", 30, UiTheme.TEXT, true, 6)
	_reason.position = Vector2(260, 400)
	_reason.size = Vector2(1400, 44)
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_reason)

	_stats = UiTheme.label("", 24, UiTheme.MUTED, false, 4)
	_stats.position = Vector2(560, 480)
	_stats.size = Vector2(800, 260)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stats)

	var again := Button.new()
	again.text = "NEW RUN"
	again.tooltip_text = "Start a new run: day 1, two new companions, a full city."
	again.focus_mode = Control.FOCUS_NONE
	again.add_theme_font_size_override("font_size", 36)
	again.position = Vector2(960 - 200, 790)
	again.size = Vector2(400, 72)
	again.pressed.connect(func() -> void: new_run_pressed.emit())
	add_child(again)
