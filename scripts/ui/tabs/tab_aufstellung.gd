class_name TabAufstellung
extends TabBase
## Aufstellung: links das 2D-Spielfeld mit Formations-Slots und der Ersatzbank
## (oben rechts, max. 7 Plätze), rechts die detaillierte Kaderliste.
## Spieler können frei aufs Feld gezogen werden – das Spiel erkennt automatisch
## den nächstgelegenen Positions-Slot. SLOT-BASIERT: Jeder Spieler wird im Spiel
## auf seinem Slot bewertet (Fehlbesetzung kostet messbar Leistung).

## Slot-Koordinaten je Formation (x: 0=links..1=rechts, y: 0=eigenes Tor..1=vorne).
const LAYOUTS := {
	"4-4-2": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.14, 0.58), Vector2(0.38, 0.52), Vector2(0.62, 0.52), Vector2(0.86, 0.58), Vector2(0.38, 0.84), Vector2(0.62, 0.84)],
	"4-4-2 (Raute)": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.42), Vector2(0.26, 0.56), Vector2(0.74, 0.56), Vector2(0.5, 0.68), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
	"4-3-3": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.5, 0.44), Vector2(0.3, 0.56), Vector2(0.7, 0.56), Vector2(0.15, 0.8), Vector2(0.5, 0.86), Vector2(0.85, 0.8)],
	"4-2-3-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.36, 0.46), Vector2(0.64, 0.46), Vector2(0.5, 0.64), Vector2(0.15, 0.68), Vector2(0.85, 0.68), Vector2(0.5, 0.86)],
	"4-5-1": [Vector2(0.5, 0.05), Vector2(0.14, 0.3), Vector2(0.38, 0.24), Vector2(0.62, 0.24), Vector2(0.86, 0.3), Vector2(0.12, 0.6), Vector2(0.34, 0.48), Vector2(0.66, 0.48), Vector2(0.88, 0.6), Vector2(0.5, 0.66), Vector2(0.5, 0.86)],
	"3-5-2": [Vector2(0.5, 0.05), Vector2(0.26, 0.24), Vector2(0.5, 0.2), Vector2(0.74, 0.24), Vector2(0.12, 0.58), Vector2(0.36, 0.46), Vector2(0.64, 0.46), Vector2(0.88, 0.58), Vector2(0.5, 0.64), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
	"5-3-2": [Vector2(0.5, 0.05), Vector2(0.12, 0.34), Vector2(0.3, 0.24), Vector2(0.5, 0.2), Vector2(0.7, 0.24), Vector2(0.88, 0.34), Vector2(0.3, 0.54), Vector2(0.7, 0.54), Vector2(0.5, 0.66), Vector2(0.38, 0.86), Vector2(0.62, 0.86)],
}

const GROUP_COLORS := {
	"TW": Color("#eab308"), "AB": Color("#3b82f6"),
	"MF": Color("#22c55e"), "ST": Color("#ef4444"),
}

var _formation_select: OptionButton
var _pitch: PitchControl
var _chips: Array = []            # 11 SlotChip
var _bench_panel: PanelContainer  # Ersatzbank-Overlay oben rechts auf dem Feld
var _bench_chips: Array = []      # BENCH_SIZE BenchChip
var _roster_scroll: ScrollContainer
var _roster_box: VBoxContainer
var _message: Label
var _summary: Label
var _profile: PlayerProfileDialog
var _selected_pid := -1           # Klick-Klick: gewählter Spieler (Kader/Bank/Feld)

# ------------------------------------------------------------------ Spielfeld

## Rasen mit Linien; nimmt Drops ÜBERALL an und findet den nächsten Slot.
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

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"]

	func _drop_data(at: Vector2, data: Variant) -> void:
		tab.drop_on_pitch(at, data)

## Ein Formations-Slot auf dem Feld.
class SlotChip extends Button:
	var slot_index := 0
	var slot_pos := ""
	var pid := -1
	var tab: TabAufstellung

	func _init(p_tab: TabAufstellung, index: int) -> void:
		tab = p_tab
		slot_index = index
		custom_minimum_size = Vector2(148, 62)
		clip_text = true
		focus_mode = Control.FOCUS_NONE

	func _get_drag_data(_at: Vector2) -> Variant:
		if pid <= 0:
			return null
		tab.make_drag_preview(self, pid)
		return {"kind": "slot", "slot": slot_index, "pid": pid}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench", "roster"]

	func _drop_data(_at: Vector2, data: Variant) -> void:
		tab.drop_on_slot(slot_index, data)

## Ein Platz auf der Ersatzbank (Overlay auf dem Spielfeld).
class BenchChip extends Button:
	var bench_index := 0
	var pid := -1
	var tab: TabAufstellung

	func _init(p_tab: TabAufstellung, index: int) -> void:
		tab = p_tab
		bench_index = index
		custom_minimum_size = Vector2(168, 27)
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

