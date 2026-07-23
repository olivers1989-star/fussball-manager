extends Control
## Spieltag live im modernen Manager-Design: Anzeigetafel mit Spielfortschritt,
## Liveticker mit Ereignis-Symbolen, Taktik-Panel (Spielweise, Wechsel von der
## Bank, Positionen der Elf) und Konferenz. Eingriffe wirken ab der nächsten Minute.

const SPEEDS := {"1×": 0.35, "2×": 0.15, "4×": 0.05}

## Ansprachen vor dem Spiel: mutiger = mehr Wirkung, aber auch mehr Risiko.
## Die Fähigkeit "Motivation" erhöht die Chance, dass die Ansprache zündet.
const SPEECHES := [
	{"text": "Ganz normal weiter – ihr wisst, was zu tun ist.", "bonus": 0.010, "risk": 0.000},
	{"text": "Gebt euer Bestes – mehr verlange ich nicht.", "bonus": 0.020, "risk": 0.010},
	{"text": "Wir verlieren das heute nicht!", "bonus": 0.030, "risk": 0.020},
	{"text": "Heute zeigen wir denen, wer wir sind!", "bonus": 0.045, "risk": 0.035},
]

## Anzeige-Koordinaten je Zone (für Teams ohne freie Feldpunkte, z. B. Gegner).
const ZONE_SPOTS := {
	"TW": Vector2(0.5, 0.06), "LV": Vector2(0.14, 0.3), "IV": Vector2(0.5, 0.24), "RV": Vector2(0.86, 0.3),
	"DM": Vector2(0.5, 0.44), "ZM": Vector2(0.5, 0.55), "OM": Vector2(0.5, 0.68),
	"LM": Vector2(0.12, 0.55), "RM": Vector2(0.88, 0.55),
	"LA": Vector2(0.15, 0.84), "RA": Vector2(0.85, 0.84), "MS": Vector2(0.5, 0.86),
}

var _md := {}                 # {mine: MatchSim, others: [MatchSim]}
var _my_sim: MatchSim
var _my_home := false
var _event_index := 0
var _running := false

var _scoreboard: PanelContainer
var _score_label: Label
var _minute_label: Label
var _progress: ProgressBar
var _status_line: Label
var _ticker: RichTextLabel
var _prematch_panel: CenterContainer
var _live_box: HBoxContainer
var _controls_bar: HBoxContainer
var _pause_button: Button
var _speed_buttons := {}
var _post_panel: VBoxContainer
var _other_results: VBoxContainer
var _ratings_box: VBoxContainer
var _conference: VBoxContainer
var _conf_rows := {}          # "hid-aid" -> {row, score, minute, last}
var _poss_left: Label
var _poss_right: Label
var _mentality_buttons := {}
var _team_panel_h: PanelContainer
var _team_panel_a: PanelContainer
var _subs_label: Label
var _tactic_message: Label
var _timer: Timer
var _stats_grid: GridContainer
var _poss_bar: ProgressBar
var _overlay: PanelContainer
var _my_pitch: MatchPitch
var _opp_pitch: MatchPitch
var _overlay_bench_box: VBoxContainer
var _overlay_list: VBoxContainer
var _overlay_message: Label
var _overlay_subs: Label
var _live_spots := {}         # pid -> Vector2 (Anzeigeposition meiner Elf)
var _overlay_selected := -1
var _overlay_dragging := false   # true, solange eine Listenzeile gezogen wird
var _was_running := false
var _speech_buttons: Array = []
var _speech_index := 0

func _ready() -> void:
	if Game.next_fixture(Game.my_club_id).is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/hub.tscn")
		return
	_md = Game.start_matchday()
	_my_sim = _md.mine
	_my_home = _my_sim.home.id == Game.my_club_id
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_scoreboard = _build_scoreboard()
	box.add_child(_scoreboard)

	# --- Vorschau vor Anpfiff
	_prematch_panel = CenterContainer.new()
	_prematch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_prematch_panel)
	_prematch_panel.add_child(_build_prematch())

	# --- Live-Bereich: links Ticker, rechts Taktik & Konferenz
	_live_box = HBoxContainer.new()
	_live_box.add_theme_constant_override("separation", 14)
	_live_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_live_box.visible = false
	box.add_child(_live_box)

	# Linke Spalte: beide Mannschaften nebeneinander, darunter der Ticker
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 10)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.55
	_live_box.add_child(left_col)

	var teams_row := HBoxContainer.new()
	teams_row.add_theme_constant_override("separation", 10)
	left_col.add_child(teams_row)
	_team_panel_h = _build_team_panel(_my_sim.home, true)
	teams_row.add_child(_team_panel_h)
	_team_panel_a = _build_team_panel(_my_sim.away, false)
	teams_row.add_child(_team_panel_a)

	var ticker_card := _card_column("📻 Liveticker")
	var ticker_panel: VBoxContainer = ticker_card.get_child(0)
	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_following = true
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker.add_theme_font_size_override("normal_font_size", 15)
	_ticker.add_theme_constant_override("line_separation", 6)
	ticker_panel.add_child(_ticker)
	ticker_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(ticker_card)

	# Rechte Spalte: Taktik, Statistik & Konferenz
	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(430, 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.add_theme_constant_override("separation", 12)
	_live_box.add_child(side_panel)

	var tactic_card := _card_column("🎯 Deine Taktik · %s" % Game.my_club().short_name)
	side_panel.add_child(tactic_card)
	var tactic_box: VBoxContainer = tactic_card.get_child(0)

	var mentality_row := HBoxContainer.new()
	mentality_row.add_theme_constant_override("separation", 6)
	tactic_box.add_child(mentality_row)
	for m in MatchSim.MENTALITIES:
		var b := Button.new()
		b.text = m.capitalize()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_mentality_pressed.bind(m))
		mentality_row.add_child(b)
		_mentality_buttons[m] = b
	_style_mentality_buttons("ausgewogen")

	var lineup_row := HBoxContainer.new()
	lineup_row.add_theme_constant_override("separation", 8)
	tactic_box.add_child(lineup_row)
	var lineup_button := Button.new()
	lineup_button.text = "🧩 Aufstellung & Wechsel"
	UITheme.make_primary(lineup_button)
	lineup_button.pressed.connect(_open_overlay)
	lineup_row.add_child(lineup_button)
	_subs_label = Label.new()
	_subs_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	lineup_row.add_child(_subs_label)
	_tactic_message = Label.new()
	_tactic_message.add_theme_font_size_override("font_size", 12)
	_tactic_message.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_tactic_message.clip_text = true
	tactic_box.add_child(_tactic_message)

	# Statistik als Vergleichsbalken
	var stats_card := _card_column("📊 Statistik")
	side_panel.add_child(stats_card)
	var stats_box: VBoxContainer = stats_card.get_child(0)
	var poss_head := HBoxContainer.new()
	poss_head.add_theme_constant_override("separation", 6)
	stats_box.add_child(poss_head)
	_poss_left = Label.new()
	_poss_left.text = "50 %"
	_poss_left.add_theme_font_size_override("font_size", 15)
	_poss_left.add_theme_color_override("font_color", UITheme.ACCENT)
	poss_head.add_child(_poss_left)
	var poss_title := Label.new()
	poss_title.text = "Ballbesitz"
	poss_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poss_title.add_theme_font_size_override("font_size", 12)
	poss_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	poss_head.add_child(poss_title)
	_poss_right = Label.new()
	_poss_right.text = "50 %"
	_poss_right.add_theme_font_size_override("font_size", 15)
	_poss_right.add_theme_color_override("font_color", Color("#f87171"))
	poss_head.add_child(_poss_right)
	_poss_bar = ProgressBar.new()
	_poss_bar.max_value = 100
	_poss_bar.value = 50
	_poss_bar.show_percentage = false
	_poss_bar.custom_minimum_size = Vector2(0, 11)
	_poss_bar.add_theme_stylebox_override("background", UITheme.box(Color("#7f1d1d"), 5))
	_poss_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.ACCENT, 5))
	_poss_bar.tooltip_text = "Spielanteile"
	stats_box.add_child(_poss_bar)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 4
	_stats_grid.add_theme_constant_override("h_separation", 7)
	_stats_grid.add_theme_constant_override("v_separation", 4)
	stats_box.add_child(_stats_grid)

	# Konferenz: übrige Spiele der eigenen Liga live
	var conf_card := _card_column("📺 Konferenz – deine Liga")
	conf_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(conf_card)
	var conf_box: VBoxContainer = conf_card.get_child(0)
	var conf_scroll := ScrollContainer.new()
	conf_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	conf_scroll.custom_minimum_size = Vector2(0, 110)
	conf_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conf_box.add_child(conf_scroll)
	_conference = VBoxContainer.new()
	_conference.add_theme_constant_override("separation", 3)
	_conference.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conf_scroll.add_child(_conference)

	# --- Steuerleiste
	_controls_bar = HBoxContainer.new()
	_controls_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_bar.add_theme_constant_override("separation", 8)
	_controls_bar.visible = false
	box.add_child(_controls_bar)
	_pause_button = Button.new()
	_pause_button.text = "⏸ Pause"
	_pause_button.custom_minimum_size = Vector2(120, 0)
	_controls_bar.add_child(_pause_button)
	_pause_button.pressed.connect(_on_pause_toggle)
	var speed_label := Label.new()
	speed_label.text = "  Tempo:"
	speed_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_controls_bar.add_child(speed_label)
	for speed_name in SPEEDS:
		var b := Button.new()
		b.text = speed_name
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 0)
		b.pressed.connect(_on_speed_pressed.bind(speed_name))
		_controls_bar.add_child(b)
		_speed_buttons[speed_name] = b
	_speed_buttons["1×"].button_pressed = true
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	_controls_bar.add_child(spacer)
	var instant := Button.new()
	instant.text = "⏭ Sofort beenden"
	instant.pressed.connect(_finish_instantly)
	_controls_bar.add_child(instant)

	# --- Abschluss-Panel: Spielbericht (wird bei Abpfiff gefüllt)
	_post_panel = VBoxContainer.new()
	_post_panel.add_theme_constant_override("separation", 10)
	_post_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_panel.visible = false
	box.add_child(_post_panel)

	_timer = Timer.new()
	_timer.wait_time = SPEEDS["1×"]
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

