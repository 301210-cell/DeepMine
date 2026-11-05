extends RefCounted
## Small factory helpers for building DeepMine UI in code with the pixel theme.
##   const Kit = preload("res://scripts/ui/ui_kit.gd")

const UI := "res://assets/ui/"

static func label(text: String = "", variation: String = "", color: Variant = null) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if color != null:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap_label(text: String, width: float, variation: String = "") -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l

static func rich(text: String = "", width: float = 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		r.custom_minimum_size.x = width
	r.text = text
	return r

static func sfx(b: BaseButton, click: String = "ui_click") -> void:
	b.mouse_entered.connect(func():
		if not b.disabled:
			AudioManager.play("ui_hover", -10.0, 0.04, 0.05))
	b.pressed.connect(func(): AudioManager.play(click, -3.0))

static func button(text: String, variation: String = "", cb: Callable = Callable(), min_w: float = 0.0, click: String = "ui_click") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = min_w
	sfx(b, click)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func icon(tex: Texture2D, scale: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := Vector2(16, 16)
	if tex:
		sz = tex.get_size()
	t.custom_minimum_size = sz * scale
	return t

static func ui_icon(i: int, scale: float = 1.0) -> TextureRect:
	return icon(ResourceDatabase.ui_icon(i), scale)

static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

static func hbox(sep: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h

static func vbox(sep: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v

static func margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m

static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func close_button(cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = ResourceDatabase.tex(UI + "close_normal.png")
	b.texture_hover = ResourceDatabase.tex(UI + "close_hover.png")
	b.texture_pressed = ResourceDatabase.tex(UI + "close_pressed.png")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Close (Esc)"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx(b, "ui_close")
	b.pressed.connect(cb)
	return b

static func progress(variation: String = "", w: float = 80.0, h: float = 10.0) -> ProgressBar:
	var p := ProgressBar.new()
	if variation != "":
		p.theme_type_variation = variation
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h)
	p.max_value = 1.0
	p.step = 0.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Bar with centred text on top ("120 / 500 XP").
static func text_bar(variation: String, w: float, h: float) -> Array:
	var bar := progress(variation, w, h)
	var l := label("", "")
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.position.y = -1
	bar.add_child(l)
	return [bar, l]

static func title_ribbon(text: String) -> Array:
	var rib := panel("PanelTitle")
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, "LabelTitle")
	rib.add_child(l)
	return [rib, l]

## Standard window: PanelContainer centred in `parent` (full-rect Control).
## Returns {"window", "body", "header", "title", "extra"} where body is a VBoxContainer.
static func window(parent: Control, title: String, size: Vector2, on_close: Callable) -> Dictionary:
	var win := panel()
	win.name = "Window"
	win.custom_minimum_size = size
	win.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(win)
	win.size = size
	win.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	var body := vbox(5)
	win.add_child(body)
	var header := hbox(4)
	body.add_child(header)
	var rib: Array = title_ribbon(title)
	rib[0].custom_minimum_size.x = 120
	header.add_child(rib[0])
	header.add_child(spacer())
	var extra := hbox(6)
	extra.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(extra)
	if on_close.is_valid():
		header.add_child(close_button(on_close))
	return {"window": win, "body": body, "header": header, "title": rib[1], "extra": extra}

static func coin_label(amount: int, variation: String = "LabelGold") -> HBoxContainer:
	var h := hbox(2)
	h.add_child(ui_icon(0))
	var l := label(ResourceDatabase.fmt_num(amount), variation)
	l.name = "Amount"
	h.add_child(l)
	return h

static func fmt_price(n: int) -> String:
	return "$" + ResourceDatabase.fmt_num(n)

static func keycap(text: String) -> Control:
	var t := TextureRect.new()
	t.texture = ResourceDatabase.tex(UI + "keycap.png")
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := maxf(16.0, 8.0 + text.length() * 5.0)
	t.custom_minimum_size = Vector2(w, 16)
	var l := label(text)
	l.add_theme_color_override("font_color", Color("1e2650"))
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.0))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position.y = -1
	t.add_child(l)
	return t

## Replaces "[E]" style key hints in plain text with gold BBCode for RichTextLabels.
static func key_bbcode(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[([^\\]]{1,14})\\]")
	return re.sub(text, "[color=#ffc93c]$1[/color]", true)

static func rarity_bb(id: String) -> String:
	return "[color=#%s]%s[/color]" % [ResourceDatabase.rarity_color(ResourceDatabase.item_rarity(id)).to_html(false), ResourceDatabase.item_name(id)]

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
