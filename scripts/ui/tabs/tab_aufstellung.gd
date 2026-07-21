class_name TabAufstellung
extends TabBase
## Aufstellung als 2D-Spielfeld: Formations-Slots auf dem Rasen, Kaderliste rechts.
## Spieler per Drag & Drop (oder Klick-Klick) auf Slots ziehen und tauschen.
## SLOT-BASIERT: Jeder Spieler wird im Spiel auf seinem Slot bewertet – ein
## Stürmer im Abwehr-Slot verteidigt mit seinen schwachen Defensiv-Attributen.

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
var _chips: Array = []          # 11 SlotChip
var _bench_list: ItemList
var _bench_ids: Array = []
var _message: Label
var _summary: Label
var _profile: PlayerProfileDialog
var _selected_slot := -1
var _selected_bench_pid := -1

# ------------------------------------------------------------------ Spielfeld

## Rasen mit Linien; die Slot-Chips sind Kinder und werden hier platziert.
class PitchControl extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# Rasen mit Mähstreifen
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
		# Mittellinie und -kreis (eigene Hälfte unten)
		draw_line(Vector2(inset, size.y * 0.5), Vector2(size.x - inset, size.y * 0.5), line, w)
		draw_arc(Vector2(size.x * 0.5, size.y * 0.5), size.x * 0.12, 0, TAU, 48, line, w)
		# Strafräume oben (Gegner) und unten (eigenes Tor)
		var box_w := size.x * 0.55
		var box_h := size.y * 0.14
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, size.y - inset - box_h), Vector2(box_w, box_h)), line, false, w)
		draw_rect(Rect2(Vector2((size.x - box_w) / 2.0, inset), Vector2(box_w, box_h)), line, false, w)
		var small_w := size.x * 0.26
		var small_h := size.y * 0.055
		draw_rect(Rect2(Vector2((size.x - small_w) / 2.0, size.y - inset - small_h), Vector2(small_w, small_h)), line, false, w)
		draw_rect(Rect2(Vector2((size.x - small_w) / 2.0, inset), Vector2(small_w, small_h)), line, false, w)

## Ein Formations-Slot auf dem Feld (Button mit Drag & Drop).
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
		var preview := Label.new()
		preview.text = "⇄ " + Game.get_player(pid).last_name
		preview.add_theme_color_override("font_color", Color.WHITE)
		var panel := PanelContainer.new()
		panel.add_child(preview)
		set_drag_preview(panel)
		return {"kind": "slot", "slot": slot_index, "pid": pid}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("kind", "") in ["slot", "bench"]

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if data.kind == "slot":
			tab.swap_slots(int(data.slot), slot_index)
		else:
			tab.assign_bench(int(data.pid), slot_index)

## Kaderliste mit Drag-Quelle je Zeile.
class BenchList extends ItemList:
	func _get_drag_data(at: Vector2) -> Variant:
		var idx := get_item_at_position(at, true)
		if idx < 0:
			return null
		var pid: int = get_item_metadata(idx)
		if not Game.get_player(pid).is_available():
			return null
		var preview := Label.new()
		preview.text = "➜ " + Game.get_player(pid).last_name
		var panel := PanelContainer.new()
		panel.add_child(preview)
		set_drag_preview(panel)
		return {"kind": "bench", "pid": pid}

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
	auto_button.text = "⭐ Beste Elf aufstellen"
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
	_pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pitch.size_flags_stretch_ratio = 1.35
	_pitch.custom_minimum_size = Vector2(420, 520)
	_pitch.clip_contents = true
	_pitch.resized.connect(_layout_chips)
	main.add_child(_pitch)
	for i in 11:
		var chip := SlotChip.new(self, i)
		chip.pressed.connect(_on_chip_clicked.bind(i))
		chip.gui_input.connect(_on_chip_gui_input.bind(i))
		_pitch.add_child(chip)
		_chips.append(chip)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	right.add_child(heading("Kader (Bank & Reserve)"))
	_bench_list = BenchList.new()
	_bench_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bench_list.allow_rmb_select = true
	_bench_list.item_clicked.connect(_on_bench_clicked)
	right.add_child(_bench_list)
	var hint := info_label()
	hint.text = "Ziehen: Spieler auf einen Slot (oder Slot auf Slot zum Tauschen).\nKlicken: erst Spieler/Slot wählen, dann Ziel anklicken. Rechtsklick: Profil."
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
	# Ungültige Aufstellung (Verletzte, Gesperrte, Verkaufte) automatisch reparieren
	c.lineup = c.match_lineup(Game.world.players).duplicate()
	_selected_slot = -1
	_selected_bench_pid = -1
	_refresh_chips()
	_refresh_bench()

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
			chip.text = "%s\n%s\nSt %d · %s · %d%%" % [
				head, p.last_name, st, Fmt.form_icon(p.form), int(p.condition)]
			chip.tooltip_text = "%s (%s)\nStärke auf %s: %d (eigene Position %s: %d)" % [
				p.full_name(), p.pos, chip.slot_pos, st, p.pos, p.strength]
		else:
			chip.text = "%s\n– frei –" % chip.slot_pos
			chip.tooltip_text = ""
		_style_chip(chip)
	var avg := total / 11.0
	var warn_text := "  ·  ⚠ %d Positionsfremde" % warnings if warnings > 0 else ""
	_summary.text = "Elf-Stärke auf Position: Ø %.1f%s" % [avg, warn_text]
	_layout_chips()

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
	if chip.slot_index == _selected_slot:
		style.set_border_width_all(3)
		style.border_color = Color.WHITE
	chip.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	chip.add_theme_stylebox_override("hover", hover)
	chip.add_theme_stylebox_override("pressed", style)
	chip.add_theme_font_size_override("font_size", 13)

