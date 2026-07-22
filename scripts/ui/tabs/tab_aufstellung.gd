class_name TabAufstellung
extends TabBase
## Aufstellung: links das 2D-Spielfeld mit FREI positionierbaren Spielern
## (Zonen-Erkennung: wo du ablegst, spielt er – LV/IV/RV, DM/ZM/OM, LM/RM,
## LA/MS/RA, TW), daneben die Ersatzbank (max. 7), rechts die detaillierte
## Kaderliste. Theoretisch sind auch 5 Stürmer möglich – ob sinnvoll, zeigt das Spiel.

const GROUP_COLORS := {
	"TW": Color("#eab308"), "AB": Color("#3b82f6"),
	"MF": Color("#22c55e"), "ST": Color("#ef4444"),
}

var _formation_select: OptionButton
var _pitch: PitchControl
var _chips: Array = []            # 11 SlotChip (Index = Startelf-Index)
var _bench_chips: Array = []      # BENCH_SIZE BenchChip (Spalte neben dem Feld)
var _roster_box: VBoxContainer
var _message: Label
var _summary: Label
var _profile: PlayerProfileDialog
var _selected_pid := -1
var _crit_popup: PopupPanel
var _crit_sliders := {}
var _crit_values := {}
var _preset_popup: PopupPanel
var _preset_list: VBoxContainer
var _preset_name_edit: LineEdit

## Die Kriterien liegen im Spielstand, damit sie erhalten bleiben.
var _pick_weights: Dictionary:
	get: return Game.pick_weights

# ------------------------------------------------------------------ Spielfeld

## Vollwertiges Spielfeld: Mähstreifen, Strafräume mit Elfmeterpunkt und Bogen,
## Torraum, Tore, Eckbögen und Mittelkreis. Drops überall erlaubt (freie Position).
class PitchControl extends Control:
	var tab: TabAufstellung

	func _draw() -> void:
		var line := Color(1, 1, 1, 0.5)
		var w := 2.0
		var inset := 10.0
		var field := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))

		# Rasen mit Mähstreifen (quer, wie im Stadion)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#1c5f31"))
		var stripes := 10
		for i in stripes:
			var band := Rect2(0, size.y * i / stripes, size.x, size.y / stripes + 1)
			draw_rect(band, Color("#20693699") if i % 2 == 0 else Color("#1a5a2d99"))

		# Außenlinien und Mittellinie
		draw_rect(field, line, false, w)
		var cy := size.y * 0.5
		draw_line(Vector2(inset, cy), Vector2(size.x - inset, cy), line, w)
		var circle_r: float = minf(size.x, size.y) * 0.115
		draw_arc(Vector2(size.x * 0.5, cy), circle_r, 0, TAU, 64, line, w)
		draw_circle(Vector2(size.x * 0.5, cy), 3.0, line)

		# Strafraum, Torraum, Elfmeterpunkt und Strafraumbogen – beide Seiten
		var box_w := size.x * 0.58
		var box_h := size.y * 0.155
		var small_w := size.x * 0.27
		var small_h := size.y * 0.062
		var spot_dist := size.y * 0.105
		var arc_r := size.y * 0.075
		for bottom in [true, false]:
			var base_y: float = size.y - inset if bottom else inset
			var dir: float = -1.0 if bottom else 1.0
			draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, base_y + (dir * box_h if bottom else 0.0)), Vector2(box_w, box_h)), line, false, w)
			draw_rect(Rect2(Vector2((size.x - small_w) / 2.0, base_y + (dir * small_h if bottom else 0.0)), Vector2(small_w, small_h)), line, false, w)
			var spot := Vector2(size.x * 0.5, base_y + dir * spot_dist)
			draw_circle(spot, 2.5, line)
			# Strafraumbogen (nur der Teil außerhalb des Strafraums)
			var start_angle: float = -0.62 if bottom else TAU / 2.0 - 0.62
			draw_arc(spot, arc_r, start_angle, start_angle + 1.24, 32, line, w)
			# Tor
			var goal_w := size.x * 0.17
			draw_rect(Rect2(Vector2((size.x - goal_w) / 2.0, base_y + (0.0 if bottom else -6.0)), Vector2(goal_w, 6.0)), Color(1, 1, 1, 0.75), false, 2.5)

		# Eckbögen
		for corner in [Vector2(inset, inset), Vector2(size.x - inset, inset),
			Vector2(inset, size.y - inset), Vector2(size.x - inset, size.y - inset)]:
			draw_arc(corner, 12.0, 0, TAU, 24, line, 1.5)

		# Zonen-Reihen dezent andeuten (Abwehr / Mittelfeld / Angriff)
		var zone := Color(1, 1, 1, 0.07)
		draw_line(Vector2(inset, size.y * (1.0 - 0.38)), Vector2(size.x - inset, size.y * (1.0 - 0.38)), zone, 1.0)
		draw_line(Vector2(inset, size.y * (1.0 - 0.74)), Vector2(size.x - inset, size.y * (1.0 - 0.74)), zone, 1.0)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"]

	func _drop_data(at: Vector2, data: Variant) -> void:
		tab.drop_on_pitch(at, data)

