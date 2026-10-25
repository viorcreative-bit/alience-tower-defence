class_name MainMenu
extends CanvasLayer

# Oyundan önceki ana menü: önce giriş (ad ile, hesap cihazda saklanır), sonra devlet seçimi ve hükümdar.
# Her devletin bir hükümdarı vardır; savaşlarda kazanılan şerefle geliştirilir. "Sefere Çık" sefer haritasını
# açar; oradan bir kuşatma ya da serbest savaş seçilince start sinyali devlet, hükümdar seviyesi ve
# kuşatmayla ("" = serbest savaş) gelir. Arkada 3B kale görünmeye devam eder.

const D := preload("res://scripts/data.gd")
const C_TEXT := GameUI.C_TEXT
const C_DIM := GameUI.C_DIM
const C_GOLD := GameUI.C_GOLD
const C_COIN := GameUI.C_COIN

signal start(country: String, king_level: int, stage: String)
signal duel_join(code: String)
signal duel_cancel

var ui: GameUI  # yazı tipleri, çerçeveler ve tema için
var models: Models
var profiles: Profiles
var root: Control
var page: VBoxContainer
var selected := "ottoman"
var name_edit: LineEdit
var cards := {}  # devlet → PanelContainer
var stage := ""  # haritada seçili kuşatma
var net: Net
var duel_label: Label  # düello bekleme satırı (main yazar)
var code_edit: LineEdit


func _init(u: GameUI, m: Models, p: Profiles, n: Net) -> void:
	ui = u
	models = m
	profiles = p
	net = n
	layer = 5


func _ready() -> void:
	root = ColorRect.new()
	(root as ColorRect).color = Color(0.06, 0.04, 0.03, 0.72)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = ui.root.theme
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 28)
	root.add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	open()


# Giriş yapılmışsa doğrudan devlet seçimine geçer; map true ise sefer haritasına
func open(map := false) -> void:
	visible = true
	if profiles.current == "":
		_show_login()
	elif map:
		_show_campaign()
	else:
		selected = profiles.country()
		_show_countries()


func _clear() -> void:
	for c in page.get_children():
		c.queue_free()
	cards.clear()


