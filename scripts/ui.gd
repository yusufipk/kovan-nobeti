extends CanvasLayer
# Menus, HUD, story panel, upgrade cards and the end screen. Everything is built in code.

const AMBER := Color(1.0, 0.74, 0.16)
const TEAL := Color(0.2, 0.85, 0.75)
const CREAM := Color(1.0, 0.95, 0.84)
const INK := Color(0.07, 0.05, 0.04)
const BARK := Color(0.15, 0.105, 0.075)
const BARK2 := Color(0.24, 0.17, 0.115)
const WAX := Color(0.6, 0.45, 0.24)
const MUTED := Color(0.86, 0.78, 0.66)
const HONEY := Color(0.98, 0.68, 0.12)
const FONT_PATH := "res://assets/font/Baloo2.ttf"

const STORY_PARAGRAPHS := [
	"Çayırın tam ortasında yükselen kadim Ana Kovan, yüzyıllardır vadinin en saf altın balını saklar. Güneş batıp gökyüzü karardığında bu balın kokusu toprağın derinliklerine sızar ve açgözlü böcek sürülerini uyandırır.",
	"Sürünün öncüleri olan zırhlı Makas ve zehirli Akrep yolu açarken, her gecenin sonunda toprağı yararak Kraliçe yükselir. Kovanı korumak için geriye yalnızca son nöbetçi arıcı, sadık arı sürüsü ve çayırın dört yanına dağılmış kadim sunaklar kalmıştır.",
	"Kraliçe'yi devirmek geceyi bitirir ama nöbeti değil: her şafakta yeni bir döngü başlar ve sürü daha da güçlenerek geri döner. Topladığın balla arıcılık ustalığını geliştir, sunakların lütfunu kuşan ve Ana Kovan düşene dek nöbeti tut.",
]

var main
var font: FontVariation
var font_bold: FontVariation
var faces := {}
var own_font := false
var root: Control
var num_layer: Control
var hurt: ColorRect
var hud: Control
var menu: Control
var menu_record: Label
var pause_panel: Control
var settings_overlay: Control
var story_panel: Control
var story_btn: Button
var story_ok: Button
var story_first := false
var choice_panel: Control
var choice_title: Label
var cards: Array[Dictionary] = []
var card_data: Array = []
var end_panel: Control
var end_title: Label
var end_stats: VBoxContainer
var end_damage: VBoxContainer
var end_again: Button
var choosing := false
var choice_lock := 0.0
var bot_t := 0.0
var toast_text := ""
var toast_t := 0.0
var hurt_marks: Array[Dictionary] = []
var ult_flash := 0.0
var banner_title := ""
var banner_sub := ""
var banner_t := 0.0
var icons := {}
var sliders := {}
var knob: ImageTexture
var hint_t := 0.0
var hold_choice := false
var choice_kind := ""
var end_menu: Button
var menu_btns: Array[Button] = []
var settings_ok: Button
var end_lock := 0.0
var end_goal: Label
var hive_opened := 0
var end_hive: Button
var reroll_btn: Button
var hive_panel: Control
var hive_btn: Button
var hive_back: Button
var hive_honey: Label
var hive_tiles: Array[Dictionary] = []
var chip_buy: StyleBoxFlat
var chip_wait: StyleBoxFlat
var chip_full: StyleBoxFlat

func setup(m) -> void:
	main = m
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	own_font = ResourceLoader.exists(FONT_PATH)
	font = _face(600)
	font_bold = _face(800)
	knob = _knob()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hurt = ColorRect.new()
	hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt.color = Color(1, 0, 0, 0)
	var hsh := Shader.new()
	hsh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat d = length(UV - vec2(0.5)) * 1.414;\n\tCOLOR.a *= mix(0.18, 1.0, smoothstep(0.42, 1.0, d));\n}\n"
	var hmat := ShaderMaterial.new()
	hmat.shader = hsh
	hurt.material = hmat
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt)
	num_layer = Control.new()
	num_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	num_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(num_layer)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	root.add_child(hud)
	main.fx.attach_ui(num_layer, hurt)
	for i in 40:
		icons[i] = main.assets.icon(i)
	_build_choice()
	_build_menu()
	_build_pause()
	_build_end()
	_build_settings_overlay()
	_build_hive()
	_build_story()

# ---------- helpers

func _face(weight: int) -> FontVariation:
	var fv := FontVariation.new()
	if own_font:
		fv.base_font = load(FONT_PATH)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	else:
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.9 if weight >= 700 else 0.0
	return fv

func _f(size: int, bold := true) -> FontVariation:
	var key := size * 2 + (1 if bold else 0)
	if not faces.has(key):
		var fv := _face(800 if bold else 600)
		if own_font:
			fv.spacing_top = -int(round(size * 0.22))
			fv.spacing_bottom = -int(round(size * 0.2))
		faces[key] = fv
	return faces[key]

func _style(bg: Color, border: Color, bw := 2, cut := 18, margin := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(cut)
	s.corner_detail = 1
	s.anti_aliasing = true
	s.set_content_margin_all(margin)
	return s

func _label(text: String, size: int, col := CREAM, bold := true, lift := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _f(size, bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if lift:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", maxi(5, size / 7))
		l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 14))
		l.add_theme_constant_override("shadow_outline_size", maxi(5, size / 7))
	return l

func _button(text: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 66)
	b.add_theme_font_override("font", _f(28, true))
	b.add_theme_font_size_override("font_size", 28)
	var base := HONEY if primary else BARK2
	var rim := Color(1.0, 0.87, 0.5) if primary else WAX
	var under := Color(0.48, 0.27, 0.03) if primary else Color(0.04, 0.03, 0.02)
	for st in ["normal", "hover", "focus", "pressed", "disabled"]:
		var s := _style(base, rim, 2, 16, 10)
		if st == "hover" or st == "focus":
			s.bg_color = base.lightened(0.14)
			s.border_color = CREAM
		elif st == "pressed":
			s.bg_color = base.darkened(0.1)
			s.border_color = CREAM
			s.content_margin_top = 15
			s.content_margin_bottom = 5
		elif st == "disabled":
			s.bg_color = base.darkened(0.45)
			s.border_color = rim.darkened(0.5)
		if st != "pressed":
			s.shadow_color = under
			s.shadow_size = 1
			s.shadow_offset = Vector2(0, 5)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", INK if primary else CREAM)
	b.add_theme_color_override("font_hover_color", INK if primary else Color.WHITE)
	b.add_theme_color_override("font_focus_color", INK if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK if primary else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.45, 0.4))
	b.pressed.connect(func():
		main.audio.play("click")
		cb.call())
	return b

func _dim(alpha: float) -> ColorRect:
	var c := ColorRect.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.color = Color(0.045, 0.03, 0.02, alpha)
	return c

