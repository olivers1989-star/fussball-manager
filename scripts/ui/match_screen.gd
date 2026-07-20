extends Control
## Spieltag live: Die Simulation läuft Minute für Minute. Über das Taktik-Panel
## kannst du jederzeit (auch in der Pause) die Spielweise umstellen und wechseln –
## mit Wirkung ab der nächsten Spielminute. Rechts läuft die Konferenz der anderen Spiele.

const SPEEDS := {"1×": 0.35, "2×": 0.15, "4×": 0.05}

var _md := {}                 # {mine: MatchSim, others: [MatchSim]}
var _my_sim: MatchSim
var _my_home := false
var _event_index := 0
var _running := false

var _score_label: Label
var _minute_label: Label
var _ticker: RichTextLabel
var _prematch_panel: VBoxContainer
var _live_box: HBoxContainer
var _controls_bar: HBoxContainer
var _pause_button: Button
var _post_panel: VBoxContainer
var _other_results: ItemList
var _ratings_list: ItemList
var _conference: ItemList
var _mentality_select: OptionButton
var _field_list: ItemList
var _bench_list: ItemList
var _subs_label: Label
var _tactic_message: Label
var _timer: Timer

func _ready() -> void:
	if Game.next_fixture(Game.my_club_id).is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/hub.tscn")
		return
	_md = Game.start_matchday()
	_my_sim = _md.mine
	_my_home = _my_sim.home.id == Game.my_club_id
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var matchday_label := Label.new()
	matchday_label.text = "%s · Spieltag %d" % [Game.season_label(), Game.matchday() + 1]
	matchday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	matchday_label.add_theme_color_override("font_color", Color("#94a3b8"))
	box.add_child(matchday_label)

	var score_panel := PanelContainer.new()
	score_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(score_panel)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 24)
	score_panel.add_child(header)
	header.add_child(UITheme.club_badge(_my_sim.home.short_name, Color(_my_sim.home.color), 56))
	var home_label := Label.new()
	home_label.text = _my_sim.home.name
	home_label.add_theme_font_size_override("font_size", 28)
	header.add_child(home_label)
	_score_label = Label.new()
	_score_label.text = "– : –"
	_score_label.add_theme_font_size_override("font_size", 52)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(_score_label)
	var away_label := Label.new()
	away_label.text = _my_sim.away.name
	away_label.add_theme_font_size_override("font_size", 28)
	header.add_child(away_label)
	header.add_child(UITheme.club_badge(_my_sim.away.short_name, Color(_my_sim.away.color), 56))

	_minute_label = Label.new()
	_minute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minute_label.add_theme_font_size_override("font_size", 22)
	_minute_label.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(_minute_label)

	# --- Vorschau vor Anpfiff
	_prematch_panel = VBoxContainer.new()
	_prematch_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_prematch_panel.add_theme_constant_override("separation", 14)
	_prematch_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_prematch_panel)
	var compare := Label.new()
	compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compare.text = "Teamstärke: %.1f  gegen  %.1f\nStadion: %s (%s Plätze)\nDeine Formation: %s" % [
		_my_sim.home.squad_strength(Game.world.players), _my_sim.away.squad_strength(Game.world.players),
		_my_sim.home.stadium, Fmt.thousands(_my_sim.home.capacity), Game.my_club().formation]
	compare.add_theme_font_size_override("font_size", 20)
	_prematch_panel.add_child(compare)
	var kickoff := Button.new()
	kickoff.text = "⚽  Anpfiff!"
	kickoff.custom_minimum_size = Vector2(260, 54)
	kickoff.add_theme_font_size_override("font_size", 24)
	kickoff.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(kickoff)
	kickoff.pressed.connect(_on_kickoff)
	_prematch_panel.add_child(kickoff)
	var back := Button.new()
	back.text = "Zurück zur Zentrale"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	_prematch_panel.add_child(back)

	# --- Live-Bereich: links Ticker, rechts Taktik & Konferenz
	_live_box = HBoxContainer.new()
	_live_box.add_theme_constant_override("separation", 20)
	_live_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_live_box.visible = false
	box.add_child(_live_box)

	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_following = true
	_ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker.add_theme_font_size_override("normal_font_size", 18)
	_live_box.add_child(_ticker)

	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(460, 0)
	side_panel.add_theme_constant_override("separation", 8)
	_live_box.add_child(side_panel)

	var tactic_heading := Label.new()
	tactic_heading.text = "Taktik (%s)" % Game.my_club().short_name
	tactic_heading.add_theme_font_size_override("font_size", 20)
	tactic_heading.add_theme_color_override("font_color", Color("#4ade80"))
	side_panel.add_child(tactic_heading)

	var mentality_row := HBoxContainer.new()
	mentality_row.add_theme_constant_override("separation", 8)
	side_panel.add_child(mentality_row)
	var mentality_label := Label.new()
	mentality_label.text = "Spielweise:"
	mentality_row.add_child(mentality_label)
	_mentality_select = OptionButton.new()
	for m in MatchSim.MENTALITIES:
		_mentality_select.add_item(m)
	_mentality_select.select(1)   # ausgewogen
	_mentality_select.item_selected.connect(_on_mentality_changed)
	mentality_row.add_child(_mentality_select)
	_subs_label = Label.new()
	mentality_row.add_child(_subs_label)

	_field_list = ItemList.new()
	_field_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(_field_list)
	_bench_list = ItemList.new()
	_bench_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(_bench_list)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	side_panel.add_child(sub_row)
	var sub_button := Button.new()
	sub_button.text = "↔ Auswechseln"
	sub_button.pressed.connect(_on_substitute)
	sub_row.add_child(sub_button)
	_tactic_message = Label.new()
	_tactic_message.add_theme_color_override("font_color", Color("#94a3b8"))
	sub_row.add_child(_tactic_message)

	var conf_heading := Label.new()
	conf_heading.text = "Konferenz"
	conf_heading.add_theme_font_size_override("font_size", 20)
	conf_heading.add_theme_color_override("font_color", Color("#4ade80"))
	side_panel.add_child(conf_heading)
	_conference = ItemList.new()
	_conference.custom_minimum_size = Vector2(0, 190)
	side_panel.add_child(_conference)

	# --- Steuerleiste
	_controls_bar = HBoxContainer.new()
	_controls_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_bar.add_theme_constant_override("separation", 10)
	_controls_bar.visible = false
	box.add_child(_controls_bar)
	_pause_button = Button.new()
	_pause_button.text = "⏸ Pause"
	_pause_button.pressed.connect(_on_pause_toggle)
	_controls_bar.add_child(_pause_button)
	for speed_name in SPEEDS:
		var b := Button.new()
		b.text = speed_name
		b.pressed.connect(func(): _timer.wait_time = SPEEDS[speed_name])
		_controls_bar.add_child(b)
	var instant := Button.new()
	instant.text = "Sofort beenden"
	instant.pressed.connect(_finish_instantly)
	_controls_bar.add_child(instant)

	# --- Abschluss-Panel: links Noten, rechts weitere Ergebnisse
	_post_panel = VBoxContainer.new()
	_post_panel.add_theme_constant_override("separation", 10)
	_post_panel.visible = false
	box.add_child(_post_panel)
	var post_columns := HBoxContainer.new()
	post_columns.add_theme_constant_override("separation", 24)
	_post_panel.add_child(post_columns)

	var ratings_box := VBoxContainer.new()
	ratings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_columns.add_child(ratings_box)
	var ratings_heading := Label.new()
	ratings_heading.text = "Noten deiner Spieler:"
	ratings_heading.add_theme_font_size_override("font_size", 20)
	ratings_heading.add_theme_color_override("font_color", Color("#4ade80"))
	ratings_box.add_child(ratings_heading)
	_ratings_list = ItemList.new()
	_ratings_list.custom_minimum_size = Vector2(0, 240)
	ratings_box.add_child(_ratings_list)

	var others_box := VBoxContainer.new()
	others_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_columns.add_child(others_box)
	var other_heading := Label.new()
	other_heading.text = "Die weiteren Ergebnisse des Spieltags:"
	other_heading.add_theme_font_size_override("font_size", 20)
	other_heading.add_theme_color_override("font_color", Color("#4ade80"))
	others_box.add_child(other_heading)
	_other_results = ItemList.new()
	_other_results.custom_minimum_size = Vector2(0, 240)
	others_box.add_child(_other_results)
	var done := Button.new()
	done.text = "Weiter zur Zentrale →"
	done.add_theme_font_size_override("font_size", 20)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(done)
	done.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	_post_panel.add_child(done)

	_timer = Timer.new()
	_timer.wait_time = SPEEDS["1×"]
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