# ------------------------------------------------------------------ Bausteine

func _card_column(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	sb.set_content_margin_all(11)
	card.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(head)
	return card

func _build_scoreboard() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)

	row.add_child(_team_block(_my_sim.home, true))

	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 2)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(center)
	var md_label := Label.new()
	md_label.text = "%s · Spieltag %d · %s" % [Game.season_label(), Game.matchday() + 1, Game.my_league().name]
	md_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	md_label.add_theme_font_size_override("font_size", 13)
	md_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	center.add_child(md_label)
	_score_label = Label.new()
	_score_label.text = "– : –"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 38)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(_score_label)
	_minute_label = Label.new()
	_minute_label.text = "Anpfiff steht bevor"
	_minute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minute_label.add_theme_font_size_override("font_size", 16)
	_minute_label.add_theme_color_override("font_color", UITheme.ACCENT)
	center.add_child(_minute_label)
	_progress = ProgressBar.new()
	_progress.max_value = 90
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(260, 8)
	_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bar_bg := UITheme.box(UITheme.FIELD, 4)
	var bar_fill := UITheme.box(UITheme.ACCENT, 4)
	_progress.add_theme_stylebox_override("background", bar_bg)
	_progress.add_theme_stylebox_override("fill", bar_fill)
	center.add_child(_progress)

	row.add_child(_team_block(_my_sim.away, false))

	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.text = "%s · %s Zuschauer erwartet · Matchplan: %s" % [
		_my_sim.home.stadium, Fmt.thousands(int(_my_sim.home.capacity * _my_sim.home.expected_fill())), Game.match_plan]
	_status_line.add_theme_font_size_override("font_size", 13)
	_status_line.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(_status_line)
	return card