## Ein Spieler auf dem Feld (frei positioniert).
class SlotChip extends Button:
	var slot_index := 0
	var zone_pos := ""
	var pid := -1
	var tab: TabAufstellung
	# Aufbau: runder Trikot-Token mit Stärkezahl, darunter Namensplakette
	var token: PanelContainer      # farbiger Kreis (Positionsgruppe)
	var str_label: Label           # Stärkezahl im Token
	var pos_label: Label           # Positions-Kürzel über dem Token
	var name_plate: PanelContainer
	var name_label: Label
	var fresh_bar: ColorRect
	var fresh_rest: ColorRect
	var form_label: Label

	const TOKEN := 46

	func _init(p_tab: TabAufstellung, index: int) -> void:
		tab = p_tab
		slot_index = index
		custom_minimum_size = Vector2(108, 104)
		focus_mode = Control.FOCUS_NONE
		flat = true   # kein Button-Rahmen – die Karte zeichnet sich selbst

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 1)
		add_child(v)

		# Positions-Kürzel
		pos_label = Label.new()
		pos_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos_label.add_theme_font_size_override("font_size", 12)
		v.add_child(pos_label)

		# Runder Token mit der Stärke
		var token_row := HBoxContainer.new()
		token_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token_row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(token_row)
		token = PanelContainer.new()
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.custom_minimum_size = Vector2(TOKEN, TOKEN)
		token_row.add_child(token)
		str_label = Label.new()
		str_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		str_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		str_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		str_label.add_theme_font_size_override("font_size", 20)
		token.add_child(str_label)

		# Namensplakette
		name_plate = PanelContainer.new()
		name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_plate)
		name_label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.clip_text = true
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_plate.add_child(name_label)

		# Frische-Balken mit Formpfeil daneben
		var bar_row := HBoxContainer.new()
		bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_row.add_theme_constant_override("separation", 4)
		v.add_child(bar_row)
		var bar_wrap := HBoxContainer.new()
		bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_wrap.add_theme_constant_override("separation", 0)
		bar_wrap.custom_minimum_size = Vector2(0, 5)
		bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar_row.add_child(bar_wrap)
		fresh_bar = ColorRect.new()
		fresh_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fresh_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_wrap.add_child(fresh_bar)
		fresh_rest = ColorRect.new()
		fresh_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fresh_rest.color = Color(0, 0, 0, 0.35)
		fresh_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_wrap.add_child(fresh_rest)
		form_label = Label.new()
		form_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		form_label.add_theme_font_size_override("font_size", 11)
		bar_row.add_child(form_label)

	## Balken über Stretch-Ratios: gefüllter Anteil zu Restanteil.
	func set_fresh(cond: float, color: Color) -> void:
		fresh_bar.color = color
		var filled := clampf(cond, 1.0, 100.0)
		fresh_bar.size_flags_stretch_ratio = filled
		fresh_rest.size_flags_stretch_ratio = maxf(100.0 - filled, 0.01)
		fresh_rest.color = Color(0, 0, 0, 0.0) if color.a == 0.0 else Color(0, 0, 0, 0.35)

	func _get_drag_data(_at: Vector2) -> Variant:
		if pid <= 0:
			return null
		tab.make_drag_preview(self, pid)
		return {"kind": "slot", "slot": slot_index, "pid": pid}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"]

	func _drop_data(at: Vector2, data: Variant) -> void:
		# Drop auf dem eigenen Kasten = Verschieben (freie Position).
		# Auf einem anderen Spieler: Mitte = tauschen, Rand = daneben ablegen.
		if str(data.kind) == "slot":
			if int(data.slot) == slot_index:
				tab.drop_on_pitch(position + at, data)
				return
			var core := Rect2(size * 0.22, size * 0.56)
			if core.has_point(at):
				tab.drop_on_chip(slot_index, data)
			else:
				tab.drop_on_pitch(position + at, data)
		else:
			tab.drop_on_chip(slot_index, data)

## Ein Platz auf der Ersatzbank (Spalte neben dem Spielfeld).
class BenchChip extends Button:
	var bench_index := 0
	var pid := -1
	var tab: TabAufstellung

	func _init(p_tab: TabAufstellung, index: int) -> void:
		tab = p_tab
		bench_index = index
		custom_minimum_size = Vector2(0, 40)
		clip_text = true
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_LEFT

	func _get_drag_data(_at: Vector2) -> Variant:
		if pid <= 0:
			return null
		tab.make_drag_preview(self, pid)
		return {"kind": "bench", "bench": bench_index, "pid": pid}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"]

	func _drop_data(_at: Vector2, data: Variant) -> void:
		tab.drop_on_bench(bench_index, data)

## Eine Zeile der Kaderliste.
class RosterRow extends PanelContainer:
	var pid := -1
	var tab: TabAufstellung

	func _get_drag_data(_at: Vector2) -> Variant:
		if not Game.get_player(pid).is_available():
			return null
		tab.make_drag_preview(self, pid)
		# Startelf-Spieler als "slot" ziehen (verschieben), sonst als "roster" (einwechseln)
		var lineup: Array = Game.my_club().lineup
		if lineup.has(pid):
			return {"kind": "slot", "slot": lineup.find(pid), "pid": pid}
		return {"kind": "roster", "pid": pid}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		var ok: bool = data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"] \
			and int(data.get("pid", -1)) != pid
		modulate = Color(1.25, 1.25, 1.25) if ok else Color.WHITE   # Zeile hebt sich hervor
		return ok

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
			modulate = Color.WHITE

	## Drop einer Zeile auf eine andere Zeile: Spieler tauschen bzw. einwechseln.
	func _drop_data(_at: Vector2, data: Variant) -> void:
		modulate = Color.WHITE
		tab.drop_on_roster_player(pid, data)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				tab._profile.open_for(pid)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.double_click:
					tab._profile.open_for(pid)
				else:
					tab.select_player(pid)

