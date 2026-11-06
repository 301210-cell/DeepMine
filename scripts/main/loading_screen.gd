extends Control
## Loading screen on the animated title backdrop (menu_backdrop.gd): pickaxes sway, crystals and
## gems shine, lanterns flicker. Shows "Loading... X%" above a golden bar in a dark frame, the
## tagline and rotating tips. Drives res://scripts/main/game_loader.gd:
##   start(mode), poll() -> float 0..1, is_done(), error_text(), game_scene() -> PackedScene
## Set `next_mode` (static, via preload of this script) before changing to this scene.

static var next_mode := "new"

const LOADER_PATH := "res://scripts/main/game_loader.gd"
const TIPS := [
	"Stronger pickaxes can break tougher rocks.",
	"Remember to check your backpack capacity.",
	"Rare geodes may contain valuable gems.",
	"Explore side tunnels for hidden treasures.",
	"Skill points can unlock powerful abilities.",
	"Smelt raw ore into bars to sell it for much more.",
	"Elevator checkpoints save you the long climb back up.",
	"Place ladders with Right Mouse so you never get stuck.",
	"Cracked walls often hide secret caches.",
	"Thermal Boots let you walk on Magma Crust safely.",
	"Events like Crystal Surge make rare ore appear for a while.",
	"Polished gems sell for more than twice the raw price.",
	"Open geodes at the surface to reveal what's inside.",
	"Cave Sense highlights ore through the darkness.",
	"Mine carts are the fastest way through long tunnels.",
]

@onready var bar: ProgressBar = %Bar
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel
@onready var error_box: Control = %ErrorBox
@onready var error_label: Label = %ErrorLabel
@onready var back_button: Button = %BackButton
@onready var fade: ColorRect = %Fade

var loader = null
var shown := 0.0
var tip_i := 0
var tip_t := 0.0
var finishing := false
var failed := false
var stub_t := 0.0

func _ready() -> void:
	if theme == null and ResourceLoader.exists("res://scripts/ui/ui_theme.gd"):
		theme = load("res://scripts/ui/ui_theme.gd").get_theme()
	get_tree().paused = false
	style_title_bar(bar)
	back_button.pressed.connect(_back_to_menu)
	error_box.visible = false
	tip_i = randi() % TIPS.size()
	tip_label.text = "Tip: " + TIPS[tip_i]
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, 0.35)
	if ResourceLoader.exists(LOADER_PATH):
		loader = load(LOADER_PATH)
		loader.start(next_mode)

func _process(delta: float) -> void:
	tip_t += delta
	if tip_t > 3.6:
		tip_t = 0.0
		tip_i = (tip_i + 1) % TIPS.size()
		var tw := create_tween()
		tw.tween_property(tip_label, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): tip_label.text = "Tip: " + TIPS[tip_i])
		tw.tween_property(tip_label, "modulate:a", 1.0, 0.25)
	if failed:
		return
	var target := 0.0
	var done := false
	if loader:
		target = clampf(float(loader.poll()), 0.0, 1.0)
		done = bool(loader.is_done())
		var err := String(loader.error_text())
		if err != "":
			_fail(err)
			return
	else:
		stub_t += delta
		target = clampf(stub_t / 2.5, 0.0, 1.0)
		done = target >= 1.0
	if done:
		target = 1.0
	shown = minf(move_toward(shown, target, delta * (0.9 if not done else 2.2)), target)
	bar.value = shown * 100.0
	percent_label.text = "Loading... %d%%" % int(floor(shown * 100.0))
	if done and shown >= 0.999 and not finishing:
		finishing = true
		_finish()

func _finish() -> void:
	var scene: PackedScene = loader.game_scene() if loader else null
	if scene == null:
		_fail("The game scene isn't available yet (GameLoader not found).")
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_packed(scene)

func _fail(msg: String) -> void:
	failed = true
	error_box.visible = true
	error_label.text = msg
	percent_label.text = "Loading failed"
	AudioManager.play("ui_error")

func _back_to_menu() -> void:
	AudioManager.play("ui_click")
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")

func _capture_setup(args: Array) -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	# Freeze at a given progress for screenshots, e.g. capture arg "0.78"
	if args.size() > 0:
		failed = true
		shown = float(args[0])
		bar.value = shown * 100.0
		percent_label.text = "Loading... %d%%" % int(floor(shown * 100.0))
		fade.color.a = 0.0

## Golden fill inside a dark rounded frame (pixel-art 9-slices from tools/assetgen/gen_title.gd).
static func style_title_bar(b: ProgressBar) -> void:
	var frame := StyleBoxTexture.new()
	frame.texture = ResourceDatabase.tex("res://assets/ui/title_bar_frame.png")
	frame.texture_margin_left = 6
	frame.texture_margin_right = 6
	frame.texture_margin_top = 6
	frame.texture_margin_bottom = 6
	var fill := StyleBoxTexture.new()
	fill.texture = ResourceDatabase.tex("res://assets/ui/title_bar_fill.png")
	fill.texture_margin_left = 4
	fill.texture_margin_right = 4
	fill.texture_margin_top = 4
	fill.texture_margin_bottom = 4
	fill.expand_margin_left = -3
	fill.expand_margin_right = -3
	fill.expand_margin_top = -3
	fill.expand_margin_bottom = -3
	b.add_theme_stylebox_override("background", frame)
	b.add_theme_stylebox_override("fill", fill)