func _team_block(club: ClubData, is_home: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var badge := UITheme.club_badge(club.short_name, Color(club.color), 58)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := Label.new()
	name.text = club.name
	name.add_theme_font_size_override("font_size", 21)
	var info := Label.new()
	info.text = "%s · Stärke %d" % [club.shape_label(), club.team_strength(Game.world.players)]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	if is_home:
		text.add_child(name)
		text.add_child(info)
		row.add_child(badge)
		row.add_child(text)
	else:
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		text.add_child(name)
		text.add_child(info)
		row.add_child(text)
		row.add_child(badge)
	return row

## Spieltagsankündigung: Wappen mit Tabellenplätzen, Stadion & Datum,
## Fakten-Vergleich mit Sternen und die Ansprache vor dem Spiel.
func _build_prematch() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)

	var day_label := Label.new()
	day_label.text = "SPIELTAG %d · %s" % [Game.matchday() + 1, Game.date_label()]
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 13)
	day_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(day_label)

	# Wappen-Zeile mit Tabellenplätzen
	var duel := HBoxContainer.new()
	duel.alignment = BoxContainer.ALIGNMENT_CENTER
	duel.add_theme_constant_override("separation", 18)
	v.add_child(duel)
	duel.add_child(UITheme.club_badge(_my_sim.home.short_name, Color(_my_sim.home.color), 62))
	var home_name := Label.new()
	home_name.text = "(%d)  %s" % [_position_of(_my_sim.home), _my_sim.home.name]
	home_name.add_theme_font_size_override("font_size", 21)
	duel.add_child(home_name)
	var vs := Label.new()
	vs.text = "–"
	vs.add_theme_font_size_override("font_size", 26)
	vs.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	duel.add_child(vs)
	var away_name := Label.new()
	away_name.text = "%s  (%d)" % [_my_sim.away.name, _position_of(_my_sim.away)]
	away_name.add_theme_font_size_override("font_size", 21)
	duel.add_child(away_name)
	duel.add_child(UITheme.club_badge(_my_sim.away.short_name, Color(_my_sim.away.color), 62))

	var stadium_label := Label.new()
	stadium_label.text = "%s · %s Plätze · Matchplan: %s" % [_my_sim.home.stadium, Fmt.thousands(_my_sim.home.capacity), Game.match_plan]
	stadium_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stadium_label.add_theme_font_size_override("font_size", 14)
	stadium_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(stadium_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	v.add_child(columns)

	# --- Fakten
	var facts_card := _card_column("📊 Fakten")
	facts_card.custom_minimum_size = Vector2(520, 0)
	columns.add_child(facts_card)
	var facts: VBoxContainer = facts_card.get_child(0)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	facts.add_child(grid)
	var str_h := _my_sim.home.team_strength(Game.world.players)
	var str_a := _my_sim.away.team_strength(Game.world.players)
	_fact_row(grid, str(str_h), "Mannschaftsstärke", str(str_a), str_h >= str_a)
	_fact_row(grid, _stars(_season_rating(_my_sim.home)), "Saison bisher", _stars(_season_rating(_my_sim.away)), _season_rating(_my_sim.home) >= _season_rating(_my_sim.away))
	_fact_row(grid, _stars(_form_rating(_my_sim.home)), "Form (letzte 5)", _stars(_form_rating(_my_sim.away)), _form_rating(_my_sim.home) >= _form_rating(_my_sim.away))
	_fact_row(grid, _my_sim.home.shape_label(), "Ausrichtung", _my_sim.away.shape_label(), true)
	_fact_row(grid, "", "Hinspiel: %s" % _first_leg_text(), "", true)

	# --- Ansprache vor dem Spiel
	var speech_card := _card_column("🗣 Ansprache vor dem Spiel")
	speech_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(speech_card)
	var speech_box: VBoxContainer = speech_card.get_child(0)
	for i in SPEECHES.size():
		var s: Dictionary = SPEECHES[i]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "💬  „%s“" % s.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_speech_selected.bind(i))
		speech_box.add_child(b)
		_speech_buttons.append(b)
	_speech_buttons[0].set_pressed_no_signal(true)
	var speech_hint := Label.new()
	speech_hint.text = "Je mutiger die Ansprache, desto größer Wirkung UND Risiko.\nDeine Fähigkeit „Motivation“ (%d/%d) entscheidet mit, ob sie zündet." % [Game.skill("motivation"), Game.SKILL_MAX]
	speech_hint.add_theme_font_size_override("font_size", 12)
	speech_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	speech_box.add_child(speech_hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	v.add_child(buttons)
	var back := Button.new()
	back.text = "← Zurück zur Zentrale"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	buttons.add_child(back)
	var kickoff := Button.new()
	kickoff.text = "⚽  Anpfiff!"
	kickoff.custom_minimum_size = Vector2(240, 50)
	kickoff.add_theme_font_size_override("font_size", 22)
	UITheme.make_primary(kickoff)
	kickoff.pressed.connect(_on_kickoff)
	buttons.add_child(kickoff)
	return card

func _fact_row(grid: GridContainer, left: String, label: String, right: String, home_better: bool) -> void:
	var l := Label.new()
	l.text = left
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", UITheme.ACCENT if home_better and left != "" else (Color("#e3b341") if left != "" else UITheme.TEXT))
	grid.add_child(l)
	var m := Label.new()
	m.text = label
	m.custom_minimum_size = Vector2(180, 0)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_theme_font_size_override("font_size", 13)
	m.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	grid.add_child(m)
	var r := Label.new()
	r.text = right
	r.custom_minimum_size = Vector2(150, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 15)
	r.add_theme_color_override("font_color", Color("#e3b341") if home_better else UITheme.ACCENT)
	grid.add_child(r)

func _stars(value: float) -> String:
	var n := clampi(int(round(value * 5.0)), 0, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)

func _position_of(club: ClubData) -> int:
	return Game.league(club.league_id).position_of(club.id)

## Saisonbewertung 0..1 aus der Punktquote.
func _season_rating(club: ClubData) -> float:
	for row in Game.league(club.league_id).table():
		if int(row.club_id) == club.id:
			if int(row.played) == 0:
				return 0.5
			return clampf(float(row.points) / (int(row.played) * 3.0), 0.0, 1.0)
	return 0.5

## Formbewertung 0..1 aus den letzten 5 Spielen.
func _form_rating(club: ClubData) -> float:
	var recent := Game.league(club.league_id).fixtures_of_club(club.id).filter(func(x): return x.played)
	var last5 := recent.slice(maxi(0, recent.size() - 5))
	if last5.is_empty():
		return 0.5
	var pts := 0.0
	for x in last5:
		var at_home: bool = int(x.home) == club.id
		var gf: int = int(x.hg) if at_home else int(x.ag)
		var ga: int = int(x.ag) if at_home else int(x.hg)
		pts += 1.0 if gf > ga else (0.5 if gf == ga else 0.0)
	return pts / last5.size()

## Ergebnis des Hinspiels (falls schon gespielt).
func _first_leg_text() -> String:
	for x in Game.league(_my_sim.home.league_id).fixtures_of_club(_my_sim.home.id):
		if int(x.home) == _my_sim.away.id and int(x.away) == _my_sim.home.id and x.played:
			return "%s %d:%d %s" % [_my_sim.away.short_name, int(x.hg), int(x.ag), _my_sim.home.short_name]
	return "–"

func _on_speech_selected(index: int) -> void:
	_speech_index = index
	for i in _speech_buttons.size():
		_speech_buttons[i].set_pressed_no_signal(i == index)

# ------------------------------------------------------------------ Ablauf

func _on_kickoff() -> void:
	_prematch_panel.visible = false
	_live_box.visible = true
	_controls_bar.visible = true
	_score_label.text = "0 : 0"
	# Ansprache anwenden: Motivation entscheidet, ob sie zündet
	var speech: Dictionary = SPEECHES[_speech_index]
	var success := randf() < 0.45 + 0.06 * Game.skill("motivation")
	var factor := 1.0 + float(speech.bonus) if success else 1.0 - float(speech.risk)
	if _my_home:
		_my_sim.factor_h *= factor
	else:
		_my_sim.factor_a *= factor
	if success and float(speech.bonus) > 0.0:
		_ticker.append_text("[color=#4ade80]🗣 Deine Ansprache zündet – die Mannschaft geht heiß aufs Feld![/color]\n")
	elif not success and float(speech.risk) > 0.0:
		_ticker.append_text("[color=#f87171]🗣 Die Ansprache verpufft – einige Spieler wirken verunsichert.[/color]\n")
	# Anzeigepositionen meiner Elf übernehmen (für das Aufstellungs-Overlay)
	var c := Game.my_club()
	var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
	if c.lineup == lineup and c.lineup_spots.size() == lineup.size():
		for i in lineup.size():
			_live_spots[lineup[i]] = c.lineup_spots[i]
	_refresh_team_panels()
	_update_stats()
	_running = true
	_timer.start()

func _on_tick() -> void:
	if _my_sim.finished:
		_finish()
		return
	_my_sim.tick()
	for sim in _md.others:
		sim.tick()
	_flush_events()
	_score_label.text = "%d : %d" % [_my_sim.hg, _my_sim.ag]
	_minute_label.text = "%d. Minute" % _my_sim.minute
	_progress.value = _my_sim.minute
	_update_conference()
	# Frische, Bänke und Statistik live aktualisieren (Auswahl bleibt erhalten)
	if _my_sim.minute % 3 == 0:
		_refresh_team_panels()
		_update_stats()
	if _my_sim.minute == 45:
		_set_paused(true)
		_refresh_team_panels()
		_update_stats()
		_minute_label.text = "⏸ Halbzeit – Zeit für Anpassungen"
		# Halbzeitpause: direkt in die Aufstellung, damit Wechsel sofort möglich sind
		_open_overlay()
		_was_running = true
		_overlay_message.text = "Halbzeit bei %d:%d – jetzt Wechsel und Positionen anpassen." % [
			_my_sim.hg if _my_home else _my_sim.ag, _my_sim.ag if _my_home else _my_sim.hg]
	if _my_sim.finished:
		_finish()

func _on_pause_toggle() -> void:
	_set_paused(_running)

func _on_speed_pressed(speed_name: String) -> void:
	_timer.wait_time = SPEEDS[speed_name]
	for key in _speed_buttons:
		_speed_buttons[key].button_pressed = key == speed_name

func _set_paused(paused: bool) -> void:
	_running = not paused
	if paused:
		_timer.stop()
		_pause_button.text = "▶ Weiter"
	else:
		_timer.start()
		_pause_button.text = "⏸ Pause"

func _finish_instantly() -> void:
	_my_sim.run_full()
	for sim in _md.others:
		sim.run_full()
	_flush_events()
	_score_label.text = "%d : %d" % [_my_sim.hg, _my_sim.ag]
	_finish()

func _finish() -> void:
	if _post_panel.visible:
		return
	_timer.stop()
	for sim in _md.others:
		sim.run_full()
	Game.finish_matchday(_md)
	_flush_events()
	_minute_label.text = "🏁 Schlusspfiff"
	_progress.value = 90
	_score_label.text = "%d : %d" % [_my_sim.hg, _my_sim.ag]
	if _overlay != null:
		_overlay.visible = false
	_controls_bar.visible = false
	_live_box.visible = false
	# Der Bericht bringt seine eigene Anzeigetafel mit – die obere weicht
	_scoreboard.visible = false
	_post_panel.visible = true
	_build_report()

# ------------------------------------------------------------------ Spielbericht

## Ausführlicher Bericht nach dem Abpfiff: Torschützen, Spieler des Spiels,
## komplette Statistik, Noten und die weiteren Ergebnisse.
func _build_report() -> void:
	_clear_children(_post_panel)

	var my_goals: int = _my_sim.hg if _my_home else _my_sim.ag
	var opp_goals: int = _my_sim.ag if _my_home else _my_sim.hg
	var verdict := "SIEG" if my_goals > opp_goals else ("UNENTSCHIEDEN" if my_goals == opp_goals else "NIEDERLAGE")
	var verdict_color := UITheme.ACCENT if my_goals > opp_goals else (Color("#facc15") if my_goals == opp_goals else Color("#f87171"))

	# ---------------- Kopf: Endstand als Anzeigetafel
	_post_panel.add_child(_build_report_head(verdict, verdict_color))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_panel.add_child(columns)

	# ---------------- Spalte 1: Spielverlauf + Spieler des Spiels + Statistik
	var story_card := _card_column("⚽ Spielverlauf")
	story_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(story_card)
	var story: VBoxContainer = story_card.get_child(0)
	var story_scroll := ScrollContainer.new()
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story.add_child(story_scroll)
	var story_box := VBoxContainer.new()
	story_box.add_theme_constant_override("separation", 4)
	story_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.add_child(story_box)

	if _my_sim.goal_log.is_empty():
		var none := Label.new()
		none.text = "Keine Tore – die Abwehrreihen standen sicher."
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		story_box.add_child(none)
	for entry in _my_sim.goal_log:
		story_box.add_child(_goal_row(entry))
	# Spieler des Spiels: beste Note aller Beteiligten
	var best_pid := -1
	var best_note := 99.0
	for pid in _my_sim.participants(true) + _my_sim.participants(false):
		var note: float = Game.get_player(pid).last_rating
		if note > 0.0 and note < best_note:
			best_note = note
			best_pid = pid
	if best_pid > 0:
		story_box.add_child(_motm_card(best_pid, best_note))

	# Statistik als Vergleichsbalken (identisch zur Live-Ansicht)
	var stat_title := Label.new()
	stat_title.text = "Statistik"
	stat_title.add_theme_font_size_override("font_size", 13)
	stat_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	story_box.add_child(stat_title)
	var s: Dictionary = _my_sim.stats
	var poss := int(_my_sim.possession_home() * 100.0)
	if not _my_home:
		poss = 100 - poss
	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 7)
	stat_grid.add_theme_constant_override("v_separation", 5)
	story_box.add_child(stat_grid)
	var rows := [["Ballbesitz", poss, 100 - poss], ["Torschüsse", s.chances_h, s.chances_a],
		["Ecken", s.corners_h, s.corners_a], ["Freistöße", s.freekicks_h, s.freekicks_a],
		["Elfmeter", s.penalties_h, s.penalties_a], ["Gelbe Karten", s.yellow_h, s.yellow_a],
		["Platzverweise", s.reds_h, s.reds_a]]
	for i in rows.size():
		var row: Array = rows[i]
		var mine: int = int(row[1]) if (i == 0 or _my_home) else int(row[2])
		var theirs: int = int(row[2]) if (i == 0 or _my_home) else int(row[1])
		var caption := Label.new()
		caption.text = str(row[0])
		caption.custom_minimum_size = Vector2(104, 0)
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		stat_grid.add_child(caption)
		var l := Label.new()
		l.text = ("%d %%" % mine) if i == 0 else str(mine)
		l.custom_minimum_size = Vector2(38, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UITheme.ACCENT if mine >= theirs else UITheme.TEXT_DIM)
		stat_grid.add_child(l)
		var bar := _compare_bar(mine, theirs, 9)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stat_grid.add_child(bar)
		var r := Label.new()
		r.text = ("%d %%" % theirs) if i == 0 else str(theirs)
		r.custom_minimum_size = Vector2(38, 0)
		r.add_theme_font_size_override("font_size", 13)
		r.add_theme_color_override("font_color", Color("#f87171") if theirs > mine else UITheme.TEXT_DIM)
		stat_grid.add_child(r)

	# ---------------- Spalte 2: Noten deiner Spieler
	var ratings_card := _card_column("📋 Noten deiner Spieler")
	ratings_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(ratings_card)
	var ratings_holder: VBoxContainer = ratings_card.get_child(0)
	var avg_note := 0.0
	var my_players := _my_sim.participants(_my_home)
	for pid in my_players:
		avg_note += Game.get_player(pid).last_rating
	if not my_players.is_empty():
		avg_note /= my_players.size()
	var avg_label := Label.new()
	avg_label.text = "Mannschaftsnote %s · %d Spieler eingesetzt" % [("%.2f" % avg_note).replace(".", ","), my_players.size()]
	avg_label.add_theme_font_size_override("font_size", 12)
	avg_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	ratings_holder.add_child(avg_label)
	var ratings_scroll := ScrollContainer.new()
	ratings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ratings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ratings_holder.add_child(ratings_scroll)
	_ratings_box = VBoxContainer.new()
	_ratings_box.add_theme_constant_override("separation", 3)
	_ratings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings_scroll.add_child(_ratings_box)
	my_players.sort_custom(func(a, b): return Game.get_player(a).last_rating < Game.get_player(b).last_rating)
	for pid in my_players:
		_ratings_box.add_child(_rating_row(pid))

	# ---------------- Spalte 3: weitere Ergebnisse
	var others_card := _card_column("📡 Die weiteren Ergebnisse")
	others_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(others_card)
	var others_holder: VBoxContainer = others_card.get_child(0)
	var others_scroll := ScrollContainer.new()
	others_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	others_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	others_holder.add_child(others_scroll)
	_other_results = VBoxContainer.new()
	_other_results.add_theme_constant_override("separation", 2)
	_other_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	others_scroll.add_child(_other_results)
	var current_league := ""
	for sim in _md.others:
		if sim.league_name != current_league:
			current_league = sim.league_name
			var head := Label.new()
			head.text = "  " + current_league.to_upper()
			head.add_theme_font_size_override("font_size", 11)
			head.add_theme_color_override("font_color", UITheme.ACCENT)
			head.add_theme_stylebox_override("normal", UITheme.box(Color(0.08, 0.12, 0.10, 1.0), 4))
			_other_results.add_child(head)
		_other_results.add_child(_result_row(sim))

	var done := Button.new()
	done.text = "Weiter zur Zentrale  →"
	done.add_theme_font_size_override("font_size", 18)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(done)
	done.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	_post_panel.add_child(done)