func _title_with_version(title: String, size: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var t := _label(title, size, AMBER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var ver := _label(main.VERSION, 22, MUTED, false)
	ver.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(ver)
	return row

# ---------- hexagonal cells

func _hex_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 6:
		var a := TAU * k / 6.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_hex(ci: CanvasItem, c: Vector2, r: float, fill: Color, rim: Color, rim_w := 3.0) -> void:
	var pts := _hex_pts(c, r)
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	if rim.a > 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, rim, rim_w, true)

func _draw_badge(ci: CanvasItem, c: Vector2, r: float, tex: Texture2D, tint: Color, a := 1.0) -> void:
	_draw_hex(ci, c + Vector2(0, r * 0.09), r, Color(0, 0, 0, 0.35 * a), Color(0, 0, 0, 0))
	_draw_hex(ci, c, r, Color(BARK2.lerp(tint, 0.12), 0.96 * a), Color(tint, a), maxf(2.0, r * 0.07))
	_draw_hex(ci, c, r * 0.78, Color(tint, 0.1 * a), Color(0, 0, 0, 0))
	if tex != null:
		var s := r * 0.76
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(1, 1, 1, a))

func _badge(size: float, tex: Texture2D, tint := AMBER) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("tex", tex)
	c.set_meta("tint", tint)
	c.draw.connect(func(): _draw_badge(c, c.size * 0.5, size * 0.5 - 3.0, c.get_meta("tex", null), c.get_meta("tint", AMBER)))
	return c

func _set_badge(c: Control, tex: Texture2D, tint: Color) -> void:
	c.set_meta("tex", tex)
	c.set_meta("tint", tint)
	c.queue_redraw()

func _pips(r: float, centred: bool) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("r", r)
	c.set_meta("n", 0)
	c.set_meta("lv", 0)
	c.set_meta("add", 0)
	c.set_meta("col", AMBER)
	c.draw.connect(func():
		var n: int = c.get_meta("n")
		var lv: int = c.get_meta("lv")
		var add: int = c.get_meta("add")
		var col: Color = c.get_meta("col")
		var step := r * 2.15
		var x0 := (c.size.x - step * (n - 1)) * 0.5 if centred else r + 1.0
		for k in n:
			var p := Vector2(x0 + step * k, c.size.y * 0.5)
			if k < lv:
				_draw_hex(c, p, r, col, col.darkened(0.3), 1.5)
			elif k < lv + add:
				_draw_hex(c, p, r, CREAM, Color.WHITE, 1.5)
			else:
				_draw_hex(c, p, r, Color(INK, 0.7), Color(WAX, 0.7), 1.5))
	return c

func _set_pips(c: Control, n: int, lv: int, add: int, col: Color) -> void:
	var r: float = c.get_meta("r")
	c.set_meta("n", n)
	c.set_meta("lv", lv)
	c.set_meta("add", add)
	c.set_meta("col", col)
	c.custom_minimum_size = Vector2(n * r * 2.15 + 2.0, r * 2.0 + 4.0)
	c.queue_redraw()

func _keycap(text: String, size: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _style(Color(INK, 0.88), Color(CREAM, 0.55), 2, 7, 0)
	s.content_margin_left = 6
	s.content_margin_right = 6
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(size + 16, size + 16)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, size, CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _tex(t: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _knob() -> ImageTexture:
	var n := 30
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length()
			var a := clampf(n * 0.5 - 1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(CREAM if d > n * 0.5 - 5.0 else HONEY, a))
	return ImageTexture.create_from_image(img)

func fmt_time(sec: float) -> String:
	var s := int(floor(maxf(0.0, sec)))
	@warning_ignore("integer_division")
	return "%02d:%02d" % [s / 60, s % 60]

func fmt_int(v: float) -> String:
	var s := str(int(round(v)))
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - i - 1
		if left > 0 and left % 3 == 0:
			out += "."
	return out

func banner(title: String, sub: String) -> void:
	banner_title = title
	banner_sub = sub
	banner_t = 3.0
	toast_t = 0.0

func toast(t: String) -> void:
	toast_text = t
	toast_t = 2.6

func ult_ready() -> void:
	ult_flash = 6.0

func hurt_from(x: float, z: float) -> void:
	if hurt_marks.size() >= 6:
		hurt_marks.pop_front()
	hurt_marks.append({"x": x, "z": z, "t": 1.1})

# ---------- story overlay

func _build_story() -> void:
	story_panel = Control.new()
	story_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_panel.visible = false
	root.add_child(story_panel)
	story_panel.add_child(_dim(0.74))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_panel.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(980, 0)
	p.add_theme_stylebox_override("panel", _style(Color(BARK, 0.98), AMBER, 3, 28, 38))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	head.add_child(_badge(74, icons.get(24), AMBER))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 2)
	head.add_child(title_box)
	title_box.add_child(_label("KOVANIN HİKAYESİ", 46, AMBER))
	title_box.add_child(_label("Kovan Nöbeti  ·  %s" % main.VERSION, 20, MUTED, false))
	var sep := ColorRect.new()
	sep.color = Color(WAX, 0.55)
	sep.custom_minimum_size = Vector2(0, 2)
	v.add_child(sep)
	for para in STORY_PARAGRAPHS:
		var lbl := _label(para, 25, CREAM, false)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.custom_minimum_size = Vector2(880, 0)
		v.add_child(lbl)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	story_ok = _button("Kapat", func(): close_story(), true)
	story_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(story_ok)

func open_story(first_launch := false) -> void:
	story_first = first_launch
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_NONE
	story_ok.text = "Nöbete Başla" if first_launch else "Kapat"
	story_panel.visible = true
	story_ok.grab_focus()

func close_story() -> void:
	if not story_panel.visible:
		return
	story_panel.visible = false
	if not main.story_seen:
		main.story_seen = true
		main.save_settings()
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_ALL
	if menu.visible:
		if story_first and not menu_btns.is_empty():
			menu_btns[0].grab_focus()
		elif story_btn != null:
			story_btn.grab_focus()

# ---------- settings

func _slider_row(parent: Container, title: String, key: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var l := _label(title, 24, CREAM, false)
	l.custom_minimum_size = Vector2(210, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = main.settings[key]
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grab := StyleBoxFlat.new()
	grab.bg_color = HONEY
	grab.set_corner_radius_all(5)
	grab.set_content_margin_all(5)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.215, 0.14)
	track.set_corner_radius_all(5)
	track.set_content_margin_all(5)
	s.add_theme_stylebox_override("slider", track)
	for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(ic, knob)
	s.value_changed.connect(func(v: float):
		main.settings[key] = v
		main.apply_settings())
	s.drag_ended.connect(func(_changed: bool): main.save_settings())
	row.add_child(s)
	parent.add_child(row)
	if not sliders.has(key):
		sliders[key] = []
	sliders[key].append(s)

func _settings_rows(parent: Container, with_screen := true) -> void:
	_slider_row(parent, "Fare hassasiyeti", "sens", 0.2, 3.0)
	_slider_row(parent, "Müzik", "music", 0.0, 1.0)
	_slider_row(parent, "Efekt sesi", "sfx", 0.0, 1.0)
	_slider_row(parent, "Parlaklık", "brightness", 0.6, 1.5)
	if not with_screen:
		return
	var fb := _button("Tam ekran (F11)", func(): main.toggle_fullscreen())
	fb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(fb)

func _sync_sliders() -> void:
	for key in sliders:
		for s in sliders[key]:
			(s as HSlider).set_value_no_signal(main.settings[key])

func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	root.add_child(settings_overlay)
	settings_overlay.add_child(_dim(0.62))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(BARK, 0.98), WAX, 2, 26, 30))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	p.add_child(v)
	v.add_child(_title_with_version("Ayarlar", 40))
	_settings_rows(v)
	settings_ok = _button("Tamam", func(): close_settings(), true)
	settings_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(settings_ok)

