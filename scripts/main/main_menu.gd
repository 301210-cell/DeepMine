extends Control
## Main menu: animated mine-entrance scene (cart rolling out of the mine along the track,
## flickering lanterns, crystal sparkles, dust, bobbing logo) with Continue / New Game /
## Settings / Credits / Quit.

const LoadingScreenScript = preload("res://scripts/main/loading_screen.gd")
const SettingsPanel = preload("res://scripts/ui/panels/settings_panel.gd")
const SETTINGS_SCENE := "res://scenes/ui/panels/SettingsPanel.tscn"
const LOADING_SCENE := "res://scenes/main/LoadingScreen.tscn"
const CART_SPEED := 46.0     # px per second along the track
const CART_PAUSE := 1.4      # seconds hidden in the mine between runs

@onready var stage: Control = %Stage
@onready var cart: Sprite2D = %Cart
@onready var logo: TextureRect = %Logo
@onready var glows: Node2D = %Glows
@onready var continue_button: Button = %ContinueButton
@onready var continue_info: Label = %ContinueInfo
@onready var new_button: Button = %NewButton
@onready var settings_button: Button = %SettingsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_box: Control = %MenuBox
@onready var error_label: Label = %ErrorLabel
@onready var version_label: Label = %VersionLabel
@onready var overlay: Control = %Overlay
@onready var fade: ColorRect = %Fade

var time := 0.0
var cart_t := 0.0
var cart_wait := 0.0
var cart_frames: Array[AtlasTexture] = []
var arc_len := 1.0
var _leaving := false

func _ready() -> void:
	if theme == null and ResourceLoader.exists("res://scripts/ui/ui_theme.gd"):
		theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	get_tree().paused = false
	GameState.in_game = false
	GameState.ui_blocking = false
	resized.connect(_fit_stage)
	_fit_stage()
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = ResourceDatabase.tex("res://assets/backgrounds/menu_cart.png")
		at.region = Rect2(64 * i, 0, 64, 48)
		cart_frames.append(at)
	cart.texture = cart_frames[0]
	arc_len = _measure_arc()
	cart_t = 0.35
	continue_button.pressed.connect(_on_continue)
	new_button.pressed.connect(_on_new)
	settings_button.pressed.connect(_on_settings)
	credits_button.pressed.connect(_on_credits)
	quit_button.pressed.connect(_on_quit)
	for b in [continue_button, new_button, settings_button, credits_button, quit_button]:
		SettingsPanel.wire_sounds(b)
	version_label.text = "v%s  •  Godot %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), Engine.get_version_info().string.get_slice("-", 0)]
	_refresh_continue()
	error_label.visible = SaveManager.last_error != ""
	error_label.text = SaveManager.last_error
	AudioManager.play_music("menu")
	AudioManager.play_ambience("cave")
	# intro animation
	fade.color.a = 1.0
	menu_box.modulate.a = 0.0
	menu_box.position.x -= 30
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(menu_box, "modulate:a", 1.0, 0.6).set_delay(0.25)
	tw.parallel().tween_property(menu_box, "position:x", menu_box.position.x + 30, 0.5).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(continue_button if not continue_button.disabled else new_button).grab_focus()

func _fit_stage() -> void:
	var s := maxf(size.x / 640.0, size.y / 360.0)
	stage.scale = Vector2(s, s)
	stage.position = (size - Vector2(640, 360) * s) * 0.5

func _refresh_continue() -> void:
	var has := SaveManager.has_save()
	continue_button.disabled = not has
	var info := SaveManager.save_info() if has else {}
	if info.is_empty():
		continue_info.text = "No saved game"
	else:
		continue_info.text = "Lv %d  •  %dm  •  %s" % [int(info.level), int(info.depth), SettingsPanel._fmt_play(float(info.play_time))]

# ---------------------------------------------------------------- animation
func _measure_arc() -> float:
	var l := 0.0
	var prev := LoadingScreenScript.bezier(0.0)
	for i in range(1, 65):
		var p := LoadingScreenScript.bezier(i / 64.0)
		l += p.distance_to(prev)
		prev = p
	return l

