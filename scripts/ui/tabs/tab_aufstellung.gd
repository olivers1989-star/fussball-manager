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

# ------------------------------------------------------------------ Spielfeld

## Rasen mit Linien und Zonen-Andeutung; Drops überall erlaubt (freie Position).
class PitchControl extends Control:
	var tab: TabAufstellung

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#1a6b34"))
		var stripes := 8
		for i in stripes:
			if i % 2 == 0:
				draw_rect(Rect2(0, size.y * i / stripes, size.x, size.y / stripes), Color("#1d7439"))
		var line := Color(1, 1, 1, 0.55)
		var w := 2.0
		var inset := 6.0
		var field := Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2))
		draw_rect(field, line, false, w)
		draw_line(Vector2(inset, size.y * 0.5), Vector2(size.x - inset, size.y * 0.5), line, w)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.12, 0, TAU, 48, line, w)
		var box_w := size.x * 0.55
		var box_h := size.y * 0.14
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, size.y - inset - box_h), Vector2(box_w, box_h)), line, false, w)
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, inset), Vector2(box_w, box_h)), line, false, w)
		var small_w := size.x * 0.26
		var small_h := size.y * 0.055
		draw_rect(Rect2(Vector2((size.x - small_w) / 2.0, size.y - inset - small_h), Vector2(small_w, small_h)), line, false, w)
		draw_rect(Rect2(Vector2((size.x - small_w) / 2.0, inset), Vector2(small_w, small_h)), line, false, w)
		# Zonen-Reihen dezent andeuten (Abwehr / Mittelfeld / Angriff)
		var zone := Color(1, 1, 1, 0.10)
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

	func _init(p_tab: TabAufstellung, index: int) -> void:
		tab = p_tab
		slot_index = index
		custom_minimum_size = Vector2(142, 58)
		clip_text = true
		focus_mode = Control.FOCUS_NONE

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
		return {"kind": "roster", "pid": pid}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				tab._profile.open_for(pid)
			elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				tab._profile.open_for(pid)

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
	_summary = info_label()
	top.add_child(_summary)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(main)

	_pitch = PitchControl.new()
	_pitch.tab = self
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_stretch_ratio = 1.15
	_pitch.custom_minimum_size = Vector2(430, 520)
	_pitch.clip_contents = true
	_pitch.resized.connect(_layout_pitch)
	main.add_child(_pitch)
	for i in 11:
		var chip := SlotChip.new(self, i)
		chip.pressed.connect(_on_chip_clicked.bind(i))
		chip.gui_input.connect(_on_chip_gui_input.bind(i))
		_pitch.add_child(chip)
		_chips.append(chip)

	# Ersatzbank als Spalte NEBEN dem Feld – so bleiben die Außenbahnen frei
	var bench_col := VBoxContainer.new()
	bench_col.add_theme_constant_override("separation", 5)
	bench_col.custom_minimum_size = Vector2(190, 0)
	main.add_child(bench_col)
	var bench_title := Label.new()
	bench_title.text = "🪑 Ersatzbank (max. %d)" % ClubData.BENCH_SIZE
	bench_title.add_theme_font_size_override("font_size", 14)
	bench_title.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	bench_col.add_child(bench_title)
	for i in ClubData.BENCH_SIZE:
		var bc := BenchChip.new(self, i)
		bc.pressed.connect(_on_bench_chip_clicked.bind(i))
		bc.gui_input.connect(_on_bench_gui_input.bind(i))
		bench_col.add_child(bc)
		_bench_chips.append(bc)
	var bench_hint := Label.new()
	bench_hint.text = "Im Spiel darf nur von\ndieser Bank gewechselt\nwerden."
	bench_hint.add_theme_font_size_override("font_size", 11)
	bench_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	bench_col.add_child(bench_hint)

	# Rechts: detaillierte Kaderliste
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	right.add_child(heading("Kader"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 4)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_box)
	var hint := info_label()
	hint.text = "Spieler frei aufs Feld ziehen – wo du ihn ablegst, spielt er (Zonen-Erkennung).\nDoppel-/Rechtsklick: Spielerprofil."
	right.add_child(hint)

	_message = info_label()
	box.add_child(_message)

	_profile = PlayerProfileDialog.new()
	add_child(_profile)

# ------------------------------------------------------------------ Anzeige

func refresh() -> void:
	var c := Game.my_club()
	for i in _formation_select.item_count:
		if _formation_select.get_item_text(i) == c.formation:
			_formation_select.select(i)
			break
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
			var head := chip.zone_pos
			var fam := p.position_familiarity(chip.zone_pos)
			var fam_note := "eigene Position"
			if p.pos != chip.zone_pos:
				if fam >= PlayerData.SEC_LEARNED:
					head += " ✓"   # gelernte Nebenposition
					fam_note = "gelernte Nebenposition"
				elif fam >= 0.72:
					head += " ◊"   # naheliegende Aushilfsrolle
					fam_note = "Aushilfsrolle"
				else:
					head += " ⚠"   # positionsfremd
					fam_note = "positionsfremd"
					warnings += 1
			chip.text = "%s %s\n%s\nSt %d · %s · %d%%" % [head, Nations.code(p.nat), p.last_name, st, Fmt.form_icon(p.form), int(p.condition)]
			chip.tooltip_text = "%s (%s, %s)\nSpielt %s (%s, %d %% Vertrautheit): Stärke %d – eigene Position %s: %d%s" % [
				p.full_name(), p.pos, p.nat, chip.zone_pos, fam_note, int(fam * 100.0), st, p.pos, p.strength,
				("\n" + ", ".join(p.traits)) if not p.traits.is_empty() else ""]
		else:
			chip.text = "%s\n– frei –" % chip.zone_pos
			chip.tooltip_text = ""
		_style_chip(chip)
	var avg := total / 11.0
	var warn_text := "  ·  ⚠ %d positionsfremd" % warnings if warnings > 0 else ""
	_summary.text = "Ausrichtung %s · Elf-Stärke auf Position: Ø %.1f%s" % [c.shape_label(), avg, warn_text]
	_layout_pitch()