# ------------------------------------------------------------------ Ablauf

func _on_kickoff() -> void:
	_prematch_panel.visible = false
	_live_box.visible = true
	_controls_bar.visible = true
	_score_label.text = "0 : 0"
	_refresh_tactic_panel()
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
	_minute_label.text = "%d'" % _my_sim.minute
	_update_conference()
	if _my_sim.minute == 45:
		_set_paused(true)
		_minute_label.text = "Halbzeit – Zeit für Anpassungen"
	if _my_sim.finished:
		_finish()

func _on_pause_toggle() -> void:
	_set_paused(_running)

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
	_minute_label.text = "Schlusspfiff"
	_score_label.text = "%d : %d" % [_my_sim.hg, _my_sim.ag]
	_controls_bar.visible = false
	_post_panel.visible = true
	_update_conference()
	_ratings_list.clear()
	var my_players := _my_sim.participants(_my_home)
	my_players.sort_custom(func(a, b): return Game.get_player(a).last_rating < Game.get_player(b).last_rating)
	for pid in my_players:
		var p := Game.get_player(pid)
		_ratings_list.add_item("Note %s  –  %s %s" % [
			("%.1f" % p.last_rating).replace(".", ","), p.pos, p.full_name()])
	_other_results.clear()
	var current_league := ""
	for sim in _md.others:
		if sim.league_name != current_league:
			current_league = sim.league_name
			var idx := _other_results.add_item("— %s —" % current_league)
			_other_results.set_item_disabled(idx, true)
		_other_results.add_item("%s  %d : %d  %s" % [sim.home.name, sim.hg, sim.ag, sim.away.name])

