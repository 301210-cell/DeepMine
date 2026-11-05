extends SceneTree
## Loads every script and scene to surface parse/compile errors.
func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_walk(dir.path_join(sub), out)
func _initialize() -> void:
	await process_frame
	var files: Array = []
	for root_dir in ["res://scripts", "res://scenes"]:
		_walk(root_dir, files)
	var bad := 0
	for f in files:
		if f.ends_with("setup_input_map.gd") or f.ends_with("build_theme.gd"):
			continue
		var r = load(f)
		if r == null:
			bad += 1
			print("FAILED: ", f)
	print("checked ", files.size(), " files, failed ", bad)
	quit()
