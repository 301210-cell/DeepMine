extends Control
## Settings: audio volumes, display, key rebinding, tutorial and save management.
## Works in-game (inside UIRoot) and from the main menu. open(data): data == "from_pause"
## makes Back return to the pause menu.

signal close_requested
signal save_reset

const TABS := ["Audio", "Display", "Controls", "Game"]
const FIXED_BINDS := [["Mine", "Left Mouse (hold)"], ["Use / place item", "Right Mouse"], ["Hotbar", "1 - 6 / Mouse Wheel"], ["Quick heal", "H"], ["Pause", "Esc"], ["Fullscreen", "F11"]]

@onready var window: Control = %Window
@onready var close_button: BaseButton = %CloseButton
@onready var tab_row: HBoxContainer = %TabRow
@onready var pages: Control = %Pages
@onready var back_button: Button = %BackButton
@onready var title_icon: TextureRect = %TitleIcon

var from_pause := false
var current_tab := "Audio"
var _tab_buttons: Dictionary = {}
var _capturing := ""
var _capture_button: Button = null

func _ready() -> void:
	title_icon.texture = ResourceDatabase.ui_icon(9)
	close_button.pressed.connect(_on_back)
	back_button.pressed.connect(_on_back)
	wire_sounds(back_button)
	var group := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"TabButton"
		b.custom_minimum_size = Vector2(80, 22)
		b.focus_mode = Control.FOCUS_NONE
		var tt: String = t
		b.pressed.connect(func(): _show_tab(tt))
		wire_sounds(b)
		tab_row.add_child(b)
		_tab_buttons[t] = b
	_show_tab("Audio")

func open(data = null) -> void:
	from_pause = String(data) == "from_pause" if data != null else false
	_show_tab(current_tab)
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2(0.94, 0.94)
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "scale", Vector2.ONE, 0.18)
	tw.tween_property(window, "modulate:a", 1.0, 0.12)

func _on_back() -> void:
	AudioManager.play("ui_close")
	_cancel_capture()
	SaveManager.save_settings()
	if from_pause and GameState.in_game:
		Events.open_panel_requested.emit("pause", null)
	else:
		close_requested.emit()

func _show_tab(t: String) -> void:
	current_tab = t
	_tab_buttons[t].button_pressed = true
	_cancel_capture()
	for c in pages.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	pages.add_child(sc)
	match t:
		"Audio": _build_audio(vb)
		"Display": _build_display(vb)
		"Controls": _build_controls(vb)
		"Game": _build_game(vb)

# ---------------------------------------------------------------- tabs
func _row(parent: Control, label: String, hint := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 120
	if hint != "":
		l.tooltip_text = hint
		l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	parent.add_child(h)
	return h

func _header(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"LabelGold"
	parent.add_child(l)

func _build_audio(vb: VBoxContainer) -> void:
	_header(vb, "VOLUME")
	for pair in [["master", "Master"], ["music", "Music"], ["sfx", "Sound Effects"], ["ambient", "Ambience"]]:
		var key: String = pair[0]
		var h := _row(vb, pair[1])
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = float(SaveManager.settings.get(key, 1.0))
		s.custom_minimum_size = Vector2(170, 14)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		var pct := Label.new()
		pct.text = "%d%%" % int(round(s.value * 100))
		pct.custom_minimum_size.x = 36
		pct.theme_type_variation = &"LabelSmall"
		s.value_changed.connect(func(v: float):
			pct.text = "%d%%" % int(round(v * 100))
			SaveManager.settings[key] = v
			SaveManager.apply_settings())
		s.drag_ended.connect(func(_c): SaveManager.save_settings(); AudioManager.play("ui_click"))
		h.add_child(s)
		h.add_child(pct)
	var mute := _check(vb, "Mute all sound", "mute")
	mute.tooltip_text = "Silences music, effects and ambience."

func _check(parent: Control, label: String, key: String) -> CheckButton:
	var h := _row(parent, label)
	var c := CheckButton.new()
	c.button_pressed = bool(SaveManager.settings.get(key, false))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool): AudioManager.play("ui_click"); SaveManager.set_setting(key, on))
	h.add_child(c)
	return c

func _build_display(vb: VBoxContainer) -> void:
	_header(vb, "DISPLAY")
	_check(vb, "Fullscreen", "fullscreen")
	_check(vb, "Screen shake", "screen_shake")
	_check(vb, "Show FPS", "show_fps")
	var l := Label.new()
	l.text = "Tip: press F11 to toggle fullscreen at any time."
	l.theme_type_variation = &"LabelDim"
	vb.add_child(l)

func _build_controls(vb: VBoxContainer) -> void:
	_header(vb, "KEY BINDINGS  (click a key to change it)")
	for a in SaveManager.REBINDABLE:
		var action: String = a[0]
		var h := _row(vb, a[1])
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 20)
		b.theme_type_variation = &"ButtonDark"
		b.text = SaveManager.binding_text(action)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _begin_capture(action, b))
		wire_sounds(b)
		h.add_child(b)
	vb.add_child(HSeparator.new())
	for fb in FIXED_BINDS:
		var h2 := _row(vb, fb[0])
		var v := Label.new()
		v.text = fb[1]
		v.theme_type_variation = &"LabelDim"
		h2.add_child(v)
	var rb := Button.new()
	rb.text = "Reset Bindings"
	rb.theme_type_variation = &"ButtonRed"
	rb.custom_minimum_size = Vector2(110, 22)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rb.pressed.connect(func(): SaveManager.reset_keybinds(); _show_tab("Controls"))
	wire_sounds(rb)
	vb.add_child(rb)