# ------------------------------------------------------------------ Aufbau

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(heading("Aufstellung"))
	var form_label := Label.new()
	form_label.text = "Preset:"
	top.add_child(form_label)
	_formation_select = OptionButton.new()
	for key in ClubData.FORMATIONS:
		_formation_select.add_item(key)
	_formation_select.item_selected.connect(_on_formation_changed)
	top.add_child(_formation_select)
	var auto_button := Button.new()
	auto_button.text = "⭐ Beste Elf & Bank"
	auto_button.pressed.connect(_on_best_eleven)
	UITheme.make_primary(auto_button)
	top.add_child(auto_button)
	var crit_button := Button.new()
	crit_button.text = "⚙ Kriterien"
	crit_button.pressed.connect(_open_criteria)
	top.add_child(crit_button)
	var preset_button := Button.new()
	preset_button.text = "📋 Aufstellungen"
	preset_button.pressed.connect(_open_presets)
	top.add_child(preset_button)
	_summary = info_label()
	top.add_child(_summary)
	_build_criteria_popup()
	_build_preset_popup()

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(main)

	# ============================================ LINKS: detaillierte Spielerliste
	var list_card := PanelContainer.new()
	var list_sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	list_sb.set_content_margin_all(10)
	list_card.add_theme_stylebox_override("panel", list_sb)
	list_card.custom_minimum_size = Vector2(600, 0)
	main.add_child(list_card)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_card.add_child(list_box)
	var list_title := Label.new()
	list_title.text = "Spielerliste"
	list_title.add_theme_font_size_override("font_size", 17)
	list_title.add_theme_color_override("font_color", UITheme.ACCENT)
	list_box.add_child(list_title)
	list_box.add_child(_table_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box.add_child(scroll)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 2)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_box)

	# ============================================ RECHTS: Spielfeld + Ersatzbank
	var pitch_col := VBoxContainer.new()
	pitch_col.add_theme_constant_override("separation", 6)
	pitch_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pitch_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(pitch_col)

	var pitch_row := HBoxContainer.new()
	pitch_row.add_theme_constant_override("separation", 8)
	pitch_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pitch_col.add_child(pitch_row)

	_pitch = PitchControl.new()
	_pitch.tab = self
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.custom_minimum_size = Vector2(430, 520)
	_pitch.clip_contents = true
	_pitch.resized.connect(_layout_pitch)
	pitch_row.add_child(_pitch)
	for i in 11:
		var chip := SlotChip.new(self, i)
		chip.pressed.connect(_on_chip_clicked.bind(i))
		chip.gui_input.connect(_on_chip_gui_input.bind(i))
		_pitch.add_child(chip)
		_chips.append(chip)

	# Ersatzbank als schmale Spalte am rechten Feldrand
	var bench_col := VBoxContainer.new()
	bench_col.add_theme_constant_override("separation", 4)
	bench_col.custom_minimum_size = Vector2(172, 0)
	pitch_row.add_child(bench_col)
	var bench_title := Label.new()
	bench_title.text = "🪑 Bank (max. %d)" % ClubData.BENCH_SIZE
	bench_title.add_theme_font_size_override("font_size", 13)
	bench_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	bench_col.add_child(bench_title)
	for i in ClubData.BENCH_SIZE:
		var bc := BenchChip.new(self, i)
		bc.pressed.connect(_on_bench_chip_clicked.bind(i))
		bc.gui_input.connect(_on_bench_gui_input.bind(i))
		bench_col.add_child(bc)
		_bench_chips.append(bc)

	var hint := info_label()
	hint.text = "Spieler aus der Liste frei aufs Feld ziehen – wo du ihn ablegst, spielt er. Doppel-/Rechtsklick: Profil."
	pitch_col.add_child(hint)
	_message = info_label()
	pitch_col.add_child(_message)

	_profile = PlayerProfileDialog.new()
	add_child(_profile)