## Anzeigetafel im Spielbericht: Wappen, Endstand, Ergebnis-Banner und Eckdaten.
func _build_report_head(verdict: String, verdict_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	var title := Label.new()
	title.text = "📰 Spielbericht · %s, %d. Spieltag" % [Game.my_league().name, Game.matchday()]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var result_row := HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 14)
	v.add_child(result_row)
	var hn := Label.new()
	hn.text = _my_sim.home.name
	hn.custom_minimum_size = Vector2(250, 0)
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn.add_theme_font_size_override("font_size", 20)
	if _my_sim.home.id == Game.my_club_id:
		hn.add_theme_color_override("font_color", UITheme.ACCENT)
	result_row.add_child(hn)
	result_row.add_child(UITheme.club_badge(_my_sim.home.short_name, Color(_my_sim.home.color), 44))
	var score_panel := PanelContainer.new()
	var score_sb := UITheme.box(Color(0.03, 0.05, 0.04), 8, verdict_color)
	score_sb.content_margin_left = 16
	score_sb.content_margin_right = 16
	score_sb.content_margin_top = 2
	score_sb.content_margin_bottom = 2
	score_panel.add_theme_stylebox_override("panel", score_sb)
	var score := Label.new()
	score.text = "%d : %d" % [_my_sim.hg, _my_sim.ag]
	score.add_theme_font_size_override("font_size", 34)
	score_panel.add_child(score)
	result_row.add_child(score_panel)
	result_row.add_child(UITheme.club_badge(_my_sim.away.short_name, Color(_my_sim.away.color), 44))
	var an := Label.new()
	an.text = _my_sim.away.name
	an.custom_minimum_size = Vector2(250, 0)
	an.add_theme_font_size_override("font_size", 20)
	if _my_sim.away.id == Game.my_club_id:
		an.add_theme_color_override("font_color", UITheme.ACCENT)
	result_row.add_child(an)

	var banner := Label.new()
	banner.text = verdict
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 15)
	banner.add_theme_color_override("font_color", verdict_color)
	v.add_child(banner)

	var cards: int = int(_my_sim.stats.yellow_h) + int(_my_sim.stats.yellow_a) \
		+ int(_my_sim.stats.reds_h) + int(_my_sim.stats.reds_a)
	var facts := Label.new()
	facts.text = "Halbzeit %d:%d · %s · %s Zuschauer · %s" % [
		_my_sim.ht_h, _my_sim.ht_a, _my_sim.home.stadium,
		Fmt.thousands(int(_my_sim.home.capacity * _my_sim.home.expected_fill())),
		"ohne Karten" if cards == 0 else ("1 Karte" if cards == 1 else "%d Karten" % cards)]
	facts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	facts.add_theme_font_size_override("font_size", 12)
	facts.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(facts)
	return card

## Eine Torzeile im Spielverlauf: Minutenchip, Wappen, Schütze, Zwischenstand.
func _goal_row(entry: Dictionary) -> PanelContainer:
	var p := Game.get_player(int(entry.pid))
	var club: ClubData = _my_sim.home if entry.home else _my_sim.away
	var mine: bool = club.id == Game.my_club_id
	var row := PanelContainer.new()
	var sb := UITheme.box(Color(0.10, 0.17, 0.12, 1.0) if mine else Color(0.17, 0.11, 0.11, 1.0), 5)
	sb.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	row.add_child(line)
	line.add_child(UITheme.mini_pill("%d'" % int(entry.min), Color(0.05, 0.07, 0.06), UITheme.TEXT_DIM, 34))
	line.add_child(UITheme.club_badge(club.short_name, Color(club.color), 20))
	var who := Label.new()
	who.text = "⚽  %s" % p.full_name()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.clip_text = true
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", UITheme.ACCENT if mine else UITheme.TEXT)
	line.add_child(who)
	var st := Label.new()
	st.text = str(entry.score)
	st.add_theme_font_size_override("font_size", 14)
	line.add_child(st)
	return row

## Hervorgehobene Karte für den Spieler des Spiels.
func _motm_card(pid: int, note: float) -> PanelContainer:
	var star := Game.get_player(pid)
	var star_club: ClubData = _my_sim.home if _my_sim.home.player_ids.has(pid) else _my_sim.away
	var card := PanelContainer.new()
	var sb := UITheme.box(Color(0.16, 0.13, 0.04, 1.0), 7, Color("#e3b341"))
	sb.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	card.add_child(line)
	var icon := Label.new()
	icon.text = "🌟"
	icon.add_theme_font_size_override("font_size", 22)
	line.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(texts)
	var t := Label.new()
	t.text = "Spieler des Spiels"
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color("#e3b341"))
	texts.add_child(t)
	var n := Label.new()
	n.text = "%s (%s) · %s" % [star.full_name(), star_club.short_name, star.pos]
	n.add_theme_font_size_override("font_size", 15)
	texts.add_child(n)
	line.add_child(UITheme.mini_pill(("%.1f" % note).replace(".", ","), Color(0.06, 0.08, 0.06), Color("#e3b341"), 48))
	return card

## Notenzeile eines eigenen Spielers inklusive Position, Nation, Toren und Frische.
func _rating_row(pid: int) -> PanelContainer:
	var p := Game.get_player(pid)
	var row := PanelContainer.new()
	var sb := UITheme.box(Color(0.09, 0.12, 0.10, 1.0), 5)
	sb.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	row.add_child(line)
	line.add_child(UITheme.mini_pill(("%.1f" % p.last_rating).replace(".", ","),
		Color(0.05, 0.07, 0.06), PlayerToken.note_color(p.last_rating), 42))
	var slot: String = _my_sim._slot_of(pid, _my_home)
	if not (_my_sim.lineup_h if _my_home else _my_sim.lineup_a).has(pid):
		slot = p.pos
	line.add_child(UITheme.mini_pill(slot, PlayerToken.GROUP_COLORS[PlayerData.GROUP_OF[slot]].darkened(0.3), Color.WHITE, 34))
	line.add_child(Flags.icon(p.nat, 13))
	var name := Label.new()
	name.text = p.full_name() + (" ⇄" if _my_sim._subbed_in.has(pid) else "")
	name.add_theme_font_size_override("font_size", 13)
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	var g: int = _my_sim.match_goals.get(pid, 0)
	if g > 0:
		line.add_child(UITheme.mini_pill("⚽ %d" % g, Color(0.05, 0.07, 0.06), UITheme.ACCENT, 38))
	var cond := int(_my_sim.cond.get(pid, 100))
	var fresh := Label.new()
	fresh.text = "%d%%" % cond
	fresh.custom_minimum_size = Vector2(40, 0)
	fresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fresh.add_theme_font_size_override("font_size", 12)
	fresh.add_theme_color_override("font_color", PlayerToken.fresh_color(cond))
	line.add_child(fresh)
	return row

## Ergebniszeile eines Parallelspiels mit Wappen und farbigem Ausgang.
func _result_row(sim: MatchSim) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := UITheme.box(Color(0.09, 0.11, 0.14, 1.0), 5)
	sb.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	row.add_child(line)
	var hn := Label.new()
	hn.text = sim.home.short_name
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn.clip_text = true
	hn.add_theme_font_size_override("font_size", 12)
	hn.add_theme_color_override("font_color", UITheme.TEXT if sim.hg > sim.ag else UITheme.TEXT_DIM)
	line.add_child(hn)
	line.add_child(UITheme.club_badge(sim.home.short_name, Color(sim.home.color), 18))
	var score := Label.new()
	score.text = "%d : %d" % [sim.hg, sim.ag]
	score.custom_minimum_size = Vector2(46, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 13)
	line.add_child(score)
	line.add_child(UITheme.club_badge(sim.away.short_name, Color(sim.away.color), 18))
	var an := Label.new()
	an.text = sim.away.short_name
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.clip_text = true
	an.add_theme_font_size_override("font_size", 12)
	an.add_theme_color_override("font_color", UITheme.TEXT if sim.ag > sim.hg else UITheme.TEXT_DIM)
	line.add_child(an)
	return row

# ------------------------------------------------------------------ Mannschafts-Panels

