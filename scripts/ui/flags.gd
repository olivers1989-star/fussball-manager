class_name Flags
extends RefCounted
## Vereinfachte Nationalflaggen als generierte Texturen (Windows rendert keine
## Flaggen-Emojis). Muster: Streifen, Kreuze, Dreiecke, einfache Embleme.

const W := 30
const H := 20

static var _cache := {}

static func texture(nation: String) -> ImageTexture:
	if _cache.has(nation):
		return _cache[nation]
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	_paint(img, nation)
	var tex := ImageTexture.create_from_image(img)
	_cache[nation] = tex
	return tex

static func _paint(img: Image, nation: String) -> void:
	match nation:
		"Deutschland":
			_hstripes(img, [Color.BLACK, Color("#dd0000"), Color("#ffce00")])
		"Österreich":
			_hstripes(img, [Color("#ed2939"), Color.WHITE, Color("#ed2939")])
		"Niederlande":
			_hstripes(img, [Color("#ae1c28"), Color.WHITE, Color("#21468b")])
		"Ägypten":
			_hstripes(img, [Color("#ce1126"), Color.WHITE, Color.BLACK])
		"Serbien":
			_hstripes(img, [Color("#c6363c"), Color("#0c4076"), Color.WHITE])
		"Kroatien":
			_hstripes(img, [Color("#ff0000"), Color.WHITE, Color("#171796")])
		"Frankreich":
			_vstripes(img, [Color("#002395"), Color.WHITE, Color("#ed2939")])
		"Italien":
			_vstripes(img, [Color("#009246"), Color.WHITE, Color("#ce2b37")])
		"Belgien":
			_vstripes(img, [Color.BLACK, Color("#fdda24"), Color("#ef3340")])
		"Polen":
			_hstripes(img, [Color.WHITE, Color("#dc143c")])
		"Spanien":
			_hstripes(img, [Color("#aa151b"), Color("#f1bf00"), Color("#f1bf00"), Color("#aa151b")])
		"Argentinien":
			_hstripes(img, [Color("#74acdf"), Color.WHITE, Color("#74acdf")])
		"Portugal":
			img.fill(Color("#ff0000"))
			img.fill_rect(Rect2i(0, 0, int(W * 0.4), H), Color("#006600"))
			_disc(img, int(W * 0.4), H / 2, 4, Color("#ffff00"))
		"Brasilien":
			img.fill(Color("#009c3b"))
			_diamond(img, Color("#ffdf00"))
			_disc(img, W / 2, H / 2, 4, Color("#002776"))
		"Türkei":
			img.fill(Color("#e30a17"))
			_disc(img, 12, H / 2, 6, Color.WHITE)
			_disc(img, 14, H / 2, 5, Color("#e30a17"))
			_disc(img, 20, H / 2, 2, Color.WHITE)
		"Marokko":
			img.fill(Color("#c1272d"))
			_disc(img, W / 2, H / 2, 4, Color("#006233"))
		"Dänemark":
			img.fill(Color("#c8102e"))
			_cross(img, 10, Color.WHITE, 3)
		"Schweiz":
			img.fill(Color("#da291c"))
			img.fill_rect(Rect2i(W / 2 - 2, 4, 4, H - 8), Color.WHITE)
			img.fill_rect(Rect2i(7, H / 2 - 2, W - 14, 4), Color.WHITE)
		"England":
			img.fill(Color.WHITE)
			_cross(img, W / 2, Color("#ce1124"), 3)
		"Tschechien":
			_hstripes(img, [Color.WHITE, Color("#d7141a")])
			_triangle(img, Color("#11457e"))
		_:
			img.fill(Color("#64748b"))

static func _hstripes(img: Image, colors: Array) -> void:
	var band := float(H) / colors.size()
	for i in colors.size():
		img.fill_rect(Rect2i(0, int(i * band), W, int(ceil(band))), colors[i])

static func _vstripes(img: Image, colors: Array) -> void:
	var band := float(W) / colors.size()
	for i in colors.size():
		img.fill_rect(Rect2i(int(i * band), 0, int(ceil(band)), H), colors[i])

static func _cross(img: Image, cx: int, color: Color, thickness: int) -> void:
	img.fill_rect(Rect2i(cx - thickness / 2 - 1, 0, thickness, H), color)
	img.fill_rect(Rect2i(0, H / 2 - thickness / 2 - 1, W, thickness), color)

static func _disc(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(maxi(cy - r, 0), mini(cy + r + 1, H)):
		for x in range(maxi(cx - r, 0), mini(cx + r + 1, W)):
			if Vector2(x - cx, y - cy).length() <= r:
				img.set_pixel(x, y, color)

static func _diamond(img: Image, color: Color) -> void:
	var cx := W / 2.0
	var cy := H / 2.0
	for y in H:
		for x in W:
			if absf(x - cx) / (W * 0.42) + absf(y - cy) / (H * 0.42) <= 1.0:
				img.set_pixel(x, y, color)

static func _triangle(img: Image, color: Color) -> void:
	for y in H:
		var reach := int((1.0 - absf(y - H / 2.0) / (H / 2.0)) * W * 0.45)
		for x in reach:
			img.set_pixel(x, y, color)

## Fertiges Flaggen-Control mit Tooltip (Name der Nation).
static func icon(nation: String, height := 14) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(nation)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(height * 1.5, height)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.tooltip_text = nation
	return rect