func _process(delta: float) -> void:
	time += delta
	logo.position.y = 6.0 + round(sin(time * 1.5) * 2.0)
	for g in glows.get_children():
		g.modulate.a = 0.6 + 0.22 * sin(time * 6.5 + g.position.x * 0.37) + 0.12 * sin(time * 15.0 + g.position.y)
	# cart rolls out of the mine portal along the track, then respawns
	if cart_wait > 0.0:
		cart_wait -= delta
		cart.modulate.a = 0.0
		return
	var speed_scale := lerpf(0.45, 1.0, smoothstep(0.0, 0.6, cart_t))
	cart_t += delta * CART_SPEED * speed_scale / arc_len
	if cart_t >= 1.0:
		cart_t = 0.0
		cart_wait = CART_PAUSE
		return
	var p := LoadingScreenScript.bezier(cart_t)
	var d := LoadingScreenScript.bezier(minf(cart_t + 0.01, 1.0)) - LoadingScreenScript.bezier(maxf(cart_t - 0.01, 0.0))
	cart.position = p.round()
	cart.rotation = atan2(d.y, d.x) * 0.6
	var s := lerpf(0.45, 1.05, smoothstep(0.0, 0.75, cart_t))
	cart.scale = Vector2(s, s)
	cart.modulate.a = clampf(cart_t / 0.06, 0.0, 1.0) * clampf((1.0 - cart_t) / 0.05, 0.0, 1.0)
	cart.texture = cart_frames[int(time * 9.0) % 2]

# ---------------------------------------------------------------- buttons
func _on_continue() -> void:
	if not SaveManager.has_save():
		return
	_start("continue")

func _on_new() -> void:
	if SaveManager.has_save():
		var go := func():
			SaveManager.reset_save()
			_start("new")
		SettingsPanel.make_confirm(overlay, "Start a New Game?", "Your current save will be moved aside as a backup file and a brand-new mine will be generated.", go, "New Game", "ButtonGreen")
	else:
		_start("new")

func _start(mode: String) -> void:
	if _leaving:
		return
	_leaving = true
	LoadingScreenScript.next_mode = mode
	AudioManager.stop_music(0.6)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file(LOADING_SCENE)

func _on_settings() -> void:
	var p: Control = load(SETTINGS_SCENE).instantiate()
	overlay.add_child(p)
	p.open(null)
	p.close_requested.connect(func():
		p.queue_free()
		settings_button.grab_focus())
	p.save_reset.connect(_refresh_continue)

func _on_credits() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var pc := PanelContainer.new()
	root.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pc.add_child(vb)
	var t := Label.new()
	t.text = "Credits"
	t.theme_type_variation = &"LabelTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for line in [
		["DeepMine — Underground Mining Simulator", ""],
		["Made with Godot 4", "LabelGold"],
		["", ""],
		["Game design, code & systems", "LabelDim"],
		["The DeepMine team", ""],
		["Pixel art, fonts & UI", "LabelDim"],
		["Procedurally generated in-engine (tools/assetgen)", ""],
		["Music, sound effects & ambience", "LabelDim"],
		["Synthesized in-engine (tools/assetgen)", ""],
		["", ""],
		["Thanks for playing — see you in the deep!", "LabelSmall"],
	]:
		var l := Label.new()
		l.text = line[0]
		if line[1] != "":
			l.theme_type_variation = StringName(line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(90, 24)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	SettingsPanel.wire_sounds(close)
	close.pressed.connect(func():
		root.queue_free()
		credits_button.grab_focus())
	vb.add_child(close)
	overlay.add_child(root)
	pc.reset_size()
	pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	close.grab_focus()

func _on_quit() -> void:
	SaveManager.save_settings()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	await tw.finished
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveManager.set_setting("fullscreen", not bool(SaveManager.settings.get("fullscreen", false)))
	elif event.is_action_pressed("pause") and overlay.get_child_count() > 0:
		var top := overlay.get_child(overlay.get_child_count() - 1)
		if top.has_signal("close_requested"):
			top.emit_signal("close_requested")
		else:
			top.queue_free()
		get_viewport().set_input_as_handled()

func _capture_setup(_args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).create_timer(1.2).timeout
	cart_t = 0.62
	cart_wait = 0.0