func _build_game(vb: VBoxContainer) -> void:
	_header(vb, "TUTORIAL")
	if GameState.in_game:
		var tut: Dictionary = GameState.tutorial
		var active := not bool(tut.get("done", false)) and not bool(tut.get("skipped", false))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		vb.add_child(h)
		var st := Label.new()
		st.text = "Status: " + ("in progress" if active else ("skipped" if bool(tut.get("skipped", false)) else "completed"))
		st.custom_minimum_size.x = 160
		h.add_child(st)
		if active:
			h.add_child(_small_button("Skip Tutorial", "ButtonDark", func():
				GameState.tutorial["skipped"] = true
				GameState.tutorial["done"] = true
				Events.tutorial_changed.emit()
				_show_tab("Game")))
		h.add_child(_small_button("Replay Tutorial", "Button", func():
			GameState.tutorial = {"step": 0, "done": false, "skipped": false}
			GameState.quest_state["tutorial_progress"] = 0
			Events.tutorial_changed.emit()
			Events.notify.emit("Tutorial restarted. Talk to Mara!", "info")
			_show_tab("Game")))
	else:
		var l := Label.new()
		l.text = "Tutorial options are available while playing."
		l.theme_type_variation = &"LabelDim"
		vb.add_child(l)
	vb.add_child(HSeparator.new())
	_header(vb, "SAVE DATA")
	var info := Label.new()
	info.theme_type_variation = &"LabelSmall"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 300
	var si := SaveManager.save_info()
	if si.is_empty():
		info.text = "No save file yet."
	else:
		info.text = "Level %d  •  Deepest %dm  •  $%s  •  Played %s" % [int(si.level), int(si.depth), ResourceDatabase.fmt_num(int(si.coins)), _fmt_play(float(si.play_time))]
	vb.add_child(info)
	var rs := _small_button("Reset Save...", "ButtonRed", _reset_save_step1)
	rs.disabled = not SaveManager.has_save() and not GameState.in_game
	vb.add_child(rs)

func _small_button(text: String, variation: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = StringName(variation)
	b.custom_minimum_size = Vector2(110, 22)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	wire_sounds(b)
	return b

static func _fmt_play(sec: float) -> String:
	var m := int(sec / 60.0)
	if m < 60:
		return "%dm" % m
	return "%dh %02dm" % [m / 60, m % 60]

func _reset_save_step1() -> void:
	make_confirm(self, "Reset Save?", "This starts DeepMine over from the beginning. Your level, coins, skills and collection will be reset.", _reset_save_step2, "Continue", "ButtonRed")

func _reset_save_step2() -> void:
	make_confirm(self, "Are you absolutely sure?", "Last chance! Your current save will be moved aside (kept as a backup file in the save folder) and a fresh game will start next time.", _do_reset_save, "Reset Save", "ButtonRed")

func _do_reset_save() -> void:
	SaveManager.reset_save()
	Events.notify.emit("Save reset.", "warn")
	save_reset.emit()
	if GameState.in_game:
		GameState.in_game = false
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	else:
		_show_tab("Game")

# ---------------------------------------------------------------- key capture
func _begin_capture(action: String, b: Button) -> void:
	_cancel_capture()
	_capturing = action
	_capture_button = b
	b.text = "Press a key..."
	b.theme_type_variation = &"ButtonGold"

func _cancel_capture() -> void:
	if _capturing != "" and is_instance_valid(_capture_button):
		_capture_button.text = SaveManager.binding_text(_capturing)
		_capture_button.theme_type_variation = &"ButtonDark"
	_capturing = ""
	_capture_button = null

func _input(event: InputEvent) -> void:
	if _capturing == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_capture()
			return
		var ev := InputEventKey.new()
		ev.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		ev.device = -1
		_apply_capture(ev)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		get_viewport().set_input_as_handled()
		var mb := InputEventMouseButton.new()
		mb.button_index = event.button_index
		mb.device = -1
		_apply_capture(mb)

func _apply_capture(ev: InputEvent) -> void:
	var action := _capturing
	SaveManager.rebind(action, ev)
	AudioManager.play("ui_click")
	_capturing = ""
	if is_instance_valid(_capture_button):
		_capture_button.text = SaveManager.binding_text(action)
		_capture_button.theme_type_variation = &"ButtonDark"
	_capture_button = null

# ---------------------------------------------------------------- shared static helpers
## Adds hover/click sounds to a button.
static func wire_sounds(b: BaseButton) -> void:
	b.mouse_entered.connect(func(): AudioManager.play("ui_hover", -10.0))
	b.pressed.connect(func(): AudioManager.play("ui_click"))

## Simple modal confirmation dialog built in code (used when no UIRoot.show_confirm is available).
static func make_confirm(parent: Control, title: String, text: String, on_yes: Callable, yes_text := "Yes", yes_variation := "ButtonGreen") -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(250, 0)
	root.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = &"LabelTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 230
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	vb.add_child(h)
	var no := Button.new()
	no.text = "Cancel"
	no.theme_type_variation = &"ButtonDark"
	no.custom_minimum_size = Vector2(80, 24)
	var yes := Button.new()
	yes.text = yes_text
	yes.theme_type_variation = StringName(yes_variation)
	yes.custom_minimum_size = Vector2(80, 24)
	h.add_child(no)
	h.add_child(yes)
	wire_sounds(no)
	wire_sounds(yes)
	no.pressed.connect(root.queue_free)
	yes.pressed.connect(func():
		root.queue_free()
		on_yes.call())
	parent.add_child(root)
	# centre after layout
	pc.reset_size()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pc.pivot_offset = pc.size * 0.5
	pc.scale = Vector2(0.9, 0.9)
	pc.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(pc, "scale", Vector2.ONE, 0.15)
	no.grab_focus()
	return root

func _capture_setup(args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	open(null)
	if args.size() > 0:
		_show_tab(String(args[0]))
