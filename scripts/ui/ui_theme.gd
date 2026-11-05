extends RefCounted
## DeepMine UI theme builder (pixel-art 9-slice StyleBoxTextures + bitmap fonts).
##   const UiTheme = preload("res://scripts/ui/ui_theme.gd")
##   control.theme = UiTheme.get_theme()      # cached: loads assets/ui/theme.tres or builds it
## Type variations: ButtonGreen, ButtonGold, ButtonRed, ButtonDark, TabActive, TabButton, SlotButton,
## PanelDark, PanelPurple, HudBox, LabelTitle, LabelHeader, LabelSmall, LabelGold, LabelDim,
## ProgressRed, ProgressGreen, ProgressGold, ProgressOrange, ProgressPurple, IconButton.

const UI := "res://assets/ui/"
const FONT_PATH := "res://assets/fonts/pixel.fnt"
const FONT_BIG_PATH := "res://assets/fonts/pixel_big.fnt"
const THEME_PATH := "res://assets/ui/theme.tres"

const COL_TEXT := Color("eef2ff")
const COL_DIM := Color("8a93a8")
const COL_SOFT := Color("c3cad8")
const COL_GOLD := Color("ffc93c")
const COL_SHADOW := Color(0.04, 0.05, 0.09, 0.9)
const COL_NAVY := Color("0b1026")

static var _cached: Theme = null

static func get_theme() -> Theme:
	if _cached:
		return _cached
	if ResourceLoader.exists(THEME_PATH):
		var t: Theme = load(THEME_PATH)
		if t:
			_fix_fonts(t)
			_cached = t
			return t
	_cached = build()
	return _cached

static func font() -> Font:
	return _load_font(FONT_PATH)

static func font_big() -> Font:
	return _load_font(FONT_BIG_PATH)

static func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f: Font = load(path)
		if f is FontFile:
			(f as FontFile).fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
		return f
	return ThemeDB.fallback_font

static func _fix_fonts(t: Theme) -> void:
	for f in [t.default_font]:
		if f is FontFile:
			(f as FontFile).fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	var big := font_big()
	if big is FontFile:
		(big as FontFile).fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY

static func _tex(file: String) -> Texture2D:
	var p := UI + file
	if ResourceLoader.exists(p):
		return load(p)
	return null

## StyleBoxTexture with 9-slice margins (left, top, right, bottom) and optional content margins.
static func sb(file: String, l: int, t: int, r: int, b: int, cl: int = -1, ct: int = -1, cr: int = -1, cb: int = -1) -> StyleBox:
	var tex := _tex(file)
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("141a3a")
		flat.border_color = Color("5a6378")
		flat.set_border_width_all(2)
		flat.set_content_margin_all(maxi(cl, 4))
		return flat
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = l
	s.texture_margin_top = t
	s.texture_margin_right = r
	s.texture_margin_bottom = b
	s.content_margin_left = cl if cl >= 0 else l
	s.content_margin_top = ct if ct >= 0 else t
	s.content_margin_right = cr if cr >= 0 else r
	s.content_margin_bottom = cb if cb >= 0 else b
	return s

static func _dim(s: StyleBox, mul: float = 0.6) -> StyleBox:
	var d: StyleBox = s.duplicate()
	if d is StyleBoxTexture:
		(d as StyleBoxTexture).modulate_color = Color(mul, mul, mul, 1)
	return d

static func _button_styles(t: Theme, type: String, color: String, has_disabled: bool) -> void:
	var n := sb("button_%s_normal.png" % color, 8, 8, 8, 10, 8, 4, 8, 6)
	var h := sb("button_%s_hover.png" % color, 8, 8, 8, 10, 8, 4, 8, 6)
	var p := sb("button_%s_pressed.png" % color, 8, 8, 8, 10, 8, 5, 8, 5)
	var d := sb("button_%s_disabled.png" % color, 8, 8, 8, 10, 8, 4, 8, 6) if has_disabled else _dim(n, 0.55)
	t.set_stylebox("normal", type, n)
	t.set_stylebox("hover", type, h)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, d)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, Color("f4f7ff"))
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, Color("e8ecff"))
	t.set_color("font_hover_pressed_color", type, Color.WHITE)
	t.set_color("font_focus_color", type, Color("f4f7ff"))
	t.set_color("font_disabled_color", type, Color("9aa3b8"))

