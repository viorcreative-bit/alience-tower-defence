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

signal action(name: String, arg: String)

var game: Game
var font_title: FontFile
var font_body: FontFile
var font_bold: FontFile

var root: Control
var lbl_gold: Label
var lbl_wall: Label
var lbl_wave: Label
var context: VBoxContainer
var btn_sound: Button
var btn_speed: Button
var btn_light: Button
var btn_charge: Button
var btn_primary: Button
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
	_build_banner()
	_build_overlay()


func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 24
	t.set_color("font_color", "Label", C_TEXT)
	var btn := _box(Color("#2b2019"), C_EDGE, 10)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", _box(Color("#3a2b21"), C_GOLD, 10))
	t.set_stylebox("pressed", "Button", _box(Color("#4a3628"), C_GOLD, 10))
	t.set_stylebox("disabled", "Button", _box(Color("#221a14"), Color("#3a2b20"), 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#7d6a55"))
	t.set_font("font", "Button", font_bold)
	t.set_font_size("font_size", "Button", 24)
	return t


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
	top = PanelContainer.new()
	var sb := _box(Color(0.12, 0.09, 0.07, 0.92), Color(0, 0, 0, 0), 0, 0)
	sb.border_color = C_GOLD
	sb.border_width_bottom = 2
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	top.add_theme_stylebox_override("panel", sb)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	top.add_child(hb)
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", -6)
	title.add_child(_label("OSMANLI", 34, C_GOLD, font_title))
	title.add_child(_label("KALE SAVUNMASI", 15, C_TEXT, font_title))
	hb.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	lbl_gold = _stat(hb, "AKÇE", C_COIN)
	lbl_wall = _stat(hb, "SUR", C_WALL)
	lbl_wave = _stat(hb, "DALGA", C_TEXT)


func _stat(parent: Control, name: String, color: Color) -> Label:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	var n := _label(name, 15, C_DIM, font_bold)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(n)
	var val := _label("0", 32, color, font_bold)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(val)
	parent.add_child(v)
	return val


# ---------------------------------------------------------------- alt panel

func _build_panel() -> void:
	panel = PanelContainer.new()
	var sb := _box(Color(0.12, 0.09, 0.07, 0.95), Color(0, 0, 0, 0), 0, 0)
	sb.border_color = C_GOLD
	sb.border_width_top = 2
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	context = VBoxContainer.new()
	context.custom_minimum_size = Vector2(0, 200)
	context.add_theme_constant_override("separation", 8)
	vb.add_child(context)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	btn_sound = _ctrl(row, "Ses", 80, func(): action.emit("sound", ""))
	btn_speed = _ctrl(row, "1×", 64, func(): action.emit("speed", ""))
	btn_light = _ctrl(row, "Öğle", 92, func(): action.emit("light", ""))
	btn_charge = _ctrl(row, "Allah Allah!", 150, func(): action.emit("charge", ""))
	btn_primary = _ctrl(row, "1. Dalgayı Başlat", 0, func(): action.emit("primary", ""))
	btn_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_primary.add_theme_stylebox_override("normal", _box(Color("#9e1b25"), Color("#d4453f"), 10))
	btn_primary.add_theme_stylebox_override("hover", _box(Color("#bf2a33"), C_GOLD, 10))
	btn_primary.add_theme_stylebox_override("pressed", _box(Color("#bf2a33"), C_GOLD, 10))
	btn_charge.add_theme_color_override("font_color", C_GOLD)


func _ctrl(parent: Control, text: String, w: float, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 64)
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


func _render_idle() -> void:
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
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not game.can_build(type)
		grid.add_child(b)
		b.pressed.connect(func(): action.emit("build", type))
		var col := Color(def.color)
		b.add_theme_stylebox_override("normal", _card_box(col, false))
		b.add_theme_stylebox_override("hover", _card_box(col, true))
		b.add_theme_stylebox_override("pressed", _card_box(col, true))
		b.add_theme_stylebox_override("disabled", _card_box(col.darkened(0.5), false))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_top = 6
		v.offset_right = -10
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


func _card_box(col: Color, hot: bool) -> StyleBoxFlat:
	var s := _box(Color("#2b2019") if not hot else Color("#3a2b21"), C_GOLD if hot else C_EDGE, 10)
	s.border_width_left = 8
	s.border_color = col if not hot else C_GOLD
	return s


func _info_head(name: String, sub: String, lvl: String, col: Color) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(sw)
	hb.add_child(_label(name, 28, C_TEXT, font_bold))
	if sub != "":
		var s := _label(sub, 20, C_DIM)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(s)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(_label(lvl, 22, C_GOLD, font_bold))
	context.add_child(hb)


func _render_tower(t: Dictionary) -> void:
	var s := game.tower_stats(t)
	_info_head(D.TOWER_NAMES[t.type][0], "", "Seviye %d/%d" % [t.level, D.UPGRADE.max_level], Color(D.TOWERS[t.type].color))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	hb.add_child(_label("Hasar  %s" % D.num(s.damage), 23))
	hb.add_child(_label("Menzil  %s kare" % D.num(s.range, 2), 23))
	hb.add_child(_label("Atış  %s sn" % D.num(s.rate, 2), 23))
	context.add_child(hb)
	context.add_child(_label(D.tower_feature(t.type, s), 22, C_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	context.add_child(row)
	var maxed: bool = t.level >= D.UPGRADE.max_level
	var up := Button.new()
	up.text = "En yüksek seviye" if maxed else "Yükselt · %d" % game.tower_upgrade_cost(t)
	up.disabled = not game.can_upgrade_tower(t)
	up.custom_minimum_size = Vector2(0, 60)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): action.emit("upgrade", ""))
	row.add_child(up)
	var sell := Button.new()
	sell.text = "Sat +%d" % D.sell_value(t.spent)
	sell.custom_minimum_size = Vector2(170, 60)
	sell.pressed.connect(func(): action.emit("sell", ""))
	row.add_child(sell)


func _render_building(id: String) -> void:
	var level: int = game.buildings[id]
	var names: Array = D.BUILDING_NAMES[id]
	_info_head(names[0], names[1], "Seviye %d/%d" % [level, D.MAX_BUILDING_LEVEL], Color(D.BUILDINGS[id].color))
	var now := _label(D.building_effect(id, level) if level else "Henüz kurulmadı", 22, C_TEXT)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context.add_child(now)
	if level < D.MAX_BUILDING_LEVEL:
		var nx := _label("Sonraki: " + D.building_effect(id, level + 1), 20, C_DIM)
		nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		context.add_child(nx)
	var block := game.building_block(id)
	var cost := game.building_cost(id)
	var label := ""
	if block.is_empty():
		label = ("Yükselt · %d" if level else "Kur · %d") % cost
	elif block.kind == "max":
		label = "En yüksek seviye"
	elif block.kind == "requires":
		label = "Önce %s %d. seviye" % [D.BUILDING_NAMES[block.building][0], block.level]
	else:
		label = "Saray %d. seviye gerekli" % block.level
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	context.add_child(row)
	var up := Button.new()
	up.text = label
	up.disabled = not game.can_upgrade_building(id)
	up.custom_minimum_size = Vector2(0, 60)
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(func(): action.emit("building", id))
	row.add_child(up)
	var kind = game.troop_of(id)
	if kind != null and level > 0:
		var cap := game.troop_cap(kind)
		var tr := game.training_of(kind)
		var have := game.troop_count(kind)
		var full: bool = have + tr.queue >= cap
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 60)
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
		for l in [a, c]:
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
	lbl_gold.text = str(game.gold)
	lbl_wall.text = str(game.wall)
	lbl_wave.text = "%d/%d" % [game.wave, game.total_waves]
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
	var key := "|".join([mode, game.phase, game.raid, game.wave, game.gold, sel.c if sel else -1, sel.r if sel else -1,
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
