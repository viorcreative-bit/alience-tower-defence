class_name CampaignMap
extends Control

# Sefer haritası: parşömen üzerine kabaca çizilmiş Balkanlar ve Anadolu kıyıları, Tuna nehri ve
# kuşatılacak kaleler. Kazanılan kale altın, sıradaki kırmızı (yanıp söner), kilitli olanlar gri.
# Kaleye dokununca picked sinyali gelir. Konumlar boylam/enlemdir; çizim kutuya sığdırılır.

const D := preload("res://scripts/data.gd")

signal picked(id: String)

const LON := Vector2(12.0, 32.0)
const LAT := Vector2(34.4, 49.5)
const C_PAPER := Color("#d9c39a")
const C_PAPER_DARK := Color("#b89a6a")
const C_SEA := Color("#7d9aa0")
const C_SEA_EDGE := Color("#4f6d74")
const C_INK := Color("#4a3018")
const C_RIVER := Color("#5f8a96")

# Akdeniz, Ege ve Adriyatik tek parça; Marmara ve Karadeniz ayrı
const SEA := [[12, 34.4], [32, 34.4], [32, 36.4], [30.5, 36.6], [29, 36.6], [28, 36.8], [27.3, 37.6], [26.8, 38.4], [26.3, 39.4],
	[26.2, 40.1], [25.5, 40.8], [24, 40.9], [23, 40.5], [22.9, 40.0], [23.2, 39.2], [22.9, 38.6], [24, 38.1], [23.1, 37.4],
	[22.8, 36.5], [21.8, 36.8], [21.6, 37.8], [21.1, 38.3], [20.7, 39.1], [20.0, 39.7], [19.4, 40.4], [19.5, 41.8], [18.5, 42.5],
	[17.3, 43.1], [16.0, 43.5], [15.2, 44.3], [14.4, 45.3], [13.6, 45.7], [12.4, 45.4], [12.3, 44.6], [13.5, 43.6], [14.0, 42.6],
	[15.9, 41.9], [16.9, 41.1], [18.5, 40.2], [17.9, 40.0], [16.6, 39.6], [16.5, 38.7], [15.7, 38.0], [15.8, 39.5], [15.0, 40.2],
	[14.2, 40.8], [13.0, 41.3], [12.0, 41.8]]
const MARMARA := [[26.6, 40.4], [27.5, 40.9], [29.0, 41.0], [29.3, 40.7], [28.0, 40.35], [26.7, 40.1]]
const BLACK_SEA := [[28.0, 41.3], [29.1, 41.2], [31.0, 41.1], [32.0, 41.5], [32.0, 46.8], [31.5, 46.6], [30.7, 46.4], [30.2, 45.8],
	[29.7, 45.2], [28.8, 44.5], [28.6, 43.5], [27.9, 42.7], [28.0, 42.0]]
const ISLANDS := [[[27.7, 36.1], [28.2, 36.45], [28.25, 36.1], [27.9, 35.9]], [[23.5, 35.55], [24.6, 35.4], [26.3, 35.3], [26.2, 35.0], [24.7, 35.05], [23.6, 35.25]]]
const DANUBE := [[12.0, 48.6], [14.3, 48.3], [16.37, 48.21], [17.1, 48.1], [18.8, 47.8], [19.0, 47.5], [18.9, 46.6], [18.68, 45.99],
	[19.5, 45.2], [20.46, 44.82], [22.5, 44.6], [22.9, 43.8], [25.0, 43.6], [27.5, 44.1], [28.2, 45.4], [29.6, 45.2]]
const LANDS := {"RUMELİ": [23.5, 42.4], "ANADOLU": [30.5, 39.2], "MACARİSTAN": [20.6, 47.3], "AVUSTURYA": [13.9, 47.0],
	"ADRİYATİK": [16.0, 42.6], "KARADENİZ": [30.8, 43.4], "AKDENİZ": [20.0, 36.0], "VENEDİK": [13.9, 46.2]}

var profiles: Profiles
var font: Font
var font_title: Font
var selected := ""
var t := 0.0


func _init(p: Profiles, f: Font, ft: Font) -> void:
	profiles = p
	font = f
	font_title = ft
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