## Panel einer Mannschaft: Kopf mit Taktik, darunter Name · Note · Tore (live).
func _build_team_panel(club: ClubData, is_home: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	head.add_child(UITheme.club_badge(club.short_name, Color(club.color), 26))
	var name := Label.new()
	name.text = club.short_name
	name.add_theme_font_size_override("font_size", 15)
	if club.id == Game.my_club_id:
		name.add_theme_color_override("font_color", UITheme.ACCENT)
	head.add_child(name)
	var tactic := Label.new()
	tactic.add_theme_font_size_override("font_size", 12)
	tactic.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	tactic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tactic.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(tactic)
	card.set_meta("tactic", tactic)
	var header_row := HBoxContainer.new()
	v.add_child(header_row)
	for entry in [["Name", 0, true], ["Stä", 34, false], ["Fri", 40, false], ["Note", 40, false], ["Tore", 34, false]]:
		var h := Label.new()
		h.text = entry[0]
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		if entry[2]:
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			h.custom_minimum_size = Vector2(entry[1], 0)
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(h)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	v.add_child(rows)
	card.set_meta("rows", rows)
	card.set_meta("is_home", is_home)
	return card

func _refresh_team_panels() -> void:
	_subs_label.text = "Wechsel %d/%d" % [_my_sim.subs_used(_my_home), MatchSim.MAX_SUBS]
	for panel in [_team_panel_h, _team_panel_a]:
		var is_home: bool = panel.get_meta("is_home")
		var tactic: Label = panel.get_meta("tactic")
		tactic.text = "Taktik: %s" % (_my_sim.mentality_h if is_home else _my_sim.mentality_a)
		var rows: VBoxContainer = panel.get_meta("rows")
		_clear_children(rows)
		var lineup: Array = _my_sim.lineup_h if is_home else _my_sim.lineup_a
		for pid in lineup:
			var p := Game.get_player(pid)
			var row := HBoxContainer.new()
			var slot := _my_sim._slot_of(pid, is_home)
			var name := Label.new()
			var sub_mark := " ⇄" if _my_sim._subbed_in.has(pid) else ""
			name.text = "%s  %s%s" % [slot, p.last_name, sub_mark]
			name.add_theme_font_size_override("font_size", 13)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name.clip_text = true
			row.add_child(name)
			# Stärke (stabil, auf der gespielten Position) – ändert sich NICHT im Spiel
			var st := Label.new()
			st.text = str(p.strength_at(slot))
			st.custom_minimum_size = Vector2(34, 0)
			st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			st.add_theme_font_size_override("font_size", 13)
			row.add_child(st)
			# Frische (sinkt im Spiel)
			var fresh := Label.new()
			var cond := int(_my_sim.cond[pid])
			fresh.text = "%d%%" % cond
			fresh.custom_minimum_size = Vector2(40, 0)
			fresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fresh.add_theme_font_size_override("font_size", 13)
			fresh.add_theme_color_override("font_color", UITheme.DANGER if cond < 40 else (UITheme.WARN if cond < 60 else UITheme.TEXT_DIM))
			row.add_child(fresh)
			var note := Label.new()
			var rating := _my_sim.live_rating(pid)
			note.text = ("%.1f" % rating).replace(".", ",")
			note.custom_minimum_size = Vector2(40, 0)
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			note.add_theme_font_size_override("font_size", 13)
			note.add_theme_color_override("font_color", UITheme.ACCENT if rating <= 2.5 else (UITheme.TEXT if rating <= 4.0 else UITheme.DANGER))
			row.add_child(note)
			var goals := Label.new()
			var g: int = _my_sim.match_goals.get(pid, 0)
			goals.text = str(g) if g > 0 else "–"
			goals.custom_minimum_size = Vector2(34, 0)
			goals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			goals.add_theme_font_size_override("font_size", 13)
			if g > 0:
				goals.add_theme_color_override("font_color", UITheme.ACCENT)
			row.add_child(goals)
			rows.add_child(row)

# ------------------------------------------------------------------ Eingriffe

func _on_mentality_pressed(m: String) -> void:
	if _my_sim.set_mentality(_my_home, m):
		_flush_events()
		_tactic_message.text = "Spielweise: %s." % m
	_style_mentality_buttons(m)

func _style_mentality_buttons(active: String) -> void:
	for key in _mentality_buttons:
		_mentality_buttons[key].button_pressed = key == active

# ------------------------------------------------------------------ Anzeige

func _flush_events() -> void:
	while _event_index < _my_sim.events.size():
		_show_event(_my_sim.events[_event_index])
		_event_index += 1

func _show_event(ev: Dictionary) -> void:
	var color := "#cbd5e1"
	var icon := ""
	var emphasis := false
	var bg := ""
	match ev.kind:
		"goal_home", "goal_away":
			var my_goal: bool = (ev.kind == "goal_home") == _my_home
			color = "#4ade80" if my_goal else "#f87171"
			bg = "#14532d" if my_goal else "#4c1d1d"
			icon = "⚽ "
			emphasis = true
		"chance":
			color = "#94a3b8"
			icon = "💨 "
		"card":
			color = "#facc15"
			icon = "🟨 "
		"red":
			color = "#ef4444"
			icon = "🟥 "
			emphasis = true
		"sub":
			color = "#60a5fa"
			icon = "🔁 "
		"injury":
			color = "#fb923c"
			icon = "🚑 "
		"flow":
			color = "#64748b"
		"info":
			color = "#8fa1b8"
			icon = "🕒 "
	var min_chip := "[bgcolor=#1c2733][color=#8fa1b8] %2d' [/color][/bgcolor]" % int(ev.min)
	if bg != "":
		# Tore als hervorgehobener Block – das Highlight des Spiels
		_ticker.append_text("%s [bgcolor=%s][b][color=%s]  %s%s  [/color][/b][/bgcolor]\n" % [min_chip, bg, color, icon, ev.text])
		_pulse_score()
	elif emphasis:
		_ticker.append_text("%s [b][color=%s]%s%s[/color][/b]\n" % [min_chip, color, icon, ev.text])
	else:
		_ticker.append_text("%s [color=%s]%s%s[/color]\n" % [min_chip, color, icon, ev.text])

## Kurzes Aufblitzen der Anzeigetafel beim Torerfolg.
func _pulse_score() -> void:
	if _score_label == null or not is_inside_tree():
		return
	_score_label.pivot_offset = _score_label.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_score_label, "scale", Vector2(1.22, 1.22), 0.12)
	tw.tween_property(_score_label, "modulate", Color("#4ade80"), 0.12)
	tw.chain().set_parallel(true)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(_score_label, "modulate", Color.WHITE, 0.35)

## Konferenz: eine Zeile je Parallelspiel, Tore blitzen kurz grün auf.
func _update_conference() -> void:
	for sim in _md.others:
		if sim.home.league_id != Game.my_club().league_id:
			continue
		var key := "%d-%d" % [sim.home.id, sim.away.id]
		if not _conf_rows.has(key):
			_conf_rows[key] = _build_conf_row(sim)
			_conference.add_child(_conf_rows[key].row)
		var entry: Dictionary = _conf_rows[key]
		var score := "%d : %d" % [sim.hg, sim.ag]
		var goal_now: bool = entry.last != score
		entry.last = score
		entry.score.text = score
		entry.minute.text = "Ende" if sim.finished else "%d'" % sim.minute
		var flash: StyleBoxFlat = UITheme.box(Color(0.12, 0.28, 0.16, 1.0) if goal_now else Color(0.09, 0.11, 0.14, 1.0), 5)
		flash.set_content_margin_all(3)
		if goal_now:
			flash.set_border_width_all(1)
			flash.border_color = UITheme.ACCENT
		entry.row.add_theme_stylebox_override("panel", flash)
		entry.score.add_theme_color_override("font_color", UITheme.ACCENT if goal_now else UITheme.TEXT)

func _build_conf_row(sim: MatchSim) -> Dictionary:
	var row := PanelContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	row.add_child(line)
	var hn := Label.new()
	hn.text = sim.home.short_name
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn.add_theme_font_size_override("font_size", 12)
	line.add_child(hn)
	line.add_child(UITheme.club_badge(sim.home.short_name, Color(sim.home.color), 18))
	var score := Label.new()
	score.text = "0 : 0"
	score.custom_minimum_size = Vector2(46, 0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 13)
	line.add_child(score)
	line.add_child(UITheme.club_badge(sim.away.short_name, Color(sim.away.color), 18))
	var an := Label.new()
	an.text = sim.away.short_name
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.add_theme_font_size_override("font_size", 12)
	line.add_child(an)
	var minute := Label.new()
	minute.text = "0'"
	minute.custom_minimum_size = Vector2(34, 0)
	minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	minute.add_theme_font_size_override("font_size", 11)
	minute.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(minute)
	return {"row": row, "score": score, "minute": minute, "last": ""}

