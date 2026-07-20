class_name TabUebersicht
extends TabBase
## Übersicht: nächstes Spiel, Tabellenplatz, letzte Ergebnisse, beste Torschützen.

var _welcome: Label
var _next_match: Label
var _position: Label
var _results: ItemList
var _scorers: ItemList

func _init() -> void:
	super()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_welcome = heading("")
	box.add_child(_welcome)

	_next_match = Label.new()
	_next_match.add_theme_font_size_override("font_size", 20)
	box.add_child(_next_match)

	_position = Label.new()
	_position.add_theme_font_size_override("font_size", 20)
	box.add_child(_position)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(heading("Letzte Spiele"))
	_results = ItemList.new()
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_results)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	right.add_child(heading("Beste Torschützen (eigenes Team)"))
	_scorers = ItemList.new()
	_scorers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_scorers)

func refresh() -> void:
	var c := Game.my_club()
	_welcome.text = "Willkommen, %s! – %s (%s)" % [Game.manager_name, c.name, Game.my_league().name]

	var f := Game.next_fixture(c.id)
	if f.is_empty():
		_next_match.text = "Die Saison ist beendet."
	else:
		var home := int(f.home) == c.id
		var opponent := Game.club(int(f.away) if home else int(f.home))
		_next_match.text = "Nächstes Spiel – Spieltag %d: %s %s (%s)" % [
			Game.matchday() + 1,
			"HEIM gegen" if home else "AUSWÄRTS bei",
			opponent.name,
			c.stadium if home else opponent.stadium,
		]

	_position.text = "Tabellenplatz: %d.  ·  %s  ·  Spieltag %d/34  ·  Saisonziel: %s" % [
		Game.my_league().position_of(c.id), Game.season_label(), Game.matchday(),
		Game.season_goal.get("text", "–")]

	_results.clear()
	var played := Game.my_league().fixtures_of_club(c.id).filter(func(x): return x.played)
	played.reverse()
	for i in mini(6, played.size()):
		var x: Dictionary = played[i]
		var h := Game.club(int(x.home))
		var a := Game.club(int(x.away))
		var mine_home := h.id == c.id
		var my_goals: int = int(x.hg) if mine_home else int(x.ag)
		var their_goals: int = int(x.ag) if mine_home else int(x.hg)
		var icon := "✓" if my_goals > their_goals else ("–" if my_goals == their_goals else "✗")
		_results.add_item("%s  ST %d: %s %d:%d %s" % [icon, int(x.round) + 1, h.name, int(x.hg), int(x.ag), a.name])

	_scorers.clear()
	var squad := c.players(Game.world.players)
	squad.sort_custom(func(a, b): return a.goals_season > b.goals_season)
	for i in mini(8, squad.size()):
		var p: PlayerData = squad[i]
		if p.goals_season == 0 and i > 0:
			break
		_scorers.add_item("%d Tore – %s (%s)" % [p.goals_season, p.full_name(), p.pos])
