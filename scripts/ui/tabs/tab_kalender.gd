class_name TabKalender
extends TabBase
## Monatskalender: Spieltagstermine des eigenen Vereins, heutiger Tag markiert.

const MONTHS := ["Januar", "Februar", "März", "April", "Mai", "Juni",
	"Juli", "August", "September", "Oktober", "November", "Dezember"]
const DAYS_IN_MONTH := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var _view_month := 8
var _view_year := 2026
var _initialized := false

var _month_label: Label
var _grid: GridContainer

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(heading("Kalender"))
	var prev := Button.new()
	prev.text = "←"
	prev.pressed.connect(_shift_month.bind(-1))
	top.add_child(prev)
	_month_label = Label.new()
	_month_label.add_theme_font_size_override("font_size", 20)
	_month_label.custom_minimum_size = Vector2(200, 0)
	_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_month_label)
	var next := Button.new()
	next.text = "→"
	next.pressed.connect(_shift_month.bind(1))
	top.add_child(next)
	var legend := info_label()
	legend.text = "     ▪ Grün: heute   ·   ▪ Vereinsfarbe: Spieltag   ·   🎯 Spielvorbereitung   ·   Training an allen übrigen Tagen"
	top.add_child(legend)

	var header := GridContainer.new()
	header.columns = 7
	header.add_theme_constant_override("h_separation", 8)
	box.add_child(header)
	for day_name in ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]:
		var l := Label.new()
		l.text = day_name
		l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		l.custom_minimum_size = Vector2(150, 0)
		header.add_child(l)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func refresh() -> void:
	if not _initialized:
		var today := Game.date_dict()
		_view_month = int(today.month)
		_view_year = int(today.year)
		_initialized = true
	_rebuild()

func _shift_month(delta: int) -> void:
	_view_month += delta
	if _view_month > 12:
		_view_month = 1
		_view_year += 1
	elif _view_month < 1:
		_view_month = 12
		_view_year -= 1
	_rebuild()

func _days_in(month: int, year: int) -> int:
	if month == 2 and (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)):
		return 29
	return DAYS_IN_MONTH[month - 1]

func _rebuild() -> void:
	_month_label.text = "%s %d" % [MONTHS[_view_month - 1], _view_year]
	while _grid.get_child_count() > 0:
		var child := _grid.get_child(0)
		_grid.remove_child(child)
		child.free()

	# Spieltage und Spielvorbereitungs-Tage des Monats sammeln
	var matchdays := {}
	var prep_days := {}
	var dates: Array = Game.world.matchday_dates
	for i in dates.size():
		var d: Dictionary = Time.get_datetime_dict_from_unix_time(int(dates[i]))
		if int(d.month) == _view_month and int(d.year) == _view_year:
			matchdays[int(d.day)] = i
		var prep: Dictionary = Time.get_datetime_dict_from_unix_time(int(dates[i]) - 86400)
		if int(prep.month) == _view_month and int(prep.year) == _view_year:
			prep_days[int(prep.day)] = i
	var today := Game.date_dict()
	var is_this_month: bool = int(today.month) == _view_month and int(today.year) == _view_year

	var first_unix := int(Time.get_unix_time_from_datetime_dict({
		"year": _view_year, "month": _view_month, "day": 1, "hour": 12, "minute": 0, "second": 0}))
	var lead_days: int = (int(Time.get_datetime_dict_from_unix_time(first_unix).weekday) + 6) % 7
	for i in lead_days:
		_grid.add_child(Control.new())

	var c := Game.my_club()
	for day in range(1, _days_in(_view_month, _view_year) + 1):
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(150, 86)
		var style := UITheme.box(UITheme.FIELD, 8, UITheme.BORDER, 8)
		if is_this_month and day == int(today.day):
			style.border_color = UITheme.ACCENT
			style.set_border_width_all(2)
		if matchdays.has(day):
			style.bg_color = Color(c.color).darkened(0.55)
		cell.add_theme_stylebox_override("panel", style)
		_grid.add_child(cell)

		var cell_box := VBoxContainer.new()
		cell_box.add_theme_constant_override("separation", 2)
		cell.add_child(cell_box)
		var num := Label.new()
		num.text = str(day)
		num.add_theme_font_size_override("font_size", 15)
		num.add_theme_color_override("font_color", UITheme.ACCENT if (is_this_month and day == int(today.day)) else UITheme.TEXT_DIM)
		cell_box.add_child(num)

		if matchdays.has(day):
			var md: int = matchdays[day]
			var md_label := Label.new()
			md_label.text = "Spieltag %d" % (md + 1)
			md_label.add_theme_font_size_override("font_size", 13)
			cell_box.add_child(md_label)
			var f := Game.my_league().fixture_of(c.id, md)
			if not f.is_empty():
				var home := int(f.home) == c.id
				var opponent := Game.club(int(f.away) if home else int(f.home))
				var vs := Label.new()
				if f.played:
					vs.text = "%d:%d %s %s" % [int(f.hg), int(f.ag), "vs" if home else "bei", opponent.short_name]
				else:
					vs.text = "%s %s (%s)" % ["vs" if home else "bei", opponent.short_name, "H" if home else "A"]
				vs.add_theme_font_size_override("font_size", 13)
				vs.add_theme_color_override("font_color", UITheme.TEXT_DIM)
				cell_box.add_child(vs)
		elif prep_days.has(day):
			var prep_label := Label.new()
			prep_label.text = "🎯 Spielvorbereitung"
			prep_label.add_theme_font_size_override("font_size", 12)
			prep_label.add_theme_color_override("font_color", UITheme.ACCENT)
			cell_box.add_child(prep_label)
			var plan_label := Label.new()
			plan_label.text = "Plan: %s" % Game.match_plan
			plan_label.add_theme_font_size_override("font_size", 11)
			plan_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			cell_box.add_child(plan_label)
		else:
			var training_label := Label.new()
			training_label.text = "Training: %s" % Game.training_focus
			training_label.add_theme_font_size_override("font_size", 11)
			training_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			cell_box.add_child(training_label)