func _update_stats() -> void:
	var poss := _my_sim.possession_home() * 100.0
	if not _my_home:
		poss = 100.0 - poss
	_poss_bar.value = poss
	_poss_bar.tooltip_text = "Spielanteile: %d %% für dich" % int(poss)
	_poss_left.text = "%d %%" % int(poss)
	_poss_right.text = "%d %%" % (100 - int(poss))
	_clear_children(_stats_grid)
	var s: Dictionary = _my_sim.stats
	var rows := [
		["Torschüsse", s.chances_h, s.chances_a],
		["Ecken", s.corners_h, s.corners_a],
		["Freistöße", s.freekicks_h, s.freekicks_a],
		["Elfmeter", s.penalties_h, s.penalties_a],
		["Gelbe Karten", s.yellow_h, s.yellow_a],
		["Rote Karten", s.reds_h, s.reds_a],
	]
	for row in rows:
		var mine: int = int(row[1] if _my_home else row[2])
		var theirs: int = int(row[2] if _my_home else row[1])
		var caption := Label.new()
		caption.text = str(row[0])
		caption.custom_minimum_size = Vector2(96, 0)
		caption.add_theme_font_size_override("font_size", 12)
		caption.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_stats_grid.add_child(caption)
		var left := Label.new()
		left.text = str(mine)
		left.custom_minimum_size = Vector2(24, 0)
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		left.add_theme_font_size_override("font_size", 13)
		left.add_theme_color_override("font_color", UITheme.ACCENT if mine >= theirs else UITheme.TEXT_DIM)
		_stats_grid.add_child(left)
		var bar := _compare_bar(mine, theirs)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_stats_grid.add_child(bar)
		var right := Label.new()
		right.text = str(theirs)
		right.custom_minimum_size = Vector2(24, 0)
		right.add_theme_font_size_override("font_size", 13)
		right.add_theme_color_override("font_color", Color("#f87171") if theirs > mine else UITheme.TEXT_DIM)
		_stats_grid.add_child(right)

## Zweiseitiger Vergleichsbalken: links meine Zahl (grün), rechts der Gegner (rot).
func _compare_bar(mine: int, theirs: int, height := 8) -> Control:
	var total := maxi(mine + theirs, 1)
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	wrap.custom_minimum_size = Vector2(60, height)
	var l := ColorRect.new()
	l.color = UITheme.ACCENT if mine > 0 else Color(1, 1, 1, 0.08)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = maxf(float(mine), 0.02)
	l.custom_minimum_size = Vector2(0, height)
	wrap.add_child(l)
	var r := ColorRect.new()
	r.color = Color("#ef4444") if theirs > 0 else Color(1, 1, 1, 0.08)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_stretch_ratio = maxf(float(theirs), 0.02)
	r.custom_minimum_size = Vector2(0, height)
	wrap.add_child(r)
	wrap.tooltip_text = "%d : %d von %d" % [mine, theirs, total]
	return wrap

# ------------------------------------------------------------------ Aufstellungs-Overlay

## Spielfeld-Ansicht einer Mannschaft im Spiel. Meine Elf ist interaktiv:
## Chips ziehen = Position live umstellen, Bank-Chip auf Spieler ziehen = Wechsel.
class MatchPitch extends PitchBoard:
	var screen
	var is_home := false
	var interactive := false
	var chips := {}   # pid -> PlayerToken

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return interactive and data is Dictionary and data.get("kind", "") in ["mslot", "mbench"]

	func _drop_data(at: Vector2, data: Variant) -> void:
		screen._overlay_drop_on_pitch(at, data, self)

func _open_overlay() -> void:
	_was_running = _running
	_set_paused(true)
	if _overlay == null:
		_build_overlay()
	_overlay.move_to_front()
	_overlay.visible = true
	_overlay_selected = -1
	_refresh_overlay()

func _close_overlay() -> void:
	_overlay.visible = false
	_refresh_team_panels()
	if _was_running and not _my_sim.finished:
		_set_paused(false)

func _build_overlay() -> void:
	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Vollständig deckend – sonst schimmert die Live-Ansicht durch
	var sb := UITheme.box(Color(0.04, 0.06, 0.05, 1.0), 0)
	sb.set_content_margin_all(18)
	_overlay.add_theme_stylebox_override("panel", sb)
	add_child(_overlay)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_overlay.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var title := Label.new()
	title.text = "🧩 Aufstellung & Wechsel"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	head.add_child(title)
	_overlay_subs = Label.new()
	_overlay_subs.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	head.add_child(_overlay_subs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Button.new()
	close.text = "✔ Fertig – weiter geht's"
	UITheme.make_primary(close)
	close.pressed.connect(_close_overlay)
	head.add_child(close)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(columns)

	# ---------------- Links: Spielerliste mit Live-Noten (wie im Aufstellungstab)
	var list_card := PanelContainer.new()
	var list_sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	list_sb.set_content_margin_all(10)
	list_card.add_theme_stylebox_override("panel", list_sb)
	list_card.custom_minimum_size = Vector2(470, 0)
	columns.add_child(list_card)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_card.add_child(list_box)
	var list_title := Label.new()
	list_title.text = "Spielerliste"
	list_title.add_theme_font_size_override("font_size", 16)
	list_title.add_theme_color_override("font_color", UITheme.ACCENT)
	list_box.add_child(list_title)
	var head_row := PanelContainer.new()
	head_row.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 6))
	list_box.add_child(head_row)
	var head_cells := HBoxContainer.new()
	head_cells.add_theme_constant_override("separation", 6)
	head_row.add_child(head_cells)
	for col in [["Pos", 40], ["Name", 0], ["Stä", 34], ["Fri", 42], ["Note", 40], ["Tore", 34]]:
		var h := Label.new()
		h.text = col[0]
		h.add_theme_font_size_override("font_size", 11)
		h.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		if int(col[1]) == 0:
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			h.custom_minimum_size = Vector2(int(col[1]), 0)
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head_cells.add_child(h)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(list_scroll)
	_overlay_list = VBoxContainer.new()
	_overlay_list.add_theme_constant_override("separation", 2)
	_overlay_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_overlay_list)
	_overlay_message = Label.new()
	_overlay_message.add_theme_font_size_override("font_size", 12)
	_overlay_message.add_theme_color_override("font_color", UITheme.WARN)
	_overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_box.add_child(_overlay_message)

	# ---------------- Mitte: mein Spielfeld (interaktiv)
	var my_col := VBoxContainer.new()
	my_col.add_theme_constant_override("separation", 4)
	my_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_col.size_flags_stretch_ratio = 1.25
	columns.add_child(my_col)
	var my_title := Label.new()
	my_title.text = "Deine Elf – ziehen stellt die Position live um"
	my_title.add_theme_font_size_override("font_size", 13)
	my_title.add_theme_color_override("font_color", UITheme.ACCENT)
	my_col.add_child(my_title)
	_my_pitch = MatchPitch.new()
	_my_pitch.screen = self
	_my_pitch.is_home = _my_home
	_my_pitch.interactive = true
	_my_pitch.clip_contents = true
	_my_pitch.resized.connect(_refresh_overlay_pitches)
	my_col.add_child(_pitch_frame(_my_pitch))

	# ---------------- Rechts: Ersatzbank und Gegner
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.custom_minimum_size = Vector2(264, 0)
	columns.add_child(right_col)
	var bench_title := Label.new()
	bench_title.text = "🪑 Ersatzbank"
	bench_title.add_theme_font_size_override("font_size", 14)
	bench_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	right_col.add_child(bench_title)
	_overlay_bench_box = VBoxContainer.new()
	_overlay_bench_box.add_theme_constant_override("separation", 4)
	right_col.add_child(_overlay_bench_box)
	var hint := Label.new()
	hint.text = "Bank auf Feldspieler ziehen (oder beide anklicken) = Wechsel."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	right_col.add_child(hint)
	var opp_club: ClubData = _my_sim.away if _my_home else _my_sim.home
	var opp_title := Label.new()
	opp_title.text = "Gegner: %s (%s)" % [opp_club.short_name, opp_club.shape_label()]
	opp_title.add_theme_font_size_override("font_size", 13)
	opp_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	right_col.add_child(opp_title)
	_opp_pitch = MatchPitch.new()
	_opp_pitch.screen = self
	_opp_pitch.is_home = not _my_home
	_opp_pitch.interactive = false
	_opp_pitch.clip_contents = true
	_opp_pitch.resized.connect(_refresh_overlay_pitches)
	right_col.add_child(_pitch_frame(_opp_pitch))

## Hält das Spielfeld im gleichen Seitenverhältnis wie im Aufstellungs-
## bildschirm – sonst zieht eine breite Spalte Strafraum und Kreis auseinander.
func _pitch_frame(pitch: MatchPitch) -> AspectRatioContainer:
	var frame := AspectRatioContainer.new()
	frame.ratio = 0.89
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(pitch)
	return frame

func _refresh_overlay() -> void:
	_overlay_subs.text = "Wechsel %d/%d · %d. Minute · %d:%d" % [
		_my_sim.subs_used(_my_home), MatchSim.MAX_SUBS, _my_sim.minute,
		_my_sim.hg if _my_home else _my_sim.ag, _my_sim.ag if _my_home else _my_sim.hg]
	_fill_overlay_list()
	_fill_overlay_bench()
	_refresh_overlay_pitches()

