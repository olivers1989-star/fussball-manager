extends Control
## Spieltag live im modernen Manager-Design: Anzeigetafel mit Spielfortschritt,
## Liveticker mit Ereignis-Symbolen, Taktik-Panel (Spielweise, Wechsel von der
## Bank, Positionen der Elf) und Konferenz. Eingriffe wirken ab der nächsten Minute.

const SPEEDS := {"1×": 0.35, "2×": 0.15, "4×": 0.05}

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
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
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

	var ticker_card := _card_column("📻 Liveticker")
	var ticker_panel: VBoxContainer = ticker_card.get_child(0)
	_ticker = RichTextLabel.new()
	_ticker.bbcode_enabled = true
	_ticker.scroll_following = true
	_ticker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ticker.add_theme_font_size_override("normal_font_size", 16)
	_ticker.add_theme_constant_override("line_separation", 7)
	ticker_panel.add_child(_ticker)
	ticker_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_card.size_flags_stretch_ratio = 1.5
	_live_box.add_child(ticker_card)

	var side_panel := VBoxContainer.new()
	side_panel.custom_minimum_size = Vector2(470, 0)
	side_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_panel.add_theme_constant_override("separation", 12)
	_live_box.add_child(side_panel)

	# Taktik-Karte
	var tactic_card := _card_column("🎯 Taktik · %s" % Game.my_club().short_name)
	tactic_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	_subs_label = Label.new()
	_subs_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	mentality_row.add_child(_subs_label)

	var field_head := Label.new()
	field_head.text = "Auf dem Feld"
	field_head.add_theme_font_size_override("font_size", 13)
	field_head.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	tactic_box.add_child(field_head)
	_field_list = ItemList.new()
	_field_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_list.custom_minimum_size = Vector2(0, 250)
	tactic_box.add_child(_field_list)
	var bench_head := Label.new()
	bench_head.text = "Ersatzbank (nur von hier darf gewechselt werden)"
	bench_head.add_theme_font_size_override("font_size", 13)
	bench_head.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	tactic_box.add_child(bench_head)
	_bench_list = ItemList.new()
	_bench_list.custom_minimum_size = Vector2(0, 150)
	tactic_box.add_child(_bench_list)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	tactic_box.add_child(sub_row)
	var sub_button := Button.new()
	sub_button.text = "↔ Auswechseln"
	UITheme.make_primary(sub_button)
	sub_button.pressed.connect(_on_substitute)
	sub_row.add_child(sub_button)
	_tactic_message = Label.new()
	_tactic_message.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_tactic_message.clip_text = true
	_tactic_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_row.add_child(_tactic_message)

	# Konferenz-Karte
	var conf_card := _card_column("📡 Konferenz · %s" % Game.my_league().name)
	side_panel.add_child(conf_card)
	var conf_box: VBoxContainer = conf_card.get_child(0)
	_conference = ItemList.new()
	_conference.custom_minimum_size = Vector2(0, 150)
	conf_box.add_child(_conference)

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

	# --- Abschluss-Panel: Noten + weitere Ergebnisse
	_post_panel = VBoxContainer.new()
	_post_panel.add_theme_constant_override("separation", 12)
	_post_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_panel.visible = false
	box.add_child(_post_panel)
	var post_columns := HBoxContainer.new()
	post_columns.add_theme_constant_override("separation", 14)
	post_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_post_panel.add_child(post_columns)

	var ratings_card := _card_column("📋 Noten deiner Spieler")
	ratings_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_columns.add_child(ratings_card)
	var ratings_holder: VBoxContainer = ratings_card.get_child(0)
	var ratings_scroll := ScrollContainer.new()
	ratings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ratings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ratings_holder.add_child(ratings_scroll)
	_ratings_box = VBoxContainer.new()
	_ratings_box.add_theme_constant_override("separation", 3)
	_ratings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings_scroll.add_child(_ratings_box)

	var others_card := _card_column("⚽ Die weiteren Ergebnisse")
	others_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	post_columns.add_child(others_card)
	var others_holder: VBoxContainer = others_card.get_child(0)
	_other_results = ItemList.new()
	_other_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	others_holder.add_child(_other_results)

	var done := Button.new()
	done.text = "Weiter zur Zentrale  →"
	done.add_theme_font_size_override("font_size", 19)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(done)
	done.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	_post_panel.add_child(done)

	_timer = Timer.new()
	_timer.wait_time = SPEEDS["1×"]
	_timer.timeout.connect(_on_tick)
	add_child(_timer)

# ------------------------------------------------------------------ Bausteine