## Eine Zeile der Kaderliste (Drag-Quelle, Klick wählt, Rechtsklick öffnet Profil).
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
			elif event.button_index == MOUSE_BUTTON_LEFT:
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
	form_label.text = "Formation:"
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
	main.add_theme_constant_override("separation", 18)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(main)

	_pitch = PitchControl.new()
	_pitch.tab = self
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_stretch_ratio = 1.25
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

	# Ersatzbank als Overlay oben rechts auf dem Spielfeld
	_bench_panel = PanelContainer.new()
	var bench_style := StyleBoxFlat.new()
	bench_style.bg_color = Color(0.04, 0.07, 0.06, 0.82)
	bench_style.set_corner_radius_all(10)
	bench_style.set_border_width_all(1)
	bench_style.border_color = Color(1, 1, 1, 0.25)
	bench_style.set_content_margin_all(8)
	_bench_panel.add_theme_stylebox_override("panel", bench_style)
	var bench_box := VBoxContainer.new()
	bench_box.add_theme_constant_override("separation", 4)
	_bench_panel.add_child(bench_box)
	var bench_title := Label.new()
	bench_title.text = "🪑 Ersatzbank"
	bench_title.add_theme_font_size_override("font_size", 13)
	bench_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	bench_box.add_child(bench_title)
	for i in ClubData.BENCH_SIZE:
		var bc := BenchChip.new(self, i)
		bc.pressed.connect(_on_bench_chip_clicked.bind(i))
		bc.gui_input.connect(_on_bench_gui_input.bind(i))
		bench_box.add_child(bc)
		_bench_chips.append(bc)
	_bench_panel.resized.connect(_layout_pitch)
	_pitch.add_child(_bench_panel)

	# Rechts: detaillierte Kaderliste
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	right.add_child(heading("Kader"))
	_roster_scroll = ScrollContainer.new()
	_roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_roster_scroll)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 4)
	_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll.add_child(_roster_box)
	var hint := info_label()
	hint.text = "Spieler einfach aufs Feld ziehen – die Position wird automatisch erkannt.\nBank: auf die Ersatzbank ziehen. Rechtsklick: Spielerprofil."
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
	# Ungültige Aufstellung/Bank automatisch reparieren
	c.lineup = c.match_lineup(Game.world.players).duplicate()
	c.bench = c.match_bench(Game.world.players, c.lineup).duplicate()
	_selected_pid = -1
	_refresh_all()

func _refresh_all() -> void:
	_refresh_chips()
	_refresh_bench()
	_refresh_roster()

func _refresh_chips() -> void:
	var c := Game.my_club()
	var slots: Array = ClubData.FORMATIONS[c.formation]
	var total := 0
	var warnings := 0
	for i in 11:
		var chip: SlotChip = _chips[i]
		chip.slot_pos = slots[i]
		chip.pid = c.lineup[i] if i < c.lineup.size() else -1
		if chip.pid > 0:
			var p := Game.get_player(chip.pid)
			var st := p.strength_at(chip.slot_pos)
			total += st
			var head := chip.slot_pos
			if p.pos != chip.slot_pos:
				head += " ⚠ (%s)" % p.pos if p.group() != PlayerData.GROUP_OF[chip.slot_pos] else " ◊ (%s)" % p.pos
			if p.group() != PlayerData.GROUP_OF[chip.slot_pos]:
				warnings += 1
			chip.text = "%s\n%s\nSt %d · %s · %d%%" % [head, p.last_name, st, Fmt.form_icon(p.form), int(p.condition)]
			chip.tooltip_text = "%s (%s, %s)\nStärke auf %s: %d (auf %s: %d)%s" % [
				p.full_name(), p.pos, p.nat, chip.slot_pos, st, p.pos, p.strength,
				("\n" + ", ".join(p.traits)) if not p.traits.is_empty() else ""]
		else:
			chip.text = "%s\n– frei –" % chip.slot_pos
			chip.tooltip_text = ""
		_style_chip(chip)
	var avg := total / 11.0
	var warn_text := "  ·  ⚠ %d Positionsfremde" % warnings if warnings > 0 else ""
	_summary.text = "Elf-Stärke auf Position: Ø %.1f%s" % [avg, warn_text]
	_layout_pitch()

func _style_chip(chip: SlotChip) -> void:
	var group: String = PlayerData.GROUP_OF[chip.slot_pos]
	var base: Color = GROUP_COLORS[group]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.08, 0.92)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = base
	if chip.pid > 0 and Game.get_player(chip.pid).group() != group:
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
	chip.add_theme_font_size_override("font_size", 13)

