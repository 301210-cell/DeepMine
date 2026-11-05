extends SceneTree
## Screenshot helper. Loads a scene, waits N frames, saves the window image, quits.
## If the scene root has `_capture_setup(args: Array)`, it is called first (use it to open panels / fill demo data).
## Run via: bash tools/capture.sh res://path/Scene.tscn C:/abs/out.png [frames] [args...]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("capture: need <scene> <out.png>")
		quit(1)
		return
	var frames := int(args[2]) if args.size() > 2 else 40
	# Never read or write the player's real save files from tests or screenshot runs.
	root.get_node("SaveManager").use_test_saves()
	var packed: PackedScene = load(args[0])
	if packed == null:
		print("capture: cannot load ", args[0])
		quit(1)
		return
	var sc := packed.instantiate()
	root.add_child(sc)
	await process_frame
	await process_frame
	if sc.has_method("_capture_setup"):
		sc.call("_capture_setup", args.slice(3))
	for i in frames:
		await process_frame
	await create_timer(1.5).timeout
	var img := root.get_texture().get_image()
	img.save_png(args[1])
	print("capture saved ", args[1], " ", img.get_size())
	quit()