func open_settings() -> void:
	_sync_sliders()
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_NONE
	settings_overlay.visible = true
	settings_ok.grab_focus()

func close_settings() -> void:
	if not settings_overlay.visible:
		return
	settings_overlay.visible = false
	main.save_settings()
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_ALL
	if menu.visible and menu_btns.size() > 3:
		menu_btns[3].grab_focus()

# ---------- beekeeping (meta upgrades)

func _build_hive() -> void:
	hive_panel = Control.new()
	hive_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hive_panel.visible = false
	root.add_child(hive_panel)
	hive_panel.add_child(_dim(0.78))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hive_panel.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	cc.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := _label("ARICILIK", 64, AMBER, true, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var purse := PanelContainer.new()
	var ps := _style(Color(BARK, 0.95), AMBER, 2, 16, 8)
	ps.content_margin_left = 18
	ps.content_margin_right = 24
	purse.add_theme_stylebox_override("panel", ps)
	purse.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(purse)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	purse.add_child(ph)
	ph.add_child(_tex(icons.get(24), 50))
	hive_honey = _label("0", 44, CREAM)
	ph.add_child(hive_honey)
	chip_buy = _style(HONEY, Color(1.0, 0.87, 0.5), 2, 12, 6)
	chip_wait = _style(Color(INK, 0.6), Color(WAX, 0.45), 2, 12, 6)
	chip_full = _style(Color(TEAL, 0.1), Color(TEAL, 0.7), 2, 12, 6)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	for def in main.game.META:
		var b := Button.new()
		b.custom_minimum_size = Vector2(800, 132)
		b.add_theme_stylebox_override("normal", _style(Color(BARK, 0.97), Color(WAX, 0.75), 2, 22, 0))
		b.add_theme_stylebox_override("hover", _style(Color(BARK2, 0.99), AMBER, 3, 22, 0))
		b.add_theme_stylebox_override("focus", _style(Color(BARK2, 0.99), AMBER, 3, 22, 0))
		b.add_theme_stylebox_override("pressed", _style(BARK2.lightened(0.06), CREAM, 3, 22, 0))
		b.add_theme_stylebox_override("disabled", _style(Color(BARK.darkened(0.2), 0.95), Color(WAX, 0.3), 2, 22, 0))
		var id: String = def.id
		b.pressed.connect(func(): _buy(id))
		grid.add_child(b)
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18
		row.offset_right = -22
		row.offset_top = 10
		row.offset_bottom = -10
		row.add_theme_constant_override("separation", 20)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var badge := _badge(106, icons.get(def.icon))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(badge)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.add_theme_constant_override("separation", 3)
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mid)
		mid.add_child(_label(def.name, 30, CREAM))
		mid.add_child(_label(def.desc, 23, MUTED, false))
		var pips := _pips(9.0, false)
		mid.add_child(pips)
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(156, 58)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
		var price := HBoxContainer.new()
		price.add_theme_constant_override("separation", 8)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(price)
		var pc := _tex(icons.get(24), 36)
		price.add_child(pc)
		var cost := _label("", 30, CREAM)
		price.add_child(cost)
		hive_tiles.append({"def": def, "button": b, "pips": pips, "cost": cost, "coin": pc, "chip": chip, "badge": badge, "mid": mid})
	hive_back = _button("Geri", func(): close_hive())
	hive_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(hive_back)

func _refresh_hive() -> void:
	hive_honey.text = fmt_int(main.honey)
	for t in hive_tiles:
		var def: Dictionary = t.def
		var lv := int(main.meta.get(def.id, 0))
		var full: bool = lv >= def.cost.size()
		var can: bool = not full and main.honey >= int(def.cost[lv])
		_set_pips(t.pips, def.cost.size(), lv, 0, TEAL if full else AMBER)
		_set_badge(t.badge, icons.get(def.icon), TEAL if full else AMBER)
		t.coin.visible = not full
		t.coin.modulate.a = 1.0 if can else 0.55
		t.cost.text = "TAM" if full else str(def.cost[lv])
		t.cost.add_theme_color_override("font_color", TEAL if full else (INK if can else Color(0.62, 0.56, 0.5)))
		t.chip.add_theme_stylebox_override("panel", chip_full if full else (chip_buy if can else chip_wait))
		t.badge.modulate.a = 1.0 if (can or full) else 0.6
		t.mid.modulate.a = 1.0 if (can or full) else 0.72
		t.button.disabled = not can

func _buy(id: String) -> void:
	if Time.get_ticks_msec() - hive_opened < 400:
		return
	if main.buy_meta(id):
		main.audio.play("chest", -4.0, 1.2)
		_refresh_hive()

func open_hive() -> void:
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_NONE
	_refresh_hive()
	menu.visible = false
	hive_panel.visible = true
	hive_opened = Time.get_ticks_msec()
	hive_back.grab_focus()

func close_hive() -> void:
	if not hive_panel.visible:
		return
	hive_panel.visible = false
	for b in menu_btns:
		b.focus_mode = Control.FOCUS_ALL
	_menu_texts()
	if main.state == main.MENU:
		menu.visible = true
		hive_btn.grab_focus()

func _menu_texts() -> void:
	hive_btn.text = "Arıcılık  ·  %s bal" % fmt_int(main.honey)