func _title() -> void:
	var t := ui._label("KALE SAVUNMASI", 50, C_GOLD, ui.font_title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("shadow_offset_y", 3)
	page.add_child(t)
	var s := ui._label("Devletini seç, hükümdarını yücelt, kaleni koru", 22, C_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(s)


func _panel() -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := ui._frame("panel", 18, 22)
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	page.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _button(parent: Control, text: String, cb: Callable, red := false, h := 70) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.pressed.connect(cb)
	if red:
		b.add_theme_stylebox_override("normal", ui._frame("red"))
		b.add_theme_stylebox_override("hover", ui._frame("red_hot"))
		b.add_theme_stylebox_override("pressed", ui._frame("red_hot"))
		b.add_theme_font_size_override("font_size", 28)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- giriş

func _show_login() -> void:
	_clear()
	page.add_child(_spacer(80))
	_title()
	page.add_child(_spacer(30))
	var v := _panel()
	v.add_child(ui._label("GİRİŞ", 30, C_GOLD, ui.font_title))
	v.add_child(ui._label("Komutan adın:", 22, C_DIM))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Örnek: Mehmed"
	name_edit.max_length = Profiles.MAX_NAME
	name_edit.custom_minimum_size = Vector2(0, 70)
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.add_theme_stylebox_override("normal", ui._box(Color("#120d0a"), Color("#6a4b30"), 10))
	name_edit.add_theme_stylebox_override("focus", ui._box(Color("#120d0a"), C_GOLD, 10))
	name_edit.add_theme_color_override("font_color", C_TEXT)
	name_edit.add_theme_color_override("font_placeholder_color", Color("#7d6a55"))
	name_edit.text_submitted.connect(func(t): _login(t))
	v.add_child(name_edit)
	_button(v, "Giriş Yap", func(): _login(name_edit.text), true, 76)
	var note := ui._label("Hesabın bu cihazda saklanır. Aynı adla girince kaldığın yerden devam edersin.", 19, C_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var saved := profiles.names()
	if saved.size():
		v.add_child(ui._label("Kayıtlı hesaplar", 22, C_GOLD, ui.font_bold))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for n in saved:
			var b := Button.new()
			b.text = n
			b.custom_minimum_size = Vector2(0, 58)
			b.pressed.connect(_login.bind(n))
			flow.add_child(b)


func _login(name: String) -> void:
	if not profiles.login(name):
		name_edit.placeholder_text = "Önce bir ad yaz"
		name_edit.grab_focus()
		return
	selected = profiles.country()
	_show_countries()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# ---------------------------------------------------------------- devlet ve hükümdar

func _show_countries() -> void:
	_clear()
	# üst satır: hoş geldin, şeref, çıkış
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	page.add_child(top)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -4)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(ui._label("Hoş geldin,", 20, C_DIM))
	who.add_child(ui._label(profiles.current, 32, C_TEXT, ui.font_bold))
	top.add_child(who)
	var hon := HBoxContainer.new()
	hon.add_child(ui._icon("palace", 34))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", -6)
	hv.add_child(ui._label("ŞEREF", 14, C_DIM, ui.font_bold))
	hv.add_child(ui._label(str(profiles.honor()), 30, C_COIN, ui.font_bold))
	hon.add_child(hv)
	hon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hon)
	var out := Button.new()
	out.text = "Çıkış"
	out.custom_minimum_size = Vector2(110, 58)
	out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out.pressed.connect(func():
		profiles.logout()
		_show_login())
	top.add_child(out)

	var h := ui._label("DEVLETİNİ SEÇ", 30, C_GOLD, ui.font_title)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(h)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for c in D.COUNTRY_ORDER:
		grid.add_child(_country_card(c))

	page.add_child(_king_panel())
	var day := profiles.daily()
	var pb := _button(page, "Görevler, Başarımlar ve Sıralama  ·  bugün %d/%d görev" % [day.done.size(), day.ids.size()], _show_progress, false, 62)
	pb.add_theme_color_override("font_color", C_COIN)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	var go := _button(row, "Sefere Çık", func():
		profiles.set_v("country", selected)
		_show_campaign(), true, 84)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var du := _button(row, "Düello", func():
		profiles.set_v("country", selected)
		show_duel(), false, 84)
	du.custom_minimum_size.x = 190
	du.add_theme_font_size_override("font_size", 28)
	du.add_theme_color_override("font_color", C_GOLD)
	go.icon = load("res://assets/ui/swords.png")
	go.add_theme_constant_override("icon_max_width", 36)
	go.add_theme_font_size_override("font_size", 32)


func _flag_rect(c: String, w: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = models.ottoman_flag() if c == "ottoman" else models.nation_flag(c)
	if c == "ottoman" and models.tex_cache.has("ottoman_img"):
		# ortak sancak dokusu başka devlete çevrilmiş olabilir; Osmanlı'nın asıl resmini göster
		r.texture = ImageTexture.create_from_image(models.tex_cache.ottoman_img)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(w, w * 0.64)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _country_card(c: String) -> Control:
	var info: Dictionary = D.COUNTRIES[c]
	var on := c == selected
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 118)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := ui._frame("card_hot" if on else "card", 12, 10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", ui._frame("card_hot", 12, 10))
	b.add_theme_stylebox_override("pressed", ui._frame("card_hot", 12, 10))
	b.pressed.connect(func():
		selected = c
		_show_countries())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	row.add_child(_flag_rect(c, 70))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(ui._label(info.short, 22, C_GOLD if on else C_TEXT, ui.font_title))
	var r := ui._label(info.ruler, 18, C_TEXT, ui.font_bold)
	r.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(r)
	col.add_child(_stars(profiles.king_level(c), 14))
	for l in col.get_children():
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


# Hükümdar seviyesi: dolu ve boş altın baklavalar (yazı tiplerinde yıldız işareti yok)
func _stars(level: int, size := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in D.KING.max_level:
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_COIN if i < level else Color(0, 0, 0, 0.35)
		sb.border_color = C_COIN
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(size, size)
		p.rotation_degrees = 45
		p.pivot_offset = Vector2(size, size) / 2.0
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(size * 1.3, size * 1.3)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = Vector2(size * 0.15, size * 0.15)
		slot.add_child(p)
		h.add_child(slot)
	return h


func _king_panel() -> Control:
	var c := selected
	var info: Dictionary = D.COUNTRIES[c]
	var lv := profiles.king_level(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var p := PanelContainer.new()
	var sb := ui._frame("panel", 18, 20)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_king_view(c, lv))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(ui._label(D.NATION_NAMES[c], 22, C_DIM, ui.font_bold))
	names.add_child(ui._label(D.ruler_name(c), 28, C_TEXT, ui.font_bold))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lrow.add_child(ui._label("Seviye %d/%d" % [lv, D.KING.max_level], 20, C_COIN, ui.font_bold))
	var st := _stars(lv)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lrow.add_child(st)
	names.add_child(lrow)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	var fl := _flag_rect(c, 72)
	fl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	names.add_child(fl)
	head.add_child(names)
	var desc := ui._label(info.text + ".", 21, C_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	v.add_child(ui._label("Şimdi: " + D.king_text(c, lv), 22, C_TEXT, ui.font_bold))
	if lv < D.KING.max_level:
		v.add_child(ui._label("Sonraki seviye: " + D.king_text(c, lv + 1), 22, Color("#a8d872"), ui.font_bold))
		var cost := D.king_cost(lv)
		var up := _button(v, "Hükümdarı Geliştir  ·  %d şeref" % cost, func():
			if profiles.upgrade_king(c):
				_show_countries(), false, 64)
		up.icon = load("res://assets/ui/palace.png")
		up.disabled = not profiles.can_upgrade_king(c)
		if up.disabled:
			var need := ui._label("Şeref, savaşta püskürttüğün her dalgayla kazanılır (%d şeref eksik)." % (cost - profiles.honor()), 18, C_DIM)
			need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(need)
	else:
		v.add_child(ui._label("Hükümdar en yüksek seviyede!", 22, C_GOLD, ui.font_bold))
	return p


# Hükümdarın 3B önizlemesi: kendi dünyası olan küçük bir görüntü alanında yavaşça döner
func _king_view(c: String, level: int) -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(170, 210)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#a89a88")
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	sun.light_color = Color("#ffe8c8")
	vp.add_child(sun)
	var ch := models.king(c, level)
	ch.root.scale = Vector3.ONE
	var turn := Node3D.new()
	turn.add_child(ch.root)
	vp.add_child(turn)
	var aabb := _bounds(ch.root)
	var h := maxf(aabb.size.y, 0.1)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.transform = Transform3D(Basis(), Vector3(0, aabb.position.y + h * 0.6, h * 2.0)).looking_at(Vector3(0, aabb.position.y + h * 0.48, 0))
	vp.add_child(cam)
	ch.anim.play("Idle")
	var tw := turn.create_tween().set_loops()
	turn.rotation.y = -0.5
	tw.tween_property(turn, "rotation:y", 0.5, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(turn, "rotation:y", -0.5, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return box


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.get_aabb()
		var t := Transform3D()
		var p: Node = mi
		while p and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		b = t * b
		out = b if first else out.merge(b)
		first = false
	return out


# ---------------------------------------------------------------- sefer haritası

# Kuşatmalar sırayla açılır. Haritada kaleye dokununca altında bilgisi çıkar.
func _show_campaign() -> void:
	_clear()
	selected = profiles.country()
	if stage == "" or not profiles.stage_open(stage):
		stage = D.STAGE_ORDER[0]
		for id in D.STAGE_ORDER:
			if profiles.stage_open(id):
				stage = id
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	page.add_child(top)
	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(110, 58)
	back.pressed.connect(_show_countries)
	top.add_child(back)
	var h := ui._label("SEFER HARİTASI", 32, C_GOLD, ui.font_title)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(h)
	var fl := _flag_rect(selected, 64)
	top.add_child(fl)

	var map := CampaignMap.new(profiles, ui.font_bold, ui.font_title)
	map.custom_minimum_size = Vector2(0, 560)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.selected = stage
	map.picked.connect(func(id):
		stage = id
		_show_campaign())
	page.add_child(map)

	var st: Dictionary = D.STAGES[stage]
	var open := profiles.stage_open(stage)
	var stars := profiles.stage_stars(stage)
	var v := _panel()
	var head := HBoxContainer.new()
	head.add_child(ui._label("%s Kuşatması" % st.name, 30, C_TEXT, ui.font_title))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(ui._label(str(st.year), 26, C_GOLD, ui.font_bold))
	v.add_child(head)
	var d := ui._label(st.text, 20, C_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var foes := []
	for n in st.nations:
		var nm: String = D.NATION_NAMES["ottoman" if n == selected else n]
		if not nm in foes:
			foes.append(nm)
	var info := ui._label("%d dalga · %s · düşman canı ×%s" % [st.picks.size(), D.join_list(foes), D.num(st.hp, 2)], 20, C_TEXT, ui.font_bold)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var rw := "Zafer ödülü: %d şeref" % st.honor if stars == 0 else "Kazanıldı · en iyi %d/3 yıldız" % stars
	v.add_child(ui._label(rw, 20, C_COIN, ui.font_bold))
	v.add_child(_hero_row(_show_campaign))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var go := _button(row, "Kuşatmaya Başla" if open else "Önce önceki kaleyi kazan", func(): _go(stage), true, 76)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = not open
	if open:
		go.icon = load("res://assets/ui/swords.png")
		go.add_theme_constant_override("icon_max_width", 32)
	var free := _button(row, "Serbest Savaş", func(): _go(""), false, 76)
	free.custom_minimum_size.x = 200


# Savaşa götürülecek kahraman komutan: üç düğme ve seçilenin yeteneği
func _hero_row(refresh: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var l := ui._label("Komutan", 20, C_DIM, ui.font_bold)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var cur := profiles.hero()
	for id in D.HERO_ORDER:
		var b := Button.new()
		b.text = D.HEROES[id].short
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var on: bool = id == cur
		b.add_theme_stylebox_override("normal", ui._frame("card_hot" if on else "card", 12, 8))
		b.add_theme_color_override("font_color", Color(D.HEROES[id].ring) if on else C_TEXT)
		b.pressed.connect(func():
			profiles.set_v("hero", id)
			refresh.call())
		row.add_child(b)
	var h: Dictionary = D.HEROES[cur]
	var d := ui._label("%s, %s · %s: %s" % [h.name, h.title, h.ability, D.hero_effect(cur)], 18, C_TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return v


func _go(id: String) -> void:
	visible = false
	start.emit(selected, profiles.king_level(selected), id)


# ---------------------------------------------------------------- görevler, başarımlar, sıralama

func _show_progress() -> void:
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	page.add_child(top)
	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(110, 58)
	back.pressed.connect(_show_countries)
	top.add_child(back)
	var h := ui._label("ŞEREF DEFTERİ", 32, C_GOLD, ui.font_title)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(h)
	var hv := ui._label("%d şeref" % profiles.honor(), 24, C_COIN, ui.font_bold)
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hv)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	sc.add_child(col)

	# günlük görevler
	var day := profiles.daily()
	var qv := _section(col, "GÜNLÜK GÖREVLER", "Her gün üç yeni görev. Tamamlayınca şeref kendiliğinden gelir.")
	for q in day.ids:
		var qd: Dictionary = D.QUESTS[q]
		var done: bool = day.done.has(q)
		_progress_row(qv, qd.text, mini(day.progress.get(qd.stat, 0), qd.goal), qd.goal, "+%d şeref" % qd.honor, done)

	# başarımlar
	var av := _section(col, "BAŞARIMLAR", "%d/%d rozet" % [profiles.get_v("ach", {}).size(), D.ACHIEVEMENT_ORDER.size()])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	av.add_child(grid)
	for a in D.ACHIEVEMENT_ORDER:
		grid.add_child(_badge(a))

	# çevrimiçi sıralama
	var ov := _section(col, "ÇEVRİMİÇİ SIRALAMA", "Bütün komutanlar, kazanılan toplam şerefe göre.")
	var wait := ui._label("Yükleniyor…" if Net.configured() else "Çevrimiçi sunucu henüz bağlanmadı.", 20, C_DIM)
	ov.add_child(wait)
	if Net.configured():
		net.fetch_top(func(rows):
			if not is_instance_valid(wait):
				return
			if rows == null:
				wait.text = "Sunucuya ulaşılamadı. İnternetini kontrol et."
				return
			wait.queue_free()
			if rows.is_empty():
				ov.add_child(ui._label("Henüz kimse yok. İlk sen ol!", 20, C_DIM))
			for i in rows.size():
				var r: Dictionary = rows[i]
				_rank_row(ov, i, str(r.get("name", "?")), "%d şeref · %d yıldız · %d düello" % [int(r.get("honor", 0)), int(r.get("stars", 0)), int(r.get("duel_wins", 0))],
					str(r.get("name", "")) == profiles.current))

	# sıralama
	var lv := _section(col, "BU CİHAZ", "Bu cihazdaki komutanlar, kazanılan toplam şerefe göre.")
	var rows := profiles.leaderboard()
	for i in rows.size():
		var r: Dictionary = rows[i]
		_rank_row(lv, i, r.name, "%d şeref · %d yıldız · %d rozet · en iyi %d. dalga" % [r.honor, r.stars, r.ach, r.best], r.name == profiles.current)


func _rank_row(parent: Control, i: int, name: String, info: String, me: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var rk := ui._label("%d." % (i + 1), 24, C_COIN if i == 0 else C_DIM, ui.font_bold)
	rk.custom_minimum_size = Vector2(44, 0)
	row.add_child(rk)
	var nm := ui._label(name, 24, C_GOLD if me else C_TEXT, ui.font_bold)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nm)
	row.add_child(ui._label(info, 19, C_DIM))
	parent.add_child(row)


func _section(parent: Control, title: String, sub: String) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := ui._frame("panel", 18, 20)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(ui._label(title, 26, C_GOLD, ui.font_title))
	var s := ui._label(sub, 18, C_DIM)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	return v


func _progress_row(parent: Control, text: String, now: int, goal: int, prize: String, done: bool) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	var h := HBoxContainer.new()
	var t := ui._label(text, 21, C_TEXT if not done else Color("#a8d872"), ui.font_bold)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(ui._label("Tamam" if done else "%d/%d · %s" % [now, goal, prize], 19, Color("#a8d872") if done else C_COIN, ui.font_bold))
	v.add_child(h)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.custom_minimum_size = Vector2(0, 8)
	v.add_child(bg)
	var fill := ColorRect.new()
	fill.color = Color("#a8d872") if done else C_COIN
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(now) / maxf(1.0, goal), 0.0, 1.0)
	bg.add_child(fill)


func _badge(id: String) -> Control:
	var a: Dictionary = D.ACHIEVEMENTS[id]
	var got := profiles.has_ach(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ui._frame("card_hot" if got else "card", 12, 10))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 112)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var gem := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_COIN if got else Color(0, 0, 0, 0.35)
	sb.border_color = C_COIN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	gem.add_theme_stylebox_override("panel", sb)
	gem.custom_minimum_size = Vector2(20, 20)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(gem)
	var n := ui._label(a.name, 21, C_GOLD if got else C_TEXT, ui.font_bold)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	v.add_child(h)
	var t := ui._label(a.text, 17, C_DIM)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var pr := profiles.ach_progress(id)
	v.add_child(ui._label("Kazanıldı · +%d şeref" % a.honor if got else "%d/%d · +%d şeref" % [pr[0], pr[1], a.honor], 17, Color("#a8d872") if got else C_COIN, ui.font_bold))
	return p


# ---------------------------------------------------------------- düello

func show_duel() -> void:
	visible = true
	_clear()
	duel_label = null
	selected = profiles.country()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	page.add_child(top)
	var back := Button.new()
	back.text = "Geri"
	back.custom_minimum_size = Vector2(110, 58)
	back.pressed.connect(func():
		duel_cancel.emit()
		_show_countries())
	top.add_child(back)
	var h := ui._label("DÜELLO", 32, C_GOLD, ui.font_title)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(h)
	top.add_child(_flag_rect(selected, 64))
	var v := _panel()
	v.add_child(ui._label("İki komutan, iki kale", 28, C_TEXT, ui.font_title))
	var d := ui._label("Rakibinle aynı anda savaşırsın. Dalgalar kendiliğinden gelir ve bitmez. Yendiğin düşmanlar " +
		"rakibine ek asker olarak gider; patron yenersen kuşatma kulesi yollarsın. Suru önce düşen kaybeder. " +
		"Zafer %d, yenilgi %d şeref getirir." % [D.DUEL.honor_win, D.DUEL.honor_lose], 20, C_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	v.add_child(_hero_row(show_duel))
	if not Net.configured():
		var n := ui._label("Çevrimiçi sunucu henüz bağlanmadı; düello çok yakında açılacak.", 22, C_COIN, ui.font_bold)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
		return
	var host := _button(v, "Oda Kur", func():
		var r := RandomNumberGenerator.new()
		r.randomize()
		_wait_duel(DuelLink.make_code(r)), true, 76)
	host.icon = load("res://assets/ui/swords.png")
	host.add_theme_constant_override("icon_max_width", 32)
	v.add_child(ui._label("ya da arkadaşının oda koduyla katıl:", 20, C_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "ABCD"
	code_edit.max_length = D.DUEL.code_len
	code_edit.custom_minimum_size = Vector2(0, 70)
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_size_override("font_size", 34)
	code_edit.add_theme_stylebox_override("normal", ui._box(Color("#120d0a"), Color("#6a4b30"), 10))
	code_edit.add_theme_stylebox_override("focus", ui._box(Color("#120d0a"), C_GOLD, 10))
	code_edit.add_theme_color_override("font_color", C_TEXT)
	code_edit.text_changed.connect(func(t):
		var c := code_edit.caret_column
		code_edit.text = t.to_upper()
		code_edit.caret_column = c)
	code_edit.text_submitted.connect(func(t): _join_code(t))
	row.add_child(code_edit)
	var join := _button(row, "Katıl", func(): _join_code(code_edit.text), false, 70)
	join.custom_minimum_size.x = 180


func _join_code(t: String) -> void:
	var c := t.strip_edges().to_upper()
	if c.length() != D.DUEL.code_len:
		code_edit.placeholder_text = "%d harf" % D.DUEL.code_len
		code_edit.grab_focus()
		return
	_wait_duel(c)


# Odaya girildi; rakip gelince main oyunu başlatır
func _wait_duel(code: String) -> void:
	_clear()
	page.add_child(_spacer(120))
	var v := _panel()
	v.add_child(ui._label("ODA KODU", 24, C_DIM, ui.font_bold))
	var c := ui._label(code, 84, C_GOLD, ui.font_title)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	duel_label = ui._label("Sunucuya bağlanılıyor…", 22, C_TEXT)
	duel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(duel_label)
	_button(v, "Vazgeç", func():
		duel_cancel.emit()
		show_duel(), false, 66)
	duel_join.emit(code)


func duel_status(text: String) -> void:
	if duel_label and is_instance_valid(duel_label):
		duel_label.text = text