# Boylam/enlemi kutu içindeki noktaya çevirir (enlem küçüldükçe boylam sıkışır)
func to_px(lon: float, lat: float) -> Vector2:
	var k := cos(deg_to_rad(42.0))
	var w := (LON.y - LON.x) * k
	var h := LAT.y - LAT.x
	var s := minf(size.x / w, size.y / h)
	var off := (size - Vector2(w, h) * s) / 2.0
	return off + Vector2((lon - LON.x) * k, LAT.y - lat) * s


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(to_px(p[0], p[1]))
	return out


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, C_PAPER)
	# kenarlara doğru koyulaşan eski kâğıt
	for i in 10:
		var k := i / 10.0
		draw_rect(r.grow(-k * 26.0), Color(C_PAPER_DARK, 0.07), false, 6.0)
	draw_set_transform(Vector2.ZERO)
	for sea in [SEA, MARMARA, BLACK_SEA]:
		var poly := _poly(sea)
		draw_colored_polygon(poly, C_SEA)
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, C_SEA_EDGE, 2.0, true)
	for isl in ISLANDS:
		draw_colored_polygon(_poly(isl), C_PAPER)
	draw_polyline(_poly(DANUBE), C_RIVER, 3.5, true)
	for name in LANDS:
		var p: Array = LANDS[name]
		var at := to_px(p[0], p[1])
		var sz := 17
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(font, at - Vector2(w / 2.0, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(C_INK, 0.42))
	_draw_compass(Vector2(size.x - 56, size.y - 62), 34.0)
	# sefer yolu: kaleden kaleye kesik çizgi
	var prev := Vector2.INF
	for id in D.STAGE_ORDER:
		var m: Array = D.STAGES[id].map
		var p := to_px(m[0], m[1])
		if prev != Vector2.INF:
			_dashed(prev, p, Color("#8e1b24", 0.8) if profiles.stage_open(id) else Color(C_INK, 0.35))
		prev = p
	for id in D.STAGE_ORDER:
		_draw_castle(id)
	draw_rect(r, C_INK, false, 3.0)


func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var l := a.distance_to(b)
	var n := int(l / 14.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), c, 3.0, true)


func _draw_compass(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(C_INK, 0.12))
	draw_arc(c, r, 0, TAU, 32, Color(C_INK, 0.5), 2.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(6, 0), c + Vector2(-6, 0)]), Color("#8e1b24"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, r), c + Vector2(6, 0), c + Vector2(-6, 0)]), Color(C_INK, 0.6))
	draw_string(font, c + Vector2(-6, -r - 4), "K", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_INK)


func _draw_castle(id: String) -> void:
	var st: Dictionary = D.STAGES[id]
	var p := to_px(st.map[0], st.map[1])
	var stars := profiles.stage_stars(id)
	var open := profiles.stage_open(id)
	var fill := Color("#e0b24a") if stars > 0 else (Color("#b3202a") if open else Color("#8a8076"))
	if id == selected:
		draw_circle(p, 30.0, Color(1, 0.95, 0.7, 0.35))
	if open and stars == 0:
		var k := 0.5 + 0.5 * sin(t * 4.0)
		draw_arc(p, 22.0 + k * 6.0, 0, TAU, 32, Color(0.85, 0.1, 0.1, 0.7 - k * 0.5), 3.0, true)
	# küçük kale: iki burç ve kapı
	var body := Rect2(p + Vector2(-13, -10), Vector2(26, 18))
	draw_rect(body, fill)
	for x in [-16, 8]:
		draw_rect(Rect2(p + Vector2(x, -18), Vector2(8, 26)), fill)
		draw_rect(Rect2(p + Vector2(x, -18), Vector2(8, 26)), C_INK, false, 2.0)
	draw_rect(body, C_INK, false, 2.0)
	draw_rect(Rect2(p + Vector2(-4, -1), Vector2(8, 9)), C_INK)
	# ad ve yıl
	var name := "%s %d" % [st.name, st.year]
	var sz := 22
	var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var lp := p + Vector2(-w / 2.0, 36)
	if lp.x < 6:
		lp.x = 6
	if lp.x + w > size.x - 6:
		lp.x = size.x - 6 - w
	draw_string_outline(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 6, Color(C_PAPER, 0.9))
	draw_string(font, lp, name, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, C_INK if open else Color(C_INK, 0.5))
	if stars > 0:
		for i in 3:
			var c := p + Vector2(-16 + i * 16, -30)
			_diamond(c, 6.0, Color("#f2c94c") if i < stars else Color(0, 0, 0, 0.25))


func _diamond(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, C_INK, 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var bd := 60.0
		for id in D.STAGE_ORDER:
			var m: Array = D.STAGES[id].map
			var d := to_px(m[0], m[1]).distance_to(event.position)
			if d < bd:
				bd = d
				best = id
		if best != "":
			accept_event()
			picked.emit(best)