# ---------- main menu

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.06, 0.035, 0.02, 0.26)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(140, -430)
	v.add_theme_constant_override("separation", 14)
	menu.add_child(v)
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -34)
	v.add_child(logo)
	logo.add_child(_label("KOVAN", 164, AMBER, true, true))
	logo.add_child(_label("NÖBETİ", 164, CREAM, true, true))
	menu_record = _label("", 28, CREAM, false, true)
	v.add_child(menu_record)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp)
	var start := _button("Başla", func(): main.start_run(), true)
	start.name = "Basla"
	hive_btn = _button("Arıcılık", func(): open_hive())
	story_btn = _button("Hikaye", func(): open_story(false))
	for b in [start, hive_btn, story_btn, _button("Ayarlar", func(): open_settings()), _button("Çıkış", func(): main.quit_game())]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
		menu_btns.append(b)

func show_menu() -> void:
	close_settings()
	close_hive()
	close_story()
	_menu_texts()
	menu.visible = true
	hud.visible = false
	pause_panel.visible = false
	choice_panel.visible = false
	choosing = false
	end_panel.visible = false
	var r: Dictionary = main.record
	if r.get("runs", 0) > 0:
		var s := "En iyi: Döngü %d · %s · %s böcek" % [int(r.get("best_loop", 1)), fmt_time(r.get("best_time", 0.0)), fmt_int(r.get("best_kills", 0))]
		if r.get("wins", 0) > 0:
			s += " · %d Kraliçe" % int(r.wins)
		menu_record.text = s
	else:
		menu_record.text = "Sonsuz nöbet · Kraliçe her 10 dakikada uyanır"
	(menu.find_child("Basla", true, false) as Button).grab_focus()

# ---------- pause

func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.visible = false
	root.add_child(pause_panel)
	pause_panel.add_child(_dim(0.62))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(BARK, 0.98), WAX, 2, 26, 30))
	cc.add_child(p)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 24)
	p.add_child(outer)
	outer.add_child(_title_with_version("Duraklatıldı", 44))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 48)
	outer.add_child(h)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	h.add_child(left)
	var cont := _button("Devam", func(): main.toggle_pause(), true)
	cont.name = "Devam"
	left.add_child(cont)
	left.add_child(_button("Yeniden başla", func():
		main.leave_run()
		main.start_run()))
	left.add_child(_button("Ana menü", func():
		main.leave_run()
		main.to_menu()))
	left.add_child(_button("Tam ekran (F11)", func(): main.toggle_fullscreen()))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 34)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	_settings_rows(right, false)

func show_pause(on: bool) -> void:
	pause_panel.visible = on
	if on:
		_sync_sliders()
		(pause_panel.find_child("Devam", true, false) as Button).grab_focus()

# ---------- upgrade choice

func _build_choice() -> void:
	choice_panel = Control.new()
	choice_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_panel.visible = false
	root.add_child(choice_panel)
	choice_panel.add_child(_dim(0.55))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_panel.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 30)
	cc.add_child(v)
	choice_title = _label("SEVİYE ATLADIN", 64, AMBER, true, true)
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(choice_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	v.add_child(h)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(390, 598)
		b.add_theme_stylebox_override("normal", _style(Color(BARK, 0.98), Color(WAX, 0.8), 2, 28, 0))
		b.add_theme_stylebox_override("hover", _style(BARK2, CREAM, 3, 28, 0))
		b.add_theme_stylebox_override("focus", _style(BARK2, CREAM, 3, 28, 0))
		b.add_theme_stylebox_override("pressed", _style(BARK2.lightened(0.06), CREAM, 3, 28, 0))
		var idx := i
		b.pressed.connect(func(): _choose(idx))
		h.add_child(b)
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 5
		box.offset_right = -5
		box.offset_top = 5
		box.offset_bottom = -5
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var strip := PanelContainer.new()
		var band := StyleBoxFlat.new()
		band.bg_color = AMBER
		band.corner_detail = 1
		band.anti_aliasing = true
		band.corner_radius_top_left = 24
		band.corner_radius_top_right = 24
		band.content_margin_left = 24
		band.content_margin_right = 14
		band.content_margin_top = 7
		band.content_margin_bottom = 7
		strip.add_theme_stylebox_override("panel", band)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(strip)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(top)
		var kind := _label("", 24, INK)
		kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(kind)
		top.add_child(_keycap(str(i + 1), 22))
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 22)
		pad.add_theme_constant_override("margin_right", 22)
		pad.add_theme_constant_override("margin_top", 16)
		pad.add_theme_constant_override("margin_bottom", 14)
		pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pad)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 8)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.add_child(body)
		var badge := _badge(176, null)
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(badge)
		var nm := _label("", 34, CREAM)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(nm)
		var pips := _pips(8.0, true)
		pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(pips)
		var lv := _label("", 22, AMBER)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(lv)
		var ds := _label("", 24, Color(0.95, 0.89, 0.78), false)
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(ds)
		var line := ColorRect.new()
		line.color = Color(WAX, 0.45)
		line.custom_minimum_size = Vector2(0, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(line)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 10)
		foot.alignment = BoxContainer.ALIGNMENT_CENTER
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(foot)
		var pair := _badge(50, null)
		pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(pair)
		var ev := _label("", 20, MUTED, false)
		ev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ev.custom_minimum_size = Vector2(262, 0)
		ev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(ev)
		cards.append({"button": b, "box": box, "band": band, "kind": kind, "badge": badge, "name": nm, "pips": pips, "level": lv, "desc": ds, "line": line, "foot": foot, "pair": pair, "evo": ev})
	reroll_btn = _button("Yenile", func(): _reroll())
	reroll_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reroll_btn.focus_mode = Control.FOCUS_NONE
	v.add_child(reroll_btn)

func _reroll() -> void:
	if not choosing or choice_lock > 0.0 or main.game.rerolls <= 0 or choice_kind == "evo" or main.paused:
		return
	main.game.rerolls -= 1
	show_choice(choice_kind, main.game.choices(), true)