static func _img_tex(w: int, h: int, rows: Array, palette: Dictionary) -> ImageTexture:
	## Tiny hand-authored pixel icons for theme widgets (checkbox, slider knob...).
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(h, rows.size()):
		var row: String = rows[y]
		for x in mini(w, row.length()):
			var ch := row[x]
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)

static func build() -> Theme:
	var t := Theme.new()
	var f := font()
	var fb := font_big()
	t.default_font = f
	t.default_font_size = 10

	# ---------------------------------------------------------------- labels
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("font_shadow_color", "Label", COL_SHADOW)
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 1)
	for v in [["LabelTitle", COL_GOLD, true], ["LabelHeader", COL_TEXT, true], ["LabelSmall", COL_SOFT, false], ["LabelGold", COL_GOLD, false], ["LabelDim", COL_DIM, false]]:
		t.set_type_variation(v[0], "Label")
		t.set_color("font_color", v[0], v[1])
		if v[2]:
			t.set_font("font", v[0], fb)
			t.set_font_size("font_size", v[0], 16)

	t.set_color("default_color", "RichTextLabel", COL_TEXT)
	t.set_color("font_shadow_color", "RichTextLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "RichTextLabel", 1)
	t.set_constant("shadow_offset_y", "RichTextLabel", 1)
	t.set_constant("line_separation", "RichTextLabel", 1)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# ---------------------------------------------------------------- panels
	var panel := sb("panel.png", 12, 12, 12, 12, 10, 10, 10, 10)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	for v in [["PanelDark", "panel_dark.png", 6, 6], ["PanelPurple", "panel_purple.png", 12, 10], ["HudBox", "hud_box.png", 8, 4]]:
		t.set_type_variation(v[0], "PanelContainer")
		t.set_stylebox("panel", v[0], sb(v[1], v[2], v[2], v[2], v[2], v[3] + (2 if v[0] == "HudBox" else 0), v[3], v[3] + (2 if v[0] == "HudBox" else 0), v[3]))
	t.set_type_variation("PanelTitle", "PanelContainer")
	t.set_stylebox("panel", "PanelTitle", sb("panel_title.png", 10, 6, 10, 6, 10, 2, 10, 3))

	# ---------------------------------------------------------------- buttons
	_button_styles(t, "Button", "blue", true)
	for v in [["ButtonGreen", "green", true], ["ButtonGold", "gold", true], ["ButtonRed", "red", false], ["ButtonDark", "dark", false]]:
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1], v[2])
	t.set_color("font_color", "ButtonGold", Color("3a2400"))
	t.set_color("font_hover_color", "ButtonGold", Color("2a1800"))
	t.set_color("font_pressed_color", "ButtonGold", Color("2a1800"))
	t.set_color("font_hover_pressed_color", "ButtonGold", Color("2a1800"))
	t.set_color("font_focus_color", "ButtonGold", Color("3a2400"))
	t.set_color("font_disabled_color", "ButtonGold", Color("6b5a3a"))

	var tab := sb("tab_active.png", 8, 8, 8, 4, 8, 4, 8, 4)
	t.set_type_variation("TabActive", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "TabActive", tab)
	t.set_stylebox("focus", "TabActive", StyleBoxEmpty.new())
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", sb("button_dark_normal.png", 8, 8, 8, 10, 8, 4, 8, 5))
	t.set_stylebox("hover", "TabButton", sb("button_dark_hover.png", 8, 8, 8, 10, 8, 4, 8, 5))
	t.set_stylebox("pressed", "TabButton", tab)
	t.set_stylebox("hover_pressed", "TabButton", tab)
	t.set_stylebox("disabled", "TabButton", _dim(sb("button_dark_normal.png", 8, 8, 8, 10, 8, 4, 8, 5)))
	t.set_stylebox("focus", "TabButton", StyleBoxEmpty.new())
	t.set_color("font_color", "TabButton", COL_SOFT)
	t.set_color("font_hover_color", "TabButton", COL_TEXT)
	t.set_color("font_pressed_color", "TabButton", Color.WHITE)
	t.set_color("font_hover_pressed_color", "TabButton", Color.WHITE)
	t.set_color("font_focus_color", "TabButton", COL_SOFT)

	# Inventory slots (toggle buttons)
	t.set_type_variation("SlotButton", "Button")
	t.set_stylebox("normal", "SlotButton", sb("slot.png", 6, 6, 6, 6, 2, 2, 2, 2))
	t.set_stylebox("hover", "SlotButton", sb("slot_hover.png", 6, 6, 6, 6, 2, 2, 2, 2))
	t.set_stylebox("pressed", "SlotButton", sb("slot_selected.png", 6, 6, 6, 6, 2, 2, 2, 2))
	t.set_stylebox("hover_pressed", "SlotButton", sb("slot_selected.png", 6, 6, 6, 6, 2, 2, 2, 2))
	t.set_stylebox("disabled", "SlotButton", _dim(sb("slot.png", 6, 6, 6, 6, 2, 2, 2, 2), 0.7))
	t.set_stylebox("focus", "SlotButton", StyleBoxEmpty.new())

	# Flat icon buttons (HUD)
	t.set_type_variation("IconButton", "Button")
	t.set_stylebox("normal", "IconButton", sb("hud_box.png", 8, 8, 8, 8, 3, 3, 3, 3))
	t.set_stylebox("hover", "IconButton", sb("slot_hover.png", 6, 6, 6, 6, 3, 3, 3, 3))
	t.set_stylebox("pressed", "IconButton", sb("slot_selected.png", 6, 6, 6, 6, 3, 3, 3, 3))
	t.set_stylebox("hover_pressed", "IconButton", sb("slot_selected.png", 6, 6, 6, 6, 3, 3, 3, 3))
	t.set_stylebox("focus", "IconButton", StyleBoxEmpty.new())
	t.set_color("font_color", "IconButton", COL_TEXT)

	# ---------------------------------------------------------------- progress bars
	t.set_stylebox("background", "ProgressBar", sb("bar_bg.png", 5, 4, 5, 4, 0, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", sb("bar_fill_blue.png", 5, 4, 5, 4, 0, 0, 0, 0))
	t.set_color("font_color", "ProgressBar", COL_TEXT)
	t.set_color("font_outline_color", "ProgressBar", COL_NAVY)
	for v in [["ProgressRed", "red"], ["ProgressGreen", "green"], ["ProgressGold", "gold"], ["ProgressOrange", "orange"], ["ProgressPurple", "purple"]]:
		t.set_type_variation(v[0], "ProgressBar")
		t.set_stylebox("fill", v[0], sb("bar_fill_%s.png" % v[1], 5, 4, 5, 4, 0, 0, 0, 0))

	# ---------------------------------------------------------------- tooltip
	t.set_stylebox("panel", "TooltipPanel", sb("tooltip.png", 6, 6, 6, 6, 5, 4, 5, 4))
	t.set_color("font_color", "TooltipLabel", COL_TEXT)
	t.set_color("font_shadow_color", "TooltipLabel", COL_SHADOW)
	t.set_constant("shadow_offset_x", "TooltipLabel", 1)
	t.set_constant("shadow_offset_y", "TooltipLabel", 1)

	# ---------------------------------------------------------------- scrollbars
	var track := StyleBoxFlat.new()
	track.bg_color = Color("0e1430")
	track.border_color = Color("2a3466")
	track.set_border_width_all(1)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color("5a6378")
	grab.border_color = Color("8a93a8")
	grab.border_width_top = 1
	grab.border_width_left = 1
	var grab_h: StyleBoxFlat = grab.duplicate()
	grab_h.bg_color = Color("8a93a8")
	var grab_p: StyleBoxFlat = grab.duplicate()
	grab_p.bg_color = Color("4aa3ff")
	var empty := _img_tex(1, 1, [], {})
	for sbt in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sbt, track)
		t.set_stylebox("scroll_focus", sbt, track)
		t.set_stylebox("grabber", sbt, grab)
		t.set_stylebox("grabber_highlight", sbt, grab_h)
		t.set_stylebox("grabber_pressed", sbt, grab_p)
		for ic in ["increment", "increment_highlight", "increment_pressed", "decrement", "decrement_highlight", "decrement_pressed"]:
			t.set_icon(ic, sbt, empty)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())

	# ---------------------------------------------------------------- separators
	var line := StyleBoxLine.new()
	line.color = Color("3c4458")
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = Color("3c4458")
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox("separator", "VSeparator", vline)

	# ---------------------------------------------------------------- sliders
	var knob_pal := {"o": Color("0b0d18"), "w": Color("f4f7ff"), "l": Color("c3cad8"), "b": Color("4aa3ff"), "d": Color("2f5fb8")}
	var knob := _img_tex(8, 12, ["oooooo", "owwwwlo", "owbbbdo", "owbbbdo", "owbbbdo", "owbbbdo", "owbbbdo", "owbbbdo", "olddddo", "oooooo"], knob_pal)
	var knob_h := _img_tex(8, 12, ["oooooo", "owwwwwo", "owwbbwo", "owbbbwo", "owbbbwo", "owbbbwo", "owbbbwo", "owbbbwo", "owwwwwo", "oooooo"], knob_pal)
	t.set_stylebox("slider", "HSlider", sb("bar_bg.png", 5, 4, 5, 4, 0, 4, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", sb("bar_fill_blue.png", 5, 4, 5, 4, 0, 4, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb("bar_fill_blue.png", 5, 4, 5, 4, 0, 4, 0, 4))
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob_h)
	t.set_icon("grabber_disabled", "HSlider", knob)

	# ---------------------------------------------------------------- checkboxes
	var cb_pal := {"o": Color("0b0d18"), "f": Color("141a3a"), "e": Color("5a6378"), "g": Color("5fdc6a"), "G": Color("2f9a3c"), "w": Color("e8ffe8")}
	var unchecked := _img_tex(12, 12, ["eeeeeeeeeeee", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "efffffffffoe", "eoooooooooo e".replace(" ", ""), "eeeeeeeeeeee"], cb_pal)
	var checked := _img_tex(12, 12, ["eeeeeeeeeeee", "efffffffffoe", "effffffffgoe", "efffffffggoe", "efffffffgGoe", "egffffffgGoe", "eggffffggGoe", "efggffggGfoe", "effggggGffoe", "efffgGGfffoe", "eoooooooooo e".replace(" ", ""), "eeeeeeeeeeee"], cb_pal)
	for ct in ["CheckBox", "CheckButton"]:
		t.set_icon("checked", ct, checked)
		t.set_icon("unchecked", ct, unchecked)
		t.set_icon("checked_disabled", ct, checked)
		t.set_icon("unchecked_disabled", ct, unchecked)
		t.set_stylebox("normal", ct, StyleBoxEmpty.new())
		t.set_stylebox("hover", ct, StyleBoxEmpty.new())
		t.set_stylebox("pressed", ct, StyleBoxEmpty.new())
		t.set_stylebox("hover_pressed", ct, StyleBoxEmpty.new())
		t.set_stylebox("focus", ct, StyleBoxEmpty.new())
		t.set_color("font_color", ct, COL_TEXT)
		t.set_color("font_hover_color", ct, Color.WHITE)
		t.set_color("font_pressed_color", ct, COL_TEXT)
		t.set_color("font_hover_pressed_color", ct, Color.WHITE)
		t.set_constant("h_separation", ct, 4)
	var on_pal := {"o": Color("0b0d18"), "g": Color("5fdc6a"), "d": Color("1e2650"), "w": Color("f4f7ff"), "e": Color("5a6378")}
	var sw_on := _img_tex(20, 12, ["oooooooooooooooooooo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oggggggggggggwwwwwwo", "oooooooooooooooooooo"], on_pal)
	var sw_off := _img_tex(20, 12, ["oooooooooooooooooooo", "oeeeeeedddddddddddo".insert(18, "d"), "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oeeeeeeddddddddddddo", "oooooooooooooooooooo"], on_pal)
	t.set_icon("checked", "CheckButton", sw_on)
	t.set_icon("unchecked", "CheckButton", sw_off)
	t.set_icon("checked_disabled", "CheckButton", sw_on)
	t.set_icon("unchecked_disabled", "CheckButton", sw_off)

	# ---------------------------------------------------------------- option button / popups / line edit
	_button_styles(t, "OptionButton", "dark", false)
	var arrow := _img_tex(8, 6, ["wwwwwww", " wwwww", "  www", "   w"], {"w": Color("c3cad8")})
	t.set_icon("arrow", "OptionButton", arrow)
	t.set_constant("arrow_margin", "OptionButton", 4)
	t.set_stylebox("panel", "PopupMenu", sb("panel_dark.png", 6, 6, 6, 6, 4, 4, 4, 4))
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color("2f5fb8")
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_color("font_color", "PopupMenu", COL_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("panel", "PopupPanel", sb("panel_dark.png", 6, 6, 6, 6, 4, 4, 4, 4))
	t.set_stylebox("normal", "LineEdit", sb("panel_dark.png", 6, 6, 6, 6, 5, 3, 5, 3))
	t.set_stylebox("focus", "LineEdit", sb("slot_selected.png", 6, 6, 6, 6, 5, 3, 5, 3))
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("caret_color", "LineEdit", COL_GOLD)

	# ---------------------------------------------------------------- containers spacing
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("h_separation", "GridContainer", 2)
	t.set_constant("v_separation", "GridContainer", 2)
	return t
