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
var _other_results: ItemList
var _ratings_box: VBoxContainer
var _conference: ItemList
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
var _overlay_message: Label
var _overlay_subs: Label
var _live_spots := {}         # pid -> Vector2 (Anzeigeposition meiner Elf)
var _overlay_selected := -1
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

	box.add_child(_build_scoreboard())

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

	# Statistik & Konferenz nebeneinander in einer Karte
	var info_card := _card_column("📊 Statistik & Konferenz")
	side_panel.add_child(info_card)
	var info_box: VBoxContainer = info_card.get_child(0)
	_poss_bar = ProgressBar.new()
	_poss_bar.max_value = 100
	_poss_bar.value = 50
	_poss_bar.show_percentage = false
	_poss_bar.custom_minimum_size = Vector2(0, 10)
	_poss_bar.add_theme_stylebox_override("background", UITheme.box(Color("#7f1d1d"), 4))
	_poss_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.ACCENT, 4))
	_poss_bar.tooltip_text = "Spielanteile"
	info_box.add_child(_poss_bar)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 14)
	info_box.add_child(info_row)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 3
	_stats_grid.add_theme_constant_override("h_separation", 8)
	_stats_grid.add_theme_constant_override("v_separation", 2)
	_stats_grid.custom_minimum_size = Vector2(190, 0)
	info_row.add_child(_stats_grid)
	_conference = ItemList.new()
	_conference.custom_minimum_size = Vector2(0, 108)
	_conference.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_conference)

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
	info.text = "%s · Kader %.1f" % [club.shape_label(), club.overall_strength(Game.world.players)]
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
	var str_h := _my_sim.home.overall_strength(Game.world.players)
	var str_a := _my_sim.away.overall_strength(Game.world.players)
	_fact_row(grid, "%.1f" % str_h, "Kaderstärke", "%.1f" % str_a, str_h >= str_a)
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
		_minute_label.text = "⏸ Halbzeit – Zeit für Anpassungen"
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
	_post_panel.visible = true
	_build_report()

# ------------------------------------------------------------------ Spielbericht

