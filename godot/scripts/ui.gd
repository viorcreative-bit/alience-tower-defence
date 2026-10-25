class_name GameUI
extends CanvasLayer

# Arayüz: üst şerit (akçe, sur, dalga), alt bağlamsal panel (ipucu, kule kartları, kule ve bina bilgisi),
# kontrol düğmeleri, ortadaki duyuru şeridi ve zafer/yenilgi ekranı.

const D := preload("res://scripts/data.gd")

const C_PANEL := Color("#1f1712")
const C_EDGE := Color("#4a3524")
const C_TEXT := Color("#f3e6c8")
const C_DIM := Color("#b9a383")
const C_RED := Color("#b3202a")
const C_GOLD := Color("#e0b24a")
const C_COIN := Color("#f2c94c")
const C_WALL := Color("#cfd6e0")
const C_DANGER := Color("#ff5b4d")
const C_RES := {"wood": Color("#d39a5e"), "iron": Color("#b9c3cf"), "food": Color("#a8d872")}

signal action(name: String, arg: String)

var game: Game
var font_title: FontFile
var font_body: FontFile
var font_bold: FontFile

var root: Control
var lbl_gold: Label
var lbl_wall: Label
var lbl_wave: Label
var lbl_res := {}
var context: VBoxContainer
var btn_sound: Button
var btn_speed: Button
var btn_light: Button
var btn_charge: Button
var btn_primary: Button
var btn_view: Button
var banner: Label
var banner_tween: Tween
var overlay: Control
var overlay_title: Label
var overlay_text: Label
var bars: Control
var panel: PanelContainer
var top: PanelContainer

var last_key := ""
var last_controls := ""
var train_bar: ColorRect
var best_wave := 0
var city_view := false


func _init(g: Game) -> void:
	game = g
	font_title = _font(["cinzel-latin-900-normal", "cinzel-latin-ext-900-normal"])
	font_body = _font(["barlow-semi-condensed-latin-500-normal", "barlow-semi-condensed-latin-ext-500-normal"])
	font_bold = _font(["barlow-semi-condensed-latin-700-normal", "barlow-semi-condensed-latin-ext-700-normal"])


func _font(files: Array) -> FontFile:
	var main: FontFile = load("res://assets/fonts/%s.woff2" % files[0])
	var ext: FontFile = load("res://assets/fonts/%s.woff2" % files[1])
	var f: FontFile = main.duplicate()
	f.fallbacks = [ext]
	return f