func _refresh_bench() -> void:
	var c := Game.my_club()
	for i in ClubData.BENCH_SIZE:
		var bc: BenchChip = _bench_chips[i]
		bc.pid = c.bench[i] if i < c.bench.size() else -1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.09, 0.12, 0.1, 0.95)
		style.set_corner_radius_all(6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.2)
		if bc.pid > 0:
			var p := Game.get_player(bc.pid)
			bc.text = " %s  %s · St %d · %d%%" % [p.pos, p.last_name, p.strength, int(p.condition)]
			bc.tooltip_text = "%s (%s)" % [p.full_name(), p.nat]
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
	var layout: Array = LAYOUTS.get(Game.my_club().formation, LAYOUTS["4-4-2"])
	var s := _pitch.size
	_bench_panel.position = Vector2(s.x - _bench_panel.size.x - 10, 10)
	var panel_rect := Rect2(_bench_panel.position, _bench_panel.size).grow(4)
	for i in 11:
		var chip: SlotChip = _chips[i]
		var norm: Vector2 = layout[i]
		var pos := Vector2(norm.x * s.x, (1.0 - norm.y) * s.y)
		chip.position = pos - chip.custom_minimum_size / 2.0
		chip.position.x = clampf(chip.position.x, 2, s.x - chip.custom_minimum_size.x - 2)
		chip.position.y = clampf(chip.position.y, 2, s.y - chip.custom_minimum_size.y - 2)
		# Chips weichen der Ersatzbank aus (z. B. der RM im 4-4-2)
		if Rect2(chip.position, chip.custom_minimum_size).intersects(panel_rect):
			chip.position.y = panel_rect.position.y + panel_rect.size.y + 4

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
	style.bg_color = Color(0.10, 0.13, 0.12, 1.0) if on_bench else UITheme.SURFACE
	style.set_corner_radius_all(8)
	style.set_border_width_all(2 if pid == _selected_pid else 1)
	style.border_color = Color.WHITE if pid == _selected_pid else Color(1, 1, 1, 0.08)
	style.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	line.add_child(UITheme.mini_pill(p.pos, GROUP_COLORS[p.group()].darkened(0.35), Color.WHITE, 36))

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 0)
	line.add_child(name_box)
	var name_label := Label.new()
	name_label.text = p.full_name() + ("   🪑" if on_bench else "")
	name_label.add_theme_font_size_override("font_size", 14)
	name_box.add_child(name_label)
	var sub := Label.new()
	var traits_txt := (" · " + ", ".join(p.traits)) if not p.traits.is_empty() else ""
	sub.text = "%d J. · %s%s" % [p.age, Nations.code(p.nat), traits_txt]
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	sub.clip_text = true
	name_box.add_child(sub)

	var st := Label.new()
	st.text = "St %d" % p.strength
	st.add_theme_font_size_override("font_size", 15)
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

func make_drag_preview(source: Control, pid: int) -> void:
	var p := Game.get_player(pid)
	var preview := Label.new()
	preview.text = "  %s (%s)  " % [p.last_name, p.pos]
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.07, 0.95)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color.WHITE
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(preview)
	source.set_drag_preview(panel)

# ------------------------------------------------------------------ Drag & Drop

## Drop irgendwo auf dem Rasen: nächstgelegenen Slot finden (Positions-Erkennung).
func drop_on_pitch(at: Vector2, data: Dictionary) -> void:
	var best_slot := 0
	var best_dist := INF
	for i in 11:
		var chip: SlotChip = _chips[i]
		var center: Vector2 = chip.position + chip.size / 2.0
		var d := at.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_slot = i
	drop_on_slot(best_slot, data)

func drop_on_slot(slot: int, data: Dictionary) -> void:
	match str(data.kind):
		"slot":
			_swap_slots(int(data.slot), slot)
		"bench":
			_bench_to_slot(int(data.bench), slot)
		"roster":
			_roster_to_slot(int(data.pid), slot)

func drop_on_bench(bench_index: int, data: Dictionary) -> void:
	var c := Game.my_club()
	match str(data.kind):
		"bench":
			# Bankplätze untereinander tauschen
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
			_roster_to_bench(int(data.pid), bench_index)
		"slot":
			_slot_to_bench(int(data.slot), bench_index)
	_refresh_all()

# ------------------------------------------------------------------ Kader-Operationen

func _ensure_bench_size(c: ClubData) -> void:
	while c.bench.size() < ClubData.BENCH_SIZE:
		c.bench.append(-1)