## Ausführlicher Bericht nach dem Abpfiff: Torschützen, Spieler des Spiels,
## komplette Statistik, Noten und die weiteren Ergebnisse.
func _build_report() -> void:
	for child in _post_panel.get_children():
		child.queue_free()

	# Kopf: Endstand mit Halbzeitstand
	var head_card := _card_column("📰 Spielbericht · %s, Spieltag %d" % [Game.my_league().name, Game.matchday()])
	_post_panel.add_child(head_card)
	var head_box: VBoxContainer = head_card.get_child(0)
	var result_row := HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 16)
	head_box.add_child(result_row)
	result_row.add_child(UITheme.club_badge(_my_sim.home.short_name, Color(_my_sim.home.color), 42))
	var res := Label.new()
	res.text = "%s  %d : %d  %s" % [_my_sim.home.name, _my_sim.hg, _my_sim.ag, _my_sim.away.name]
	res.add_theme_font_size_override("font_size", 24)
	result_row.add_child(res)
	result_row.add_child(UITheme.club_badge(_my_sim.away.short_name, Color(_my_sim.away.color), 42))
	var ht := Label.new()
	ht.text = "Halbzeit %d:%d · %s · Spielanteile %d %% : %d %%" % [
		_my_sim.ht_h, _my_sim.ht_a, _my_sim.home.stadium,
		int(_my_sim.possession_home() * 100.0), 100 - int(_my_sim.possession_home() * 100.0)]
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ht.add_theme_font_size_override("font_size", 13)
	ht.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	head_box.add_child(ht)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_panel.add_child(columns)

	# Spalte 1: Spielverlauf (Tore) + Spieler des Spiels + Statistik
	var story_card := _card_column("⚽ Spielverlauf")
	story_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(story_card)
	var story: VBoxContainer = story_card.get_child(0)
	if _my_sim.goal_log.is_empty():
		var none := Label.new()
		none.text = "Keine Tore – die Abwehrreihen standen sicher."
		none.add_theme_font_size_override("font_size", 13)
		none.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		story.add_child(none)
	for entry in _my_sim.goal_log:
		var p := Game.get_player(int(entry.pid))
		var club: ClubData = _my_sim.home if entry.home else _my_sim.away
		var line := Label.new()
		line.text = "%2d'  ⚽ %s  %s (%s)" % [int(entry.min), entry.score, p.full_name(), club.short_name]
		line.add_theme_font_size_override("font_size", 14)
		var mine: bool = club.id == Game.my_club_id
		line.add_theme_color_override("font_color", UITheme.ACCENT if mine else UITheme.TEXT)
		story.add_child(line)
	# Spieler des Spiels: beste Note aller Beteiligten
	var best_pid := -1
	var best_note := 99.0
	for pid in _my_sim.participants(true) + _my_sim.participants(false):
		var note: float = Game.get_player(pid).last_rating
		if note > 0.0 and note < best_note:
			best_note = note
			best_pid = pid
	if best_pid > 0:
		var star := Game.get_player(best_pid)
		var star_club := _my_sim.home if _my_sim.home.player_ids.has(best_pid) else _my_sim.away
		story.add_child(HSeparator.new())
		var motm := Label.new()
		motm.text = "🌟 Spieler des Spiels: %s (%s) · Note %s" % [star.full_name(), star_club.short_name, ("%.1f" % best_note).replace(".", ",")]
		motm.add_theme_font_size_override("font_size", 14)
		motm.add_theme_color_override("font_color", Color("#e3b341"))
		story.add_child(motm)
	story.add_child(HSeparator.new())
	var stat_grid := GridContainer.new()
	stat_grid.columns = 3
	stat_grid.add_theme_constant_override("h_separation", 10)
	stat_grid.add_theme_constant_override("v_separation", 2)
	story.add_child(stat_grid)
	var s: Dictionary = _my_sim.stats
	for row in [["Chancen", s.chances_h, s.chances_a], ["Ecken", s.corners_h, s.corners_a],
		["Freistöße", s.freekicks_h, s.freekicks_a], ["Elfmeter", s.penalties_h, s.penalties_a],
		["Gelbe Karten", s.yellow_h, s.yellow_a], ["Platzverweise", s.reds_h, s.reds_a]]:
		var l := Label.new()
		l.text = str(row[1])
		l.custom_minimum_size = Vector2(30, 0)
		l.add_theme_font_size_override("font_size", 13)
		stat_grid.add_child(l)
		var m := Label.new()
		m.text = str(row[0])
		m.custom_minimum_size = Vector2(120, 0)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add_theme_font_size_override("font_size", 12)
		m.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		stat_grid.add_child(m)
		var r := Label.new()
		r.text = str(row[2])
		r.add_theme_font_size_override("font_size", 13)
		stat_grid.add_child(r)

	# Spalte 2: Noten deiner Spieler
	var ratings_card := _card_column("📋 Noten deiner Spieler")
	ratings_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(ratings_card)
	var ratings_holder: VBoxContainer = ratings_card.get_child(0)
	var ratings_scroll := ScrollContainer.new()
	ratings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ratings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ratings_holder.add_child(ratings_scroll)
	_ratings_box = VBoxContainer.new()
	_ratings_box.add_theme_constant_override("separation", 3)
	_ratings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings_scroll.add_child(_ratings_box)
	var my_players := _my_sim.participants(_my_home)
	my_players.sort_custom(func(a, b): return Game.get_player(a).last_rating < Game.get_player(b).last_rating)
	for pid in my_players:
		var p := Game.get_player(pid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var note_color := UITheme.ACCENT if p.last_rating <= 2.5 else (UITheme.TEXT if p.last_rating <= 4.0 else UITheme.DANGER)
		row.add_child(UITheme.mini_pill(("%.1f" % p.last_rating).replace(".", ","), Color(0.1, 0.14, 0.12), note_color, 44))
		var name := Label.new()
		name.text = "%s  %s" % [p.pos, p.full_name()]
		name.add_theme_font_size_override("font_size", 14)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var g: int = _my_sim.match_goals.get(p.id, 0)
		if g > 0:
			row.add_child(UITheme.mini_pill("⚽ %d" % g, Color(0.1, 0.14, 0.12), UITheme.ACCENT, 44))
		_ratings_box.add_child(row)

	# Spalte 3: weitere Ergebnisse
	var others_card := _card_column("📡 Die weiteren Ergebnisse")
	others_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(others_card)
	var others_holder: VBoxContainer = others_card.get_child(0)
	_other_results = ItemList.new()
	_other_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	others_holder.add_child(_other_results)
	var current_league := ""
	for sim in _md.others:
		if sim.league_name != current_league:
			current_league = sim.league_name
			var idx := _other_results.add_item("— %s —" % current_league)
			_other_results.set_item_disabled(idx, true)
		_other_results.add_item("%s  %d : %d  %s" % [sim.home.name, sim.hg, sim.ag, sim.away.name])

	var done := Button.new()
	done.text = "Weiter zur Zentrale  →"
	done.add_theme_font_size_override("font_size", 18)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(done)
	done.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	_post_panel.add_child(done)

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
		for child in rows.get_children():
			child.queue_free()
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
	match ev.kind:
		"goal_home", "goal_away":
			var my_goal: bool = (ev.kind == "goal_home") == _my_home
			color = "#4ade80" if my_goal else "#f87171"
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
	if emphasis:
		_ticker.append_text("%s [b][color=%s]%s%s[/color][/b]\n" % [min_chip, color, icon, ev.text])
	else:
		_ticker.append_text("%s [color=%s]%s%s[/color]\n" % [min_chip, color, icon, ev.text])

func _update_conference() -> void:
	_conference.clear()
	for sim in _md.others:
		if sim.home.league_id != Game.my_club().league_id:
			continue
		_conference.add_item("%s %d : %d %s   (%d')" % [sim.home.short_name, sim.hg, sim.ag, sim.away.short_name, sim.minute])

func _update_stats() -> void:
	_poss_bar.value = _my_sim.possession_home() * 100.0
	if not _my_home:
		_poss_bar.value = 100.0 - _poss_bar.value
	_poss_bar.tooltip_text = "Spielanteile: %d %% für dich" % int(_poss_bar.value)
	for child in _stats_grid.get_children():
		child.queue_free()
	var s: Dictionary = _my_sim.stats
	var rows := [
		["Chancen", s.chances_h, s.chances_a],
		["Ecken", s.corners_h, s.corners_a],
		["Freistöße", s.freekicks_h, s.freekicks_a],
		["Elfmeter", s.penalties_h, s.penalties_a],
		["Gelbe", s.yellow_h, s.yellow_a],
		["Rote", s.reds_h, s.reds_a],
	]
	for row in rows:
		var left := Label.new()
		left.text = str(row[1] if _my_home else row[2])
		left.custom_minimum_size = Vector2(26, 0)
		left.add_theme_font_size_override("font_size", 13)
		left.add_theme_color_override("font_color", UITheme.ACCENT)
		_stats_grid.add_child(left)
		var mid := Label.new()
		mid.text = str(row[0])
		mid.custom_minimum_size = Vector2(90, 0)
		mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.add_theme_font_size_override("font_size", 13)
		mid.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_stats_grid.add_child(mid)
		var right := Label.new()
		right.text = str(row[2] if _my_home else row[1])
		right.add_theme_font_size_override("font_size", 13)
		_stats_grid.add_child(right)

# ------------------------------------------------------------------ Aufstellungs-Overlay

## Spielfeld-Ansicht einer Mannschaft im Spiel. Meine Elf ist interaktiv:
## Chips ziehen = Position live umstellen, Bank-Chip auf Spieler ziehen = Wechsel.
class MatchPitch extends Control:
	var screen
	var is_home := false
	var interactive := false
	var chips := {}   # pid -> Button

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1a6b34"))
		for i in 8:
			if i % 2 == 0:
				draw_rect(Rect2(0, size.y * i / 8.0, size.x, size.y / 8.0), Color("#1d7439"))
		var line := Color(1, 1, 1, 0.45)
		var inset := 4.0
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)), line, false, 1.5)
		draw_line(Vector2(inset, size.y * 0.5), Vector2(size.x - inset, size.y * 0.5), line, 1.5)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.11, 0, TAU, 40, line, 1.5)
		var box_w := size.x * 0.5
		var box_h := size.y * 0.13
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, size.y - inset - box_h), Vector2(box_w, box_h)), line, false, 1.5)
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, inset), Vector2(box_w, box_h)), line, false, 1.5)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return interactive and data is Dictionary and data.get("kind", "") in ["mslot", "mbench"]

	func _drop_data(at: Vector2, data: Variant) -> void:
		screen._overlay_drop_on_pitch(at, data, self)