func _ready() -> void:
	bars = Control.new()
	bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bars)

	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)

	_build_top()
	_build_panel()
	_build_view_button()
	_build_banner()
	_build_overlay()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 24
	t.set_color("font_color", "Label", C_TEXT)
	t.set_stylebox("normal", "Button", _frame("button"))
	t.set_stylebox("hover", "Button", _frame("button_hot"))
	t.set_stylebox("pressed", "Button", _frame("button_hot"))
	t.set_stylebox("disabled", "Button", _frame("button_off"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#7d6a55"))
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 24)
	t.set_constant("icon_max_width", "Button", 30)
	t.set_constant("h_separation", "Button", 8)
	return t


# Süslü çerçeve (assets/ui, tools/make_ui_art.py ile çizilir): 9 parçalı doku
func _frame(name: String, margin := 16, pad := 12) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://assets/ui/%s.png" % name)
	s.set_texture_margin_all(margin)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _icon(name: String, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://assets/ui/%s.png" % name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


func _thumb(path: String, size: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _frame("card", 12, 4))
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(r)
	return p


func _box(bg: Color, edge: Color, radius := 12, border := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _label(text: String, size := 24, color := C_TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	return l


# ---------------------------------------------------------------- üst şerit

func _build_top() -> void:
	# gün batımında İstanbul silueti, altında süslü şerit; solda asılı sancak
	top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(col)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/ui/skyline.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.custom_minimum_size = Vector2(0, 54)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sky)
	var bar := PanelContainer.new()
	var fs := _frame("panel", 18, 14)
	fs.content_margin_left = 66
	fs.content_margin_top = 10
	fs.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", fs)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	bar.add_child(rows)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	rows.add_child(hb)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -8)
	var t1 := _label("OSMANLI", 38, C_GOLD, font_title)
	t1.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	t1.add_theme_constant_override("shadow_offset_y", 2)
	title.add_child(t1)
	title.add_child(_label("KALE SAVUNMASI", 15, C_TEXT, font_title))
	hb.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	lbl_gold = _stat(hb, "AKÇE", "coin", C_COIN)
	hb.add_child(_divider())
	lbl_wall = _stat(hb, "SUR", "castle", C_WALL)
	hb.add_child(_divider())
	lbl_wave = _stat(hb, "DALGA", "swords", C_TEXT)
	var line := ColorRect.new()
	line.color = Color(C_GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	rows.add_child(line)
	# odun, demir, yemek: askerler ve Saray bunlarla yükselir
	var rb := HBoxContainer.new()
	rb.alignment = BoxContainer.ALIGNMENT_END
	rb.add_theme_constant_override("separation", 6)
	rows.add_child(rb)
	for k in D.RES_ORDER:
		rb.add_child(_icon(k, 28))
		var n := _label(String(D.RES_NAMES[k]).to_upper(), 15, C_DIM, font_bold)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rb.add_child(n)
		var v := _label("0", 22, C_RES[k], font_bold)
		v.custom_minimum_size = Vector2(54, 0)
		rb.add_child(v)
		lbl_res[k] = v
	# şeridin solundan sarkan sancak
	var flag := _icon("banner", 0)
	flag.custom_minimum_size = Vector2(46, 100)
	flag.position = Vector2(14, 40)
	root.add_child(flag)


func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(C_GOLD, 0.35)
	d.custom_minimum_size = Vector2(1, 44)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return d


func _stat(parent: Control, name: String, icon: String, color: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	var n := _label(name, 14, C_DIM, font_bold)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(_icon(icon, 30))
	var val := _label("0", 30, color, font_bold)
	h.add_child(val)
	v.add_child(h)
	parent.add_child(v)
	return val


# ---------------------------------------------------------------- alt panel

func _build_panel() -> void:
	panel = PanelContainer.new()
	var sb := _frame("panel", 18, 16)
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	context = VBoxContainer.new()
	context.custom_minimum_size = Vector2(0, 210)
	context.add_theme_constant_override("separation", 8)
	vb.add_child(context)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	btn_sound = _ctrl(row, "Ses", 96, func(): action.emit("sound", ""))
	btn_sound.icon = load("res://assets/ui/speaker.png")
	btn_speed = _ctrl(row, "1×", 64, func(): action.emit("speed", ""))
	btn_light = _ctrl(row, "Öğle", 92, func(): action.emit("light", ""))
	btn_charge = _ctrl(row, "Allah Allah!", 150, func(): action.emit("charge", ""))
	btn_primary = _ctrl(row, "1. Dalgayı Başlat", 0, func(): action.emit("primary", ""))
	btn_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_primary.icon = load("res://assets/ui/swords.png")
	btn_primary.add_theme_constant_override("icon_max_width", 34)
	btn_primary.add_theme_stylebox_override("normal", _frame("red"))
	btn_primary.add_theme_stylebox_override("hover", _frame("red_hot"))
	btn_primary.add_theme_stylebox_override("pressed", _frame("red_hot"))
	btn_primary.add_theme_font_size_override("font_size", 25)
	btn_charge.add_theme_color_override("font_color", C_GOLD)


func _ctrl(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 66)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func panel_top() -> float:
	return panel.get_global_rect().position.y


func top_bottom() -> float:
	return top.get_global_rect().end.y


func _clear_context() -> void:
	for c in context.get_children():
		c.queue_free()
	train_bar = null


# Şehir görünüşünde bina kartları şeridi: dokununca o bina seçilir
func _render_strip() -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 168)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	context.add_child(sc)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	sc.add_child(hb)
	for id in D.BUILDING_ORDER:
		var lv: int = game.buildings[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(124, 160)
		b.add_theme_stylebox_override("normal", _frame("card", 12, 6))
		b.add_theme_stylebox_override("hover", _frame("card_hot", 12, 6))
		b.add_theme_stylebox_override("pressed", _frame("card_hot", 12, 6))
		b.pressed.connect(func(): action.emit("pick_building", id))
		hb.add_child(b)
		var th := TextureRect.new()
		th.texture = load("res://assets/thumbs/b_%s.png" % id)
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.position = Vector2(10, 6)
		th.size = Vector2(104, 100)
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.modulate = Color.WHITE if lv > 0 else Color(0.62, 0.56, 0.5)
		b.add_child(th)
		var n := _label(String(D.BUILDING_NAMES[id][0]), 17, C_TEXT, font_bold)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.position = Vector2(4, 104)
		n.size = Vector2(116, 40)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_theme_constant_override("line_spacing", -6)
		b.add_child(n)
		var l := _label(("Seviye %d" % lv) if lv else ("Kur %d" % game.building_cost(id)), 15, C_GOLD if lv else C_DIM, font_bold)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(4, 136)
		l.size = Vector2(116, 20)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)


func _render_idle() -> void:
	if city_view:
		_render_strip()
		return
	var lines := []
	if game.phase == "wave":
		lines.append("Ani baskın! Akıncıları kapıya varmadan durdur." if game.raid else "Dalga sürerken de kule ve bina kurabilirsin.")
	else:
		lines.append("Yolun dışındaki boş kareye dokunup kule kur. Surların içindeki arsalara dokunup şehri geliştir; Kışla, Okçu Ocağı ve Sipahi Ocağı surların önüne asker yetiştirir.")
	var l := _label(lines[0], 23, C_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_child(l)
	if game.phase == "build" and game.wave < game.total_waves:
		var n := _label(D.describe_wave(game.wave), 23, C_TEXT, font_bold)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		context.add_child(n)


func _render_build() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	context.add_child(grid)
	for type in D.TOWER_ORDER:
		var def: Dictionary = D.TOWERS[type]
		var unlocked := game.is_tower_unlocked(type)
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not game.can_build(type)
		grid.add_child(b)
		var th := TextureRect.new()
		th.texture = load("res://assets/thumbs/t_%s.png" % type)
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		th.position = Vector2(8, 6)
		th.size = Vector2(84, 84)
		th.modulate = Color.WHITE if unlocked else Color(0.5, 0.45, 0.4)
		b.add_child(th)
		b.pressed.connect(func(): action.emit("build", type))
		var col := Color(def.color)
		b.add_theme_stylebox_override("normal", _card_box(col, false))
		b.add_theme_stylebox_override("hover", _card_box(col, true))
		b.add_theme_stylebox_override("pressed", _card_box(col, true))
		b.add_theme_stylebox_override("disabled", _card_box(col.darkened(0.5), false))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 96
		v.offset_top = 10
		v.offset_right = -12
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -2)
		b.add_child(v)
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(hb)
		var name := _label(D.TOWER_NAMES[type][0], 24, C_TEXT if unlocked else C_DIM, font_bold)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(name)
		hb.add_child(_label(str(def.cost), 24, C_COIN if game.gold >= def.cost else C_DANGER, font_bold))
		var desc: String = D.TOWER_NAMES[type][1] if unlocked else "%s gerekli" % D.BUILDING_NAMES[def.unlock][0]
		v.add_child(_label(desc, 20, C_DIM))
		for c in [v, hb]:
			for l in c.get_children():
				if l is Control:
					l.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _card_box(_col: Color, hot: bool) -> StyleBox:
	return _frame("card_hot" if hot else "card", 12, 8)


# Seçili kule ya da bina: solda resim, sağda ad, alt başlık, seviye; metin satırları dönen sütuna eklenir
func _info_head(name: String, sub: String, lvl: String, thumb: String) -> VBoxContainer:
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	context.add_child(outer)
	outer.add_child(_thumb(thumb, 112))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(_label(name, 28, C_TEXT, font_title))
	if sub != "":
		var s := _label(sub, 20, C_DIM)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(s)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(_label(lvl, 22, C_GOLD, font_bold))
	col.add_child(hb)
	return col


func _coin_button(text: String, enabled: bool, cb: Callable, h := 60.0) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.icon = load("res://assets/ui/coin.png")
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", C_COIN)
	b.pressed.connect(cb)
	return b


func _render_tower(t: Dictionary) -> void:
	var s := game.tower_stats(t)
	var col := _info_head(D.TOWER_NAMES[t.type][0], "", "Seviye %d/%d" % [t.level, D.UPGRADE.max_level], "res://assets/thumbs/t_%s.png" % t.type)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	hb.add_child(_label("Hasar %s" % D.num(s.damage), 22))
	hb.add_child(_label("Menzil %s" % D.num(s.range, 2), 22))
	hb.add_child(_label("Atış %s sn" % D.num(s.rate, 2), 22))
	col.add_child(hb)
	col.add_child(_label(D.tower_feature(t.type, s), 21, C_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	context.add_child(row)
	var maxed: bool = t.level >= D.UPGRADE.max_level
	var up := _coin_button("En yüksek seviye" if maxed else "Yükselt - %d" % game.tower_upgrade_cost(t), game.can_upgrade_tower(t), func(): action.emit("upgrade", ""))
	row.add_child(up)
	var sell := Button.new()
	sell.text = "Sat +%d" % D.sell_value(t.spent)
	sell.custom_minimum_size = Vector2(170, 60)
	sell.pressed.connect(func(): action.emit("sell", ""))
	row.add_child(sell)


func res_text(cost: Dictionary) -> String:
	var parts := []
	for k in D.RES_ORDER:
		if cost.has(k):
			parts.append("%d %s" % [cost[k], D.RES_NAMES[k]])
	return ", ".join(parts)


func _render_building(id: String) -> void:
	var level: int = game.buildings[id]
	var names: Array = D.BUILDING_NAMES[id]
	var col := _info_head(names[0], names[1], "Seviye %d/%d" % [level, D.MAX_BUILDING_LEVEL], "res://assets/thumbs/b_%s.png" % id)
	var now := _label(D.building_effect(id, level) if level else "Henüz kurulmadı", 21, C_TEXT)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(now)
	if level < D.MAX_BUILDING_LEVEL:
		var nx := _label("Sonraki: " + D.building_effect(id, level + 1), 19, C_DIM)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(nx)
	var block := game.building_block(id)
	var cost := game.building_cost(id)
	var label := ""
	var need := game.building_res(id)
	if block.is_empty():
		label = ("Yükselt - %d" if level else "Kur - %d") % cost
		if need.size():
			label += " · " + res_text(need)
	elif block.kind == "max":
		label = "En yüksek seviye"
	elif block.kind == "requires":
		label = "Önce %s %d. seviye" % [D.BUILDING_NAMES[block.building][0], block.level]
	else:
		label = "Saray %d. seviye gerekli" % block.level
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	context.add_child(row)
	var up := _coin_button(label, game.can_upgrade_building(id), func(): action.emit("building", id),
		84 if game.troop_of(id) != null and level > 0 else 60)
	if not block.is_empty():
		up.icon = null
	row.add_child(up)
	var kind = game.troop_of(id)
	if kind != null and level > 0:
		var cap := game.troop_cap(kind)
		var tr := game.training_of(kind)
		var have := game.troop_count(kind)
		var full: bool = have + tr.queue >= cap
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not game.can_train(kind)
		b.pressed.connect(func(): action.emit("train", kind))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", -4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var a := _label("Ocak dolu" if full else "Yetiştir · %d" % D.TROOPS[kind].cost, 22, C_TEXT, font_bold)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var q := " · %d eğitimde" % tr.queue if tr.queue else ""
		var c := _label("%s %d/%d%s" % [D.TROOP_NAMES[kind], have, cap, q], 18, C_DIM)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tres: Dictionary = D.TROOPS[kind].res
		var miss := game.missing_res(tres)
		var r := _label(("Eksik: " + miss) if miss != "" and not full else res_text(tres), 18, C_DANGER if miss != "" and not full else C_RES.food)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for l in [a, r, c]:
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		train_bar = ColorRect.new()
		train_bar.color = Color(C_GOLD, 0.35)
		train_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		train_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		train_bar.size = Vector2(0, 5)
		b.add_child(train_bar)
		b.add_child(v)
		b.set_meta("kind", kind)
		row.add_child(b)


# Savaş ile şehir görünüşü arasında geçiş: haritanın sağ üstünde durur
func _build_view_button() -> void:
	btn_view = Button.new()
	btn_view.custom_minimum_size = Vector2(184, 58)
	btn_view.add_theme_font_size_override("font_size", 23)
	btn_view.add_theme_stylebox_override("normal", _frame("panel", 18, 14))
	btn_view.add_theme_stylebox_override("hover", _frame("button_hot", 16, 14))
	btn_view.add_theme_stylebox_override("pressed", _frame("button_hot", 16, 14))
	btn_view.add_theme_color_override("font_color", C_GOLD)
	btn_view.icon = load("res://assets/ui/palace.png")
	btn_view.add_theme_constant_override("icon_max_width", 32)
	btn_view.pressed.connect(func(): action.emit("view", ""))
	root.add_child(btn_view)
	set_view_label(false)


func set_view_label(city: bool) -> void:
	city_view = city
	btn_view.text = "Savaşa Dön" if city else "Şehre Bak"
	last_key = ""


# ---------------------------------------------------------------- duyuru ve bitiş ekranı

func _build_banner() -> void:
	banner = _label("", 40, C_TEXT, font_title)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	banner.add_theme_constant_override("outline_size", 12)
	banner.position.y -= 260
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)


func show_banner(text: String, color: Color, life := 2.2) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	if banner_tween:
		banner_tween.kill()
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE
	banner_tween = create_tween()
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.2)
	banner_tween.tween_interval(life)
	banner_tween.tween_property(banner, "modulate:a", 0.0, 0.5)


func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.04, 0.03, 0.78)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	root.add_child(overlay)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	overlay.add_child(v)
	overlay_title = _label("", 46, C_GOLD, font_title)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(overlay_title)
	overlay_text = _label("", 26, C_TEXT)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_text.custom_minimum_size = Vector2(560, 0)
	v.add_child(overlay_text)
	var again := Button.new()
	again.text = "Yeniden Oyna"
	again.custom_minimum_size = Vector2(300, 72)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.add_theme_stylebox_override("normal", _box(Color("#9e1b25"), Color("#d4453f"), 10))
	again.add_theme_stylebox_override("hover", _box(Color("#bf2a33"), C_GOLD, 10))
	again.pressed.connect(func(): action.emit("restart", ""))
	v.add_child(again)


# ---------------------------------------------------------------- her kare

func refresh(sound_on: bool, light_name: String) -> void:
	btn_view.position = Vector2(root.size.x - btn_view.size.x - 14, top_bottom() + 12)
	lbl_gold.text = str(game.gold)
	lbl_wall.text = str(game.wall)
	lbl_wave.text = "%d/%d" % [game.wave, game.total_waves]
	for k in lbl_res:
		lbl_res[k].text = str(game.res[k])
	lbl_wall.add_theme_color_override("font_color", C_DANGER if game.wall <= 5 else C_WALL)

	var sel = game.selected
	var tower = game.selected_tower()
	var mode := "idle"
	if sel != null:
		mode = "building" if sel.has("building") else ("tower" if tower != null else "build")
	var tkey := ""
	if mode == "building":
		var kind = game.troop_of(sel.building)
		if kind != null:
			var tr := game.training_of(kind)
			tkey = "%d,%d" % [game.troop_count(kind), tr.queue]
	var key := "|".join([mode, game.phase, game.raid, game.wave, game.gold, str(game.res.values()), sel.c if sel else -1, sel.r if sel else -1,
		tower.level if tower else 0, str(game.buildings.values()), tkey])
	if key != last_key:
		last_key = key
		_clear_context()
		match mode:
			"tower":
				_render_tower(tower)
			"build":
				_render_build()
			"building":
				_render_building(sel.building)
			_:
				_render_idle()
	if train_bar and is_instance_valid(train_bar):
		var b: Control = train_bar.get_parent()
		var kind: String = b.get_meta("kind")
		var tr := game.training_of(kind)
		var p: float = tr.time / D.TROOPS[kind].train if tr.queue else 0.0
		train_bar.position = Vector2(4, b.size.y - 8)
		train_bar.size = Vector2((b.size.x - 8) * p, 5)

	var ch: Dictionary = game.charge
	var cstate := "none"
	if ch.level:
		cstate = str(ceili(ch.cooldown)) if ch.cooldown > 0.0 else ("ready" if game.can_charge() else "idle")
	var ckey := "|".join([game.speed, game.phase, game.raid, game.wave, sound_on, cstate, ch.active > 0.0, light_name])
	if ckey != last_controls:
		last_controls = ckey
		btn_sound.text = "Ses" if sound_on else "Sessiz"
		btn_speed.text = "%d×" % game.speed
		btn_light.text = light_name
		btn_charge.visible = ch.level > 0
		btn_charge.disabled = not game.can_charge()
		btn_charge.text = ("%d sn" % ceili(ch.cooldown)) if ch.cooldown > 0.0 and ch.active <= 0.0 else "Allah Allah!"
		btn_primary.disabled = game.phase != "build"
		if game.phase == "wave":
			btn_primary.text = "Ani baskın!" if game.raid else "%d. dalga sürüyor" % game.wave
		else:
			btn_primary.text = "%d. Dalgayı Başlat" % mini(game.wave + 1, game.total_waves)

	var ended := game.phase == "won" or game.phase == "lost"
	if ended and not overlay.visible:
		if game.phase == "won":
			overlay_title.text = "Devlet-i Aliyye Muzaffer!"
			overlay_text.text = "%d seferin hepsini püskürttün. Surda %d sağlamlık kaldı." % [game.total_waves, game.wall]
		else:
			overlay_title.text = "Kale Düştü"
			overlay_text.text = "%d. dalgada surlar yıkıldı.\nEn yüksek dalga: %d" % [game.wave, best_wave]
	overlay.visible = ended