## Kopfzeile der Spielerliste (Spaltenüberschriften).
func _table_header() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(UITheme.FIELD, 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	for col in [["Pos", 38], ["Spielt", 46], ["Name", 0], ["Alt", 30], ["Talent", 66], ["Stä", 34], ["Fri", 40], ["Fo", 26]]:
		var l := Label.new()
		l.text = col[0]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		if int(col[1]) == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size = Vector2(int(col[1]), 0)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
	return panel

# ------------------------------------------------------------------ Anzeige

func refresh() -> void:
	var c := Game.my_club()
	for i in _formation_select.item_count:
		if _formation_select.get_item_text(i) == c.formation:
			_formation_select.select(i)
			break
	# Kriterien-Regler an den (ggf. geladenen) Spielstand angleichen
	for key in _crit_sliders:
		_crit_sliders[key].set_value_no_signal(float(_pick_weights.get(key, 0.4)) * 100.0)
	_update_crit_labels()
	c.lineup = c.match_lineup(Game.world.players).duplicate()
	if c.lineup_spots.size() != c.lineup.size():
		c.lineup_spots = ClubData.FORMATION_SPOTS.get(c.formation, ClubData.FORMATION_SPOTS["4-4-2"]).duplicate()
	c.bench = c.match_bench(Game.world.players, c.lineup).duplicate()
	_selected_pid = -1
	_refresh_all()

func _refresh_all() -> void:
	_refresh_chips()
	_refresh_bench()
	_refresh_roster()

func _refresh_chips() -> void:
	var c := Game.my_club()
	var slots := c.lineup_slots()
	var total := 0
	var warnings := 0
	for i in 11:
		var chip: SlotChip = _chips[i]
		chip.pid = c.lineup[i] if i < c.lineup.size() else -1
		chip.zone_pos = slots[i] if i < slots.size() else "ZM"
		if chip.pid > 0:
			var p := Game.get_player(chip.pid)
			var st := p.strength_at(chip.zone_pos)
			total += st
			var mark := ""
			var fam := p.position_familiarity(chip.zone_pos)
			var fam_note := "eigene Position"
			if p.pos != chip.zone_pos:
				if fam >= PlayerData.SEC_LEARNED:
					mark = "  ✓"
					fam_note = "gelernte Nebenposition"
				elif fam >= 0.72:
					mark = "  ◊"
					fam_note = "Aushilfsrolle"
				else:
					mark = "  ⚠"
					fam_note = "positionsfremd"
					warnings += 1
			chip.pos_label.text = chip.zone_pos + mark
			chip.name_label.text = p.last_name
			chip.str_label.text = str(st)
			chip.form_label.text = Fmt.form_icon(p.form)
			chip.form_label.add_theme_color_override("font_color", Fmt.form_color(p.form))
			chip.set_fresh(p.condition, _fresh_color(p.condition))
			chip.tooltip_text = "%s (%s, %s)\nSpielt %s (%s, %d %% Vertrautheit): Stärke %d – eigene Position %s: %d\nFrische %d %%%s" % [
				p.full_name(), p.pos, p.nat, chip.zone_pos, fam_note, int(fam * 100.0), st, p.pos, p.strength,
				int(p.condition), ("\n" + ", ".join(p.traits)) if not p.traits.is_empty() else ""]
		else:
			chip.pos_label.text = chip.zone_pos
			chip.name_label.text = "frei"
			chip.str_label.text = "–"
			chip.form_label.text = ""
			chip.set_fresh(0.0, Color(0, 0, 0, 0))
			chip.tooltip_text = ""
		_style_chip(chip)
	var avg := total / 11.0
	var warn_text := "  ·  ⚠ %d positionsfremd" % warnings if warnings > 0 else ""
	_summary.text = "Mannschaftsstärke %d  ·  Ausrichtung %s  ·  Ø auf Position %.1f%s" % [total, c.shape_label(), avg, warn_text]
	_layout_pitch()

## Karte im Taktikboard-Stil: runder Trikot-Token in der Farbe der
## Positionsgruppe, darunter Namensplakette. Fehlbesetzung färbt orange.
func _style_chip(chip: SlotChip) -> void:
	var group: String = PlayerData.GROUP_OF[chip.zone_pos]
	var base: Color = GROUP_COLORS[group]
	var empty := chip.pid <= 0
	var mis := false
	if not empty:
		mis = Game.get_player(chip.pid).position_familiarity(chip.zone_pos) < 0.72
	var token_color: Color = base if not mis else Color("#f59e0b")
	if empty:
		token_color = Color(0.35, 0.4, 0.38, 0.55)
	var selected := not empty and chip.pid == _selected_pid

	# Runder Token (voller Eckenradius = Kreis)
	var token_sb := StyleBoxFlat.new()
	token_sb.bg_color = token_color.darkened(0.12)
	token_sb.set_corner_radius_all(SlotChip.TOKEN / 2)
	token_sb.set_border_width_all(3 if selected else 2)
	token_sb.border_color = Color.WHITE if selected else token_color.lightened(0.35)
	token_sb.shadow_color = Color(0, 0, 0, 0.45)
	token_sb.shadow_size = 4
	token_sb.content_margin_top = 2
	chip.token.add_theme_stylebox_override("panel", token_sb)
	chip.str_label.add_theme_color_override("font_color", Color.WHITE if not empty else Color(1, 1, 1, 0.5))

	# Namensplakette
	var plate := UITheme.box(Color(0.05, 0.08, 0.07, 0.88), 5)
	plate.content_margin_left = 6
	plate.content_margin_right = 6
	plate.content_margin_top = 1
	plate.content_margin_bottom = 1
	if selected:
		plate.set_border_width_all(1)
		plate.border_color = Color.WHITE
	chip.name_plate.add_theme_stylebox_override("panel", plate)
	chip.name_label.add_theme_color_override("font_color", Color.WHITE if not empty else Color(1, 1, 1, 0.5))
	chip.pos_label.add_theme_color_override("font_color", token_color.lightened(0.45))

	# Der Button selbst bleibt unsichtbar (nur Klickfläche)
	var invisible := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		chip.add_theme_stylebox_override(state, invisible)

## Stärke-Farbe: Weltklasse grün, Durchschnitt neutral, schwach rötlich.
func _strength_color(st: int) -> Color:
	if st >= 82:
		return Color("#4ade80")
	if st >= 70:
		return Color("#e2e8f0")
	if st >= 58:
		return Color("#facc15")
	return Color("#f87171")

## Frische-Farbe: grün (frisch) → gelb → rot (platt).
func _fresh_color(cond: float) -> Color:
	if cond >= 75.0:
		return Color("#22c55e")
	if cond >= 55.0:
		return Color("#eab308")
	if cond >= 35.0:
		return Color("#f97316")
	return Color("#ef4444")

func _refresh_bench() -> void:
	var c := Game.my_club()
	for i in ClubData.BENCH_SIZE:
		var bc: BenchChip = _bench_chips[i]
		bc.pid = c.bench[i] if i < c.bench.size() else -1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.12, 0.1, 1.0)
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.18)
		if bc.pid > 0:
			var p := Game.get_player(bc.pid)
			bc.text = " %s %s %s · St %d · %d%%" % [p.pos, Nations.code(p.nat), p.last_name, p.strength, int(p.condition)]
			bc.tooltip_text = "%s (%s)%s" % [p.full_name(), p.nat, ("\n" + ", ".join(p.traits)) if not p.traits.is_empty() else ""]
			style.border_color = GROUP_COLORS[p.group()].darkened(0.1)
			if bc.pid == _selected_pid:
				style.set_border_width_all(2)
				style.border_color = Color.WHITE
		else:
			bc.text = " – frei –"
			bc.tooltip_text = ""
		bc.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.08)
		bc.add_theme_stylebox_override("hover", hover)
		bc.add_theme_stylebox_override("pressed", style)
		bc.add_theme_font_size_override("font_size", 12)