func _card_column(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(head)
	return card

func _build_scoreboard() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
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
	_score_label.add_theme_font_size_override("font_size", 54)
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

func _build_prematch() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 14, UITheme.BORDER)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	var title := Label.new()
	title.text = "Gleich geht's los!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	v.add_child(title)
	var compare := Label.new()
	compare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compare.text = "Elf-Stärke: %.1f gegen %.1f\nDeine Ausrichtung: %s · Matchplan: %s\n%s (%s Plätze)" % [
		_my_sim.home.squad_strength(Game.world.players), _my_sim.away.squad_strength(Game.world.players),
		Game.my_club().shape_label(), Game.match_plan,
		_my_sim.home.stadium, Fmt.thousands(_my_sim.home.capacity)]
	compare.add_theme_font_size_override("font_size", 17)
	compare.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(compare)
	var kickoff := Button.new()
	kickoff.text = "⚽  Anpfiff!"
	kickoff.custom_minimum_size = Vector2(260, 54)
	kickoff.add_theme_font_size_override("font_size", 24)
	kickoff.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.make_primary(kickoff)
	kickoff.pressed.connect(_on_kickoff)
	v.add_child(kickoff)
	var back := Button.new()
	back.text = "Zurück zur Zentrale"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
	v.add_child(back)
	return card

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
	_minute_label.text = "%d. Minute" % _my_sim.minute
	_progress.value = _my_sim.minute
	_update_conference()
	# Frische & Bänke live aktualisieren (Auswahl bleibt erhalten)
	if _my_sim.minute % 3 == 0:
		_refresh_tactic_panel()
	if _my_sim.minute == 45:
		_set_paused(true)
		_refresh_tactic_panel()
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
	_controls_bar.visible = false
	_live_box.visible = false
	_post_panel.visible = true
	_fill_ratings()
	_other_results.clear()
	var current_league := ""
	for sim in _md.others:
		if sim.league_name != current_league:
			current_league = sim.league_name
			var idx := _other_results.add_item("— %s —" % current_league)
			_other_results.set_item_disabled(idx, true)
		_other_results.add_item("%s  %d : %d  %s" % [sim.home.name, sim.hg, sim.ag, sim.away.name])

func _fill_ratings() -> void:
	for child in _ratings_box.get_children():
		child.queue_free()
	var my_players := _my_sim.participants(_my_home)
	my_players.sort_custom(func(a, b): return Game.get_player(a).last_rating < Game.get_player(b).last_rating)
	for pid in my_players:
		var p := Game.get_player(pid)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var note_color := UITheme.ACCENT if p.last_rating <= 2.5 else (UITheme.TEXT if p.last_rating <= 4.0 else UITheme.DANGER)
		var note := UITheme.mini_pill(("%.1f" % p.last_rating).replace(".", ","), Color(0.1, 0.14, 0.12), note_color, 44)
		row.add_child(note)
		var name := Label.new()
		name.text = "%s  %s" % [p.pos, p.full_name()]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		if p.goals_season > 0 and _goals_in_match(p.id) > 0:
			row.add_child(UITheme.mini_pill("⚽ %d" % _goals_in_match(p.id), Color(0.1, 0.14, 0.12), UITheme.ACCENT, 44))
		_ratings_box.add_child(row)

func _goals_in_match(pid: int) -> int:
	var count := 0
	var p := Game.get_player(pid)
	for ev in _my_sim.events:
		if ev.kind in ["goal_home", "goal_away"] and p.full_name() in str(ev.text):
			count += 1
	return count

# ------------------------------------------------------------------ Eingriffe

func _on_mentality_pressed(m: String) -> void:
	if _my_sim.set_mentality(_my_home, m):
		_flush_events()
		_tactic_message.text = "Spielweise: %s." % m
	_style_mentality_buttons(m)

func _style_mentality_buttons(active: String) -> void:
	for key in _mentality_buttons:
		_mentality_buttons[key].button_pressed = key == active

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
	_subs_label.text = "  Wechsel %d/%d" % [_my_sim.subs_used(_my_home), MatchSim.MAX_SUBS]
	var sel_field := _selected_pid(_field_list)
	var sel_bench := _selected_pid(_bench_list)
	var lineup: Array = _my_sim.lineup_h if _my_home else _my_sim.lineup_a
	_fill_field_list(lineup)
	_fill_bench_list(_my_sim.bench(_my_home))
	_restore_selection(_field_list, sel_field)
	_restore_selection(_bench_list, sel_bench)

func _selected_pid(list: ItemList) -> int:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return -1
	return int(list.get_item_metadata(selected[0]))

func _restore_selection(list: ItemList, pid: int) -> void:
	if pid < 0:
		return
	for i in list.item_count:
		if int(list.get_item_metadata(i)) == pid:
			list.select(i)
			return

## Feldspieler in Aufstellungs-Reihenfolge, mit der Position, die sie GERADE spielen.
func _fill_field_list(lineup: Array) -> void:
	_field_list.clear()
	for pid in lineup:
		var p := Game.get_player(pid)
		var slot := _my_sim._slot_of(pid, _my_home)
		var pos_txt := slot if slot == p.pos else "%s (%s)" % [slot, p.pos]
		var cond := int(_my_sim.cond[pid])
		var idx := _field_list.add_item("%-9s %s · St %d · Frische %d%%" % [pos_txt, p.full_name(), p.strength_at(slot), cond])
		_field_list.set_item_metadata(idx, pid)
		if cond < 40:
			_field_list.set_item_custom_fg_color(idx, UITheme.DANGER)
		elif cond < 60:
			_field_list.set_item_custom_fg_color(idx, UITheme.WARN)

func _fill_bench_list(ids: Array) -> void:
	_bench_list.clear()
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a, b):
		var order_a: int = PlayerData.POSITIONS.find(Game.get_player(a).pos)
		var order_b: int = PlayerData.POSITIONS.find(Game.get_player(b).pos)
		return order_a < order_b)
	for pid in sorted:
		var p := Game.get_player(pid)
		var joker := "  🃏" if p.has_trait("Joker") else ""
		var idx := _bench_list.add_item("%-4s %s · St %d · Frische %d%%%s" % [p.pos, p.full_name(), p.strength, int(_my_sim.cond[pid]), joker])
		_bench_list.set_item_metadata(idx, pid)

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