func show_choice(kind: String, list: Array, again := false) -> void:
	choosing = true
	choice_lock = 0.25 if again else 0.45
	Engine.time_scale = main.debug_speed
	reroll_btn.text = "Yenile (R)  ·  %d" % main.game.rerolls
	reroll_btn.disabled = main.game.rerolls <= 0
	reroll_btn.visible = kind != "evo"
	bot_t = 0.25
	card_data = list
	choice_kind = kind
	choice_title.text = "ŞAMPİYON SANDIĞI" if kind == "evo" else ("SANDIK AÇILDI" if kind == "chest" else "SEVİYE %d" % main.game.level)
	for i in 3:
		var u: Dictionary = list[i]
		var c: Dictionary = cards[i]
		var l: int = main.game.level_of(u.id)
		var twice: bool = kind == "chest" and u.id != "sifa" and l + 1 < u.max
		var tone := AMBER
		c.name.text = u.name
		c.desc.text = u.desc[l] if u.kind == "w" else u.desc
		if u.id == "sifa":
			tone = Color(1.0, 0.58, 0.52)
			c.kind.text = "ŞİFA"
		elif u.kind == "e":
			tone = Color(1.0, 0.92, 0.62)
			c.kind.text = "EVRİM"
		elif u.kind == "w":
			c.kind.text = "YENİ SİLAH" if l == 0 else "SİLAH"
			if twice:
				c.desc.text = "%s\n%s" % [u.desc[l], u.desc[l + 1]]
		else:
			tone = TEAL
			c.kind.text = "ÖZELLİK"
		var levelled: bool = u.id != "sifa" and u.kind != "e"
		c.pips.visible = levelled
		c.level.visible = levelled
		if levelled:
			_set_pips(c.pips, u.max, l, 2 if twice else 1, tone)
			c.level.text = "Seviye %d ve %d" % [l + 1, l + 2] if twice else "Seviye %d" % (l + 1)
			c.level.add_theme_color_override("font_color", tone)
		c.band.bg_color = tone
		_set_badge(c.badge, icons.get(u.icon), tone)
		c.name.add_theme_color_override("font_color", AMBER if u.kind == "e" else CREAM)
		var partner: String = "" if not levelled else main.game.evo_partner(u.id)
		var need_text := ""
		var met := false
		if partner != "" and u.kind == "w":
			var need: Array = main.game.EVO[u.id]
			need_text = "Evrim için 6. seviye ve %s %d" % [main.game.upg(need[0]).name, need[1]]
			met = main.game.evo_ready(u.id)
		elif partner != "" and main.game.level_of(partner) <= main.game.upg(partner).max:
			var need2: Array = main.game.EVO[partner]
			met = l >= int(need2[1])
			need_text = ("%s evrimi için yeterli" % main.game.upg(partner).name) if met else "%s evrimi için %d gerek" % [main.game.upg(partner).name, need2[1]]
		c.line.visible = need_text != ""
		c.foot.visible = need_text != ""
		if need_text != "":
			_set_badge(c.pair, icons.get(main.game.upg(partner).icon), AMBER if met else WAX)
			c.evo.text = need_text
			c.evo.add_theme_color_override("font_color", AMBER if met else MUTED)
	choice_panel.visible = true
	if main.bot_mode:
		_check_cards()
	if again:
		return
	choice_panel.modulate.a = 0.0
	get_tree().paused = true
	main.audio.play("chest" if kind == "chest" else "levelup")
	main.release_mouse()
	var held := get_viewport().gui_get_focus_owner()
	if held != null:
		held.release_focus()

func _check_cards() -> void:
	await get_tree().process_frame
	for i in mini(cards.size(), card_data.size()):
		var need: float = (cards[i].box as Control).get_combined_minimum_size().y + 10.0
		if need > (cards[i].button as Control).size.y + 0.5:
			print("T CARD tall id=%s kind=%s needs=%d has=%d" % [card_data[i].id, choice_kind, int(need), int((cards[i].button as Control).size.y)])

func _choose(i: int) -> void:
	if not choosing or choice_lock > 0.0 or main.paused:
		return
	choosing = false
	main.audio.play("click")
	var picked: Dictionary = card_data[i]
	if picked.kind == "e":
		main.game.evolve(picked.id)
	else:
		main.game.apply(picked.id)
	if choice_kind == "chest" and picked.id != "sifa" and picked.kind != "e" and main.game.level_of(picked.id) < picked.max:
		main.game.apply(picked.id)
	choice_panel.visible = false
	if main.game.queue.is_empty():
		get_tree().paused = false
		main.capture_mouse()
		main.weapons.push_back(main.player.pos, 6.5, 16.0)
		main.player.inv_t = maxf(main.player.inv_t, 0.5)
	else:
		main.game.pop_choice()

# ---------- end screen

func _build_end() -> void:
	end_panel = Control.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.visible = false
	root.add_child(end_panel)
	end_panel.add_child(_dim(0.66))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	cc.add_child(v)
	end_title = _label("", 92, AMBER, true, true)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for k in 2:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(540, 420)
		p.add_theme_stylebox_override("panel", _style(Color(BARK, 0.97), Color(WAX, 0.8), 2, 26, 28))
		h.add_child(p)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		p.add_child(box)
		if k == 0:
			end_stats = box
		else:
			end_damage = box
	end_goal = _label("", 30, AMBER, true, true)
	end_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_goal)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 24)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bh)
	end_again = _button("Bir tur daha (Enter)", func(): main.start_run(), true)
	bh.add_child(end_again)
	end_hive = _button("Arıcılık", func():
		main.to_menu()
		open_hive())
	bh.add_child(end_hive)
	end_menu = _button("Ana menü", func(): main.to_menu())
	bh.add_child(end_menu)
	for eb in [end_again, end_hive, end_menu]:
		eb.focus_mode = Control.FOCUS_NONE

func _stat_row(parent: Container, name: String, value: String, col := CREAM) -> void:
	var row := HBoxContainer.new()
	var a := _label(name, 24, MUTED, false)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(_label(value, 26, col))
	parent.add_child(row)