func _layout_pitch() -> void:
	var c := Game.my_club()
	var s := _pitch.size
	for i in 11:
		var chip: SlotChip = _chips[i]
		var spot: Vector2 = c.lineup_spots[i] if i < c.lineup_spots.size() else Vector2(0.5, 0.5)
		var pos := Vector2(spot.x * s.x, (1.0 - spot.y) * s.y)
		chip.position = pos - chip.custom_minimum_size / 2.0
	# Überlappende Karten auseinanderschieben (nur Anzeige, Spots bleiben):
	# jeweils entlang der Achse mit der geringeren Überlappung, damit die
	# Formation ihre Form behält
	var chip_size: Vector2 = _chips[0].custom_minimum_size
	var min_x := chip_size.x - 4.0   # Karten dürfen sich leicht überschneiden
	var min_y := chip_size.y - 12.0  # (nur Rand, der Token bleibt frei)
	for pass_no in 8:
		var moved := false
		for i in 11:
			for j in range(i + 1, 11):
				var a: SlotChip = _chips[i]
				var b: SlotChip = _chips[j]
				var dx: float = a.position.x - b.position.x
				var dy: float = a.position.y - b.position.y
				var ox := min_x - absf(dx)   # Überlappung waagerecht
				var oy := min_y - absf(dy)   # Überlappung senkrecht
				if ox <= 0.0 or oy <= 0.0:
					continue
				moved = true
				if ox <= oy:
					var push_x := ox / 2.0 + 0.5
					var sign_x := 1.0 if dx >= 0.0 else -1.0
					a.position.x += push_x * sign_x
					b.position.x -= push_x * sign_x
				else:
					var push_y := oy / 2.0 + 0.5
					var sign_y := 1.0 if dy >= 0.0 else -1.0
					a.position.y += push_y * sign_y
					b.position.y -= push_y * sign_y
		if not moved:
			break
	for i in 11:
		var chip: SlotChip = _chips[i]
		chip.position.x = clampf(chip.position.x, 2, s.x - chip_size.x - 2)
		chip.position.y = clampf(chip.position.y, 2, s.y - chip_size.y - 2)

## Baut die FM-artige Spielerliste: Startelf (in Aufstellungs-Reihenfolge),
## dann Bank, dann Reserve – jede Gruppe mit Zwischenüberschrift.
func _refresh_roster() -> void:
	for child in _roster_box.get_children():
		child.queue_free()
	var c := Game.my_club()

	_roster_box.add_child(_group_header("STARTELF", c.lineup.size()))
	var slots := c.lineup_slots()
	for i in c.lineup.size():
		_roster_box.add_child(_build_roster_row(c.lineup[i], "start", slots[i] if i < slots.size() else ""))

	var bench_ids: Array = c.bench.filter(func(pid): return pid > 0 and not c.lineup.has(pid))
	_roster_box.add_child(_group_header("ERSATZBANK", bench_ids.size()))
	for pid in bench_ids:
		_roster_box.add_child(_build_roster_row(pid, "bench", ""))

	var reserve: Array = c.player_ids.filter(func(pid): return not c.lineup.has(pid) and not bench_ids.has(pid))
	reserve.sort_custom(func(a, b):
		var pa := Game.get_player(a)
		var pb := Game.get_player(b)
		var order_a: int = PlayerData.POSITIONS.find(pa.pos)
		var order_b: int = PlayerData.POSITIONS.find(pb.pos)
		if order_a != order_b:
			return order_a < order_b
		return pa.effective_rating() > pb.effective_rating())
	_roster_box.add_child(_group_header("RESERVE", reserve.size()))
	for pid in reserve:
		_roster_box.add_child(_build_roster_row(pid, "reserve", ""))

func _group_header(text: String, count: int) -> Label:
	var l := Label.new()
	l.text = "  %s (%d)" % [text, count]
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	l.add_theme_stylebox_override("normal", UITheme.box(Color(0.08, 0.12, 0.10, 1.0), 4))
	return l

## Eine kompakte Tabellenzeile passend zu den Spaltenüberschriften.
func _build_roster_row(pid: int, kind: String, zone: String) -> RosterRow:
	var p := Game.get_player(pid)
	var row := RosterRow.new()
	row.pid = pid
	row.tab = self
	var style := StyleBoxFlat.new()
	match kind:
		"start": style.bg_color = Color(0.10, 0.17, 0.12, 1.0)
		"bench": style.bg_color = Color(0.12, 0.13, 0.16, 1.0)
		_: style.bg_color = Color(0.09, 0.11, 0.13, 0.6)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	if pid == _selected_pid:
		style.set_border_width_all(2)
		style.border_color = Color.WHITE
	row.add_theme_stylebox_override("panel", style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "Ziehen: auf einen anderen Spieler (Liste oder Feld) zum Tauschen"

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	row.add_child(line)

	# Pos (natürliche Position)
	var pos_cell := CenterContainer.new()
	pos_cell.custom_minimum_size = Vector2(38, 0)
	pos_cell.add_child(UITheme.mini_pill(p.pos, GROUP_COLORS[p.group()].darkened(0.3), Color.WHITE, 34))
	line.add_child(pos_cell)

	# Spielt: aktuelle Zone (Startelf) mit Vertrautheits-Farbe, sonst –
	var zone_lbl := Label.new()
	zone_lbl.custom_minimum_size = Vector2(46, 0)
	zone_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_lbl.add_theme_font_size_override("font_size", 13)
	if zone != "" and PlayerData.GROUP_OF.has(zone):
		var fam := p.position_familiarity(zone)
		zone_lbl.text = zone
		zone_lbl.add_theme_color_override("font_color", UITheme.ACCENT if fam >= 0.999 else (UITheme.TEXT if fam >= 0.72 else UITheme.WARN))
	else:
		zone_lbl.text = "–"
		zone_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(zone_lbl)

	# Name mit Flagge + Verletzungs-/Sperr-Symbol
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_row)
	name_row.add_child(Flags.icon(p.nat, 13))
	var name_label := Label.new()
	name_label.text = p.full_name()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	if p.is_injured():
		name_row.add_child(_cell_icon("🚑", UITheme.DANGER))
	elif p.is_suspended():
		name_row.add_child(_cell_icon("🟥", UITheme.WARN))
	elif not p.learned_positions().is_empty():
		name_row.add_child(_cell_icon("⇄", UITheme.TEXT_DIM))

	# Alter
	line.add_child(_num_cell("%d" % p.age, 30, UITheme.TEXT))
	# Talent
	var tal := Label.new()
	tal.text = p.talent_stars()
	tal.custom_minimum_size = Vector2(66, 0)
	tal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tal.add_theme_font_size_override("font_size", 11)
	tal.add_theme_color_override("font_color", UITheme.WARN if p.talent >= 4 else UITheme.TEXT_DIM)
	line.add_child(tal)
	# Stärke
	line.add_child(_num_cell("%d" % p.strength, 34, UITheme.TEXT))
	# Frische
	line.add_child(_num_cell("%d%%" % int(p.condition), 40, UITheme.TEXT_DIM if p.condition >= 70 else UITheme.WARN))
	# Form
	var form := Label.new()
	form.text = Fmt.form_icon(p.form)
	form.custom_minimum_size = Vector2(26, 0)
	form.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form.add_theme_color_override("font_color", Fmt.form_color(p.form))
	line.add_child(form)
	# Alle Zellen durchlässig machen, damit Klick und Drag der ganzen Zeile gelten
	_pass_mouse_to_row(line)
	return row

