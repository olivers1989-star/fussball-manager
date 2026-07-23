class_name PitchBoard
extends Control
## Gezeichnetes Spielfeld nach echten Proportionen (68 × 105 m): Mähstreifen,
## Mittelkreis, Strafraum, Torraum, Elfmeterpunkt, Strafraumbogen, Tore und
## Eckbögen. Wird vom Aufstellungsbildschirm und vom Spiel gemeinsam genutzt,
## damit das Feld überall gleich aussieht.

func _draw() -> void:
	var line := Color(1, 1, 1, 0.62)
	var w := 2.0
	var margin := 16.0
	var fw: float = size.x - margin * 2.0     # Feldbreite
	var fh: float = size.y - margin * 2.0     # Feldlänge
	var left := margin
	var right := size.x - margin
	var top := margin
	var bottom := size.y - margin
	var cx := size.x * 0.5

	# Rasen: Grundton plus deutlich sichtbare Mähstreifen
	draw_rect(Rect2(Vector2.ZERO, size), Color("#14532d"))
	var stripes := 12
	for i in stripes:
		var y0: float = margin + fh * i / stripes
		var band := Rect2(left, y0, fw, fh / stripes + 1.0)
		draw_rect(band, Color("#2a7d47") if i % 2 == 0 else Color("#246e3e"))

	# Außenlinie und Mittellinie mit Anstoßkreis
	draw_rect(Rect2(Vector2(left, top), Vector2(fw, fh)), line, false, w)
	var cy := size.y * 0.5
	draw_line(Vector2(left, cy), Vector2(right, cy), line, w)
	var circle_r: float = fw * 0.135          # 9,15 m von 68 m Breite
	draw_arc(Vector2(cx, cy), circle_r, 0, TAU, 64, line, w)
	draw_circle(Vector2(cx, cy), 3.0, line)

	# Strafraum, Torraum, Elfmeterpunkt, Strafraumbogen und Tor – beide Seiten
	var box_w := fw * 0.593                   # 40,3 m breit
	var box_h := fh * 0.157                   # 16,5 m tief
	var small_w := fw * 0.269                 # 18,3 m breit
	var small_h := fh * 0.052                 # 5,5 m tief
	var spot_dist := fh * 0.105               # 11 m Elfmeterpunkt
	var arc_r := fw * 0.135                   # 9,15 m Radius
	var goal_w := fw * 0.108                  # 7,32 m Torbreite
	for is_bottom in [true, false]:
		var base_y: float = bottom if is_bottom else top
		var dir: float = -1.0 if is_bottom else 1.0   # ins Feld hinein
		var box_y: float = base_y - box_h if is_bottom else base_y
		draw_rect(Rect2(Vector2(cx - box_w / 2.0, box_y), Vector2(box_w, box_h)), line, false, w)
		var small_y: float = base_y - small_h if is_bottom else base_y
		draw_rect(Rect2(Vector2(cx - small_w / 2.0, small_y), Vector2(small_w, small_h)), line, false, w)
		var spot := Vector2(cx, base_y + dir * spot_dist)
		draw_circle(spot, 2.5, line)
		# Strafraumbogen: nur der Teil, der aus dem Strafraum herausragt
		var box_edge: float = base_y + dir * box_h
		var dy: float = absf(box_edge - spot.y)
		if arc_r > dy:
			var half := acos(clampf(dy / arc_r, -1.0, 1.0))
			var center_angle: float = -PI / 2.0 if is_bottom else PI / 2.0
			draw_arc(spot, arc_r, center_angle - half, center_angle + half, 32, line, w)
		# Tor (steht außerhalb der Grundlinie)
		var goal_depth := 7.0
		var goal_y: float = base_y if is_bottom else base_y - goal_depth
		draw_rect(Rect2(Vector2(cx - goal_w / 2.0, goal_y), Vector2(goal_w, goal_depth)), Color(1, 1, 1, 0.85), false, 2.5)

	# Eckbögen: Viertelkreise, die ins Feld zeigen
	var corner_r := fw * 0.028
	draw_arc(Vector2(left, top), corner_r, 0, PI / 2.0, 12, line, 1.5)
	draw_arc(Vector2(right, top), corner_r, PI / 2.0, PI, 12, line, 1.5)
	draw_arc(Vector2(right, bottom), corner_r, PI, PI * 1.5, 12, line, 1.5)
	draw_arc(Vector2(left, bottom), corner_r, PI * 1.5, TAU, 12, line, 1.5)