## Anzeigepositionen einer Elf: eigene freie Punkte, wenn verfügbar; sonst
## Zonen-Standardpunkte mit horizontaler Auffächerung doppelter Positionen.
func _display_spots(sim_lineup: Array, is_home: bool, club: ClubData) -> Dictionary:
	var spots := {}
	if club.lineup == sim_lineup:
		# Im Aufstellungsbildschirm gesetzte Punkte haben Vorrang. Wurde er nie
		# geöffnet, ist lineup_spots leer – dann nehmen wir dieselben
		# Formationspunkte, die auch er anzeigen würde. Nur so steht die Elf
		# hier genauso wie dort.
		var base: Array = club.lineup_spots
		if base.size() != sim_lineup.size():
			base = ClubData.FORMATION_SPOTS.get(club.formation, ClubData.FORMATION_SPOTS["4-4-2"])
		if base.size() == sim_lineup.size():
			for i in sim_lineup.size():
				spots[sim_lineup[i]] = base[i]
			if is_home == _my_home:
				for pid in sim_lineup:
					if _live_spots.has(pid):
						spots[pid] = _live_spots[pid]
			return spots
	# Zonen zählen und auffächern
	var by_slot := {}
	for pid in sim_lineup:
		var slot := _my_sim._slot_of(pid, is_home)
		if not by_slot.has(slot):
			by_slot[slot] = []
		by_slot[slot].append(pid)
	for slot in by_slot:
		var group: Array = by_slot[slot]
		var base: Vector2 = ZONE_SPOTS.get(slot, Vector2(0.5, 0.5))
		for k in group.size():
			var offset := (k - (group.size() - 1) / 2.0) * 0.17
			spots[group[k]] = Vector2(clampf(base.x + offset, 0.08, 0.92), base.y)
	# Meine gemerkten Live-Positionen haben Vorrang
	if is_home == _my_home:
		for pid in sim_lineup:
			if _live_spots.has(pid):
				spots[pid] = _live_spots[pid]
	return spots

func _refresh_overlay_pitches() -> void:
	if _overlay == null or not _overlay.visible:
		return
	_fill_pitch(_my_pitch, Game.my_club())
	_fill_pitch(_opp_pitch, _my_sim.away if _my_home else _my_sim.home)

func _fill_pitch(pitch: MatchPitch, club: ClubData) -> void:
	_clear_children(pitch)
	pitch.chips.clear()
	var lineup: Array = _my_sim.lineup_h if pitch.is_home else _my_sim.lineup_a
	var spots := _display_spots(lineup, pitch.is_home, club)
	# Das Gegnerfeld ist nur eine kleine Vorschau – dort reichen Mini-Karten
	var compact := not pitch.interactive
	var chip_size := Vector2(46, 48) if compact else Vector2(108, 104)
	for pid in lineup:
		var p := Game.get_player(pid)
		var slot: String = _my_sim._slot_of(pid, pitch.is_home)
		var st := p.strength_at(slot)
		var chip := PlayerToken.new()
		chip.pid = pid
		chip.zone_pos = slot
		chip.custom_minimum_size = chip_size
		chip.pos_label.text = slot
		chip.str_label.text = str(st)
		chip.name_label.text = p.last_name
		# Live-Note direkt auf der Karte
		var note := _my_sim.live_rating(pid)
		chip.extra_label.visible = true
		chip.extra_label.text = ("Note %.1f" % note).replace(".", ",")
		chip.extra_label.add_theme_color_override("font_color", PlayerToken.note_color(note))
		var cond: float = _my_sim.cond[pid]
		chip.set_fresh(cond, PlayerToken.fresh_color(cond))
		chip.form_label.text = "⇄" if _my_sim._subbed_in.has(pid) else ""
		chip.form_label.add_theme_color_override("font_color", UITheme.ACCENT)
		chip.style_token(PlayerData.GROUP_OF[slot], p.position_familiarity(slot) < 0.72, pid == _overlay_selected)
		chip.tooltip_text = "%s (%s)\nSpielt %s · Stärke %d · Frische %d %%\nNote %s" % [
			p.full_name(), p.pos, slot, st, int(cond), ("%.1f" % note).replace(".", ",")]
		if compact:
			# Auf dem Mini-Feld nur Position und Stärke – Namen stehen im Tooltip
			chip.str_label.add_theme_font_size_override("font_size", 13)
			chip.pos_label.add_theme_font_size_override("font_size", 10)
			chip.name_plate.visible = false
			chip.extra_label.visible = false
			chip.fresh_bar.get_parent().visible = false
			chip.token.custom_minimum_size = Vector2(28, 28)
		var spot: Vector2 = spots.get(pid, Vector2(0.5, 0.5))
		chip.position = Vector2(spot.x * pitch.size.x, (1.0 - spot.y) * pitch.size.y) - chip_size / 2.0
		chip.position.x = clampf(chip.position.x, 1, maxf(pitch.size.x - chip_size.x - 1, 1))
		chip.position.y = clampf(chip.position.y, 1, maxf(pitch.size.y - chip_size.y - 1, 1))
		if pitch.interactive:
			chip.pressed.connect(_on_overlay_chip_clicked.bind(pid))
			chip.set_drag_forwarding(
				func(_at: Vector2): return _overlay_drag_data(chip, p, "mslot", pid),
				func(_at: Vector2, data: Variant): return data is Dictionary and data.get("kind", "") in ["mbench", "mslot"],
				func(at: Vector2, data: Variant): _overlay_drop_on_chip(pid, chip, at, data))
		pitch.add_child(chip)
		pitch.chips[pid] = chip
	# Karten entzerren, damit sich keine Token überdecken
	_declutter(pitch, chip_size, Vector2(4, 12) if not compact else Vector2(6, 12))

## Schiebt überlappende Karten entlang der geringeren Überlappung auseinander.
func _declutter(pitch: MatchPitch, chip_size: Vector2, slack: Vector2) -> void:
	var chips: Array = pitch.get_children()
	var min_x := chip_size.x - slack.x
	var min_y := chip_size.y - slack.y
	for _pass in 8:
		var moved := false
		for i in chips.size():
			for j in range(i + 1, chips.size()):
				var a: Control = chips[i]
				var b: Control = chips[j]
				var dx: float = a.position.x - b.position.x
				var dy: float = a.position.y - b.position.y
				var ox := min_x - absf(dx)
				var oy := min_y - absf(dy)
				if ox <= 0.0 or oy <= 0.0:
					continue
				moved = true
				if ox <= oy:
					var push_x := ox / 2.0 + 0.5
					var sx := 1.0 if dx >= 0.0 else -1.0
					a.position.x += push_x * sx
					b.position.x -= push_x * sx
				else:
					var push_y := oy / 2.0 + 0.5
					var sy := 1.0 if dy >= 0.0 else -1.0
					a.position.y += push_y * sy
					b.position.y -= push_y * sy
		if not moved:
			break
	for chip in chips:
		chip.position.x = clampf(chip.position.x, 1, maxf(pitch.size.x - chip_size.x - 1, 1))
		chip.position.y = clampf(chip.position.y, 1, maxf(pitch.size.y - chip_size.y - 1, 1))

## Spielerliste im Halbzeit-Fenster: Startelf und Bank mit Live-Noten.
func _fill_overlay_list() -> void:
	_clear_children(_overlay_list)
	var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
	_overlay_list.add_child(_overlay_group_header("AUF DEM FELD", lineup.size()))
	for pid in lineup:
		_overlay_list.add_child(_overlay_list_row(pid, true))
	var bench := _my_sim.bench(_my_home)
	_overlay_list.add_child(_overlay_group_header("ERSATZBANK", bench.size()))
	for pid in bench:
		_overlay_list.add_child(_overlay_list_row(pid, false))

func _overlay_group_header(text: String, count: int) -> Label:
	var l := Label.new()
	l.text = "  %s (%d)" % [text, count]
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	l.add_theme_stylebox_override("normal", UITheme.box(Color(0.08, 0.12, 0.10, 1.0), 4))
	return l

func _overlay_list_row(pid: int, on_pitch: bool) -> PanelContainer:
	var p := Game.get_player(pid)
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.17, 0.12, 1.0) if on_pitch else Color(0.12, 0.13, 0.16, 1.0)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	if pid == _overlay_selected:
		style.set_border_width_all(2)
		style.border_color = Color.WHITE
	row.add_theme_stylebox_override("panel", style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	row.add_child(line)

	var slot: String = _my_sim._slot_of(pid, _my_home) if on_pitch else p.pos
	var pos_cell := CenterContainer.new()
	pos_cell.custom_minimum_size = Vector2(40, 0)
	pos_cell.add_child(UITheme.mini_pill(slot, PlayerToken.GROUP_COLORS[PlayerData.GROUP_OF[slot]].darkened(0.3), Color.WHITE, 36))
	line.add_child(pos_cell)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_row)
	name_row.add_child(Flags.icon(p.nat, 13))
	var name_label := Label.new()
	name_label.text = p.full_name() + (" ⇄" if _my_sim._subbed_in.has(pid) else "")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	line.add_child(_overlay_cell(str(p.strength_at(slot)), 34, UITheme.TEXT))
	var cond := int(_my_sim.cond[pid])
	line.add_child(_overlay_cell("%d%%" % cond, 42, PlayerToken.fresh_color(cond)))
	if on_pitch:
		var note := _my_sim.live_rating(pid)
		line.add_child(_overlay_cell(("%.1f" % note).replace(".", ","), 40, PlayerToken.note_color(note)))
	else:
		line.add_child(_overlay_cell("–", 40, UITheme.TEXT_DIM))
	var goals: int = _my_sim.match_goals.get(pid, 0)
	line.add_child(_overlay_cell(str(goals) if goals > 0 else "–", 34, UITheme.ACCENT if goals > 0 else UITheme.TEXT_DIM))

	# Container schlucken Maus-Events – die Zeile selbst muss sie bekommen
	_pass_mouse_to_children(line)
	# Ziehen aus der Liste: aufs Feld, auf eine Karte oder auf eine andere Zeile.
	row.set_drag_forwarding(
		func(_at: Vector2):
			_overlay_dragging = true
			return _overlay_drag_data(row, p, "mslot" if on_pitch else "mbench", pid),
		func(_at: Vector2, data: Variant): return data is Dictionary \
			and data.get("kind", "") in ["mbench", "mslot"] and int(data.get("pid", -1)) != pid,
		func(_at: Vector2, data: Variant): _overlay_drop_on_row(pid, on_pitch, data))
	# Auswahl erst beim LOSLASSEN: würde schon der Mausdruck die Liste neu
	# aufbauen, wäre diese Zeile weg, bevor Godot einen Drag starten kann.
	row.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _overlay_dragging:
				_overlay_dragging = false
				return
			if on_pitch:
				_on_overlay_chip_clicked(pid)
			else:
				_on_overlay_bench_clicked(pid))
	return row