func _style_chip(chip: SlotChip) -> void:
	var group: String = PlayerData.GROUP_OF[chip.zone_pos]
	var base: Color = GROUP_COLORS[group]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.08, 0.92)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = base
	if chip.pid > 0 and Game.get_player(chip.pid).position_familiarity(chip.zone_pos) < 0.72:
		style.border_color = Color("#f59e0b")
		style.bg_color = Color(0.2, 0.12, 0.02, 0.94)
	if chip.pid > 0 and chip.pid == _selected_pid:
		style.set_border_width_all(3)
		style.border_color = Color.WHITE
	chip.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	chip.add_theme_stylebox_override("hover", hover)
	chip.add_theme_stylebox_override("pressed", style)
	chip.add_theme_font_size_override("font_size", 12)

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
	# Überlappende Chips sanft auseinanderschieben (nur Anzeige, Spots bleiben)
	var chip_size: Vector2 = _chips[0].custom_minimum_size
	for pass_no in 3:
		for i in 11:
			for j in range(i + 1, 11):
				var a: SlotChip = _chips[i]
				var b: SlotChip = _chips[j]
				var dx: float = absf(a.position.x - b.position.x)
				var dy: float = absf(a.position.y - b.position.y)
				if dx < chip_size.x * 0.9 and dy < chip_size.y * 0.9:
					var push := (chip_size.y * 0.95 - dy) / 2.0 + 1.0
					if a.position.y <= b.position.y:
						a.position.y -= push
						b.position.y += push
					else:
						a.position.y += push
						b.position.y -= push
	for i in 11:
		var chip: SlotChip = _chips[i]
		chip.position.x = clampf(chip.position.x, 2, s.x - chip_size.x - 2)
		chip.position.y = clampf(chip.position.y, 2, s.y - chip_size.y - 2)

func _refresh_roster() -> void:
	for child in _roster_box.get_children():
		child.queue_free()
	var c := Game.my_club()
	var ids: Array = c.player_ids.filter(func(pid): return not c.lineup.has(pid))
	ids.sort_custom(func(a, b):
		var pa := Game.get_player(a)
		var pb := Game.get_player(b)
		var bench_a := c.bench.has(a)
		var bench_b := c.bench.has(b)
		if bench_a != bench_b:
			return bench_a
		var order_a: int = PlayerData.POSITIONS.find(pa.pos)
		var order_b: int = PlayerData.POSITIONS.find(pb.pos)
		if order_a != order_b:
			return order_a < order_b
		return pa.effective_rating() > pb.effective_rating())
	for pid in ids:
		_roster_box.add_child(_build_roster_row(pid, c.bench.has(pid)))

func _build_roster_row(pid: int, on_bench: bool) -> RosterRow:
	var p := Game.get_player(pid)
	var row := RosterRow.new()
	row.pid = pid
	row.tab = self
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.14, 0.12, 1.0) if on_bench else UITheme.SURFACE
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_content_margin_all(7)
	row.add_theme_stylebox_override("panel", style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	line.add_child(UITheme.mini_pill(p.pos, GROUP_COLORS[p.group()].darkened(0.35), Color.WHITE, 36))
	line.add_child(Flags.icon(p.nat, 15))

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	line.add_child(name_box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = p.full_name()
	name_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(name_label)
	if on_bench:
		name_row.add_child(UITheme.mini_pill("BANK", Color("#3f3f46"), Color.WHITE, 42))
	var talent := Label.new()
	talent.text = p.talent_stars()
	talent.add_theme_font_size_override("font_size", 11)
	talent.add_theme_color_override("font_color", UITheme.WARN if p.talent >= 4 else UITheme.TEXT_DIM)
	name_row.add_child(talent)
	var sub := Label.new()
	var note_txt := (", Ø %.1f" % p.avg_rating()).replace(".", ",") if p.matches_season > 0 else ""
	var traits_txt := (" · " + ", ".join(p.traits)) if not p.traits.is_empty() else ""
	sub.text = "%d J. · %d Sp.%s · %d Tore · %s%s" % [p.age, p.matches_season, note_txt, p.goals_season, Fmt.money(p.market_value()), traits_txt]
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	sub.clip_text = true
	name_box.add_child(sub)

	var st := Label.new()
	st.text = "St %d" % p.strength
	st.add_theme_font_size_override("font_size", 16)
	line.add_child(st)
	var form := Label.new()
	form.text = Fmt.form_icon(p.form)
	form.add_theme_color_override("font_color", Fmt.form_color(p.form))
	line.add_child(form)
	var cond := Label.new()
	cond.text = "%d%%" % int(p.condition)
	cond.add_theme_font_size_override("font_size", 12)
	cond.add_theme_color_override("font_color", UITheme.TEXT_DIM if p.condition >= 70 else UITheme.WARN)
	line.add_child(cond)
	if p.is_injured():
		line.add_child(UITheme.mini_pill("🚑 %d" % p.injury_matchdays, Color("#7f1d1d"), Color.WHITE, 48))
	elif p.is_suspended():
		line.add_child(UITheme.mini_pill("🟥 %d" % p.suspended_matchdays, Color("#854d0e"), Color.WHITE, 48))
	return row

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
	c.lineup = c.best_eleven(Game.world.players)
	c.bench = c.best_bench(Game.world.players, c.lineup)
	_message.text = "Beste Elf und Bank wurden aufgestellt."
	refresh()