func show_end(_victory: bool, new_record: bool) -> void:
	var g = main.game
	hud.visible = false
	end_title.text = "KOVAN DÜŞTÜ"
	end_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.36))
	for c in end_stats.get_children():
		c.queue_free()
	for c in end_damage.get_children():
		c.queue_free()
	_stat_row(end_stats, "Ulaşılan döngü", "Döngü %d" % g.loop, AMBER)
	_stat_row(end_stats, "Toplam süre", fmt_time(g.time), AMBER if new_record else CREAM)
	_stat_row(end_stats, "Devrilen Kraliçe", str(g.boss_kills), AMBER if g.boss_kills > 0 else CREAM)
	_stat_row(end_stats, "Öldürülen böcek", fmt_int(g.kills))
	_stat_row(end_stats, "Seviye", str(g.level))
	_stat_row(end_stats, "Verilen hasar", fmt_int(g.stats.dealt))
	_stat_row(end_stats, "Alınan hasar", fmt_int(g.stats.taken))
	_stat_row(end_stats, "Açılan sandık", str(g.stats.chests))
	_stat_row(end_stats, "Uyanan sunak", str(g.stats.shrines))
	_stat_row(end_stats, "Kazanılan bal", "+%d" % main.last_honey, AMBER)
	if new_record:
		_stat_row(end_stats, "Yeni süre rekoru", fmt_time(g.time), AMBER)
	var by: Dictionary = g.stats.by
	var keys: Array = by.keys()
	keys.sort_custom(func(a, b): return by[a] > by[b])
	var top := 1.0
	if not keys.is_empty():
		top = maxf(1.0, by[keys[0]])
	(end_damage.get_parent() as Control).visible = not keys.is_empty()
	for k in keys:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var hh := HBoxContainer.new()
		var nm := _label(g.SRC_NAMES.get(k, k), 24, CREAM, false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(nm)
		hh.add_child(_label(fmt_int(by[k]), 24, AMBER))
		row.add_child(hh)
		var bar := ColorRect.new()
		bar.color = HONEY
		bar.custom_minimum_size = Vector2(maxf(6.0, 480.0 * by[k] / top), 8)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(bar)
		end_damage.add_child(row)
	end_panel.visible = true
	end_lock = 1.2
	end_again.disabled = true
	end_menu.disabled = true
	end_hive.disabled = true
	var goal_name := ""
	var goal_cost := 0
	for def in g.META:
		var mlv := int(main.meta.get(def.id, 0))
		if mlv < def.cost.size() and (goal_name == "" or int(def.cost[mlv]) < goal_cost):
			goal_name = def.name
			goal_cost = int(def.cost[mlv])
	end_hive.text = "Arıcılık  ·  %d bal" % main.honey
	if goal_name == "":
		end_goal.text = "Arıcılık'taki bütün geliştirmeler alındı"
	elif main.honey >= goal_cost:
		end_goal.text = "Balın %s geliştirmesine yetiyor" % goal_name
	else:
		end_goal.text = "%s için %d bal daha" % [goal_name, goal_cost - main.honey]

# ---------- per frame

func _process(dt: float) -> void:
	if choosing:
		choice_lock -= dt
		choice_panel.modulate.a = minf(1.0, choice_panel.modulate.a + dt * 6.0)
		if main.bot_mode and not hold_choice:
			bot_t -= dt
			if bot_t <= 0.0:
				choice_lock = 0.0
				_choose(bot_pick(card_data))
	if end_panel.visible and end_lock > 0.0:
		end_lock -= dt
		if end_lock <= 0.0:
			end_again.disabled = false
			end_menu.disabled = false
			end_hive.disabled = false
	if not get_tree().paused:
		if toast_t > 0.0 and banner_t <= 0.0:
			toast_t -= dt
		if banner_t > 0.0:
			banner_t -= dt
		hint_t -= dt
		if ult_flash > 0.0:
			ult_flash -= dt
		for hm in hurt_marks:
			hm.t -= dt / maxf(0.05, Engine.time_scale / main.debug_speed)
		while not hurt_marks.is_empty() and hurt_marks[0].t <= 0.0:
			hurt_marks.pop_front()
	if hud.visible:
		hud.queue_redraw()

func bot_pick(list: Array) -> int:
	var pick := randi() % 3
	for want in (["w", "e"] if randf() < 0.6 else ["e"]):
		for ci in 3:
			if list[ci].kind == want and list[ci].id != "sifa":
				pick = ci
	return pick

func _input(ev: InputEvent) -> void:
	if end_panel.visible and end_lock <= 0.0 and ev is InputEventKey and ev.pressed and not ev.echo:
		var ek: int = (ev as InputEventKey).physical_keycode
		if ek == KEY_ENTER or ek == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			main.start_run()
			return
	if choosing and not main.paused and ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = (ev as InputEventKey).physical_keycode
		if k == KEY_1 or k == KEY_KP_1:
			_choose(0)
		elif k == KEY_2 or k == KEY_KP_2:
			_choose(1)
		elif k == KEY_3 or k == KEY_KP_3:
			_choose(2)
		elif k == KEY_R:
			_reroll()

func start_hud() -> void:
	close_settings()
	close_story()
	menu.visible = false
	end_panel.visible = false
	pause_panel.visible = false
	choice_panel.visible = false
	choosing = false
	hud.visible = true
	hint_t = 14.0
	toast_t = 0.0
	banner_t = 0.0
	hurt_marks.clear()
	ult_flash = 0.0

func _text(c: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	if size > 80:
		size = (size >> 3) << 3
	elif size > 40:
		size = (size >> 2) << 2
	c.draw_string_outline(font_bold, pos, s, align, width, size, maxi(5, size / 5), Color(INK, col.a))
	c.draw_string(font_bold, pos, s, align, width, size, col)

func _lozenge(r: Rect2, k: float) -> PackedVector2Array:
	var m := r.position.y + r.size.y * 0.5
	return PackedVector2Array([Vector2(r.position.x + k, r.position.y), Vector2(r.end.x - k, r.position.y), Vector2(r.end.x, m),
		Vector2(r.end.x - k, r.end.y), Vector2(r.position.x + k, r.end.y), Vector2(r.position.x, m)])

func _bar(c: CanvasItem, r: Rect2, frac: float, col: Color, bg := Color(0.1, 0.07, 0.05, 0.85)) -> void:
	var k := minf(r.size.y * 0.5, 13.0)
	c.draw_colored_polygon(_lozenge(r.grow(3), k + 3.0), Color(0.03, 0.02, 0.015, 0.88))
	var shape := _lozenge(r, k)
	c.draw_colored_polygon(shape, bg)
	var w := r.size.x * clampf(frac, 0.0, 1.0)
	if w >= r.size.x - 0.5:
		c.draw_colored_polygon(shape, col)
	elif w > 2.0:
		var clip := PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, r.size.y), r.position + Vector2(0, r.size.y)])
		for poly in Geometry2D.intersect_polygons(shape, clip):
			if poly.size() >= 3:
				c.draw_colored_polygon(poly, col)

func _chip(c: CanvasItem, at: Vector2, r: float, s: String, col: Color) -> void:
	c.draw_circle(at, r, INK)
	c.draw_arc(at, r, 0, TAU, 24, col, 2.0, true)
	var size := int(r * 1.5)
	c.draw_string(font_bold, at + Vector2(-r, size * 0.32), s, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, size, col)

func _key(c: CanvasItem, at: Vector2, half: float, s: String, lit: bool, a := 1.0) -> void:
	var r := Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0)
	c.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.45 * a))
	c.draw_rect(r, Color(HONEY if lit else INK, a))
	c.draw_rect(r, Color(CREAM if lit else WAX, a), false, 2.0)
	var size := int(half * 1.45)
	c.draw_string(font_bold, at + Vector2(-half, size * 0.32), s, HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, size, Color(INK if lit else MUTED, a))