# ------------------------------------------------------------------ Eingriffe

func _on_mentality_changed(index: int) -> void:
	if _my_sim.set_mentality(_my_home, _mentality_select.get_item_text(index)):
		_flush_events()
		_tactic_message.text = "Spielweise geändert."

func _on_substitute() -> void:
	var sel_field := _field_list.get_selected_items()
	var sel_bench := _bench_list.get_selected_items()
	if sel_field.is_empty() or sel_bench.is_empty():
		_tactic_message.text = "Je einen Spieler auf Feld und Bank wählen."
		return
	var pid_out: int = _field_list.get_item_metadata(sel_field[0])
	var pid_in: int = _bench_list.get_item_metadata(sel_bench[0])
	var error := _my_sim.substitute(_my_home, pid_out, pid_in)
	if error.is_empty():
		_tactic_message.text = "Wechsel vollzogen."
		_flush_events()
		_refresh_tactic_panel()
	else:
		_tactic_message.text = error

func _refresh_tactic_panel() -> void:
	_subs_label.text = "Wechsel: %d/%d" % [_my_sim.subs_used(_my_home), MatchSim.MAX_SUBS]
	var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
	_fill_player_list(_field_list, lineup, "FELD")
	_fill_player_list(_bench_list, _my_sim.bench(_my_home), "BANK")

func _fill_player_list(list: ItemList, ids: Array, prefix: String) -> void:
	list.clear()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var pa: PlayerData = Game.get_player(a)
		var pb: PlayerData = Game.get_player(b)
		var order := {"TW": 0, "AB": 1, "MF": 2, "ST": 3}
		if order[pa.pos] != order[pb.pos]:
			return order[pa.pos] < order[pb.pos]
		return pa.rating() > pb.rating())
	for pid in sorted:
		var p := Game.get_player(pid)
		var idx := list.add_item("%s  %s %s (St %d · Frische %d%%)" % [prefix, p.pos, p.full_name(), p.strength, int(_my_sim.cond[pid])])
		list.set_item_metadata(idx, pid)

# ------------------------------------------------------------------ Anzeige

func _flush_events() -> void:
	while _event_index < _my_sim.events.size():
		_show_event(_my_sim.events[_event_index])
		_event_index += 1

func _show_event(ev: Dictionary) -> void:
	var color := "#cbd5e1"
	match ev.kind:
		"goal_home", "goal_away":
			var my_goal: bool = (ev.kind == "goal_home") == _my_home
			color = "#4ade80" if my_goal else "#f87171"
		"chance":
			color = "#94a3b8"
		"card":
			color = "#facc15"
		"red":
			color = "#ef4444"
		"sub":
			color = "#60a5fa"
		"injury":
			color = "#fb923c"
	_ticker.append_text("[color=%s]%d'  %s[/color]\n" % [color, int(ev.min), ev.text])

func _update_conference() -> void:
	_conference.clear()
	for sim in _md.others:
		if sim.home.league_id != Game.my_club().league_id:
			continue
		_conference.add_item("%s %d : %d %s" % [sim.home.short_name, sim.hg, sim.ag, sim.away.short_name])