func _open_overlay() -> void:
	_was_running = _running
	_set_paused(true)
	if _overlay == null:
		_build_overlay()
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
	var sb := UITheme.box(Color(0.02, 0.04, 0.03, 0.97), 0)
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
	columns.add_theme_constant_override("separation", 14)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(columns)

	var my_col := VBoxContainer.new()
	my_col.add_theme_constant_override("separation", 4)
	my_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_col.size_flags_stretch_ratio = 1.1
	columns.add_child(my_col)
	var my_title := Label.new()
	my_title.text = "Deine Elf – Spieler ziehen = Position live umstellen"
	my_title.add_theme_font_size_override("font_size", 14)
	my_title.add_theme_color_override("font_color", UITheme.ACCENT)
	my_col.add_child(my_title)
	_my_pitch = MatchPitch.new()
	_my_pitch.screen = self
	_my_pitch.is_home = _my_home
	_my_pitch.interactive = true
	_my_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_my_pitch.clip_contents = true
	_my_pitch.resized.connect(_refresh_overlay_pitches)
	my_col.add_child(_my_pitch)

	var mid_col := VBoxContainer.new()
	mid_col.add_theme_constant_override("separation", 5)
	mid_col.custom_minimum_size = Vector2(210, 0)
	columns.add_child(mid_col)
	var bench_title := Label.new()
	bench_title.text = "🪑 Ersatzbank"
	bench_title.add_theme_font_size_override("font_size", 14)
	bench_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	mid_col.add_child(bench_title)
	_overlay_bench_box = VBoxContainer.new()
	_overlay_bench_box.add_theme_constant_override("separation", 4)
	mid_col.add_child(_overlay_bench_box)
	var hint := Label.new()
	hint.text = "Bank-Spieler auf einen\nFeldspieler ziehen (oder\nbeide anklicken) = Wechsel.\nJede Position möglich – auf\nfremder Position schwächer.\nMax. 5 Wechsel."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	mid_col.add_child(hint)
	_overlay_message = Label.new()
	_overlay_message.add_theme_font_size_override("font_size", 12)
	_overlay_message.add_theme_color_override("font_color", UITheme.WARN)
	_overlay_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_message.custom_minimum_size = Vector2(200, 0)
	mid_col.add_child(_overlay_message)

	var opp_col := VBoxContainer.new()
	opp_col.add_theme_constant_override("separation", 4)
	opp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(opp_col)
	var opp_club: ClubData = _my_sim.away if _my_home else _my_sim.home
	var opp_title := Label.new()
	opp_title.text = "Gegner: %s (%s)" % [opp_club.name, opp_club.shape_label()]
	opp_title.add_theme_font_size_override("font_size", 14)
	opp_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	opp_col.add_child(opp_title)
	_opp_pitch = MatchPitch.new()
	_opp_pitch.screen = self
	_opp_pitch.is_home = not _my_home
	_opp_pitch.interactive = false
	_opp_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_opp_pitch.clip_contents = true
	_opp_pitch.resized.connect(_refresh_overlay_pitches)
	opp_col.add_child(_opp_pitch)