## Setzt Maus-Events aller Kinder auf "ignorieren", damit die Zeile selbst
## Klicks und Drag & Drop erhält (Container schlucken sie sonst).
func _pass_mouse_to_row(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pass_mouse_to_row(child)

func _num_cell(text: String, width: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	return l

func _cell_icon(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	return l

## Drag-Vorschau: sieht aus wie der Spieler-Kasten und hängt ZENTRIERT am
## Cursor – der Kasten landet also genau dort, wo man ihn sieht.
func make_drag_preview(source: Control, pid: int) -> void:
	var p := Game.get_player(pid)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.08, 0.9)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
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

# ------------------------------------------------------------------ Drag & Drop

func _norm_spot(at: Vector2) -> Vector2:
	var s := _pitch.size
	return Vector2(clampf(at.x / s.x, 0.02, 0.98), clampf(1.0 - at.y / s.y, 0.02, 0.98))

## Drop auf dem Rasen: FREIE Positionierung – der Spieler spielt genau dort.
func drop_on_pitch(at: Vector2, data: Dictionary) -> void:
	var c := Game.my_club()
	var spot := _norm_spot(at)
	match str(data.kind):
		"slot":
			# Eigenen Feldspieler verschieben – die Zone bestimmt seine Position
			var idx := int(data.slot)
			c.lineup_spots[idx] = spot
			var p := Game.get_player(c.lineup[idx])
			_message.text = "%s spielt jetzt %s." % [p.full_name(), ClubData.zone_position(spot)]
			_refresh_all()
		"bench", "roster":
			_insert_from_outside(int(data.pid), spot, data)

## Neuer Spieler kommt aufs Feld: Er übernimmt exakt den Ablagepunkt.
## Der nächststehende bisherige Feldspieler weicht (Bankplatz des Neuen oder Reserve).
func _insert_from_outside(pid_in: int, spot: Vector2, data: Dictionary) -> void:
	var c := Game.my_club()
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		_message.text = "%s ist nicht einsatzbereit (%s)." % [p_in.full_name(), "verletzt" if p_in.is_injured() else "gesperrt"]
		return
	# Nächstgelegenen Feldspieler als Weichenden bestimmen
	var nearest := 0
	var best := INF
	for i in c.lineup.size():
		var d: float = c.lineup_spots[i].distance_to(spot)
		if d < best:
			best = d
			nearest = i
	var pid_out: int = c.lineup[nearest]
	c.lineup[nearest] = pid_in
	c.lineup_spots[nearest] = spot
	if str(data.kind) == "bench":
		c.bench[int(data.bench)] = pid_out
		_message.text = "%s kommt als %s, %s auf die Bank." % [p_in.full_name(), ClubData.zone_position(spot), Game.get_player(pid_out).last_name]
	else:
		var bench_idx := c.bench.find(pid_in)
		if bench_idx >= 0:
			c.bench[bench_idx] = pid_out
			_message.text = "%s kommt als %s, %s übernimmt den Bankplatz." % [p_in.full_name(), ClubData.zone_position(spot), Game.get_player(pid_out).last_name]
		else:
			_message.text = "%s kommt als %s (raus: %s)." % [p_in.full_name(), ClubData.zone_position(spot), Game.get_player(pid_out).full_name()]
	_refresh_all()

## Drop direkt auf einem Feldspieler: Positionen tauschen bzw. ihn ersetzen.
func drop_on_chip(slot: int, data: Dictionary) -> void:
	var c := Game.my_club()
	match str(data.kind):
		"slot":
			var from := int(data.slot)
			if from == slot:
				return
			var tmp: int = c.lineup[from]
			c.lineup[from] = c.lineup[slot]
			c.lineup[slot] = tmp
			_message.text = "Positionstausch: %s ↔ %s." % [Game.get_player(c.lineup[slot]).last_name, Game.get_player(c.lineup[from]).last_name]
			_refresh_all()
		"bench":
			var pid_in: int = c.bench[int(data.bench)]
			var p_in := Game.get_player(pid_in)
			if not p_in.is_available():
				_message.text = "%s ist nicht einsatzbereit." % p_in.full_name()
				return
			var pid_out: int = c.lineup[slot]
			c.lineup[slot] = pid_in
			c.bench[int(data.bench)] = pid_out
			_message.text = "%s ersetzt %s (%s)." % [p_in.full_name(), Game.get_player(pid_out).last_name, ClubData.zone_position(c.lineup_spots[slot])]
			_refresh_all()
		"roster":
			_insert_at_slot(int(data.pid), slot)

## Drop einer Listenzeile auf eine andere: die beiden Spieler tauschen ihre
## Rollen – egal ob Startelf, Bank oder Reserve.
func drop_on_roster_player(target_pid: int, data: Dictionary) -> void:
	var dragged := int(data.get("pid", -1))
	if dragged <= 0 or dragged == target_pid:
		return
	swap_players(dragged, target_pid)

## Universeller Rollentausch zweier Spieler (Startelf-Slot / Bankplatz / Reserve).
func swap_players(pid_a: int, pid_b: int) -> void:
	var c := Game.my_club()
	var la := c.lineup.find(pid_a)
	var lb := c.lineup.find(pid_b)
	var ba := c.bench.find(pid_a)
	var bb := c.bench.find(pid_b)
	var p_a := Game.get_player(pid_a)
	var p_b := Game.get_player(pid_b)
	# Wer neu in Elf oder Bank rutscht, muss einsatzbereit sein
	if (lb >= 0 or bb >= 0) and not p_a.is_available():
		_message.text = "%s ist nicht einsatzbereit (%s)." % [p_a.full_name(), "verletzt" if p_a.is_injured() else "gesperrt"]
		return
	if (la >= 0 or ba >= 0) and not p_b.is_available():
		_message.text = "%s ist nicht einsatzbereit (%s)." % [p_b.full_name(), "verletzt" if p_b.is_injured() else "gesperrt"]
		return
	if la < 0 and ba < 0 and lb < 0 and bb < 0:
		_message.text = "Beide Spieler sind bereits in der Reserve."
		return
	if la >= 0:
		c.lineup[la] = pid_b
	elif ba >= 0:
		c.bench[ba] = pid_b
	if lb >= 0:
		c.lineup[lb] = pid_a
	elif bb >= 0:
		c.bench[bb] = pid_a
	_message.text = "%s ↔ %s getauscht." % [p_a.last_name, p_b.last_name]
	_refresh_all()

func _insert_at_slot(pid_in: int, slot: int) -> void:
	var c := Game.my_club()
	if c.lineup.has(pid_in):
		drop_on_chip(slot, {"kind": "slot", "slot": c.lineup.find(pid_in)})
		return
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		_message.text = "%s ist nicht einsatzbereit." % p_in.full_name()
		return
	var pid_out: int = c.lineup[slot]
	c.lineup[slot] = pid_in
	var bench_idx := c.bench.find(pid_in)
	if bench_idx >= 0:
		c.bench[bench_idx] = pid_out
	_message.text = "%s ersetzt %s (%s)." % [p_in.full_name(), Game.get_player(pid_out).last_name, ClubData.zone_position(c.lineup_spots[slot])]
	_refresh_all()

func drop_on_bench(bench_index: int, data: Dictionary) -> void:
	var c := Game.my_club()
	match str(data.kind):
		"bench":
			var from := int(data.bench)
			if from == bench_index:
				return
			_ensure_bench_size(c)
			var tmp: int = c.bench[from]
			c.bench[from] = c.bench[bench_index]
			c.bench[bench_index] = tmp
			c.bench = c.bench.filter(func(pid): return pid > 0)
			_message.text = "Bankplätze getauscht."
		"roster":
			var p := Game.get_player(int(data.pid))
			if not p.is_available():
				_message.text = "%s ist nicht einsatzbereit." % p.full_name()
			else:
				_ensure_bench_size(c)
				var old := c.bench.find(int(data.pid))
				if old >= 0:
					c.bench[old] = c.bench[bench_index]
				c.bench[bench_index] = int(data.pid)
				c.bench = c.bench.filter(func(x): return x > 0)
				_message.text = "%s sitzt auf der Bank." % p.full_name()
		"slot":
			if bench_index >= c.bench.size() or c.bench[bench_index] <= 0:
				_message.text = "Die Startelf braucht 11 Spieler – tausche mit einem Bankspieler."
			else:
				var slot := int(data.slot)
				var pid_in: int = c.bench[bench_index]
				var p_in := Game.get_player(pid_in)
				if not p_in.is_available():
					_message.text = "%s ist nicht einsatzbereit." % p_in.full_name()
				else:
					var pid_out: int = c.lineup[slot]
					c.lineup[slot] = pid_in
					c.bench[bench_index] = pid_out
					_message.text = "%s rückt in die Startelf, %s auf die Bank." % [p_in.full_name(), Game.get_player(pid_out).last_name]
	_refresh_all()

func _ensure_bench_size(c: ClubData) -> void:
	while c.bench.size() < ClubData.BENCH_SIZE:
		c.bench.append(-1)

# ------------------------------------------------------------------ Klick-Bedienung

func select_player(pid: int) -> void:
	_selected_pid = pid if _selected_pid != pid else -1
	if _selected_pid > 0:
		_message.text = "%s gewählt – Ziel anklicken (Feldspieler oder Bankplatz)." % Game.get_player(pid).full_name()
	_refresh_all()

func _on_chip_clicked(slot: int) -> void:
	var c := Game.my_club()
	if _selected_pid > 0 and _selected_pid != c.lineup[slot]:
		var pid := _selected_pid
		_selected_pid = -1
		if c.lineup.has(pid):
			drop_on_chip(slot, {"kind": "slot", "slot": c.lineup.find(pid)})
		elif c.bench.has(pid):
			drop_on_chip(slot, {"kind": "bench", "bench": c.bench.find(pid)})
		else:
			_insert_at_slot(pid, slot)
		return
	var chip: SlotChip = _chips[slot]
	if chip.pid > 0:
		select_player(chip.pid)

func _on_chip_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var chip: SlotChip = _chips[slot]
		if chip.pid > 0:
			_profile.open_for(chip.pid)

func _on_bench_chip_clicked(bench_index: int) -> void:
	var c := Game.my_club()
	if _selected_pid > 0:
		var pid := _selected_pid
		_selected_pid = -1
		if c.lineup.has(pid):
			drop_on_bench(bench_index, {"kind": "slot", "slot": c.lineup.find(pid)})
		else:
			drop_on_bench(bench_index, {"kind": "roster", "pid": pid})
		return
	var bc: BenchChip = _bench_chips[bench_index]
	if bc.pid > 0:
		select_player(bc.pid)

func _on_bench_gui_input(event: InputEvent, bench_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var bc: BenchChip = _bench_chips[bench_index]
		if bc.pid > 0:
			_profile.open_for(bc.pid)

# ------------------------------------------------------------------ Aktionen

func _on_formation_changed(index: int) -> void:
	var c := Game.my_club()
	c.apply_formation(_formation_select.get_item_text(index), Game.world.players)
	_message.text = "Preset %s geladen – Positionen frei anpassbar." % c.formation
	refresh()

func _on_best_eleven() -> void:
	var c := Game.my_club()
	c.lineup_spots = ClubData.FORMATION_SPOTS.get(c.formation, ClubData.FORMATION_SPOTS["4-4-2"]).duplicate()
	c.lineup = c.best_eleven(Game.world.players, "", _pick_weights)
	c.bench = c.best_bench(Game.world.players, c.lineup, _pick_weights)
	_message.text = "Beste Elf & Bank nach %s aufgestellt." % _crit_label()
	refresh()

# ------------------------------------------------------------------ Kriterien-Popup

func _crit_label() -> String:
	var best_key := "str"
	for k in _pick_weights:
		if _pick_weights[k] > _pick_weights[best_key]:
			best_key = k
	return {"str": "Stärke", "fresh": "Frische", "form": "Form"}[best_key]

func _build_criteria_popup() -> void:
	_crit_popup = PopupPanel.new()
	add_child(_crit_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(320, 0)
	_crit_popup.add_child(box)
	var title := Label.new()
	title.text = "Auswahl-Kriterien für „Beste Elf & Bank“"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Wie stark zählt jeder Faktor bei der Auto-Aufstellung?"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(hint)
	for entry in [["str", "Stärke"], ["fresh", "Frische"], ["form", "Form"]]:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var lbl := Label.new()
		lbl.text = entry[1]
		lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(lbl)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = _pick_weights[key] * 100.0
		slider.custom_minimum_size = Vector2(160, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_crit_changed.bind(key))
		row.add_child(slider)
		_crit_sliders[key] = slider
		var val := Label.new()
		val.custom_minimum_size = Vector2(40, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		_crit_values[key] = val
	var apply := Button.new()
	apply.text = "⭐ Jetzt aufstellen"
	UITheme.make_primary(apply)
	apply.pressed.connect(func(): _crit_popup.hide(); _on_best_eleven())
	box.add_child(apply)
	_update_crit_labels()

func _open_criteria() -> void:
	_crit_popup.popup_centered()

func _on_crit_changed(value: float, key: String) -> void:
	_pick_weights[key] = value / 100.0
	_update_crit_labels()

func _update_crit_labels() -> void:
	for key in _crit_values:
		_crit_values[key].text = "%d%%" % int(_pick_weights[key] * 100.0)

# ------------------------------------------------------------------ Gespeicherte Aufstellungen

func _build_preset_popup() -> void:
	_preset_popup = PopupPanel.new()
	add_child(_preset_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(430, 0)
	_preset_popup.add_child(box)
	var title := Label.new()
	title.text = "Gespeicherte Aufstellungen"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Formation, Positionen auf dem Feld und Ersatzbank werden mitgespeichert."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	box.add_child(hint)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	box.add_child(save_row)
	_preset_name_edit = LineEdit.new()
	_preset_name_edit.placeholder_text = "Name (leer = automatisch)"
	_preset_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_preset_name_edit)
	var save_button := Button.new()
	save_button.text = "💾 Sichern"
	UITheme.make_primary(save_button)
	save_button.pressed.connect(_on_preset_save)
	save_row.add_child(save_button)
	_preset_list = VBoxContainer.new()
	_preset_list.add_theme_constant_override("separation", 4)
	box.add_child(_preset_list)

func _open_presets() -> void:
	_refresh_preset_list()
	_preset_popup.popup_centered()

func _refresh_preset_list() -> void:
	for child in _preset_list.get_children():
		child.queue_free()
	if Game.lineup_presets.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Aufstellung gespeichert."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_preset_list.add_child(empty)
		return
	for i in Game.lineup_presets.size():
		var preset: Dictionary = Game.lineup_presets[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_preset_list.add_child(row)
		var name_label := Label.new()
		name_label.text = "%s  (%s)" % [str(preset.name), str(preset.get("formation", ""))]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)
		var load_button := Button.new()
		load_button.text = "Laden"
		load_button.pressed.connect(_on_preset_load.bind(i))
		row.add_child(load_button)
		var del := Button.new()
		del.text = "🗑"
		del.pressed.connect(_on_preset_delete.bind(i))
		row.add_child(del)

func _on_preset_save() -> void:
	var saved := Game.save_lineup_preset(_preset_name_edit.text)
	_preset_name_edit.text = ""
	_message.text = "Aufstellung „%s“ gespeichert." % saved
	_refresh_preset_list()

func _on_preset_load(index: int) -> void:
	var replaced := Game.load_lineup_preset(index)
	_preset_popup.hide()
	if replaced < 0:
		_message.text = "Aufstellung konnte nicht geladen werden."
		return
	var preset: Dictionary = Game.lineup_presets[index]
	_message.text = "Aufstellung „%s“ geladen." % str(preset.name) if replaced == 0 \
		else "Aufstellung „%s“ geladen – %d Spieler ersetzt (fehlen oder nicht fit)." % [str(preset.name), replaced]
	refresh()

func _on_preset_delete(index: int) -> void:
	Game.delete_lineup_preset(index)
	_refresh_preset_list()