## Ablage auf einer Listenzeile: Bank auf Feld = Wechsel, Feld auf Feld =
## Positionstausch, Feld auf Bank = der Bankspieler kommt für ihn.
func _overlay_drop_on_row(pid: int, on_pitch: bool, data: Dictionary) -> void:
	var other := int(data.pid)
	var dragged_from_pitch: bool = str(data.kind) == "mslot"
	if on_pitch and dragged_from_pitch:
		_overlay_swap_positions(pid, other)
	elif on_pitch and not dragged_from_pitch:
		_overlay_substitute(pid, other)
	elif not on_pitch and dragged_from_pitch:
		_overlay_substitute(other, pid)
	else:
		_overlay_message.text = "Zwei Bankspieler lassen sich nicht tauschen."
		_refresh_overlay()

## Leert einen Container SOFORT. queue_free() allein reicht nicht: Die Knoten
## hängen bis zum Frame-Ende weiter im Baum – sie würden neue Karten beim
## Entzerren wegschieben und Klicks sowie Drags abfangen.
func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

## Setzt Maus-Events aller Kinder auf "ignorieren", damit die Zeile selbst
## Klicks und Drag & Drop erhält.
func _pass_mouse_to_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pass_mouse_to_children(child)

func _overlay_cell(text: String, width: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	return l

## Drag-Start aus dem Overlay: Vorschau setzen und Drag-Daten liefern.
func _overlay_drag_data(source: Control, p: PlayerData, kind: String, pid: int) -> Dictionary:
	make_overlay_preview(source, p)
	return {"kind": kind, "pid": pid}

func make_overlay_preview(source: Control, p: PlayerData) -> void:
	var panel := PanelContainer.new()
	var style := UITheme.box(Color(0.05, 0.08, 0.07, 0.92), 7, Color.WHITE)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "%s\n%s · St %d" % [p.last_name, p.pos, p.strength]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	panel.add_child(label)
	panel.custom_minimum_size = Vector2(142, 58)
	var wrapper := Control.new()
	wrapper.add_child(panel)
	panel.position = -panel.custom_minimum_size / 2.0
	source.set_drag_preview(wrapper)

func _fill_overlay_bench() -> void:
	_clear_children(_overlay_bench_box)
	for pid in _my_sim.bench(_my_home):
		var p := Game.get_player(pid)
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(0, 36)
		chip.focus_mode = Control.FOCUS_NONE
		var selected: bool = pid == _overlay_selected
		var style := UITheme.box(Color(0.13, 0.20, 0.15) if selected else Color(0.09, 0.12, 0.1), 6,
			Color.WHITE if selected else Color(1, 1, 1, 0.18))
		style.set_content_margin_all(4)
		for state in ["normal", "hover", "pressed", "focus"]:
			chip.add_theme_stylebox_override(state, style)
		var cond := int(_my_sim.cond[pid])
		chip.tooltip_text = "%s · %s · Stärke %d · Frische %d %%%s" % [
			p.full_name(), p.pos, p.strength, cond, "\nJoker: stark als Einwechselspieler" if p.has_trait("Joker") else ""]

		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_preset(Control.PRESET_FULL_RECT)
		line.add_theme_constant_override("separation", 5)
		chip.add_child(line)
		var pill := UITheme.mini_pill(p.pos, PlayerToken.GROUP_COLORS[PlayerData.GROUP_OF[p.pos]].darkened(0.3), Color.WHITE, 34)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(pill)
		var flag := Flags.icon(p.nat, 13)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(flag)
		var texts := VBoxContainer.new()
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_theme_constant_override("separation", 0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(texts)
		var nm := Label.new()
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.text = p.last_name + (" 🃏" if p.has_trait("Joker") else "")
		nm.clip_text = true
		nm.add_theme_font_size_override("font_size", 12)
		texts.add_child(nm)
		var sub := Label.new()
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.text = "St %d · %d%%" % [p.strength, cond]
		sub.add_theme_font_size_override("font_size", 10)
		sub.add_theme_color_override("font_color", PlayerToken.fresh_color(cond))
		texts.add_child(sub)

		chip.pressed.connect(_on_overlay_bench_clicked.bind(pid))
		chip.set_drag_forwarding(
			func(_at: Vector2): return _overlay_drag_data(chip, p, "mbench", pid),
			func(_at: Vector2, data: Variant): return data is Dictionary and data.get("kind", "") == "mslot",
			func(_at: Vector2, data: Variant): _overlay_substitute(int(data.pid), pid))
		_overlay_bench_box.add_child(chip)

## Drop auf meinem Feld: Feldspieler verschieben (Zone live umstellen)
## oder Bankspieler auf die Zone des nächsten Feldspielers einwechseln.
func _overlay_drop_on_pitch(at: Vector2, data: Dictionary, pitch: MatchPitch) -> void:
	var norm := Vector2(clampf(at.x / pitch.size.x, 0.02, 0.98), clampf(1.0 - at.y / pitch.size.y, 0.02, 0.98))
	var zone := ClubData.zone_position(norm)
	if str(data.kind) == "mslot":
		var pid := int(data.pid)
		if _my_sim.set_slot(_my_home, pid, zone):
			_live_spots[pid] = norm
			_overlay_message.text = "%s spielt jetzt %s." % [Game.get_player(pid).last_name, zone]
			_flush_events()
		_refresh_overlay()
	elif str(data.kind) == "mbench":
		# Einwechseln: Ziel ist der Feldspieler, der der Ablage am nächsten steht
		var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
		var spots := _display_spots(lineup, _my_home, Game.my_club())
		var nearest := -1
		var best := INF
		for pid in lineup:
			var d: float = spots.get(pid, Vector2(0.5, 0.5)).distance_to(norm)
			if d < best:
				best = d
				nearest = pid
		if nearest > 0:
			_overlay_substitute(nearest, int(data.pid))

## Ablage auf einer Spielerkarte: Bankspieler = Wechsel; Feldspieler in der
## Mitte = Positionen tauschen, am Rand = frei daneben ablegen. Ohne das
## würden die großen Karten den halben Platz blockieren, weil jeder Drop auf
## einer Karte statt auf dem Rasen landet.
func _overlay_drop_on_chip(pid: int, chip: Control, at: Vector2, data: Dictionary) -> void:
	if str(data.kind) == "mbench":
		_overlay_substitute(pid, int(data.pid))
		return
	var other := int(data.pid)
	if other == pid:
		_overlay_drop_on_pitch(chip.position + at, data, _my_pitch)
		return
	var core := Rect2(chip.size * 0.22, chip.size * 0.56)
	if core.has_point(at):
		_overlay_swap_positions(pid, other)
	else:
		_overlay_drop_on_pitch(chip.position + at, data, _my_pitch)

## Zwei Feldspieler tauschen Zone und Anzeigeposition.
func _overlay_swap_positions(a: int, b: int) -> void:
	var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
	if not (lineup.has(a) and lineup.has(b)):
		return
	var spots := _display_spots(lineup, _my_home, Game.my_club())
	var zone_a: String = _my_sim._slot_of(a, _my_home)
	var zone_b: String = _my_sim._slot_of(b, _my_home)
	_my_sim.set_slot(_my_home, a, zone_b)
	_my_sim.set_slot(_my_home, b, zone_a)
	_live_spots[a] = spots.get(b, Vector2(0.5, 0.5))
	_live_spots[b] = spots.get(a, Vector2(0.5, 0.5))
	_overlay_message.text = "%s und %s haben die Positionen getauscht." % [
		Game.get_player(a).last_name, Game.get_player(b).last_name]
	_refresh_overlay()

func _overlay_substitute(pid_out: int, pid_in: int) -> void:
	var error := _my_sim.substitute(_my_home, pid_out, pid_in)
	if error.is_empty():
		# Der Neue erbt die Anzeigeposition des Ausgewechselten
		if _live_spots.has(pid_out):
			_live_spots[pid_in] = _live_spots[pid_out]
		_overlay_message.text = "Wechsel: %s kommt für %s." % [Game.get_player(pid_in).last_name, Game.get_player(pid_out).last_name]
		_flush_events()
	else:
		_overlay_message.text = error
	_overlay_selected = -1
	_refresh_overlay()

func _on_overlay_chip_clicked(pid: int) -> void:
	if _overlay_selected > 0 and _overlay_selected != pid and not (_my_sim.lineup_h if _my_home else _my_sim.lineup_a).has(_overlay_selected):
		# Bankspieler war gewählt → Wechsel
		var pid_in := _overlay_selected
		_overlay_substitute(pid, pid_in)
		return
	_overlay_selected = pid if _overlay_selected != pid else -1
	_refresh_overlay()

func _on_overlay_bench_clicked(pid: int) -> void:
	if _overlay_selected > 0 and (_my_sim.lineup_h if _my_home else _my_sim.lineup_a).has(_overlay_selected):
		# Feldspieler war gewählt → Wechsel
		var pid_out := _overlay_selected
		_overlay_substitute(pid_out, pid)
		return
	_overlay_selected = pid if _overlay_selected != pid else -1
	_refresh_overlay()