func _refresh_overlay() -> void:
	_overlay_subs.text = "Wechsel %d/%d · %d. Minute · %d:%d" % [
		_my_sim.subs_used(_my_home), MatchSim.MAX_SUBS, _my_sim.minute,
		_my_sim.hg if _my_home else _my_sim.ag, _my_sim.ag if _my_home else _my_sim.hg]
	_fill_overlay_bench()
	_refresh_overlay_pitches()

## Anzeigepositionen einer Elf: eigene freie Punkte, wenn verfügbar; sonst
## Zonen-Standardpunkte mit horizontaler Auffächerung doppelter Positionen.
func _display_spots(sim_lineup: Array, is_home: bool, club: ClubData) -> Dictionary:
	var spots := {}
	if club.lineup == sim_lineup and club.lineup_spots.size() == sim_lineup.size():
		for i in sim_lineup.size():
			spots[sim_lineup[i]] = club.lineup_spots[i]
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
	for child in pitch.get_children():
		child.queue_free()
	pitch.chips.clear()
	var lineup: Array = _my_sim.lineup_h if pitch.is_home else _my_sim.lineup_a
	var spots := _display_spots(lineup, pitch.is_home, club)
	var chip_size := Vector2(118, 48)
	for pid in lineup:
		var p := Game.get_player(pid)
		var slot: String = _my_sim._slot_of(pid, pitch.is_home)
		var chip := Button.new()
		chip.custom_minimum_size = chip_size
		chip.clip_text = true
		chip.focus_mode = Control.FOCUS_NONE
		var st := p.strength_at(slot)
		chip.text = "%s %s\n%s · %d%%" % [slot, p.last_name, "St %d" % st, int(_my_sim.cond[pid])]
		chip.add_theme_font_size_override("font_size", 11)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.09, 0.08, 0.94)
		style.set_corner_radius_all(7)
		style.set_border_width_all(2)
		var group_colors := {"TW": Color("#eab308"), "AB": Color("#3b82f6"), "MF": Color("#22c55e"), "ST": Color("#ef4444")}
		style.border_color = group_colors[PlayerData.GROUP_OF[slot]]
		if pid == _overlay_selected:
			style.border_color = Color.WHITE
			style.set_border_width_all(3)
		chip.add_theme_stylebox_override("normal", style)
		chip.add_theme_stylebox_override("hover", style)
		chip.add_theme_stylebox_override("pressed", style)
		var spot: Vector2 = spots.get(pid, Vector2(0.5, 0.5))
		chip.position = Vector2(spot.x * pitch.size.x, (1.0 - spot.y) * pitch.size.y) - chip_size / 2.0
		chip.position.x = clampf(chip.position.x, 1, maxf(pitch.size.x - chip_size.x - 1, 1))
		chip.position.y = clampf(chip.position.y, 1, maxf(pitch.size.y - chip_size.y - 1, 1))
		if pitch.interactive:
			chip.pressed.connect(_on_overlay_chip_clicked.bind(pid))
			chip.set_drag_forwarding(
				func(_at: Vector2): return _overlay_drag_data(chip, p, "mslot", pid),
				func(_at: Vector2, data: Variant): return data is Dictionary and data.get("kind", "") == "mbench",
				func(_at: Vector2, data: Variant): _overlay_substitute(pid, int(data.pid)))
		pitch.add_child(chip)
		pitch.chips[pid] = chip

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
	label.text = "%s\nSt %d" % [p.last_name, p.strength]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	panel.add_child(label)
	panel.custom_minimum_size = Vector2(118, 48)
	var wrapper := Control.new()
	wrapper.add_child(panel)
	panel.position = -panel.custom_minimum_size / 2.0
	source.set_drag_preview(wrapper)

func _fill_overlay_bench() -> void:
	for child in _overlay_bench_box.get_children():
		child.queue_free()
	for pid in _my_sim.bench(_my_home):
		var p := Game.get_player(pid)
		var chip := Button.new()
		chip.custom_minimum_size = Vector2(0, 34)
		chip.clip_text = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var joker := " 🃏" if p.has_trait("Joker") else ""
		chip.text = " %s %s · St %d · %d%%%s" % [p.pos, p.last_name, p.strength, int(_my_sim.cond[pid]), joker]
		chip.add_theme_font_size_override("font_size", 12)
		var style := UITheme.box(Color(0.09, 0.12, 0.1), 6, Color(1, 1, 1, 0.2) if pid != _overlay_selected else Color.WHITE)
		chip.add_theme_stylebox_override("normal", style)
		chip.add_theme_stylebox_override("hover", style)
		chip.add_theme_stylebox_override("pressed", style)
		chip.pressed.connect(_on_overlay_bench_clicked.bind(pid))
		chip.set_drag_forwarding(
			func(_at: Vector2): return _overlay_drag_data(chip, p, "mbench", pid),
			func(_at: Vector2, _data: Variant): return false,
			func(_at: Vector2, _data: Variant): pass)
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