func _draw_hud() -> void:
	var g = main.game
	var pl = main.player
	var en = main.enemies
	var W := hud.size.x
	var H := hud.size.y
	var now := Time.get_ticks_msec() * 0.001
	hud.draw_rect(Rect2(0, 0, W, 15), Color(0.05, 0.035, 0.025, 0.88))
	hud.draw_rect(Rect2(0, 0, W * clampf(float(g.xp) / float(g.xp_need), 0.0, 1.0), 12), AMBER)
	var lc := Vector2(70, 74)
	_draw_hex(hud, lc + Vector2(0, 4), 44.0, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	_draw_hex(hud, lc, 44.0, Color(BARK, 0.94), AMBER, 3.0)
	_text(hud, Vector2(lc.x - 44, lc.y + 13), str(g.level), 38, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 88)
	if icons.get(28) != null:
		hud.draw_texture_rect(icons[28], Rect2(128, 52, 44, 44), false)
	_text(hud, Vector2(180, 86), fmt_int(g.kills), 30, CREAM)
	var b: int = en.boss_index()
	var ch: int = en.champ_index()
	if b >= 0:
		_text(hud, Vector2(W * 0.5 - 320, 62), "KRALİÇE · DÖNGÜ %d" % g.loop, 36, Color(1.0, 0.38, 0.32), HORIZONTAL_ALIGNMENT_CENTER, 640)
		_bar(hud, Rect2(W * 0.5 - 360, 78, 720, 24), en.hp[b] / en.maxhp[b], Color(0.9, 0.16, 0.2))
		_text(hud, Vector2(W * 0.5 - 160, 134), fmt_time(g.time), 26, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 320)
	else:
		var left: float = g.CYCLE_TIME - g.loop_time
		var col := CREAM if left > 30.0 else Color(1.0, 0.45, 0.35)
		var total_secs := int(floor(g.time))
		@warning_ignore("integer_division")
		_text(hud, Vector2(W * 0.5 - 212, 76), "%02d" % (total_secs / 60), 56, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
		_text(hud, Vector2(W * 0.5 - 12, 72), ":", 56, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 24)
		_text(hud, Vector2(W * 0.5 + 12, 76), "%02d" % (total_secs % 60), 56, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 200)
		_text(hud, Vector2(W * 0.5 - 260, 108), "DÖNGÜ %d  ·  Kraliçe %s" % [g.loop, fmt_time(ceil(maxf(0.0, left)))], 22, AMBER if left > 30.0 else col, HORIZONTAL_ALIGNMENT_CENTER, 520)
		if ch >= 0:
			_text(hud, Vector2(W * 0.5 - 300, 146), g.CHAMP_NAMES[en.typ[ch] - en.T_STAG], 26, Color(1.0, 0.62, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 600)
			_bar(hud, Rect2(W * 0.5 - 260, 158, 520, 18), en.hp[ch] / en.maxhp[ch], Color(0.95, 0.46, 0.15))
	var hw := 460.0
	var hr := Rect2(W * 0.5 - hw * 0.5, H - 78, hw, 30)
	var hp_frac: float = pl.hp / pl.max_hp
	_bar(hud, hr, hp_frac, Color(0.36, 0.82, 0.3) if hp_frac > 0.3 else Color(0.95, 0.27, 0.2))
	_text(hud, Vector2(hr.position.x, hr.position.y + 23), "%d / %d" % [int(ceil(pl.hp)), int(pl.max_hp)], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, hw)
	var sl := 1.0 - clampf(pl.slide_cd / pl.slide_cd_max(), 0.0, 1.0)
	_bar(hud, Rect2(W * 0.5 - hw * 0.5 + 20, H - 36, hw - 40, 8), sl, TEAL if sl >= 1.0 else Color(0.2, 0.5, 0.55))
	var uc := Vector2(W * 0.5 + hw * 0.5 + 78, H - 62)
	var ur := 46.0
	var ready: bool = g.ult >= 1.0
	var beat := 0.5 + 0.5 * sin(now * 8.0)
	_draw_hex(hud, uc + Vector2(0, 4), ur, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	_draw_hex(hud, uc, ur, Color(BARK, 0.94), Color(0, 0, 0, 0))
	if g.ult > 0.02:
		var top := uc.y + ur - 2.0 * ur * clampf(g.ult, 0.0, 1.0)
		var pool := PackedVector2Array([Vector2(uc.x - ur, top), Vector2(uc.x + ur, top), Vector2(uc.x + ur, uc.y + ur), Vector2(uc.x - ur, uc.y + ur)])
		for poly in Geometry2D.intersect_polygons(_hex_pts(uc, ur), pool):
			if poly.size() >= 3:
				hud.draw_colored_polygon(poly, Color(1.0, 0.72, 0.14, 0.6 + (0.3 * beat if ready else 0.0)))
	if icons.get(22) != null:
		hud.draw_texture_rect(icons[22], Rect2(uc - Vector2(33, 33), Vector2(66, 66)), false, Color(1, 1, 1, 1.0 if ready else 0.5))
	_draw_hex(hud, uc, ur, Color(0, 0, 0, 0), CREAM if ready else WAX, 3.0 + (2.0 * beat if ready else 0.0))
	if ready:
		var wave := fmod(now, 1.3) / 1.3
		_draw_hex(hud, uc, ur + 30.0 * wave, Color(0, 0, 0, 0), Color(1.0, 0.86, 0.45, 0.8 * (1.0 - wave)), 3.0)
	_key(hud, uc + Vector2(38, 34), 17.0 + (2.0 * beat if ready else 0.0), "Q", ready)
	if ult_flash > 0.0 and ready:
		var fa := clampf(ult_flash, 0.0, 1.0) * clampf((6.0 - ult_flash) * 5.0, 0.0, 1.0)
		var fr := Rect2(W * 0.5 - 215, H - 190, 430, 58)
		hud.draw_colored_polygon(_lozenge(fr.grow(3), 32.0), Color(HONEY, 0.9 * fa))
		hud.draw_colored_polygon(_lozenge(fr, 29.0), Color(INK, 0.92 * fa))
		_key(hud, Vector2(fr.position.x + 62, fr.position.y + 29), 19.0, "Q", true, fa)
		hud.draw_string(font_bold, Vector2(fr.position.x + 96, fr.position.y + 39), "Kovan Çağrısı hazır", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(CREAM, fa))
	var x := 66.0
	for id in main.weapons.IDS:
		var l: int = main.weapons.levels[id]
		if l <= 0:
			continue
		var u: Dictionary = g.upg(id)
		var tone := CREAM if l >= 7 else AMBER
		_draw_badge(hud, Vector2(x, H - 66), 42.0, icons.get(u.icon), tone)
		_chip(hud, Vector2(x + 29, H - 36), 15.0, str(l), tone)
		x += 92.0
	var pi := 0
	for id in g.passives:
		var u2: Dictionary = g.upg(id)
		@warning_ignore("integer_division")
		var prow := pi / 6
		var pcol := pi % 6
		var px := 52.0 + float(pcol) * 60.0
		var py := H - 150.0 - float(prow) * 60.0
		_draw_badge(hud, Vector2(px, py), 26.0, icons.get(u2.icon), TEAL)
		_chip(hud, Vector2(px + 18, py + 19), 11.0, str(g.passives[id]), TEAL)
		pi += 1
	_draw_minimap(W)
	var hyaw: float = pl.cam_yaw
	for hm in hurt_marks:
		var hr2 := Vector2(hm.x - pl.pos.x, hm.z - pl.pos.z)
		if hr2.length() < 0.4 or hm.t <= 0.0:
			continue
		var hang := atan2(hr2.x * sin(hyaw) + hr2.y * cos(hyaw), hr2.x * cos(hyaw) - hr2.y * sin(hyaw))
		var hal := clampf(float(hm.t) * 1.6, 0.0, 1.0)
		hud.draw_arc(Vector2(W * 0.5, H * 0.5), H * 0.34, hang - 0.42, hang + 0.42, 18, Color(1.0, 0.12, 0.1, 0.8 * hal), 20.0)
		hud.draw_arc(Vector2(W * 0.5, H * 0.5), H * 0.34 + 14.0, hang - 0.3, hang + 0.3, 14, Color(1.0, 0.55, 0.4, 0.9 * hal), 5.0)
	if main.world.shrine_progress >= 0.0:
		_text(hud, Vector2(W * 0.5 - 200, H * 0.70), "Sunak uyanıyor", 26, TEAL, HORIZONTAL_ALIGNMENT_CENTER, 400)
		_bar(hud, Rect2(W * 0.5 - 170, H * 0.70 + 12, 340, 14), main.world.shrine_progress, TEAL)
	if banner_t > 0.0 and not choosing:
		var ba := clampf(banner_t * 1.5, 0.0, 1.0) * clampf((3.0 - banner_t) * 6.0, 0.0, 1.0)
		var grow := 1.0 + maxf(0.0, banner_t - 2.7) * 2.0
		hud.draw_rect(Rect2(0, H * 0.3 - 86, W, 150), Color(0.05, 0.03, 0.02, 0.55 * ba))
		_text(hud, Vector2(W * 0.5 - 800, H * 0.3), banner_title, int(92 * grow), Color(1.0, 0.42, 0.25, ba), HORIZONTAL_ALIGNMENT_CENTER, 1600)
		_text(hud, Vector2(W * 0.5 - 600, H * 0.3 + 46), banner_sub, 30, Color(1.0, 0.9, 0.7, ba), HORIZONTAL_ALIGNMENT_CENTER, 1200)
	elif toast_t > 0.0 and not choosing:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var pop := 1.0 + maxf(0.0, toast_t - 2.4) * 1.5
		_text(hud, Vector2(W * 0.5 - 600, H * 0.27), toast_text, int(46 * pop), Color(1.0, 0.9, 0.5, a), HORIZONTAL_ALIGNMENT_CENTER, 1200)
	if hint_t > 0.0:
		var ha := clampf(hint_t, 0.0, 1.0)
		_text(hud, Vector2(W * 0.5 - 700, H - 122), "WASD koş     Boşluk zıpla     Shift kay     Q dolunca Kovan Çağrısı", 26, Color(1, 1, 1, ha), HORIZONTAL_ALIGNMENT_CENTER, 1400)

func _draw_minimap(W: float) -> void:
	var c := Vector2(W - 128, 138)
	var R := 100.0
	var sc := R / 42.0
	var pl = main.player
	var yaw: float = pl.cam_yaw
	var ax := Vector2(cos(yaw), -sin(yaw)) * sc
	var ay := Vector2(sin(yaw), cos(yaw)) * sc
	var o := Vector2(pl.pos.x, pl.pos.z)
	hud.draw_circle(c, R + 6, Color(0.07, 0.05, 0.035, 0.66))
	hud.draw_arc(c, R + 4, 0, TAU, 56, Color(WAX, 0.95), 3.0, true)
	var ar: float = main.world.ARENA_R
	var prev := Vector2.ZERO
	for k in 73:
		var wa := TAU * k / 72.0
		var wr := Vector2(cos(wa) * ar, sin(wa) * ar) - o
		var wp := Vector2(wr.dot(ax), wr.dot(ay))
		if k > 0 and wp.length() < R and prev.length() < R:
			hud.draw_line(c + prev, c + wp, Color(1.0, 0.85, 0.6, 0.7), 3.0)
		prev = wp
	var gh: Vector3 = main.world.GREAT
	var gr := Vector2(gh.x, gh.y) - o
	var gp := Vector2(gr.dot(ax), gr.dot(ay))
	if gp.length() < R - gh.z * sc:
		hud.draw_circle(c + gp, gh.z * sc, Color(0.62, 0.4, 0.2, 0.9))
	else:
		hud.draw_circle(c + gp.limit_length(R - 5.0), 5.0, Color(0.62, 0.4, 0.2, 0.9))
	for s in main.world.shrines:
		if not s.done:
			var sr := Vector2(s.pos.x, s.pos.z) - o
			var p: Vector2 = c + Vector2(sr.dot(ax), sr.dot(ay)).limit_length(R - 5.0)
			hud.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)]), TEAL)
	for ch in main.world.chests:
		var cr := Vector2(ch.pos.x, ch.pos.z) - o
		var p2: Vector2 = c + Vector2(cr.dot(ax), cr.dot(ay)).limit_length(R - 5.0)
		hud.draw_rect(Rect2(p2 - Vector2(5, 5), Vector2(10, 10)), AMBER)
	for j in main.world.jars:
		var jr := Vector2(j.pos.x, j.pos.z) - o
		var jp := Vector2(jr.dot(ax), jr.dot(ay))
		if jp.length() < R:
			hud.draw_circle(c + jp, 3.5, Color(1.0, 0.45, 0.5))
	for it in main.pickups.items:
		var ir := Vector2(it.pos.x, it.pos.z) - o
		hud.draw_circle(c + Vector2(ir.dot(ax), ir.dot(ay)).limit_length(R - 5.0), 5.0, AMBER if it.kind == "chest" else (Color(1.0, 0.45, 0.5) if it.kind == "heal" else Color(0.3, 0.8, 1.0)))
	var en = main.enemies
	var dot := Color(1.0, 0.32, 0.25, 0.9)
	for i in en.count:
		if en.dead[i] == 1:
			continue
		var er := Vector2(en.px[i], en.pz[i]) - o
		var ep := Vector2(er.dot(ax), er.dot(ay))
		if en.elite[i] == 1 or en.typ[i] == en.T_BOSS or en.typ[i] >= en.T_STAG:
			hud.draw_circle(c + ep.limit_length(R - 5.0), 5.0 if en.elite[i] == 1 else 8.0, Color(1.0, 0.2, 0.2))
		elif ep.length_squared() < R * R:
			hud.draw_rect(Rect2(c + ep - Vector2(1.5, 1.5), Vector2(3, 3)), dot)
	hud.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(6.5, 6), c + Vector2(-6.5, 6)]), Color.WHITE)