func _swap_slots(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot:
		return
	var c := Game.my_club()
	var tmp: int = c.lineup[from_slot]
	c.lineup[from_slot] = c.lineup[to_slot]
	c.lineup[to_slot] = tmp
	_message.text = "Positionstausch: %s ↔ %s." % [ClubData.FORMATIONS[c.formation][from_slot], ClubData.FORMATIONS[c.formation][to_slot]]
	_refresh_all()

## Bankspieler in die Startelf: der verdrängte Spieler übernimmt den Bankplatz.
func _bench_to_slot(bench_index: int, slot: int) -> void:
	var c := Game.my_club()
	if bench_index >= c.bench.size():
		return
	var pid_in: int = c.bench[bench_index]
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		_message.text = "%s ist nicht einsatzbereit." % p_in.full_name()
		return
	var pid_out: int = c.lineup[slot]
	c.lineup[slot] = pid_in
	c.bench[bench_index] = pid_out
	_message.text = "%s rückt in die Startelf (%s), %s auf die Bank." % [p_in.full_name(), ClubData.FORMATIONS[c.formation][slot], Game.get_player(pid_out).last_name]
	_refresh_all()

## Reservespieler direkt in die Startelf: der verdrängte Spieler geht in die Reserve.
func _roster_to_slot(pid_in: int, slot: int) -> void:
	var c := Game.my_club()
	if c.lineup.has(pid_in):
		_swap_slots(c.lineup.find(pid_in), slot)
		return
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		_message.text = "%s ist nicht einsatzbereit (%s)." % [p_in.full_name(), "verletzt" if p_in.is_injured() else "gesperrt"]
		return
	var was_bench := c.bench.find(pid_in)
	var pid_out: int = c.lineup[slot]
	c.lineup[slot] = pid_in
	if was_bench >= 0:
		c.bench[was_bench] = pid_out
		_message.text = "%s spielt %s, %s übernimmt seinen Bankplatz." % [p_in.full_name(), ClubData.FORMATIONS[c.formation][slot], Game.get_player(pid_out).last_name]
	else:
		_message.text = "%s übernimmt den %s-Slot (raus: %s)." % [p_in.full_name(), ClubData.FORMATIONS[c.formation][slot], Game.get_player(pid_out).full_name()]
	_refresh_all()

func _roster_to_bench(pid: int, bench_index: int) -> void:
	var c := Game.my_club()
	if c.lineup.has(pid):
		_slot_to_bench(c.lineup.find(pid), bench_index)
		return
	var p := Game.get_player(pid)
	if not p.is_available():
		_message.text = "%s ist nicht einsatzbereit." % p.full_name()
		return
	_ensure_bench_size(c)
	var old := c.bench.find(pid)
	if old >= 0:
		c.bench[old] = c.bench[bench_index]
	c.bench[bench_index] = pid
	c.bench = c.bench.filter(func(x): return x > 0)
	_message.text = "%s sitzt auf der Bank." % p.full_name()

## Startelf-Spieler auf die Bank ziehen: nur als Tausch mit einem Bankspieler möglich.
func _slot_to_bench(slot: int, bench_index: int) -> void:
	var c := Game.my_club()
	if bench_index >= c.bench.size() or c.bench[bench_index] <= 0:
		_message.text = "Die Startelf braucht 11 Spieler – ziehe zuerst einen Ersatzspieler auf seinen Slot."
		return
	_bench_to_slot(bench_index, slot)

# ------------------------------------------------------------------ Klick-Bedienung

func select_player(pid: int) -> void:
	_selected_pid = pid if _selected_pid != pid else -1
	if _selected_pid > 0:
		_message.text = "%s gewählt – Ziel anklicken (Slot oder Bankplatz)." % Game.get_player(pid).full_name()
	_refresh_all()

func _on_chip_clicked(slot: int) -> void:
	var c := Game.my_club()
	if _selected_pid > 0 and not c.lineup.has(_selected_pid):
		var pid := _selected_pid
		_selected_pid = -1
		_roster_to_slot(pid, slot)
		return
	if _selected_pid > 0 and c.lineup.has(_selected_pid):
		var from := c.lineup.find(_selected_pid)
		_selected_pid = -1
		_swap_slots(from, slot)
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
			_slot_to_bench(c.lineup.find(pid), bench_index)
			_refresh_all()
		else:
			_roster_to_bench(pid, bench_index)
			_refresh_all()
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
	c.formation = _formation_select.get_item_text(index)
	if c.lineup.size() == 11:
		c.align_lineup(Game.world.players)
	else:
		c.lineup = c.best_eleven(Game.world.players)
	_message.text = "Formation %s gesetzt – Elf neu auf die Slots verteilt." % c.formation
	refresh()

func _on_best_eleven() -> void:
	var c := Game.my_club()
	c.lineup = c.best_eleven(Game.world.players)
	c.bench = c.best_bench(Game.world.players, c.lineup)
	_message.text = "Beste Elf und Bank wurden aufgestellt."
	refresh()