func _layout_chips() -> void:
	var layout: Array = LAYOUTS.get(Game.my_club().formation, LAYOUTS["4-4-2"])
	var s := _pitch.size
	for i in 11:
		var chip: SlotChip = _chips[i]
		var norm: Vector2 = layout[i]
		var pos := Vector2(norm.x * s.x, (1.0 - norm.y) * s.y)
		chip.position = pos - chip.custom_minimum_size / 2.0
		chip.position.x = clampf(chip.position.x, 2, s.x - chip.custom_minimum_size.x - 2)
		chip.position.y = clampf(chip.position.y, 2, s.y - chip.custom_minimum_size.y - 2)

func _refresh_bench() -> void:
	var c := Game.my_club()
	_bench_ids = c.player_ids.filter(func(pid): return not c.lineup.has(pid))
	_bench_ids.sort_custom(func(a, b):
		var pa := Game.get_player(a)
		var pb := Game.get_player(b)
		var order_a: int = PlayerData.POSITIONS.find(pa.pos)
		var order_b: int = PlayerData.POSITIONS.find(pb.pos)
		if order_a != order_b:
			return order_a < order_b
		return pa.effective_rating() > pb.effective_rating())
	_bench_list.clear()
	for pid in _bench_ids:
		var p := Game.get_player(pid)
		var status_info := ""
		if p.is_injured():
			status_info = "  🚑 %d Sp." % p.injury_matchdays
		elif p.is_suspended():
			status_info = "  🟥 %d Sp." % p.suspended_matchdays
		var idx := _bench_list.add_item("%s  %s  (St %d · %s · %d%%)%s" % [
			p.pos, p.full_name(), p.strength, Fmt.form_icon(p.form), int(p.condition), status_info])
		_bench_list.set_item_metadata(idx, pid)
		if not p.is_available():
			_bench_list.set_item_custom_fg_color(idx, Color("#f87171"))

# ------------------------------------------------------------------ Interaktion

func swap_slots(from_slot: int, to_slot: int) -> void:
	if from_slot == to_slot:
		return
	var c := Game.my_club()
	var tmp: int = c.lineup[from_slot]
	c.lineup[from_slot] = c.lineup[to_slot]
	c.lineup[to_slot] = tmp
	_message.text = "Positionstausch: %s ↔ %s." % [ClubData.FORMATIONS[c.formation][from_slot], ClubData.FORMATIONS[c.formation][to_slot]]
	_after_change()

func assign_bench(pid_in: int, slot: int) -> void:
	var p_in := Game.get_player(pid_in)
	if not p_in.is_available():
		_message.text = "%s ist nicht einsatzbereit (%s)." % [p_in.full_name(), "verletzt" if p_in.is_injured() else "gesperrt"]
		return
	var c := Game.my_club()
	var pid_out: int = c.lineup[slot]
	c.lineup[slot] = pid_in
	var out_name: String = Game.get_player(pid_out).full_name() if pid_out > 0 else "niemand"
	_message.text = "%s übernimmt den %s-Slot (raus: %s)." % [p_in.full_name(), ClubData.FORMATIONS[c.formation][slot], out_name]
	_after_change()

func _after_change() -> void:
	_selected_slot = -1
	_selected_bench_pid = -1
	_refresh_chips()
	_refresh_bench()

func _on_chip_clicked(slot: int) -> void:
	# Klick-Klick-Bedienung: Bankspieler gewählt? → einwechseln. Sonst Slot wählen/tauschen.
	if _selected_bench_pid > 0:
		var pid := _selected_bench_pid
		_selected_bench_pid = -1
		assign_bench(pid, slot)
		return
	if _selected_slot < 0:
		_selected_slot = slot
		_message.text = "Slot %s gewählt – Ziel-Slot oder Kaderspieler anklicken." % ClubData.FORMATIONS[Game.my_club().formation][slot]
		_refresh_chips()
	elif _selected_slot == slot:
		_selected_slot = -1
		_refresh_chips()
	else:
		swap_slots(_selected_slot, slot)

func _on_chip_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var chip: SlotChip = _chips[slot]
		if chip.pid > 0:
			_profile.open_for(chip.pid)

func _on_bench_clicked(index: int, _pos: Vector2, button: int) -> void:
	var pid: int = _bench_list.get_item_metadata(index)
	if button == MOUSE_BUTTON_RIGHT:
		_profile.open_for(pid)
		return
	_selected_bench_pid = pid
	if _selected_slot >= 0:
		var slot := _selected_slot
		_selected_slot = -1
		_selected_bench_pid = -1
		assign_bench(pid, slot)
	else:
		_message.text = "%s gewählt – Ziel-Slot auf dem Feld anklicken." % Game.get_player(pid).full_name()

func _on_formation_changed(index: int) -> void:
	var c := Game.my_club()
	c.formation = _formation_select.get_item_text(index)
	# Bisherige Elf behalten und slot-treu auf die neue Formation verteilen
	if c.lineup.size() == 11:
		c.align_lineup(Game.world.players)
	else:
		c.lineup = c.best_eleven(Game.world.players)
	_message.text = "Formation %s gesetzt – Elf neu auf die Slots verteilt." % c.formation
	refresh()

func _on_best_eleven() -> void:
	var c := Game.my_club()
	c.lineup = c.best_eleven(Game.world.players)
	_message.text = "Beste Elf wurde aufgestellt."
	refresh()
