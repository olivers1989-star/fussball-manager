class_name TabPokal
extends TabBase
## Zeigt den deutschen Pokal: die aktuelle Runde, den weiteren Weg des eigenen
## Vereins und die abgeschlossenen Runden. Bei Entscheidung der Pokalsieger.

var _box: VBoxContainer

func _init() -> void:
	super()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)

func refresh() -> void:
	for c in _box.get_children():
		c.queue_free()
	var cup: CupData = Game.cup
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_box.add_child(head)
	head.add_child(heading("🏆 Deutscher Pokal"))
	var sub := info_label()
	if cup == null:
		sub.text = "Kein Wettbewerb"
		head.add_child(sub)
		return
	if cup.is_finished():
		sub.text = "Saison %d/%02d · entschieden" % [cup.year, (cup.year + 1) % 100]
	else:
		sub.text = "Saison %d/%02d · %s" % [cup.year, (cup.year + 1) % 100, cup.round_name(cup.round)]
	head.add_child(sub)

	# Pokalsieger
	if cup.is_finished():
		_box.add_child(_champion_banner(cup.champion))

	# Mein Weg durch den Wettbewerb
	_box.add_child(_my_path(cup))

	# Aktuelle Runde (falls noch nicht entschieden)
	if not cup.is_finished():
		_box.add_child(_round_card(cup.round_name(cup.round) + "  ·  Auslosung", cup.pairings, false))

	# Abgeschlossene Runden (neueste zuerst)
	for i in range(cup.history.size() - 1, -1, -1):
		_box.add_child(_round_card("%s  ·  Ergebnisse" % cup.round_name(i), cup.history[i], true))

func _champion_banner(cid: int) -> PanelContainer:
	var c := Game.club(cid)
	var card := PanelContainer.new()
	var sb := UITheme.box(Color(0.16, 0.13, 0.04, 1.0), 12, Color("#e3b341"))
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	card.add_child(line)
	line.add_child(UITheme.club_badge(c.short_name, Color(c.color), 48))
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 2)
	line.add_child(t)
	var l1 := Label.new()
	l1.text = "🏆 Pokalsieger"
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", Color("#e3b341"))
	t.add_child(l1)
	var l2 := Label.new()
	l2.text = c.name
	l2.add_theme_font_size_override("font_size", 22)
	t.add_child(l2)
	return card

func _my_path(cup: CupData) -> PanelContainer:
	var card := _card("Dein Weg im Pokal")
	var box: VBoxContainer = card.get_child(0)
	var out := false
	for i in cup.history.size():
		for p in cup.history[i]:
			if int(p.home) != Game.my_club_id and int(p.away) != Game.my_club_id:
				continue
			var won: bool = int(p.winner) == Game.my_club_id
			box.add_child(_path_row(cup.round_name(i), p, won, true))
			if not won:
				out = true
	# aktuelle, noch nicht gespielte Runde
	if not out and not cup.is_finished():
		var pr := cup.pairing_of(Game.my_club_id)
		if not pr.is_empty():
			box.add_child(_path_row(cup.round_name(cup.round), pr, false, false))
	if box.get_child_count() == 0:
		var n := info_label()
		n.text = "Dein Verein ist in diesem Jahr nicht dabei."
		box.add_child(n)
	return card

func _path_row(round_name: String, p: Dictionary, won: bool, played: bool) -> PanelContainer:
	var mine_home: bool = int(p.home) == Game.my_club_id
	var opp := Game.club(int(p.away) if mine_home else int(p.home))
	var row := PanelContainer.new()
	var col := Color(0.10, 0.16, 0.12, 1.0) if (played and won) else (Color(0.17, 0.11, 0.11, 1.0) if played else Color(0.10, 0.13, 0.17, 1.0))
	var sb := UITheme.box(col, 6)
	sb.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 9)
	row.add_child(line)
	var rn := Label.new()
	rn.text = round_name
	rn.custom_minimum_size = Vector2(120, 0)
	rn.add_theme_font_size_override("font_size", 13)
	rn.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(rn)
	var where := Label.new()
	where.text = "Heim" if mine_home else "Auswärts"
	where.custom_minimum_size = Vector2(70, 0)
	where.add_theme_font_size_override("font_size", 12)
	where.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	line.add_child(where)
	line.add_child(UITheme.club_badge(opp.short_name, Color(opp.color), 22))
	var on := Label.new()
	on.text = opp.name
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.clip_text = true
	on.add_theme_font_size_override("font_size", 14)
	line.add_child(on)
	var res := Label.new()
	if played:
		var mg: int = int(p.hg) if mine_home else int(p.ag)
		var og: int = int(p.ag) if mine_home else int(p.hg)
		var extra := ""
		if bool(p.shootout):
			var mp: int = int(p.ph) if mine_home else int(p.pa)
			var op: int = int(p.pa) if mine_home else int(p.ph)
			extra = " i.E. %d:%d" % [mp, op]
		elif bool(p.extra):
			extra = " n.V."
		res.text = "%d:%d%s  %s" % [mg, og, extra, "✓" if won else "✗"]
		res.add_theme_color_override("font_color", UITheme.ACCENT if won else UITheme.DANGER)
	else:
		res.text = "offen"
		res.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	res.add_theme_font_size_override("font_size", 14)
	line.add_child(res)
	return row

func _round_card(title: String, pairings: Array, played: bool) -> PanelContainer:
	var card := _card(title)
	var box: VBoxContainer = card.get_child(0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for p in pairings:
		grid.add_child(_pairing_row(p, played))
	return card

func _pairing_row(p: Dictionary, played: bool) -> PanelContainer:
	var mine: bool = int(p.home) == Game.my_club_id or int(p.away) == Game.my_club_id
	var row := PanelContainer.new()
	var sb := UITheme.box(Color(0.10, 0.16, 0.12, 1.0) if mine else Color(0.07, 0.09, 0.12, 1.0), 5,
		UITheme.ACCENT if mine else Color(0, 0, 0, 0))
	sb.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 5)
	row.add_child(line)
	var h := Game.club(int(p.home))
	var a := Game.club(int(p.away))
	var hn := Label.new()
	hn.text = h.short_name
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn.clip_text = true
	hn.add_theme_font_size_override("font_size", 12)
	if played:
		hn.add_theme_color_override("font_color", UITheme.TEXT if int(p.winner) == h.id else UITheme.TEXT_DIM)
	line.add_child(hn)
	line.add_child(UITheme.club_badge(h.short_name, Color(h.color), 18))
	var mid := Label.new()
	if played:
		var extra := " i.E." if bool(p.shootout) else (" n.V." if bool(p.extra) else "")
		mid.text = "%d:%d%s" % [int(p.hg), int(p.ag), extra]
	else:
		mid.text = "–:–"
	mid.custom_minimum_size = Vector2(58, 0)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_theme_font_size_override("font_size", 12)
	line.add_child(mid)
	line.add_child(UITheme.club_badge(a.short_name, Color(a.color), 18))
	var an := Label.new()
	an.text = a.short_name
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.clip_text = true
	an.add_theme_font_size_override("font_size", 12)
	if played:
		an.add_theme_color_override("font_color", UITheme.TEXT if int(p.winner) == a.id else UITheme.TEXT_DIM)
	line.add_child(an)
	return row

func _card(title: String) -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UITheme.box(UITheme.SURFACE, 12, UITheme.BORDER)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	card.add_child(inner)
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(h)
	return card
